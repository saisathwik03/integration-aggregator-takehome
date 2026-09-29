import secrets
from concurrent.futures import ThreadPoolExecutor

from fastapi import FastAPI, HTTPException, Response

from app.models import ProviderRequest
from app.openbao import OpenBaoClient
from app.requests import create_request, get_request
from app.state import delete_state, get_state, save_state
from app.worker import fetch_token


app = FastAPI(
    title="Integration Aggregator",
)


openbao = OpenBaoClient()

executor = ThreadPoolExecutor(
    max_workers=4
)


@app.get("/health")
def health():
    return {
        "status": "ok",
    }


@app.post("/providers")
def register_provider(
    provider: ProviderRequest,
):
    data = {
        "name": provider.name,
        "provider": provider.provider,
        "client_id": provider.client_id,
        "client_secret": provider.client_secret,
        "provider_options": provider.provider_options,
    }

    openbao.write(
        "oauth2/servers/" + provider.name,
        data,
    )

    return {
        "name": provider.name,
        "provider": provider.provider,
        "status": "registered",
    }


@app.post(
    "/providers/{provider}/users/{user}/connect"
)
def connect_user(
    provider: str,
    user: str,
):
    state = secrets.token_urlsafe(32)

    save_state(
        state,
        provider,
        user,
    )

    result = openbao.generate_auth_url(
        provider,
        "http://127.0.0.1:8000/callback",
        state,
    )

    return {
        "authorization_url": result["data"]["url"],
        "state": state,
    }


@app.get("/callback")
def oauth_callback(
    code: str,
    state: str,
):
    state_data = get_state(state)

    if state_data is None:
        raise HTTPException(
            status_code=400,
            detail="Invalid or expired state",
        )

    provider = state_data["provider"]
    user = state_data["user"]

    delete_state(state)

    credential_name = provider + ":" + user

    try:
        openbao.save_credential(
            credential_name,
            code,
            provider,
            "http://127.0.0.1:8000/callback",
        )

    except RuntimeError:
        raise HTTPException(
            status_code=502,
            detail="OAuth provider rejected the authorization code",
        )

    return {
        "provider": provider,
        "user": user,
        "status": "connected",
    }


@app.get("/requests/{request_id}")
def get_request_status(
    request_id: str,
):
    request_data = get_request(request_id)

    if request_data is None:
        raise HTTPException(
            status_code=404,
            detail="Request not found",
        )

    return request_data


@app.get("/{provider}/{user}")
def get_token(
    provider: str,
    user: str,
    response: Response,
):
    request_id = create_request()

    executor.submit(
        fetch_token,
        request_id,
        provider,
        user,
        openbao,
    )

    response.status_code = 202
    response.headers["Location"] = (
        "/requests/" + request_id
    )

    return {
        "request_id": request_id,
        "status": "pending",
    }
