import threading
import uuid


requests = {}
requests_lock = threading.Lock()


def create_request():
    request_id = str(uuid.uuid4())

    with requests_lock:
        requests[request_id] = {
            "status": "pending",
            "result": None,
            "error": None,
        }

    return request_id


def get_request(request_id):
    with requests_lock:
        return requests.get(request_id)


def update_request(
    request_id,
    status,
    result=None,
    error=None,
):
    with requests_lock:
        if request_id in requests:
            requests[request_id] = {
                "status": status,
                "result": result,
                "error": error,
            }
