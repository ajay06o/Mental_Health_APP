# =====================================================
# PATH SETUP
# =====================================================
import os
import sys
import logging
import shutil

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
from fastapi.staticfiles import StaticFiles
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
# FASTAPI APP
# =====================================================
app = FastAPI(
    title="Mental Health Detection API",
    version="9.0.0",
)

# =====================================================
# 📁 PROFILE IMAGE UPLOAD CONFIG
# =====================================================
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

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
# 🖼 UPLOAD PROFILE IMAGE
# =====================================================
@app.post("/profile/upload-image")
def upload_profile_image(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid image file")

    file_extension = file.filename.split(".")[-1].lower()
    filename = f"user_{user.id}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    image_url = f"/uploads/{filename}"

    user.profile_image = image_url
    db.commit()
    db.refresh(user)

    return {"profile_image": image_url}

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
# PREDICT
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

        if confidence < 0.4:
            emotion = "neutral"

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