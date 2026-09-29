# Performance Test Report

## Test Configuration

- Tool: k6
- Endpoint: `GET /ci-provider/ci-user`
- Virtual users: 3
- Duration: 30 seconds
- Environment: Local Minikube deployment
- Application: Integration Aggregator

## Results

| Metric | Result |
|---|---:|
| Requests | 1,494 |
| Throughput | 49.74 requests/sec |
| p50 latency | 51.33 ms |
| p95 latency | 117.04 ms |
| Failed requests | 0% |
| Checks passed | 100% |

## Checks

The performance test verified:

- HTTP status is `202`
- Request ID is returned
- No HTTP request failures occurred

## Notes

The tested endpoint is asynchronous. It queues token retrieval and immediately
returns a request ID rather than waiting for OpenBao token retrieval to finish.

Therefore, the latency measurements represent the request-submission path,
not the end-to-end OpenBao token retrieval completion time.
