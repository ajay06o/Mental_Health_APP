# =====================================================
# PATH SETUP
# =====================================================
import os
import sys
import logging

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)

if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# =====================================================
# IMPORTS
# =====================================================
from fastapi import (
    FastAPI,
    Depends,
    HTTPException,
    UploadFile,
    File,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy import func

import cloudinary
import cloudinary.uploader

from database import engine
from dependencies import get_db
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
# LOGGER
# =====================================================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("mental_health_api")

models.Base.metadata.create_all(bind=engine)

# =====================================================
# CLOUDINARY CONFIG
# =====================================================
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
)

# =====================================================
# FASTAPI APP
# =====================================================
app = FastAPI(
    title="Mental Health Detection API",
    version="9.0.0",
)

# =====================================================
# ROOT
# =====================================================
@app.get("/")
def root():
    return {"status": "Backend Running 🚀"}

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
# CORS
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
        "name": user.name,
        "email": user.email,
        "profile_image": user.profile_image,
        "total_entries": total_entries,
        "avg_severity": float(avg_severity or 0),
        "high_risk": (avg_severity or 0) >= 3.5,
        "emergency_email": user.emergency_email,
        "emergency_name": user.emergency_name,
        "alerts_enabled": user.alerts_enabled,
    }

# =====================================================
# UPDATE PROFILE
# =====================================================
@app.put("/profile")
def update_profile(
    profile: ProfileUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if profile.name is not None:
        user.name = profile.name
    if profile.email is not None:
        user.email = profile.email
    if profile.password is not None:
        user.password = hash_password(profile.password)
    if profile.emergency_name is not None:
        user.emergency_name = profile.emergency_name
    if profile.emergency_email is not None:
        user.emergency_email = profile.emergency_email
    if profile.alerts_enabled is not None:
        user.alerts_enabled = profile.alerts_enabled

    db.commit()
    db.refresh(user)

    return {"message": "Profile updated successfully"}

# =====================================================
# 🖼 CLOUDINARY PROFILE IMAGE UPLOAD
# =====================================================
@app.post("/profile/upload-image")
def upload_profile_image(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    allowed_extensions = ["jpg", "jpeg", "png", "webp"]

    if not file.filename:
        raise HTTPException(status_code=400, detail="Invalid file")

    file_extension = file.filename.split(".")[-1].lower()

    if file_extension not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, JPEG, PNG, WEBP images allowed",
        )

    try:
        upload_result = cloudinary.uploader.upload(
            file.file,
            folder="mental_health_profiles",
            public_id=f"user_{user.id}",
            overwrite=True,
            transformation=[{"width": 400, "height": 400, "crop": "fill"}],
        )

        image_url = upload_result.get("secure_url")

        if not image_url:
            raise HTTPException(status_code=500, detail="Upload failed")

        user.profile_image = image_url
        db.commit()
        db.refresh(user)

        return {"profile_image": image_url}

    except Exception:
        logger.exception("Cloudinary upload failed")
        raise HTTPException(status_code=500, detail="Image upload failed")

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
            "id": r.id,
            "emotion": r.emotion,
            "confidence": r.confidence,
            "severity": r.severity,
            "created_at": r.timestamp.isoformat() if r.timestamp else None,
        }
        for r in records
    ]

    # =====================================================
# 🧠 PREDICT EMOTION
# =====================================================
@app.post("/predict")
def predict_emotion_api(
    data: EmotionCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not data.text or not data.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    # Run AI model
    result = final_prediction(data.text)

    emotion = result["final_mental_state"]
    confidence = result["confidence"]

    # Basic severity mapping
    severity_map = {
        "Happy": 1,
        "Sad": 2,
        "Angry": 2,
        "Anxiety": 3,
        "Depression": 4,
        "Suicidal": 5,
    }

    severity = severity_map.get(emotion, 1)

    # Save to DB
    history_entry = EmotionHistory(
        user_id=user.id,
        emotion=emotion,
        confidence=confidence,
        severity=severity,
    )

    db.add(history_entry)
    db.commit()

    return {
        "emotion": emotion,
        "confidence": confidence,
        "severity": severity,
    }

# =====================================================
# DELETE HISTORY ITEM
# =====================================================
@app.delete("/history/{record_id}")
def delete_history(
    record_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = (
        db.query(EmotionHistory)
        .filter(
            EmotionHistory.id == record_id,
            EmotionHistory.user_id == user.id,
        )
        .first()
    )

    if not record:
        raise HTTPException(status_code=404, detail="Record not found")

    db.delete(record)
    db.commit()

    return {"message": "History deleted successfully"}