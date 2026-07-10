"""The single WebSocket gateway. Auth happens on connect via a `?token=`
query param (browsers can't set custom headers on the WS handshake), then
the connection is registered with the ConnectionManager under the user's
id + role so REST-triggered events can be pushed straight to it.
"""
import asyncio
import json
import logging
from datetime import datetime, timezone

import jwt
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from ...core.db import get_db
from ...core.security import decode_access_token
from ...core.ws_manager import manager

router = APIRouter(tags=["realtime"])

log = logging.getLogger("securecity.ws")

HEARTBEAT_INTERVAL_SECONDS = 30
HEARTBEAT_TIMEOUT_SECONDS = 75  # ~2.5 missed beats before we give up on a silent client


@router.websocket("/ws")
async def ws_gateway(websocket: WebSocket, db: Session = Depends(get_db)):
    from ...models import User  # local import — same reasoning as core/deps.py

    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401)
        return

    try:
        payload = decode_access_token(token)
        if payload.get("type") != "access":
            raise jwt.InvalidTokenError("not an access token")
    except jwt.PyJWTError:
        await websocket.close(code=4401)
        return

    user = db.get(User, int(payload["sub"]))
    if user is None:
        await websocket.close(code=4401)
        return

    role = user.role.name if user.role else "citizen"
    await manager.connect(websocket, user.id, role)

    async def heartbeat() -> None:
        while True:
            await asyncio.sleep(HEARTBEAT_INTERVAL_SECONDS)
            last = manager.last_pong(websocket)
            if last is None:
                return
            age = (datetime.now(timezone.utc) - last).total_seconds()
            if age > HEARTBEAT_TIMEOUT_SECONDS:
                log.info("ws heartbeat timeout user_id=%s", user.id)
                await websocket.close(code=4000)
                return
            await websocket.send_text(
                json.dumps({"event": "ping", "data": {}, "ts": datetime.now(timezone.utc).isoformat()})
            )

    hb_task = asyncio.create_task(heartbeat())
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if msg.get("event") == "pong":
                manager.touch_pong(websocket)
    except WebSocketDisconnect:
        pass
    finally:
        hb_task.cancel()
        manager.disconnect(websocket)
