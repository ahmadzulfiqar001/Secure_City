"""Pydantic v2 request/response schemas for the Auth module."""
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator

from ..core.security import validate_password_strength


def _validated_password(v: str) -> str:
    error = validate_password_strength(v)
    if error:
        raise ValueError(error)
    return v


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    phone: str = Field(min_length=1, max_length=32)
    password: str

    @field_validator("password")
    @classmethod
    def _check_password(cls, v: str) -> str:
        return _validated_password(v)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class OtpVerifyRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6)


class ResendOtpRequest(BaseModel):
    email: EmailStr


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6)
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _check_password(cls, v: str) -> str:
        return _validated_password(v)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _check_password(cls, v: str) -> str:
        return _validated_password(v)


class UpdateProfileRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    phone: str = Field(min_length=1, max_length=32)


class UserPublic(BaseModel):
    id: int
    name: str
    email: str
    phone: str | None
    role: str | None
    is_verified: bool
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_user(cls, user) -> "UserPublic":
        return cls(
            id=user.id, name=user.name, email=user.email, phone=user.phone,
            role=user.role.name if user.role else None,
            is_verified=user.is_verified, created_at=user.created_at,
        )


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserPublic


class MessageResponse(BaseModel):
    message: str
    otp_debug: str | None = None  # only populated when SMTP isn't configured
