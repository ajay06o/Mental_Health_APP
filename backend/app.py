# =====================================================
# PATH SETUP
# =====================================================

import os
import sys
import logging

from dotenv import load_dotenv
load_dotenv()

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
from fastapi.security import OAuth2PasswordBearer
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy import func
from pydantic import BaseModel

import cloudinary
import cloudinary.uploader
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
from twilio.rest import Client
from pydantic import EmailStr

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
# SOCIAL MEDIA ANALYSIS IMPORTS (NEW)
# =====================================================
from schemas import SocialBatchAnalysisRequest
from services.analyzer import analyze_text
from services.trends import calculate_overall
from services.risk_detector import detect_risk

# =====================================================
# LOGGER
# =====================================================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("mental_health_api")

   # delete old table
if os.getenv("ENV") == "local":
    models.Base.metadata.create_all(bind=engine)# create new table

# =====================================================
# CLOUDINARY CONFIG
# =====================================================
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
)

# =====================================================
# EMAIL CONFIG (CRASH SAFE)
# =====================================================
MAIL_USERNAME = os.getenv("MAIL_USERNAME")
MAIL_PASSWORD = os.getenv("MAIL_PASSWORD")
MAIL_FROM = os.getenv("MAIL_FROM")

mail_conf = None

if MAIL_USERNAME and MAIL_PASSWORD and MAIL_FROM:
    mail_conf = ConnectionConfig(
        MAIL_USERNAME=MAIL_USERNAME,
        MAIL_PASSWORD=MAIL_PASSWORD,
        MAIL_FROM=MAIL_FROM,
        MAIL_PORT=587,
        MAIL_SERVER="smtp.gmail.com",
        MAIL_STARTTLS=True,
        MAIL_SSL_TLS=False,
        USE_CREDENTIALS=True,
    )

# =====================================================
# FASTAPI APP
# =====================================================
app = FastAPI(
    title="Mental Health Detection API",
    version="9.2.1",
)

# =====================================================
# CORS
# =====================================================
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex="http://localhost:.*",  # handles any port
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
#@app.exception_handler(Exception)
#async def global_exception_handler(request, exc):
 #   logger.exception("Unhandled backend error")
  #  return JSONResponse(
   #     status_code=500,
    #    content={"detail": "Internal Server Error"},
    #)
      



# =====================================================
# AUTH
# =====================================================
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    if not token:
        raise HTTPException(status_code=401, detail="Token missing")

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
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    email = (form_data.username or "").strip().lower()
    password = (form_data.password or "").strip()

    print("LOGIN EMAIL:", email)

    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password required")

    user = db.query(User).filter(User.email == email).first()

    if not user:
        print("❌ USER NOT FOUND")
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not verify_password(password, user.password):
        print("❌ PASSWORD WRONG")
        raise HTTPException(status_code=401, detail="Invalid credentials")

    print("✅ LOGIN SUCCESS")

    return TokenResponse(
        access_token=create_access_token({"sub": user.email}),
        refresh_token=create_refresh_token({"sub": user.email}),
        token_type="bearer",
    )

# =====================================================
# REFRESH TOKEN
# =====================================================
@app.post("/refresh", response_model=TokenResponse)
def refresh_token(
    data: RefreshTokenRequest,
):
    payload = verify_refresh_token(data.refresh_token)

    if not payload:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    email = payload.get("sub")

    if not email:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    return TokenResponse(
        access_token=create_access_token({"sub": email}),
        refresh_token=create_refresh_token({"sub": email}),
        token_type="bearer",
    )

