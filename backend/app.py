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
    EmotionResponse,
    RefreshTokenRequest,
    ProfileResponse,
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

from routes.social import router as social_router
from scheduler import start_scheduler

# =====================================================
# LOGGER
# =====================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("mental_health_api")

# =====================================================
# DATABASE INIT
# =====================================================
models.Base.metadata.create_all(bind=engine)

# =====================================================
# LIFESPAN
# =====================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 Starting Mental Health API")

    if os.environ.get("RENDER") == "true":
        start_scheduler()
        logger.info("⏰ Scheduler started")

    yield
    logger.info("🛑 Shutting down Mental Health API")

# =====================================================
# FASTAPI APP
# =====================================================
app = FastAPI(
    title="Mental Health Detection API",
    version="7.0.0",
    lifespan=lifespan,
)

# =====================================================
# ✅ PRODUCTION SAFE CORS CONFIG
# =====================================================
origins = [
    # Production Frontend
    "https://mental-health-app-zpng.onrender.com",
    "https://mental-health-app-1-rv33.onrender.com",

    # Localhost base domains
    "http://localhost",
    "http://127.0.0.1",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =====================================================
# INCLUDE ROUTERS (AFTER CORS)
# =====================================================
app.include_router(social_router)

# =====================================================
# GLOBAL ERROR HANDLER
# =====================================================
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.exception("🔥 Unhandled backend error")
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc)},
    )

# =====================================================
# HEALTH CHECK
# =====================================================
@app.get("/")
def root():
    return {"status": "OK", "message": "Backend running 🚀"}

@app.get("/health")
def health():
    return {"status": "healthy"}

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
# SEVERITY LOGIC
# =====================================================
def calculate_severity(emotion: str, confidence: float) -> int:
    emotion = emotion.lower().strip()

    if emotion == "suicidal":
        return 5
    if emotion in ["depression", "angry", "anxiety"]:
        return 4
    if emotion == "sad":
        return 3
    if emotion == "happy":
        return 1
    if confidence >= 0.8:
        return 4
    if confidence >= 0.6:
        return 3
    if confidence >= 0.4:
        return 2
    return 1

# =====================================================
# REGISTER
# =====================================================
@app.post("/register", status_code=201)
def register(user: UserCreate, db: Session = Depends(get_db)):
    email = user.email.strip().lower()

    if db.query(User).filter(User.email == email).first():
        raise HTTPException(400, "Email already registered")

    new_user = User(
        email=email,
        password=hash_password(user.password),
    )

    db.add(new_user)
    db.commit()

    logger.info(f"User registered: {email}")
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
        raise HTTPException(401, "Invalid credentials")

    logger.info(f"User login: {email}")

    return TokenResponse(
        access_token=create_access_token({"sub": user.email}),
        refresh_token=create_refresh_token({"sub": user.email}),
        token_type="bearer",
    )

# =====================================================
# PROFILE
# =====================================================
@app.get("/profile", response_model=ProfileResponse)
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

    return ProfileResponse(
        user_id=user.id,
        email=user.email,
        total_entries=int(total_entries),
        avg_severity=round(float(avg_severity), 2),
        high_risk=avg_severity >= 3.5,
        emergency_email=user.emergency_email,
        emergency_name=user.emergency_name,
        alerts_enabled=user.alerts_enabled,
    )