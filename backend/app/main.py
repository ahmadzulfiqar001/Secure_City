"""SecureCity backend — FastAPI app factory.

Module 01 laid the core plumbing (settings, logging, error handlers, DB).
Module 02 added Auth + RBAC. Module 03 added the REST CRUD layer. Module 04
adds the realtime WebSocket gateway — one router per module, included here.
"""
import asyncio
import contextlib
import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from sqlalchemy import text
from sqlalchemy.orm import Session

from slowapi import _rate_limit_exceeded_handler

from .api.v1.alerts import router as alerts_router
from .api.v1.analytics import router as analytics_router
from .api.v1.auth import router as auth_router
from .api.v1.cameras import router as cameras_router
from .api.v1.contacts import router as contacts_router
from .api.v1.engine import router as engine_router
from .api.v1.incidents import router as incidents_router
from .api.v1.notifications import router as notifications_router
from .api.v1.sos import router as sos_router
from .api.v1.ws import router as ws_router
from .api.v1.ws_test import router as ws_test_router
from .core.config import settings
from .core.db import SessionLocal, get_db
from .core.errors import register_error_handlers
from .core.logging import configure_logging
from .core.rate_limit import limiter
from .core.ws_events import DASHBOARD_TICK, STAFF_ROLES
from .core.ws_manager import manager as ws_manager

log = logging.getLogger("securecity.main")

DASHBOARD_TICK_SECONDS = 20


async def _dashboard_tick_loop() -> None:
    """Periodically pushes a fresh analytics snapshot to connected staff —
    the live-refreshing dashboard.tick event. Uses its own DB session since
    it runs outside any request lifecycle."""
    from .services.analytics_service import AnalyticsService

    while True:
        await asyncio.sleep(DASHBOARD_TICK_SECONDS)
        db = SessionLocal()
        try:
            overview = AnalyticsService(db).overview()
            await ws_manager.broadcast(DASHBOARD_TICK, overview.model_dump(mode="json"), roles=STAFF_ROLES)
        except Exception:
            log.exception("dashboard tick failed")
        finally:
            db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    ws_manager.bind_loop(asyncio.get_running_loop())
    tick_task = asyncio.create_task(_dashboard_tick_loop())
    log.info("realtime layer started", extra={"tick_seconds": DASHBOARD_TICK_SECONDS})
    yield
    tick_task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await tick_task


def create_app() -> FastAPI:
    configure_logging(settings.log_level)

    if settings.jwt_secret == "dev-only-insecure-secret-change-me":
        log.warning("SECURECITY_JWT_SECRET is on its insecure default — set a real one before deploying")
    if settings.engine_key == "dev-only-engine-key-change-me":
        log.warning("SECURECITY_ENGINE_KEY is on its insecure default — set a real one before deploying")

    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        description="AI-powered urban safety platform — REST + WebSocket API.",
        lifespan=lifespan,
    )

    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    app.add_middleware(SlowAPIMiddleware)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_error_handlers(app)
    app.include_router(auth_router)
    app.include_router(cameras_router)
    app.include_router(alerts_router)
    app.include_router(incidents_router)
    app.include_router(notifications_router)
    app.include_router(contacts_router)
    app.include_router(sos_router)
    app.include_router(analytics_router)
    app.include_router(engine_router)
    app.include_router(ws_router)

    if settings.environment != "production":
        app.include_router(ws_test_router)

    settings.static_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/static", StaticFiles(directory=str(settings.static_dir)), name="static")

    @app.get("/health", tags=["system"])
    def health(db: Session = Depends(get_db)) -> dict:
        """Real check, not a static 200 — actually queries the database."""
        try:
            db.execute(text("SELECT 1"))
            db_ok = True
        except Exception:
            log.exception("health check: database query failed")
            db_ok = False

        return {
            "status": "ok" if db_ok else "degraded",
            "app": settings.app_name,
            "environment": settings.environment,
            "database": "ok" if db_ok else "unreachable",
        }

    log.info("app created", extra={"environment": settings.environment})
    return app


app = create_app()
