from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from typing import List
import logging

from models import SocialAccount, User, EmotionHistory
from ai_models.mental_health_model import final_prediction
from security import verify_access_token
from dependencies import get_db

from utils.crypto import encrypt_token, decrypt_token
from utils.alerts import trigger_crisis_alert

# =====================================================
# LOGGER
# =====================================================
logger = logging.getLogger("social")

router = APIRouter(prefix="/social", tags=["Social"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")


# =====================================================
# AUTH USER
# =====================================================
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
# SEVERITY CALCULATION
# =====================================================
def calculate_severity(emotion: str, confidence: float) -> int:
    emotion = emotion.lower()

    if emotion == "suicidal":
        return 5
    if confidence >= 0.85:
        return 4
    if confidence >= 0.65:
        return 3
    if confidence >= 0.45:
        return 2
    return 1


# =====================================================
# CONNECT SOCIAL ACCOUNT (ENCRYPT TOKEN)
# =====================================================
@router.post("/connect")
def connect_social(
    platform: str,
    access_token: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not platform or not access_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Platform and access token required",
        )

    platform = platform.lower().strip()

    try:
        encrypted_token = encrypt_token(access_token)
    except Exception as e:
        logger.error(f"Encryption failed: {e}")
        raise HTTPException(
            status_code=500,
            detail="Token encryption failed",
        )

    existing = db.query(SocialAccount).filter(
        SocialAccount.user_id == user.id,
        SocialAccount.platform == platform,
    ).first()

    if existing:
        existing.access_token = encrypted_token
        existing.is_active = True
    else:
        db.add(
            SocialAccount(
                user_id=user.id,
                platform=platform,
                access_token=encrypted_token,
            )
        )

    db.commit()

    logger.info(f"{platform} connected for user {user.id}")

    return {"message": f"{platform} connected successfully"}


# =====================================================
# LIST CONNECTED ACCOUNTS
# =====================================================
@router.get("/connected")
def get_connected_accounts(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    accounts = db.query(SocialAccount).filter(
        SocialAccount.user_id == user.id,
        SocialAccount.is_active == True
    ).all()

    return [
        {
            "platform": acc.platform,
            "connected_at": acc.connected_at,
        }
        for acc in accounts
    ]


# =====================================================
# DISCONNECT ACCOUNT
# =====================================================
@router.delete("/disconnect/{platform}")
def disconnect_account(
    platform: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    platform = platform.lower().strip()

    account = db.query(SocialAccount).filter(
        SocialAccount.user_id == user.id,
        SocialAccount.platform == platform,
    ).first()

    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        )

    account.is_active = False
    db.commit()

    logger.info(f"{platform} disconnected for user {user.id}")

    return {"message": f"{platform} disconnected successfully"}


# =====================================================
# MOCK FETCH (Replace with real APIs later)
# =====================================================
def fetch_platform_data(platform: str, access_token: str) -> List[str]:

    # In production:
    # Call Instagram / X / Reddit APIs using access_token

    if platform == "instagram":
        return [
            "Feeling stressed lately",
            "Life is overwhelming sometimes",
        ]

    if platform == "x":
        return [
            "Why does everything feel heavy?",
            "Trying to stay positive",
        ]

    if platform == "reddit":
        return [
            "I feel anxious about my future",
            "Sometimes I just feel empty",
        ]

    return []


# =====================================================
# CORE ANALYSIS LOGIC (Scheduler + API Reusable)
# =====================================================
def run_social_analysis(user: User, db: Session):

    accounts = db.query(SocialAccount).filter(
        SocialAccount.user_id == user.id,
        SocialAccount.is_active == True
    ).all()

    if not accounts:
        return []

    results = []

    for account in accounts:
        try:
            decrypted_token = decrypt_token(account.access_token)

            texts = fetch_platform_data(
                account.platform,
                decrypted_token
            )

            if not texts:
                continue

            combined_text = " ".join(texts)

            prediction = final_prediction(combined_text)

            emotion = prediction["final_mental_state"].lower()
            confidence = float(prediction["confidence"])
            severity = calculate_severity(emotion, confidence)

            # =============================
            # 🚨 CRISIS ALERT SYSTEM
            # =============================
            if (
                severity == 5
                and user.alerts_enabled
                and user.emergency_email
            ):
                trigger_crisis_alert(user)
                logger.warning(
                    f"Crisis alert triggered for user {user.id}"
                )

            db.add(
                EmotionHistory(
                    user_id=user.id,
                    platform=account.platform,
                    emotion=emotion,
                    confidence=confidence,
                    severity=severity,
                )
            )

            results.append({
                "platform": account.platform,
                "emotion": emotion,
                "confidence": confidence,
                "severity": severity,
                "analyzed_posts": len(texts),
            })

        except Exception as e:
            logger.error(
                f"Error analyzing {account.platform} for user {user.id}: {e}"
            )
            db.rollback()

    db.commit()

    return results


# =====================================================
# ANALYZE SOCIAL ACCOUNTS (API)
# =====================================================
@router.post("/analyze")
def analyze_social_accounts(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    results = run_social_analysis(user, db)

    if not results:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No public data found",
        )

    logger.info(f"Social analysis completed for user {user.id}")

    return {
        "message": "Social analysis completed",
        "results": results,
    }