# =====================================================
# PROFILE
# =====================================================
@app.get("/profile")
def profile(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    total_entries = (
        db.query(func.count(EmotionHistory.id))
        .filter(EmotionHistory.user_id == user.id)
        .scalar() or 0
    )

    avg_mhi = (
    db.query(func.avg(EmotionHistory.mental_health_index))
    .filter(EmotionHistory.user_id == user.id)
    .scalar() or 0
)

    return {
    "user_id": user.id,
    "name": user.name,
    "email": user.email,
    "profile_image": user.profile_image,
    "total_entries": total_entries,
    "avg_mhi": float(avg_mhi or 0),
    "high_risk": (avg_mhi or 0) < 30,
    "emergency_email": user.emergency_email,
    "emergency_name": user.emergency_name,
    "alerts_enabled": user.alerts_enabled,
}

# =====================================================
# UPDATE PROFILE
# =====================================================
@app.put("/profile")
def update_profile(
    data: ProfileUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):

    if data.name is not None:
        user.name = data.name.strip()

    if data.email is not None:
        user.email = data.email.strip().lower()

    if data.password:
        user.password = hash_password(data.password)

    if data.emergency_name is not None:
        user.emergency_name = data.emergency_name.strip()

    if data.emergency_email is not None:
        user.emergency_email = data.emergency_email.strip()

    if data.alerts_enabled is not None:
        user.alerts_enabled = data.alerts_enabled

    db.commit()
    db.refresh(user)

    return {
        "message": "Profile updated successfully"
    }


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

    except Exception as e:
        logger.error(f"Cloudinary upload failed: {e}")
        raise HTTPException(status_code=500, detail="Image upload failed")

# =====================================================
# HISTORY
# =====================================================
@app.get("/history")
def history(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
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
        "risk": r.risk,
        "mental_health_index": r.mental_health_index,
        "text": r.text,
        "created_at": r.timestamp.isoformat() if r.timestamp else None,
    }
    for r in records
]

CRISIS_HELPLINES = [
    {
        "name": "Kiran Mental Health Helpline",
        "phone": "18005990019",
        "available": "24/7"
    },
    {
        "name": "AASRA Suicide Prevention",
        "phone": "+912227546669",
        "available": "24/7"
    },
    {
        "name": "Vandrevala Foundation",
        "phone": "9999666555",
        "available": "24/7"
    }
]
# =====================================================
# 🧠 PREDICT + SAFE EMERGENCY EMAIL (UPDATED)
# =====================================================
@app.post("/predict")
async def predict_emotion_api(
    data: EmotionCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):

    if not data.text or not data.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    # =====================================================
    # Load recent emotion history
    # =====================================================
    history_records = (
        db.query(EmotionHistory)
        .filter(EmotionHistory.user_id == user.id)
        .order_by(EmotionHistory.timestamp.desc())
        .limit(10)
        .all()
    )

    emotion_history = [r.emotion for r in reversed(history_records)]

    # =====================================================
    # Run AI prediction
    # =====================================================
    result = final_prediction(data.text, emotion_history)

    emotion = result["final_mental_state"]
    confidence = result["confidence"]
    severity = result["severity"]
    risk = result["risk"]
    mental_health_index = result["mental_health_index"]

    trend = result.get("trend")
    future_prediction = result.get("future_prediction")
    adaptive_analysis = result.get("adaptive_analysis")

    # =====================================================
    # Save to DB
    # =====================================================
    history_entry = EmotionHistory(
        user_id=user.id,
        emotion=emotion,
        confidence=confidence,
        severity=severity,
        risk=risk,
        mental_health_index=mental_health_index,
        text=data.text,
        platform="manual",
    )

    db.add(history_entry)
    db.commit()

    # =====================================================
    # Emergency Alert Logic
    # =====================================================
    emergency_triggered = False

    if (
        emotion == "Suicidal"
        and user.alerts_enabled
        and user.emergency_email
        and not user.alert_sent
    ):

        suicidal_count = (
            db.query(EmotionHistory)
            .filter(
                EmotionHistory.user_id == user.id,
                EmotionHistory.emotion == "Suicidal",
            )
            .count()
        )

        if suicidal_count >= 3:

            if mail_conf:

                try:
                    message = MessageSchema(
                        subject="🚨 Emergency Mental Health Alert",
                        recipients=[user.emergency_email],
                        body=f"""
Emergency Alert:

{user.name or user.email} has triggered repeated suicidal indicators.

Please check on them immediately.

This is an automated safety alert.
                        """,
                        subtype="plain",
                    )

                    fm = FastMail(mail_conf)
                    await fm.send_message(message)

                    emergency_triggered = True

                except Exception as e:
                    logger.error(f"Email sending failed: {e}")

            user.alert_sent = True
            db.commit()

    # =====================================================
    # API Response
    # =====================================================
    response = {

        "emotion": emotion,
        "confidence": confidence,
        "severity": severity,
        "risk": risk,
        "mental_health_index": mental_health_index,

        # 🧠 AI intelligence layers
        "trend": trend,
        "future_prediction": future_prediction,
        "adaptive_analysis": adaptive_analysis,

        "emergency_triggered": emergency_triggered,

        # default
        "show_crisis_support": False,
    }

    # =====================================================
    # Crisis Support Trigger
    # =====================================================
    if emotion == "Suicidal":
        response["show_crisis_support"] = True
        response["message"] = (
            "You are not alone. Support is available. "
            "Please consider reaching out to one of the helplines below."
        )
        response["helplines"] = CRISIS_HELPLINES

    return response

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

