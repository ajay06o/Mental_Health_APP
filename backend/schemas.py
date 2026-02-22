from pydantic import BaseModel, EmailStr, Field, field_validator
from datetime import datetime
from typing import Optional


# =====================================================
# AUTH SCHEMAS
# =====================================================

class UserCreate(BaseModel):
    email: EmailStr = Field(
        ...,
        example="user@gmail.com",
        description="Valid user email address",
    )
    password: str = Field(
        ...,
        min_length=6,
        max_length=128,
        example="password123",
        description="Password (min 6 characters)",
    )

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Password cannot be empty")
        return value


class TokenResponse(BaseModel):
    access_token: str = Field(
        ...,
        description="Short-lived JWT access token",
    )
    refresh_token: Optional[str] = Field(
        None,
        description="Long-lived refresh token",
    )
    token_type: str = Field(
        default="bearer",
        description="OAuth2 token type",
    )


# =====================================================
# REFRESH TOKEN
# =====================================================

class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(
        ...,
        description="Valid refresh token",
    )


# =====================================================
# EMOTION SCHEMAS
# =====================================================

class EmotionCreate(BaseModel):
    text: str = Field(
        ...,
        min_length=1,
        max_length=1000,
        example="I feel very stressed and anxious today",
        description="User input text for emotion detection",
    )

    @field_validator("text")
    @classmethod
    def validate_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Text cannot be empty")
        return value


class EmotionResponse(BaseModel):
    emotion: str = Field(..., example="anxiety")
    confidence: float = Field(..., ge=0.0, le=1.0, example=0.87)
    severity: int = Field(..., ge=1, le=5, example=3)
    timestamp: datetime = Field(..., example="2026-01-29T10:15:30Z")
    platform: Optional[str] = Field(
        None,
        example="instagram",
        description="Source platform (manual/social)",
    )


# =====================================================
# SOCIAL SCHEMAS
# =====================================================

class SocialConnectRequest(BaseModel):
    platform: str = Field(
        ...,
        example="instagram",
        description="Social platform name",
    )
    access_token: str = Field(
        ...,
        min_length=10,
        description="OAuth access token",
    )

    @field_validator("platform")
    @classmethod
    def normalize_platform(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("access_token")
    @classmethod
    def validate_token(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Access token cannot be empty")
        return value


class SocialAnalysisResult(BaseModel):
    platform: str
    emotion: str
    confidence: float
    severity: int
    analyzed_posts: int


class SocialAnalysisResponse(BaseModel):
    message: str
    results: list[SocialAnalysisResult]


# =====================================================
# PROFILE SCHEMAS
# =====================================================

class ProfileResponse(BaseModel):
    user_id: int

    # 👤 NEW: Name field
    name: Optional[str] = None

    email: EmailStr
    total_entries: int
    avg_severity: float
    high_risk: bool

    # 🔹 Emergency system
    emergency_email: Optional[EmailStr] = None
    emergency_name: Optional[str] = None
    alerts_enabled: bool


class ProfileUpdate(BaseModel):

    # 👤 NEW: Name support
    name: Optional[str] = Field(
        None,
        max_length=255,
        example="John Doe",
    )

    email: Optional[EmailStr] = Field(
        None,
        example="newemail@gmail.com",
    )

    password: Optional[str] = Field(
        None,
        min_length=6,
        max_length=128,
        example="newpassword123",
    )

    # 🔹 Emergency fields
    emergency_email: Optional[EmailStr] = Field(
        None,
        example="parent@gmail.com",
    )

    emergency_name: Optional[str] = Field(
        None,
        max_length=100,
        example="Mother",
    )

    alerts_enabled: Optional[bool] = Field(
        None,
        example=True,
    )

    # ==========================
    # VALIDATORS
    # ==========================

    @field_validator("name")
    @classmethod
    def validate_name(cls, value):
        if value:
            return value.strip()
        return value

    @field_validator("email")
    @classmethod
    def normalize_optional_email(cls, value):
        if value:
            return value.strip().lower()
        return value

    @field_validator("password")
    @classmethod
    def validate_optional_password(cls, value):
        if value:
            value = value.strip()
            if not value:
                raise ValueError("Password cannot be empty")
        return value

    @field_validator("emergency_name")
    @classmethod
    def validate_emergency_name(cls, value):
        if value:
            return value.strip()
        return value