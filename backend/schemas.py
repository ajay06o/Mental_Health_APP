from pydantic import BaseModel, EmailStr, Field
from datetime import datetime

# =========================
# AUTH SCHEMAS
# =========================
class UserCreate(BaseModel):
    email: EmailStr = Field(..., example="user@gmail.com")
    password: str = Field(..., min_length=6, example="StrongPass123")


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


# =========================
# EMOTION SCHEMAS
# =========================
class EmotionCreate(BaseModel):
    text: str = Field(..., min_length=1, example="I feel very stressed today")


class EmotionResponse(BaseModel):
    text: str
    emotion: str
    confidence: float
    severity: int
    timestamp: datetime