# =====================================================
# 🌐 SOCIAL MEDIA ANALYSIS (PRO LEVEL)
# =====================================================
# =====================================================
# 🌐 SOCIAL MEDIA ANALYSIS (PRO MAX)
# =====================================================
@app.post("/analyze-social")
def analyze_social_advanced(
    data: SocialBatchAnalysisRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):

    if not data.posts:
        raise HTTPException(status_code=400, detail="No posts provided")

    results = []
    valid_posts = 0

    # =====================================================
    # ANALYZE POSTS
    # =====================================================
    for post in data.posts:

        if not post.text or not post.text.strip():
            continue

        try:
            res = analyze_text(post.text)

            results.append({
                "text": post.text,
                "emotion": res.get("emotion", "neutral"),
                "confidence": res.get("confidence", 0.0),
                "score": res.get("score", 0),
                "timestamp": post.timestamp,
            })

            valid_posts += 1

        except Exception as e:
            logger.error(f"Social analysis error: {e}")

    if valid_posts == 0:
        raise HTTPException(status_code=400, detail="No valid posts to analyze")

    # =====================================================
    # TREND ANALYSIS
    # =====================================================
    avg_score, dominant, insights = calculate_overall(results)

    # =====================================================
    # RISK DETECTION
    # =====================================================
    risk = detect_risk(
        avg_score=avg_score,
        dominant_emotion=dominant,
        confidence=insights.get("avg_confidence", 0),
    )

    # =====================================================
    # SAVE TO DB (SAFE)
    # =====================================================
    try:
        history_entry = EmotionHistory(
            user_id=user.id,
            emotion=dominant,
            confidence=insights.get("avg_confidence", 0),
            severity="medium",
            risk=risk,
            mental_health_index=insights.get("mental_health_index", 50),
            text="SOCIAL_ANALYSIS_BATCH",
            platform=data.platform,
        )

        db.add(history_entry)
        db.commit()

    except Exception as e:
        logger.error(f"DB Save Error: {e}")
        db.rollback()

    # =====================================================
    # RESPONSE
    # =====================================================
    return {
        "user_id": data.user_id,
        "platform": data.platform,

        "overall_score": round(avg_score, 3),
        "dominant_emotion": dominant,
        "risk_level": risk,

        "mental_health_index": insights.get("mental_health_index"),
        "emotion_distribution": insights.get("emotion_distribution"),
        "avg_confidence": insights.get("avg_confidence"),
        "total_posts": insights.get("total_entries"),

        "results": results,
    }
#=====================================================
# 🔐 TEMP STORE FOR PKCE (ADD THIS)
# =====================================================
code_verifier_store = {}

# =====================================================
# 🐦 TWITTER AUTH START
# =====================================================
import requests

TWITTER_CLIENT_ID = os.getenv("TWITTER_CLIENT_ID")

TWITTER_REDIRECT_URI = "https://mental-health-app-zpng.onrender.com/auth/twitter/callback"

import base64
import hashlib
import os

def generate_pkce():
    code_verifier = base64.urlsafe_b64encode(os.urandom(32)).decode().rstrip("=")

    code_challenge = base64.urlsafe_b64encode(
        hashlib.sha256(code_verifier.encode()).digest()
    ).decode().rstrip("=")

    return code_verifier, code_challenge


