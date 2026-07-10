"""Auth + RBAC routes. Kept thin — parse request, call AuthService, shape
the response; all the actual logic lives in services/auth_service.py.
"""
from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from ...core.config import settings
from ...core.deps import get_current_user, get_db, require_role
from ...core.rate_limit import limiter
from ...models import User
from ...schemas.auth import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    LoginRequest,
    LogoutRequest,
    MessageResponse,
    OtpVerifyRequest,
    RefreshRequest,
    RegisterRequest,
    ResendOtpRequest,
    ResetPasswordRequest,
    TokenResponse,
    UpdateProfileRequest,
    UserPublic,
)
from ...services.auth_service import AuthService

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _otp_debug(code: str) -> str | None:
    """Only surfaced in the response when no SMTP is configured — mirrors
    what actually got printed to the console instead of emailed."""
    return None if settings.smtp_host else code


@router.post("/register", status_code=201, response_model=MessageResponse)
@limiter.limit("10/minute")
def register(request: Request, body: RegisterRequest, db: Session = Depends(get_db)):
    service = AuthService(db)
    _, code = service.register(body.name, body.email, body.phone, body.password, _client_ip(request))
    return MessageResponse(
        message="Account created. Verify it with the code we generated.",
        otp_debug=_otp_debug(code),
    )


@router.post("/verify-otp", response_model=TokenResponse)
@limiter.limit("10/minute")
def verify_otp(request: Request, body: OtpVerifyRequest, db: Session = Depends(get_db)):
    service = AuthService(db)
    user, access, refresh = service.verify_otp(body.email, body.code, _client_ip(request))
    return TokenResponse(access_token=access, refresh_token=refresh, user=UserPublic.from_user(user))


@router.post("/resend-otp", response_model=MessageResponse)
@limiter.limit("5/minute")
def resend_otp(request: Request, body: ResendOtpRequest, db: Session = Depends(get_db)):
    service = AuthService(db)
    code = service.resend_otp(body.email, _client_ip(request))
    return MessageResponse(message="A new code was generated.", otp_debug=_otp_debug(code))


@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(request: Request, body: LoginRequest, db: Session = Depends(get_db)):
    service = AuthService(db)
    user, access, refresh = service.login(body.email, body.password, _client_ip(request))
    return TokenResponse(access_token=access, refresh_token=refresh, user=UserPublic.from_user(user))


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("20/minute")
def refresh_token(request: Request, body: RefreshRequest, db: Session = Depends(get_db)):
    service = AuthService(db)
    user, access, refresh = service.refresh(body.refresh_token, _client_ip(request))
    return TokenResponse(access_token=access, refresh_token=refresh, user=UserPublic.from_user(user))


@router.post("/logout", response_model=MessageResponse)
def logout(request: Request, body: LogoutRequest, db: Session = Depends(get_db)):
    service = AuthService(db)
    service.logout(body.refresh_token, _client_ip(request))
    return MessageResponse(message="Logged out.")


@router.post("/forgot-password", response_model=MessageResponse)
@limiter.limit("5/minute")
def forgot_password(request: Request, body: ForgotPasswordRequest, db: Session = Depends(get_db)):
    service = AuthService(db)
    code = service.forgot_password(body.email, _client_ip(request))
    return MessageResponse(message="Use this code to reset your password.", otp_debug=_otp_debug(code))


@router.post("/reset-password", response_model=MessageResponse)
@limiter.limit("5/minute")
def reset_password(request: Request, body: ResetPasswordRequest, db: Session = Depends(get_db)):
    service = AuthService(db)
    service.reset_password(body.email, body.code, body.new_password, _client_ip(request))
    return MessageResponse(message="Password reset — sign in with your new password.")


@router.get("/me", response_model=UserPublic)
def get_me(user: User = Depends(get_current_user)):
    return UserPublic.from_user(user)


@router.put("/me", response_model=UserPublic)
def update_me(
    request: Request, body: UpdateProfileRequest,
    user: User = Depends(get_current_user), db: Session = Depends(get_db),
):
    service = AuthService(db)
    updated = service.update_profile(user, body.name, body.phone, _client_ip(request))
    return UserPublic.from_user(updated)


@router.post("/change-password", response_model=MessageResponse)
def change_password(
    request: Request, body: ChangePasswordRequest,
    user: User = Depends(get_current_user), db: Session = Depends(get_db),
):
    service = AuthService(db)
    service.change_password(user, body.current_password, body.new_password, _client_ip(request))
    return MessageResponse(message="Password changed.")


@router.delete("/me", response_model=MessageResponse)
def delete_me(request: Request, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AuthService(db)
    service.delete_account(user, _client_ip(request))
    return MessageResponse(message="Account deleted.")


# ── RBAC demo route: admin-only, lists every user ────────────────────
@router.get("/users", response_model=list[UserPublic])
def list_users(db: Session = Depends(get_db), _admin: User = Depends(require_role("admin"))):
    users = db.execute(select(User)).scalars().all()
    return [UserPublic.from_user(u) for u in users]
