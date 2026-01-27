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
from jose import jwt, JWTError
from typing import Optional
from pydantic import BaseModel
from sqlalchemy.exc import IntegrityError

from database import SessionLocal, engine
from models import User, EmotionHistory
from schemas import EmotionCreate, UserCreate, TokenResponse
from security import (
    SECRET_KEY,
    ALGORITHM,
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_refresh_token,
)

from ai_models.mental_health_model import final_prediction
import models

# =====================================================
# DB INIT
# =====================================================
models.Base.metadata.create_all(bind=engine)

# =====================================================
# FASTAPI APP
# =====================================================
app = FastAPI(
    title="Mental Health Detection API",
    version="6.5.0",
)

# =====================================================
# CORS (FIXED)
# =====================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # OK for dev + Flutter web
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
# AUTH HELPERS
# =====================================================
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email = payload.get("sub")

        if not email:
            raise HTTPException(status_code=401, detail="Invalid token")

        user = db.query(User).filter(User.email == email).first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")

        return user

    except JWTError:
        raise HTTPException(status_code=401, detail="Token error")

# =====================================================
# AUTH ROUTES
# =====================================================
@app.post("/register", response_model=TokenResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    try:
        if db.query(User).filter(User.email == user.email).first():
            raise HTTPException(status_code=400, detail="Email already registered")

        new_user = User(
            email=user.email,
            password=hash_password(user.password),
        )

        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        return {
            "access_token": create_access_token({"sub": new_user.email}),
            "refresh_token": create_refresh_token({"sub": new_user.email}),
            "token_type": "bearer",
        }

    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Email already registered")

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Registration failed: {str(e)}"
        )

@app.post("/login", response_model=TokenResponse)
def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == form.username).first()

    if not user or not verify_password(form.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )

    return {
        "access_token": create_access_token({"sub": user.email}),
        "refresh_token": create_refresh_token({"sub": user.email}),
        "token_type": "bearer",
    }

# =====================================================
# REFRESH TOKEN (FIXED)
# =====================================================
class RefreshTokenRequest(BaseModel):
    refresh_token: str

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
# EMOTION ROUTES
# =====================================================
@app.post("/predict")
def predict(
    data: EmotionCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = final_prediction(data.text)

    emotion = result["final_mental_state"]
    confidence = float(result["confidence"])

    severity = {
        "happy": 1,
        "sad": 2,
        "anxiety": 3,
        "depression": 4,
        "suicidal": 5,
    }.get(emotion, 1)

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
        "emotion": record.emotion,
        "confidence": record.confidence,
        "severity": record.severity,
        "timestamp": record.timestamp.isoformat(),
    }

# =====================================================
# HISTORY API
# =====================================================
@app.get("/history")
def get_history(
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
            "text": r.text,
            "emotion": r.emotion,
            "confidence": r.confidence,
            "severity": r.severity,
            "timestamp": r.timestamp.isoformat(),
        }
        for r in records
    ]

# =====================================================
# PROFILE APIs
# =====================================================
@app.get("/profile")
def get_profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    total_entries = (
        db.query(func.count(EmotionHistory.id))
        .filter(EmotionHistory.user_id == user.id)
        .scalar()
    ) or 0

    avg_severity = (
        db.query(func.avg(EmotionHistory.severity))
        .filter(EmotionHistory.user_id == user.id)
        .scalar()
    ) or 0.0

    high_risk = (
        db.query(EmotionHistory)
        .filter(
            EmotionHistory.user_id == user.id,
            EmotionHistory.severity >= 4,
        )
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
class ProfileUpdate(BaseModel):
    email: Optional[str] = None
    password: Optional[str] = None

@app.put("/profile")
def update_profile(
    payload: ProfileUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.email:
        exists = (
            db.query(User)
            .filter(User.email == payload.email, User.id != user.id)
            .first()
        )
        if exists:
            raise HTTPException(status_code=400, detail="Email already in use")

        user.email = payload.email

    if payload.password:
        user.password = hash_password(payload.password)

    db.commit()
    db.refresh(user)

    return {"message": "Profile updated successfully"}
