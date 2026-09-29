from app.requests import (
    create_request,
    get_request,
    update_request,
)


def test_create_request():
    request_id = create_request()

    request_data = get_request(request_id)

    assert request_data["status"] == "pending"
    assert request_data["result"] is None
    assert request_data["error"] is None


def test_update_request():
    request_id = create_request()

    update_request(
        request_id,
        "completed",
        result={"token": "test-token"},
    )

    request_data = get_request(request_id)

    assert request_data["status"] == "completed"
    assert request_data["result"] == {
        "token": "test-token",
    }
    assert request_data["error"] is None