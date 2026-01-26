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
from jose import jwt, JWTError

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

# ================= AI SEMANTIC SEARCH (optional) =================
try:
    from sentence_transformers import SentenceTransformer
    from sklearn.metrics.pairwise import cosine_similarity
    _semantic_available = True
    # Lazy load model after DB init to keep startup light
    semantic_model = None
except Exception:
    _semantic_available = False
    semantic_model = None


# =====================================================
# DB INIT
# =====================================================
models.Base.metadata.create_all(bind=engine)

# =====================================================
# LOAD SEMANTIC MODEL (LAZY SAFE)
# =====================================================
if _semantic_available:
    try:
        semantic_model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
    except Exception:
        semantic_model = None
        _semantic_available = False

# =====================================================
# FASTAPI APP
# =====================================================
app = FastAPI(
    title="Mental Health Detection API",
    version="6.1.0",
)

# =====================================================
# CORS (Render + Mobile Safe)
# =====================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
# AUTH
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
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

        user = db.query(User).filter(User.email == email).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

        return user
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

# =====================================================
# EMOTION LOGIC
# =====================================================
def contains_suicidal_intent(text: str) -> bool:
    text = text.lower()
    keywords = [
        "end my life", "kill myself", "want to die",
        "no reason to live", "suicide", "self harm",
        "can't handle this", "can't go on",
        "life is unbearable", "i give up",
        "ఆత్మహత్య", "చావాలని ఉంది",
        "ఇంకా భరించలేకపోతున్నాను",
        "मरना चाहता हूँ", "आत्महत्या",
        "अब और नहीं सह सकता",
    ]
    return any(k in text for k in keywords)

def normalize_emotion(raw: str) -> str:
    raw = raw.lower().strip()

    if raw == "suicidal":
        return "suicidal"
    if raw in ["depression", "depressed", "hopeless", "empty", "numb"]:
        return "depression"
    if raw in ["anxiety", "stress", "panic", "anger"]:
        return "anxiety"
    if raw in ["sad", "sadness", "lonely"]:
        return "sad"

    return "happy"

def calculate_severity(emotion: str) -> int:
    return {
        "happy": 1,
        "sad": 2,
        "anxiety": 3,
        "depression": 4,
        "suicidal": 5,
    }.get(emotion, 1)

# =====================================================
# SEMANTIC SEARCH
# =====================================================
def semantic_search(query: str, texts: list, threshold: float = 0.55):
    if not texts:
        return []

    if _semantic_available and semantic_model is not None:
        query_emb = semantic_model.encode([query])
        text_embs = semantic_model.encode(texts)
        similarities = cosine_similarity(query_emb, text_embs)[0]
    else:
        # Lightweight fallback: token overlap score (cheap, no heavy deps)
        q_tokens = set(str(query).lower().split())
        similarities = []
        for t in texts:
            t_tokens = set(str(t).lower().split())
            score = len(q_tokens & t_tokens) / max(1, len(t_tokens))
            similarities.append(score)

    return [
        {"index": i, "score": float(score)}
        for i, score in enumerate(similarities)
        if score >= threshold
    ]

# =====================================================
# AUTH ROUTES
# =====================================================
@app.post("/register", response_model=TokenResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
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

@app.post("/login", response_model=TokenResponse)
def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == form.username).first()
    if not user or not verify_password(form.password, user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return {
        "access_token": create_access_token({"sub": user.email}),
        "refresh_token": create_refresh_token({"sub": user.email}),
        "token_type": "bearer",
    }

@app.post("/refresh")
def refresh(payload: dict):
    refresh_token = payload.get("refresh_token")
    if not refresh_token:
        raise HTTPException(status_code=401, detail="Missing refresh token")

    email = verify_refresh_token(refresh_token)
    if not email:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    return {
        "access_token": create_access_token({"sub": email})
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
    if contains_suicidal_intent(data.text):
        emotion = "suicidal"
        severity = 5
        confidence = 1.0
    else:
        result = final_prediction(data.text)
        emotion = normalize_emotion(result["final_mental_state"])

        if emotion == "happy" and any(
            w in data.text.lower()
            for w in ["pain", "tired", "empty", "alone", "stress"]
        ):
            emotion = "depression"

        severity = calculate_severity(emotion)
        confidence = float(result["confidence"])

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
        "text": record.text,
        "emotion": record.emotion,
        "confidence": record.confidence,
        "severity": record.severity,
        "timestamp": record.timestamp.isoformat(),
    }

@app.get("/history")
def history(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(EmotionHistory)
        .filter(EmotionHistory.user_id == user.id)
        .order_by(EmotionHistory.timestamp.asc())
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
        for r in rows
    ]

@app.get("/profile")
def profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = db.query(EmotionHistory).filter(
        EmotionHistory.user_id == user.id
    ).all()

    total = len(rows)
    avg_severity = round(
        sum(r.severity for r in rows) / total, 2
    ) if total else 0

    high_risk = any(r.severity >= 4 for r in rows)

    return {
        "email": user.email,
        "total_entries": total,
        "avg_severity": avg_severity,
        "high_risk": high_risk,
    }
