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
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

from sqlalchemy.orm import Session
from sqlalchemy import func

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

from ai_models.mental_health_model import final_prediction
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
    version="1.0.1",
)

# =====================================================
# CORS (FLUTTER SAFE)
# =====================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =====================================================
# HEALTH
# =====================================================
@app.get("/")
def root():
    return {"status": "OK", "message": "Backend running 🚀"}


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
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return user

# =====================================================
# REGISTER (PUBLIC — NO TOKEN RETURN)
# =====================================================
@app.post("/register", status_code=201)
def register(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(
            status_code=400,
            detail="Email already registered",
        )

    new_user = User(
        email=user.email,
        password=hash_password(user.password),
    )

    db.add(new_user)
    db.commit()

    return {"message": "User registered successfully"}

# =====================================================
# LOGIN (PUBLIC)
# =====================================================
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
# REFRESH TOKEN (PUBLIC)
# =====================================================
@app.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshTokenRequest):
    email = verify_refresh_token(payload.refresh_token)

    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    return {
        "access_token": create_access_token({"sub": email}),
        "token_type": "bearer",
    }

# =====================================================
# 🧠 PREDICT (PROTECTED)
# =====================================================
@app.post("/predict")
def predict(
    data: EmotionCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = final_prediction(data.text)

    record = EmotionHistory(
        user_id=user.id,
        text=data.text,
        emotion=result["final_mental_state"].lower(),
        confidence=float(result["confidence"]),
        severity=1,
    )

    db.add(record)
    db.commit()
    db.refresh(record)

    return {
        "emotion": record.emotion,
        "confidence": record.confidence,
        "timestamp": record.timestamp.isoformat(),
    }

# =====================================================
# HISTORY (PROTECTED)
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
# PROFILE (PROTECTED)
# =====================================================
@app.get("/profile")
def profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    total_entries = (
        db.query(func.count(EmotionHistory.id))
        .filter(EmotionHistory.user_id == user.id)
        .scalar()
        or 0
    )

    return {
        "email": user.email,
        "total_entries": int(total_entries),
    }

# =====================================================
# UPDATE PROFILE (PROTECTED)
# =====================================================
@app.put("/profile")
def update_profile(
    payload: ProfileUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.email:
        user.email = payload.email

    if payload.password:
        user.password = hash_password(payload.password)

    db.commit()
    return {"message": "Profile updated successfully"}
