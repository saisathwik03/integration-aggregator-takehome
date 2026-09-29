import http from "k6/http";
import { check } from "k6";

export const options = {
  vus: 3,
  duration: "30s",

  thresholds: {
    http_req_failed: ["rate<0.01"],
  },
};

export default function () {
  const response = http.get(
    "http://127.0.0.1:8000/ci-provider/ci-user"
  );

  check(response, {
    "status is 202": (r) => r.status === 202,
    "request id returned": (r) =>
      r.json("request_id") !== undefined,
  });
}
