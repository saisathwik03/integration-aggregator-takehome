from app.requests import update_request


def fetch_token(
    request_id,
    provider,
    user,
    openbao,
):
    credential_name = provider + ":" + user

    try:
        result = openbao.read_credential(
            credential_name
        )

        if result is None:
            update_request(
                request_id,
                "failed",
                error="Credential not found",
            )
            return

        update_request(
            request_id,
            "completed",
            result=result,
        )

    except RuntimeError:
        update_request(
            request_id,
            "failed",
            error="Failed to retrieve credential",
        )