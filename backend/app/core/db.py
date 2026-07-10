"""SQLAlchemy 2 engine/session setup.

SQLite now (per A2 — "swappable to Postgres/Mongo" later): the
repository layer built on top of `get_db()` is the only thing that would
need to change, not every route.
"""
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import settings

connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency — one session per request, always closed after."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
