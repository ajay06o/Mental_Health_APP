# =====================================================
# PATH SETUP
# =====================================================
import os
import sys
import logging
from contextlib import asynccontextmanager

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# =====================================================
# IMPORTS
# =====================================================
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import engine
from dependencies import get_db
from models import User, EmotionHistory
from schemas import (
    UserCreate,
    TokenResponse,
    EmotionCreate,
    RefreshTokenRequest,
)
from security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_access_token,
    verify_refresh_token,
)

# social routes removed (data/consent feature disabled)
from ai_models.mental_health_model import final_prediction
import models
# from routes.webhooks import router as webhooks_router  # DEPRECATED: social scraping removed

# =====================================================
# LOGGER
# =====================================================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("mental_health_api")

models.Base.metadata.create_all(bind=engine)

# =====================================================
# FASTAPI APP
# =====================================================
app = FastAPI(
    title="Mental Health Detection API",
    version="8.0.0",
)

# Social routes removed (consent/upload endpoints disabled)
# OAuth routes deprecated: provider OAuth has been removed in favor of explicit uploads
# app.include_router(oauth_router)
# app.include_router(webhooks_router)  # DEPRECATED: webhooks removed

# =====================================================
# ROOT (Fix 404 at /)
# =====================================================
@app.get("/")
def root():
    return {"status": "Backend Running 🚀"}

# =====================================================
# HEALTH CHECK
# =====================================================
@app.get("/health")
def health():
    return {"status": "healthy"}

# =====================================================
# GLOBAL ERROR HANDLER
# =====================================================
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.exception("Unhandled backend error")
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error"},
    )

# =====================================================
# CORS (Production Safe)
# =====================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://mental-health-app-zpng.onrender.com",
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =====================================================
# AUTH
# =====================================================
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    email = verify_access_token(token)

    if not email:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user = db.query(User).filter(User.email == email).first()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user

# =====================================================
# REGISTER
# =====================================================
@app.post("/register")
def register(user: UserCreate, db: Session = Depends(get_db)):
    email = user.email.strip().lower()

    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    new_user = User(
        email=email,
        password=hash_password(user.password),
    )

    db.add(new_user)
    db.commit()

    return {"message": "User registered successfully"}

# =====================================================
# LOGIN
# =====================================================
@app.post("/login", response_model=TokenResponse)
def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    email = form.username.strip().lower()
    user = db.query(User).filter(User.email == email).first()

    if not user or not verify_password(form.password, user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return TokenResponse(
        access_token=create_access_token({"sub": user.email}),
        refresh_token=create_refresh_token({"sub": user.email}),
        token_type="bearer",
    )

# =====================================================
# REFRESH TOKEN
# =====================================================
@app.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshTokenRequest):
    email = verify_refresh_token(payload.refresh_token)

    if not email:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    return TokenResponse(
        access_token=create_access_token({"sub": email}),
        refresh_token=create_refresh_token({"sub": email}),
        token_type="bearer",
    )

# =====================================================
# PROFILE
# =====================================================
@app.get("/profile")
def profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    total_entries = (
        db.query(func.count(EmotionHistory.id))
        .filter(EmotionHistory.user_id == user.id)
        .scalar() or 0
    )

    avg_severity = (
        db.query(func.avg(EmotionHistory.severity))
        .filter(EmotionHistory.user_id == user.id)
        .scalar() or 0
    )

    return {
        "user_id": user.id,
        "email": user.email,
        "total_entries": total_entries,
        "avg_severity": float(avg_severity or 0),
        "high_risk": (avg_severity or 0) >= 3.5,
    }

# =====================================================
# HISTORY
# =====================================================
@app.get("/history")
def history(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    records = (
        db.query(EmotionHistory)
        .filter(EmotionHistory.user_id == user.id)
        .order_by(EmotionHistory.timestamp.desc())
        .all()
    )

    return [
        {
            "emotion": r.emotion,
            "confidence": r.confidence,
            "severity": r.severity,
            "timestamp": r.timestamp,
        }
        for r in records
    ]

# =====================================================
# PREDICT (FIXED — HYBRID LOGIC)
# =====================================================
@app.post("/predict")
def predict(
    data: EmotionCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not data.text or not data.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    text = data.text.strip().lower()

    # 🔥 Smart keyword override for short single-word inputs
    keyword_map = {
        "happy": "happy",
        "sad": "sad",
        "angry": "angry",
        "depressed": "depression",
        "anxious": "anxiety",
        "suicidal": "suicidal",
    }

    if text in keyword_map:
        emotion = keyword_map[text]
        confidence = 0.95
    else:
        result = final_prediction(text)
        emotion = result.get("final_mental_state", "neutral")
        confidence = float(result.get("confidence", 0.0))

        # If model confidence too low, keep neutral
        if confidence < 0.4:
            emotion = "neutral"

    # 🎯 Improved severity logic
    if emotion == "suicidal":
        severity = 5
    elif emotion in ["depression", "angry", "anxiety"]:
        severity = 4
    elif emotion == "sad":
        severity = 3
    elif emotion == "happy":
        severity = 1
    else:
        severity = 2

    record = EmotionHistory(
        user_id=user.id,
        platform="manual",
        emotion=emotion,
        confidence=confidence,
        severity=severity,
    )

    db.add(record)
    db.commit()

    return {
        "emotion": emotion,
        "confidence": confidence,
        "severity": severity,
    }