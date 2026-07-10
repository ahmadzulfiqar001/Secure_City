"""Business logic for the full auth lifecycle — the only layer that
combines repositories + security primitives + email delivery. Routers
stay thin (parse request, call a service method, shape the response).
"""
from sqlalchemy.orm import Session

from ..core.email import send_otp_email
from ..core.errors import AppError, ConflictError, NotFoundError, UnauthorizedError
from ..core.security import (
    create_access_token,
    generate_otp,
    generate_refresh_token,
    hash_password,
    hash_token,
    otp_expiry,
    refresh_token_expiry,
    utcnow,
    verify_password,
)
from ..models import User
from ..repositories.audit_log_repository import AuditLogRepository
from ..repositories.refresh_token_repository import RefreshTokenRepository
from ..repositories.user_repository import UserRepository


class AuthService:
    def __init__(self, db: Session):
        self.db = db
        self.users = UserRepository(db)
        self.tokens = RefreshTokenRepository(db)
        self.audit = AuditLogRepository(db)

    # ── registration / verification ─────────────────────────────────
    def register(self, name: str, email: str, phone: str, password: str, ip: str | None) -> tuple[User, str]:
        if self.users.get_by_email(email):
            raise ConflictError("An account with this email already exists")

        role = self.users.get_role("citizen")
        user = self.users.create(name, email, phone, hash_password(password), role)

        code = self._issue_otp(user, "verify")
        self.audit.log("register", user_id=user.id, resource_type="user", resource_id=str(user.id), ip_address=ip)
        return user, code

    def verify_otp(self, email: str, code: str, ip: str | None) -> tuple[User, str, str]:
        user = self._get_user_or_404(email)
        self._check_otp(user, code, "verify")
        self.users.mark_verified(user)
        self.users.clear_otp(user)

        access, refresh = self._issue_token_pair(user)
        self.audit.log("verify_otp", user_id=user.id, resource_type="user", resource_id=str(user.id), ip_address=ip)
        return user, access, refresh

    def resend_otp(self, email: str, ip: str | None) -> str:
        user = self._get_user_or_404(email)
        purpose = "reset" if user.is_verified else "verify"
        code = self._issue_otp(user, purpose)
        self.audit.log("resend_otp", user_id=user.id, details={"purpose": purpose}, ip_address=ip)
        return code

    # ── login / tokens ───────────────────────────────────────────────
    def login(self, email: str, password: str, ip: str | None) -> tuple[User, str, str]:
        user = self.users.get_by_email(email)
        if not user or not verify_password(password, user.password_hash):
            self.audit.log("login_failed", details={"email": email}, ip_address=ip)
            raise UnauthorizedError("Invalid email or password")

        access, refresh = self._issue_token_pair(user)
        self.audit.log("login", user_id=user.id, ip_address=ip)
        return user, access, refresh

    def refresh(self, raw_token: str, ip: str | None) -> tuple[User, str, str]:
        row = self.tokens.get_valid(hash_token(raw_token))
        if row is None:
            raise UnauthorizedError("Invalid or expired refresh token")
        self.tokens.revoke(row)  # rotate: old refresh token is single-use

        user = self.users.get_by_id(row.user_id)
        if user is None:
            raise UnauthorizedError("User not found")

        access, refresh = self._issue_token_pair(user)
        self.audit.log("refresh_token", user_id=user.id, ip_address=ip)
        return user, access, refresh

    def logout(self, raw_token: str, ip: str | None) -> None:
        row = self.tokens.get_valid(hash_token(raw_token))
        if row is not None:
            self.tokens.revoke(row)
            self.audit.log("logout", user_id=row.user_id, ip_address=ip)

    # ── password reset / change ─────────────────────────────────────
    def forgot_password(self, email: str, ip: str | None) -> str:
        user = self._get_user_or_404(email)
        code = self._issue_otp(user, "reset")
        self.audit.log("forgot_password", user_id=user.id, ip_address=ip)
        return code

    def reset_password(self, email: str, code: str, new_password: str, ip: str | None) -> None:
        user = self._get_user_or_404(email)
        self._check_otp(user, code, "reset")
        self.users.update_password(user, hash_password(new_password))
        self.users.clear_otp(user)
        self.tokens.revoke_all_for_user(user.id)  # force re-login everywhere
        self.audit.log("reset_password", user_id=user.id, ip_address=ip)

    def change_password(self, user: User, current_password: str, new_password: str, ip: str | None) -> None:
        if not verify_password(current_password, user.password_hash):
            raise UnauthorizedError("Current password is incorrect")
        self.users.update_password(user, hash_password(new_password))
        self.tokens.revoke_all_for_user(user.id)
        self.audit.log("change_password", user_id=user.id, ip_address=ip)

    # ── profile ──────────────────────────────────────────────────────
    def update_profile(self, user: User, name: str, phone: str, ip: str | None) -> User:
        updated = self.users.update_profile(user, name, phone)
        self.audit.log("update_profile", user_id=user.id, ip_address=ip)
        return updated

    def delete_account(self, user: User, ip: str | None) -> None:
        self.audit.log("delete_account", user_id=user.id, ip_address=ip)
        self.tokens.revoke_all_for_user(user.id)
        self.users.delete(user)

    # ── internals ────────────────────────────────────────────────────
    def _get_user_or_404(self, email: str) -> User:
        user = self.users.get_by_email(email)
        if not user:
            raise NotFoundError("No account with this email")
        return user

    def _issue_otp(self, user: User, purpose: str) -> str:
        code = generate_otp()
        self.users.set_otp(user, code, purpose, otp_expiry())
        send_otp_email(user.email, code, purpose)
        return code

    def _check_otp(self, user: User, code: str, purpose: str) -> None:
        if not user.otp_code or user.otp_purpose != purpose:
            raise AppError("No pending verification for this account", 400)
        if user.otp_expires_at is None or utcnow() > user.otp_expires_at:
            raise AppError("This code has expired. Request a new one.", 400)
        if code.strip() != user.otp_code:
            raise AppError("Incorrect code", 400)

    def _issue_token_pair(self, user: User) -> tuple[str, str]:
        role_name = user.role.name if user.role else "citizen"
        access = create_access_token(user.id, role_name)
        raw_refresh = generate_refresh_token()
        self.tokens.create(user.id, hash_token(raw_refresh), refresh_token_expiry())
        return access, raw_refresh
