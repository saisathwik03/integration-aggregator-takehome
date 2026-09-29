from app.requests import create_request, get_request
from app.worker import fetch_token


class FakeOpenBao:
    def __init__(self, result=None):
        self.result = result

    def read_credential(self, name):
        return self.result


def test_fetch_token_credential_not_found():
    request_id = create_request()

    openbao = FakeOpenBao()

    fetch_token(
        request_id,
        "test-provider",
        "123",
        openbao,
    )

    request_data = get_request(request_id)

    assert request_data["status"] == "failed"
    assert request_data["result"] is None
    assert request_data["error"] == "Credential not found"


def test_fetch_token_success():
    request_id = create_request()

    openbao = FakeOpenBao(
        {
            "data": {
                "access_token": "test-token",
            }
        }
    )

    fetch_token(
        request_id,
        "test-provider",
        "123",
        openbao,
    )

    request_data = get_request(request_id)

    assert request_data["status"] == "completed"
    assert request_data["result"] == {
        "data": {
            "access_token": "test-token",
        }
    }