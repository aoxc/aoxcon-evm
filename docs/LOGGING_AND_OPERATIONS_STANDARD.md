# AOXCORE Logging and Operations Standard

## Purpose
This standard defines how AOXCORE services produce logs and how teams consume logs for governance, security, and incident response.

## Core Requirements

### 1) Structured Logging
All backend logs must use structured JSON with the following minimum fields:
- `timestamp`
- `level`
- `service`
- `event`
- `requestId` (when request-scoped)
- `message`

### 2) Event Categories
Use a constrained event taxonomy:
- `api.request`
- `api.response`
- `validation.failed`
- `sentinel.analysis`
- `sentinel.degraded`
- `service.health`
- `service.error`

### 3) Correlation
- Every HTTP request gets a request ID.
- The request ID is returned as `x-request-id`.
- All logs emitted during request processing must include this ID.

### 4) Security and Privacy
- Never log private keys, raw secrets, or full credential payloads.
- Mask sensitive values before logging.
- Keep external error details operator-safe in API responses.

### 5) Operational Use
- Track p95 latency and non-2xx error rate from `api.response` logs.
- Create alerting on `sentinel.degraded` and repeated `service.error` events.
- Use log-derived incident timelines during postmortem.

## Governance Alignment
The logging model is part of DAO operational governance and supports:
- deterministic forensic reconstruction,
- auditable decision flow,
- controlled AI intervention records.
