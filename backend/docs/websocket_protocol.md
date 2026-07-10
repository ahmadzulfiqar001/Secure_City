# SecureCity WebSocket Protocol

One gateway, one endpoint, all live features. This document is the contract
a client (Flutter app, admin panel, or `/ws-test`) must follow.

## Connecting

```
ws://<host>/ws?token=<JWT access token>
wss://<host>/ws?token=<JWT access token>   (production, behind TLS)
```

Browsers cannot set custom headers on a WebSocket handshake, so the access
token (the same short-lived JWT returned by `POST /api/v1/auth/login`) is
passed as a query parameter. There is no separate WS login step.

- Missing or invalid token → the server closes the handshake with code
  `4401` before accepting the connection. There is no data frame in this
  case — treat any close before a successful `onopen` as an auth failure
  and do not silently retry with the same token; get a fresh one first
  (e.g. via `/api/v1/auth/refresh`) if it may have expired.
- On success, the server registers the connection under the user's id and
  role and the connection is live immediately — no handshake ack message
  is sent.

## Message envelope

Every server → client message is JSON:

```json
{ "event": "alert.new", "data": { ... }, "ts": "2026-07-09T04:44:45.123456+00:00" }
```

`event` is one of the types below; `data` is event-specific; `ts` is the
server's UTC timestamp when the message was sent.

Client → server messages are JSON with an `event` field. The only message
a client is expected to send is a heartbeat reply (see below).

## Event types

| event | audience | fired when |
|---|---|---|
| `alert.new` | all roles | a new alert is created (`POST /api/v1/alerts`) |
| `alert.updated` | all roles | an alert is acknowledged, resolved, flagged false-positive, or deleted |
| `camera.status` | all roles | a camera's `status` field actually changes (`PUT /api/v1/cameras/{id}`) |
| `dashboard.tick` | admin, operator | every 20s — a fresh `/api/v1/analytics/overview` snapshot |
| `sos.triggered` | admin, operator | a citizen creates an SOS event (`POST /api/v1/sos`) |
| `notification.new` | the target user only | a notification row is created for them (e.g. staff notified of an SOS) |

"all roles" means every currently-connected authenticated user, since every
seeded role (`admin`, `operator`, `citizen`) already holds `alerts:read` /
`cameras:read`. `notification.new` is always addressed to a single user —
it is never broadcast.

## Heartbeat

The server sends `{"event": "ping", "data": {}}` every **30 seconds**. The
client must reply with:

```json
{ "event": "pong" }
```

If the server receives no pong within **75 seconds** of the last one (i.e.
~2 missed beats), it closes the connection with code `4000`. Clients should
treat this the same as any other unexpected close: reconnect (see below).
Clients do not need to send unsolicited pings — the server-initiated ping
is the only heartbeat signal in this protocol.

## Reconnection protocol

On any close that wasn't requested by the client itself, reconnect with
**exponential backoff**, starting at 1 second and doubling up to a 30
second cap:

```
attempt 0: wait 1s
attempt 1: wait 2s
attempt 2: wait 4s
attempt 3: wait 8s
attempt 4: wait 16s
attempt 5+: wait 30s (capped)
```

Reset the attempt counter to 0 as soon as a connection successfully opens.
Always re-send the current (possibly refreshed) access token as the
`token` query param on every reconnect attempt — a token that expired
while disconnected will otherwise fail with `4401` in a loop, so a client
that sees repeated `4401` closes should refresh its access token before
retrying rather than backing off indefinitely on a stale one.

Reference implementation: see `_PAGE` in
`backend/app/api/v1/ws_test.py` (`connect()` / `scheduleReconnect()`).

## Dev test page

`GET /ws-test` (not mounted when `SECURECITY_ENVIRONMENT=production`) is a
self-contained HTML/JS page: paste an access token, click Connect, and
watch incoming events log live. Opening it in two tabs and creating an
alert via Swagger (`POST /api/v1/alerts`) is the standard way to verify
broadcasts are actually reaching multiple clients.
