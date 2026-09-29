from fastapi.testclient import TestClient

import app.main as main


class FakeOpenBao:
    def write(self, path, data):
        return {}

    def generate_auth_url(
        self,
        server,
        redirect_url,
        state,
    ):
        return {
            "data": {
                "url": "https://example.com/oauth"
            }
        }

    def save_credential(
        self,
        name,
        code,
        server,
        redirect_url,
    ):
        return {}

    def read_credential(self, name):
        return None


client = TestClient(main.app)

main.openbao = FakeOpenBao()


def test_health():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok"
    }


def test_register_provider():
    response = client.post(
        "/providers",
        json={
            "name": "test-provider",
            "provider": "github",
            "client_id": "test-client-id",
            "client_secret": "test-client-secret",
        },
    )

    assert response.status_code == 200

    assert response.json() == {
        "name": "test-provider",
        "provider": "github",
        "status": "registered",
    }


def test_connect_user():
    response = client.post(
        "/providers/test-provider/users/123/connect"
    )

    assert response.status_code == 200

    data = response.json()

    assert data["authorization_url"] == (
        "https://example.com/oauth"
    )

    assert "state" in data


def test_async_token_request():
    response = client.get(
        "/test-provider/123"
    )

    assert response.status_code == 202

    data = response.json()

    assert "request_id" in data
    assert data["status"] == "pending"

    assert response.headers["location"].startswith(
        "/requests/"
    )


def test_unknown_request():
    response = client.get(
        "/requests/does-not-exist"
    )

    assert response.status_code == 404

    assert response.json() == {
        "detail": "Request not found"
    }