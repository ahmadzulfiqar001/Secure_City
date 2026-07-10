"""Application settings — loaded from environment variables / .env.

Every setting has a safe dev-only default so the app still boots without a
.env present, but anything security-sensitive (jwt_secret, engine_key)
logs a warning if it's still on that default — see main.py's startup hook.
"""
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"), env_file_encoding="utf-8",
        env_prefix="SECURECITY_", extra="ignore",
    )

    app_name: str = "SecureCity Backend"
    environment: str = "development"
    debug: bool = True
    log_level: str = "INFO"

    database_url: str = f"sqlite:///{BASE_DIR / 'securecity.db'}"

    # Where AI-engine-uploaded evidence (snapshots/clips) is saved, served
    # back out under /static.
    static_dir: Path = BASE_DIR / "static"

    # JWT — rebuilt properly as part of the Auth module; kept here since
    # core/config is where every module reads shared settings from.
    jwt_secret: str = "dev-only-insecure-secret-change-me"
    jwt_algorithm: str = "HS256"
    jwt_access_ttl_minutes: int = 15
    jwt_refresh_ttl_days: int = 7

    # Shared secret the ai_engine worker authenticates its POSTs with.
    engine_key: str = "dev-only-engine-key-change-me"

    cors_origins: list[str] = ["*"]

    # OTP delivery — SMTP if configured, otherwise printed to the console.
    # There's no real mail account wired up in this environment, so the
    # console path is what's actually exercised; the SMTP path is real code
    # (see core/email.py), just unexercised without real credentials.
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "no-reply@securecity.pk"
    otp_ttl_minutes: int = 10

    # Password strength policy (register / reset / change).
    password_min_length: int = 8


settings = Settings()
