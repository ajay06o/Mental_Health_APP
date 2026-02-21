from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import Dict, Any, List

from dependencies import get_db
from models import EmotionHistory, User, UploadedContent, AuditLog
from utils.crypto import encrypt_data, decrypt_data
from ai_models.mental_health_model import final_prediction
from security import verify_access_token

router = APIRouter(prefix="/social", tags=["social"])


# =====================================================
# 🔐 AUTH HELPER
# =====================================================
def _resolve_user_from_request(request: Request, db: Session) -> User:
    """Extract and validate user from Authorization header."""
    auth = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth:
        raise HTTPException(status_code=401, detail="Missing authorization header")

    parts = auth.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Invalid authorization header")

    token = parts[1]
    email = verify_access_token(token)

    if not email:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user = db.query(User).filter(User.email == email).first()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user


# =====================================================
# 👆 CONSENT & DISCLAIMER
# =====================================================
CONSENT_TEXT = (
    "By uploading posts, captions, comments, or screenshots you explicitly consent to "
    "their analysis. This analysis is for informational purposes only and is not a "
    "medical diagnosis or treatment. If you are in crisis, seek professional help."
)


@router.get("/consent")
def get_consent():
    """Return consent text."""
    return {"consent": CONSENT_TEXT}


@router.post("/consent")
def accept_consent(request: Request, payload: Dict[str, Any], db: Session = Depends(get_db)):
    """Record user consent acceptance."""
    accepted = payload.get("accepted")
    if not accepted:
        raise HTTPException(status_code=400, detail="accepted=true required")

    user = _resolve_user_from_request(request, db)

    # Record audit log for consent acceptance
    log = AuditLog(user_id=user.id, action="consent_accepted", details="User accepted consent for uploads")
    db.add(log)
    db.commit()

    return {"status": "accepted", "user_id": user.id}


# =====================================================
# 🗂 UPLOAD CONTENT (EXPLICIT USER UPLOAD ONLY)
# =====================================================
@router.post("/upload")
def upload_content(request: Request, payload: Dict[str, Any], db: Session = Depends(get_db)):
    """
    Accept explicit user uploads.
    
    Payload:
    {
      "items": [
        {
          "type": "post|caption|comment|screenshot",
          "text": "optional text content",
          "screenshot_base64": "optional base64 image"
        }
      ]
    }
    """
    user = _resolve_user_from_request(request, db)

    items: List[Dict[str, Any]] = payload.get("items")
    if not items or not isinstance(items, list):
        raise HTTPException(status_code=400, detail="items: list required")

    results = []

    for it in items:
        typ = it.get("type")
        text = it.get("text")
        screenshot = it.get("screenshot_base64")

        if typ not in ("post", "caption", "comment", "screenshot"):
            raise HTTPException(status_code=400, detail=f"invalid type: {typ}")

        # Analyze plain-text before encrypting for storage
        analysis = None
        if text:
            analysis = final_prediction(text)
            # Persist emotion history (analysis result)
            eh = EmotionHistory(
                user_id=user.id,
                platform="upload",
                emotion=analysis.get("final_mental_state", analysis.get("emotion", "unknown")),
                confidence=float(analysis.get("confidence", 0.0)),
                severity=int(analysis.get("severity", 1)),
                text=text,
            )
            db.add(eh)
            db.commit()

        # Encrypt content at rest
        enc_text = encrypt_data(text) if text else None
        enc_screenshot = encrypt_data(screenshot) if screenshot else None

        uc = UploadedContent(
            user_id=user.id,
            content_type=typ,
            text=enc_text,
            screenshot_base64=enc_screenshot,
        )
        db.add(uc)
        db.commit()
        db.refresh(uc)

        results.append({"uploaded_id": uc.id, "type": typ, "analysis": analysis})

    return {"status": "uploaded", "results": results}


# =====================================================
# ⛔ DELETE MY DATA
# =====================================================
@router.post("/delete-data")
def delete_my_data(request: Request, db: Session = Depends(get_db)):
    """Delete all user's uploaded data and emotion history."""
    user = _resolve_user_from_request(request, db)

    # Count records for audit
    ec = db.query(EmotionHistory).filter(EmotionHistory.user_id == user.id).count()
    uc_count = db.query(UploadedContent).filter(UploadedContent.user_id == user.id).count()

    # Delete data
    db.query(EmotionHistory).filter(EmotionHistory.user_id == user.id).delete()
    db.query(UploadedContent).filter(UploadedContent.user_id == user.id).delete()

    # Record audit log
    details = f"deleted_emotion_history={ec};deleted_uploaded_content={uc_count}"
    log = AuditLog(user_id=user.id, action="delete_data", details=details)
    db.add(log)

    db.commit()

    return {"status": "deleted", "user_id": user.id}


# =====================================================
# 📜 AUDIT LOGS
# =====================================================
@router.get("/audit-logs")
def get_audit_logs(request: Request, db: Session = Depends(get_db)):
    """Retrieve user's audit logs (consent + deletion history)."""
    user = _resolve_user_from_request(request, db)

    logs = (
        db.query(AuditLog)
        .filter(AuditLog.user_id == user.id)
        .order_by(AuditLog.timestamp.desc())
        .all()
    )

    return [
        {"id": l.id, "action": l.action, "details": l.details, "timestamp": l.timestamp}
        for l in logs
    ]


# =====================================================
# 📦 GET UPLOADS (list decrypted content for user)
# =====================================================
@router.get("/uploads")
def get_uploads(request: Request, db: Session = Depends(get_db)):
    """Return user's uploaded content with decrypted text/screenshot."""
    user = _resolve_user_from_request(request, db)

    rows = (
        db.query(UploadedContent)
        .filter(UploadedContent.user_id == user.id)
        .order_by(UploadedContent.created_at.desc())
        .all()
    )

    out = []
    for r in rows:
        try:
            text = decrypt_data(r.text) if r.text else None
        except Exception:
            text = None

        try:
            screenshot = decrypt_data(r.screenshot_base64) if r.screenshot_base64 else None
        except Exception:
            screenshot = None

        out.append({
            "id": r.id,
            "content_type": r.content_type,
            "text": text,
            "screenshot_base64": screenshot,
            "created_at": r.created_at,
        })

    return out
