from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import Dict, Any
import base64

from database import SessionLocal
from dependencies import get_db
from models import SocialAccount, SocialActivity, EmotionHistory, User
from utils.crypto import encrypt_token, decrypt_token
from ai_models.mental_health_model import final_prediction
from security import verify_access_token
from providers import instagram, facebook, x as x_provider

router = APIRouter(prefix="/social", tags=["social"])


# =====================================================
# 🔐 AUTH HELPER
# =====================================================
def _resolve_user_from_request(request: Request, db: Session) -> User:
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
# 🔗 CONNECT ACCOUNT
# =====================================================
@router.post("/connect")
def connect_account(request: Request, payload: Dict[str, Any], db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)

    prov = payload.get("provider")
    ext = payload.get("external_id")
    access = payload.get("access_token")
    refresh = payload.get("refresh_token")
    scopes = payload.get("scopes")

    if not prov or not ext or not access:
        raise HTTPException(status_code=400, detail="provider, external_id and access_token required")

    account = db.query(SocialAccount).filter(
        SocialAccount.user_id == user.id,
        SocialAccount.provider == prov,
        SocialAccount.external_id == ext
    ).first()

    enc_access = encrypt_token(access)
    enc_refresh = encrypt_token(refresh) if refresh else None

    if account:
        account.access_token = enc_access
        account.refresh_token = enc_refresh
        account.scopes = scopes
    else:
        account = SocialAccount(
            user_id=user.id,
            provider=prov,
            external_id=ext,
            access_token=enc_access,
            refresh_token=enc_refresh,
            scopes=scopes,
        )
        db.add(account)

    db.commit()
    return {"status": "connected", "provider": prov}


# =====================================================
# 📄 LIST ACCOUNTS
# =====================================================
@router.get("/accounts")
def list_accounts(request: Request, db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)

    accounts = db.query(SocialAccount).filter(
        SocialAccount.user_id == user.id
    ).all()

    return [
        {
            "id": a.id,
            "provider": a.provider,
            "external_id": a.external_id,
            "last_synced": a.last_synced,
            "scopes": a.scopes,
        }
        for a in accounts
    ]


# =====================================================
# 🔐 OAUTH URL
# =====================================================
@router.get("/oauth-url/{provider}")
def get_oauth_url(provider: str, request: Request, client_redirect: str = "myapp://oauth-success"):
    auth = request.headers.get("authorization") or request.headers.get("Authorization")

    if not auth:
        raise HTTPException(status_code=401, detail="Missing authorization header")

    parts = auth.split()

    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Invalid authorization header")

    token = parts[1]

    base = str(request.base_url).rstrip("/")
    callback_url = f"{base}/oauth/{provider}/callback"

    state_raw = f"{client_redirect}|{token}"
    state = base64.urlsafe_b64encode(state_raw.encode()).decode()

    if provider == "instagram":
        url = instagram.authorize_url(redirect_uri=callback_url, state=state)
    elif provider == "facebook":
        url = facebook.authorize_url(redirect_uri=callback_url, state=state)
    elif provider == "x":
        url = x_provider.authorize_url(redirect_uri=callback_url, state=state)
    else:
        raise HTTPException(status_code=400, detail="Unknown provider")

    return {"url": url}


# =====================================================
# ❌ DISCONNECT ACCOUNT
# =====================================================
@router.post("/disconnect")
def disconnect_account(request: Request, payload: Dict[str, Any], db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)

    aid = payload.get("account_id")

    if not aid:
        raise HTTPException(status_code=400, detail="account_id required")

    acc = db.query(SocialAccount).filter(
        SocialAccount.id == aid,
        SocialAccount.user_id == user.id
    ).first()

    if not acc:
        raise HTTPException(status_code=404, detail="Account not found")

    db.delete(acc)
    db.commit()

    return {"status": "disconnected"}