@app.get("/auth/twitter")
def twitter_login():
    code_verifier, code_challenge = generate_pkce()

    # 🔥 STORE verifier (IMPORTANT)
    code_verifier_store["state123"] = code_verifier

    auth_url = (
        "https://twitter.com/i/oauth2/authorize"
        f"?response_type=code"
        f"&client_id={TWITTER_CLIENT_ID}"
        f"&redirect_uri={TWITTER_REDIRECT_URI}"
        f"&scope=tweet.read users.read offline.access"
        f"&state=state123"
        f"&code_challenge={code_challenge}"
        f"&code_challenge_method=S256"
    )

    return {"auth_url": auth_url}

# =====================================================
# 🐦 TWITTER CALLBACK
# =====================================================
@app.get("/auth/twitter/callback")
def twitter_callback(code: str, db: Session = Depends(get_db)):

    code_verifier = code_verifier_store.get("state123")

    if not code_verifier:
        raise HTTPException(status_code=400, detail="Code verifier missing")

    code_verifier_store.pop("state123", None)

    token_url = "https://api.twitter.com/2/oauth2/token"

    data = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": TWITTER_REDIRECT_URI,
        "code_verifier": code_verifier,
    }

    import base64

    client_id = TWITTER_CLIENT_ID
    client_secret = os.getenv("TWITTER_CLIENT_SECRET")

    client_creds = f"{client_id}:{client_secret}"
    basic_auth = base64.b64encode(client_creds.encode()).decode()

    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": f"Basic {basic_auth}",
}

    token_response = requests.post(
        token_url,
        data=data,
        headers=headers,
        timeout=10
    )

    if token_response.status_code != 200:
        raise HTTPException(status_code=400, detail=token_response.text)

    access_token = token_response.json().get("access_token")

    if not access_token:
        raise HTTPException(status_code=400, detail="Failed to get access token")

    user_response = requests.get(
        "https://api.twitter.com/2/users/me",
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=10
    )

    if user_response.status_code != 200:
        raise HTTPException(status_code=400, detail=user_response.text)

    user_data = user_response.json()["data"]

    twitter_id = user_data["id"]
    username = user_data["username"]

    user = db.query(User).filter(User.twitter_id == twitter_id).first()

    if user:
        user.twitter_access_token = access_token
        user.twitter_username = username
    else:
        user = User(
            name=username,
            email=f"{twitter_id}@twitter.com",
            password=hash_password(f"twitter_{twitter_id}"),
            twitter_id=twitter_id,
            twitter_username=username,
            twitter_access_token=access_token,
        )
        db.add(user)

    db.commit()
    db.refresh(user)

    from fastapi.responses import HTMLResponse

    html_content = f"""
    <h2>Twitter Connected Successfully ✅</h2>

    <p><b>User:</b> {username}</p>

    <p>Now click below to analyze your mental health:</p>

    <a href="/twitter/analyze" target="_blank">
        <button style="padding:10px 20px;font-size:16px;">
            Analyze My Mental Health
        </button>
    </a>
    """

    return HTMLResponse(content=html_content)
# =====================================================
# 🐦 TWITTER ANALYSIS (REAL DATA)
# =====================================================
@app.get("/twitter/analyze")
def analyze_twitter(user: User = Depends(get_current_user)):

    # 🔴 Check if Twitter connected
    if not user.twitter_access_token or not user.twitter_id:
        raise HTTPException(status_code=400, detail="Twitter not connected")

    # =====================================================
    # STEP 1: FETCH TWEETS
    # =====================================================
    url = f"https://api.twitter.com/2/users/{user.twitter_id}/tweets"

    headers = {
        "Authorization": f"Bearer {user.twitter_access_token}"
    }

    response = requests.get(url, headers=headers, timeout=10)

    if response.status_code != 200:
        raise HTTPException(status_code=400, detail=response.text)

    tweets = response.json().get("data", [])

    # =====================================================
    # STEP 2: ANALYZE EMOTION
    # =====================================================
    results = []

    for tweet in tweets:
        text = tweet.get("text", "")

        if not text:
            continue

        result = final_prediction(text, [])

        results.append({
            "text": text,
            "emotion": result["final_mental_state"],
            "confidence": result["confidence"]
        })

    # =====================================================
    # STEP 3: RETURN RESULT
    # =====================================================
    return {
        "total": len(results),
        "data": results
    }
