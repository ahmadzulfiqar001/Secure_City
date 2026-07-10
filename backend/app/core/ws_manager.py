"""Tracks live WebSocket connections and pushes events to them.

Domain services (AlertService, SOSService, ...) run inside FastAPI's sync
threadpool because they use a sync SQLAlchemy session. To broadcast from
that thread onto the asyncio event loop the WebSocket connections actually
live on, the *_sync helpers below use `run_coroutine_threadsafe` against
the loop captured at startup (see main.py's lifespan) — a fire-and-forget
bridge so a broadcast never blocks the HTTP response that triggered it.
"""
import asyncio
import json
import logging
from datetime import datetime, timezone

from fastapi import WebSocket

log = logging.getLogger("securecity.ws")


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[WebSocket, dict] = {}
        self.loop: asyncio.AbstractEventLoop | None = None

    def bind_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self.loop = loop

    async def connect(self, websocket: WebSocket, user_id: int, role: str) -> None:
        await websocket.accept()
        self._connections[websocket] = {
            "user_id": user_id,
            "role": role,
            "last_pong": datetime.now(timezone.utc),
        }
        log.info("ws connected user_id=%s role=%s total=%d", user_id, role, len(self._connections))

    def disconnect(self, websocket: WebSocket) -> None:
        info = self._connections.pop(websocket, None)
        if info:
            log.info("ws disconnected user_id=%s total=%d", info["user_id"], len(self._connections))

    def touch_pong(self, websocket: WebSocket) -> None:
        if websocket in self._connections:
            self._connections[websocket]["last_pong"] = datetime.now(timezone.utc)

    def last_pong(self, websocket: WebSocket) -> datetime | None:
        info = self._connections.get(websocket)
        return info["last_pong"] if info else None

    @staticmethod
    def _envelope(event: str, data: dict) -> str:
        return json.dumps({"event": event, "data": data, "ts": datetime.now(timezone.utc).isoformat()})

    async def _send(self, websocket: WebSocket, payload: str) -> None:
        try:
            await websocket.send_text(payload)
        except Exception:
            self.disconnect(websocket)

    async def broadcast(self, event: str, data: dict, roles: list[str] | None = None) -> None:
        payload = self._envelope(event, data)
        targets = [ws for ws, info in list(self._connections.items()) if roles is None or info["role"] in roles]
        for ws in targets:
            await self._send(ws, payload)

    async def send_to_user(self, user_id: int, event: str, data: dict) -> None:
        payload = self._envelope(event, data)
        targets = [ws for ws, info in list(self._connections.items()) if info["user_id"] == user_id]
        for ws in targets:
            await self._send(ws, payload)

    def broadcast_sync(self, event: str, data: dict, roles: list[str] | None = None) -> None:
        if self.loop is None:
            return
        asyncio.run_coroutine_threadsafe(self.broadcast(event, data, roles), self.loop)

    def send_to_user_sync(self, user_id: int, event: str, data: dict) -> None:
        if self.loop is None:
            return
        asyncio.run_coroutine_threadsafe(self.send_to_user(user_id, event, data), self.loop)


manager = ConnectionManager()
