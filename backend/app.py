# =====================================================
# PATH SETUP
# =====================================================
import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# =====================================================
# IMPORTS
# =====================================================
from fastapi import FastAPI, Depends, HTTPException, status, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

from sqlalchemy.orm import Session
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError

from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from database import SessionLocal, engine
from models import User, EmotionHistory
from schemas import (
    UserCreate,
    TokenResponse,
    EmotionCreate,
    RefreshTokenRequest,
    ProfileUpdate,
)
from security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_access_token,
    verify_refresh_token,
)

from ai_models.bert_emotion import predict_emotion
import models

# =====================================================
# DATABASE INIT
# =====================================================
models.Base.metadata.create_all(bind=engine)

# =====================================================
# FASTAPI APP
# =====================================================
app = FastAPI(
    title="Mental Health Detection API",
    version="8.0.2",
)

# =====================================================
# RATE LIMITER
# =====================================================
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return Response(
        content="Too many requests. Please try again later.",
        status_code=429,
    )

# =====================================================
# ✅ CORS (FLUTTER WEB + PROD SAFE)
# =====================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],  # REQUIRED for Authorization
    expose_headers=["Authorization"],
)

# =====================================================
# SECURITY HEADERS
# =====================================================
@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response

# =====================================================
# ROOT & HEALTH
# =====================================================
@app.get("/")
def root():
    return {"status": "OK", "message": "Mental Health Backend is running 🚀"}

@app.get("/health")
def health():
    return {"status": "healthy"}

# =====================================================
# DB DEPENDENCY
# =====================================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# =====================================================
# AUTH DEPENDENCY
# =====================================================
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    email = verify_access_token(token)
    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user

# =====================================================
# AUTH ROUTES
# =====================================================
@app.post("/register", response_model=TokenResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    try:
        new_user = User(
            email=user.email,
            password=hash_password(user.password),
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Email already registered")

    return {
        "access_token": create_access_token({"sub": new_user.email}),
        "refresh_token": create_refresh_token({"sub": new_user.email}),
        "token_type": "bearer",
    }

@app.post("/login", response_model=TokenResponse)
def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == form.username).first()
    if not user or not verify_password(form.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    return {
        "access_token": create_access_token({"sub": user.email}),
        "refresh_token": create_refresh_token({"sub": user.email}),
        "token_type": "bearer",
    }

# =====================================================
# REFRESH TOKEN
# =====================================================
@app.post("/refresh")
def refresh(payload: RefreshTokenRequest):
    email = verify_refresh_token(payload.refresh_token)
    if not email:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    return {
        "access_token": create_access_token({"sub": email}),
        "token_type": "bearer",
    }

# =====================================================
# EMOTION PREDICTION
# =====================================================
@app.post("/predict")
@limiter.limit("10/minute")
def predict(
    request: Request,  # REQUIRED for slowapi
    data: EmotionCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not data.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    try:
        result = predict_emotion(data.text)
    except Exception:
        result = {"emotion": "neutral", "confidence": 0.0}

    emotion = result["emotion"].lower()
    confidence = max(0.0, min(float(result["confidence"]), 1.0))

    severity_map = {
        "happy": 1,
        "sad": 2,
        "anxiety": 3,
        "depression": 4,
        "suicidal": 5,
        "neutral": 1,
    }
    severity = severity_map.get(emotion, 1)

    record = EmotionHistory(
        user_id=user.id,
        text=data.text,
        emotion=emotion,
        confidence=confidence,
        severity=severity,
    )

    db.add(record)
    db.commit()
    db.refresh(record)

    return {
        "emotion": emotion,
        "confidence": confidence,
        "severity": severity,
        "timestamp": record.timestamp.isoformat(),
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
            "timestamp": r.timestamp.isoformat(),
        }
        for r in records
    ]

# =====================================================
# PROFILE
# =====================================================
@app.get("/profile")
def profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    total_entries = db.query(func.count(EmotionHistory.id)).filter(
        EmotionHistory.user_id == user.id
    ).scalar() or 0

    avg_severity = db.query(func.avg(EmotionHistory.severity)).filter(
        EmotionHistory.user_id == user.id
    ).scalar() or 0.0

    high_risk = (
        db.query(EmotionHistory)
        .filter(EmotionHistory.user_id == user.id, EmotionHistory.severity >= 4)
        .first()
        is not None
    )

    return {
        "user_id": user.id,
        "email": user.email,
        "total_entries": int(total_entries),
        "avg_severity": round(float(avg_severity), 2),
        "high_risk": high_risk,
    }

# =====================================================
# UPDATE PROFILE
# =====================================================
@app.put("/profile")
def update_profile(
    payload: ProfileUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.email:
        exists = db.query(User).filter(
            User.email == payload.email,
            User.id != user.id,
        ).first()
        if exists:
            raise HTTPException(status_code=400, detail="Email already in use")
        user.email = payload.email

    if payload.password:
        user.password = hash_password(payload.password)

    db.commit()
    db.refresh(user)

    return {"message": "Profile updated successfully"}
