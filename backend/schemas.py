from pydantic import BaseModel, EmailStr, Field, field_validator
from datetime import datetime
from typing import Optional

# =========================
# AUTH SCHEMAS
# =========================
class UserCreate(BaseModel):
    email: EmailStr = Field(
        ...,
        example="user@gmail.com",
        description="Valid user email address",
    )
    password: str = Field(
        ...,
        min_length=6,   # ✅ match Flutter validation
        max_length=128,
        example="password123",
        description="Password (min 6 characters)",
    )


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

# =========================
# REFRESH TOKEN
# =========================
class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(
        ...,
        description="Valid refresh token",
    )

# =========================
# EMOTION SCHEMAS
# =========================
class EmotionCreate(BaseModel):
    text: str = Field(
        ...,
        min_length=1,
        max_length=1000,
        example="I feel very stressed and anxious today",
        description="User input text for emotion detection",
    )


class EmotionResponse(BaseModel):
    emotion: str = Field(
        ...,
        example="anxiety",
    )
    confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        example=0.87,
    )
    severity: int = Field(
        ...,
        ge=1,
        le=5,
        example=3,
    )
    timestamp: datetime = Field(
        ...,
        example="2026-01-29T10:15:30Z",
    )

# =========================
# PROFILE SCHEMAS
# =========================
class ProfileResponse(BaseModel):
    user_id: int
    email: EmailStr
    total_entries: int
    avg_severity: float
    high_risk: bool


class ProfileUpdate(BaseModel):
    email: Optional[EmailStr] = Field(
        None,
        example="newemail@gmail.com",
    )
    password: Optional[str] = Field(
        None,
        min_length=6,   # ✅ match Flutter
        max_length=128,
        example="newpassword123",
    )
