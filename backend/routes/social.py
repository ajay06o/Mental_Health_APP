from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import Dict, Any
import base64

from database import get_db
from models import SocialAccount, SocialActivity, EmotionHistory, User
from utils.crypto import encrypt_token, decrypt_token
from ai_models.mental_health_model import final_prediction
from security import verify_access_token
from providers import instagram, facebook, x as x_provider

router = APIRouter(prefix="/social", tags=["social"])


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


@router.post("/connect")
def connect_account(request: Request, payload: Dict[str, Any], db: Session = Depends(get_db)):
    """Connect or update a social account. Expects: provider, external_id, access_token, refresh_token (opt), scopes"""
    user = _resolve_user_from_request(request, db)

    prov = payload.get("provider")
    ext = payload.get("external_id")
    access = payload.get("access_token")
    refresh = payload.get("refresh_token")
    scopes = payload.get("scopes")

    if not prov or not ext or not access:
        raise HTTPException(status_code=400, detail="provider, external_id and access_token required")

    # Upsert
    account = (
        db.query(SocialAccount)
        .filter(SocialAccount.user_id == user.id, SocialAccount.provider == prov, SocialAccount.external_id == ext)
        .first()
    )

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


@router.get("/accounts")
def list_accounts(request: Request, db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)
    accounts = (
        db.query(SocialAccount)
        .filter(SocialAccount.user_id == user.id)
        .all()
    )

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


@router.get("/oauth-url/{provider}")
def get_oauth_url(provider: str, request: Request, client_redirect: str = "myapp://oauth-success"):
    """Return a provider authorize URL tailored for mobile flow. The user's access token is encoded into state."""
    auth = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth:
        raise HTTPException(status_code=401, detail="Missing authorization header")

    parts = auth.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Invalid authorization header")

    token = parts[1]

    # Build backend callback URL
    base = str(request.base_url).rstrip("/")
    callback_url = f"{base}/oauth/{provider}/callback"

    # State encodes client_redirect and token
    state_raw = f"{client_redirect}|{token}"
    state = base64.urlsafe_b64encode(state_raw.encode()).decode()

    # Use existing authorize helper to build provider URL
    if provider == "instagram":
        url = instagram.authorize_url(redirect_uri=callback_url, state=state)
    elif provider == "facebook":
        url = facebook.authorize_url(redirect_uri=callback_url, state=state)
    elif provider == "x":
        url = x_provider.authorize_url(redirect_uri=callback_url, state=state)
    else:
        raise HTTPException(status_code=400, detail="Unknown provider")

    return {"url": url}
@router.post("/disconnect")
def disconnect_account(request: Request, payload: Dict[str, Any], db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)
    aid = payload.get("account_id")
    if not aid:
        raise HTTPException(status_code=400, detail="account_id required")

    acc = db.query(SocialAccount).filter(SocialAccount.id == aid, SocialAccount.user_id == user.id).first()
    if not acc:
        raise HTTPException(status_code=404, detail="Account not found")

    db.delete(acc)
    db.commit()

    return {"status": "disconnected"}


def _fetch_social_activities_for_account(account: SocialAccount) -> list:
    """Dispatch to provider-specific fetchers to retrieve recent activities."""
    try:
        p = account.provider.lower()
        if p == "instagram":
            from providers.instagram_api import fetch_recent_activities

            return fetch_recent_activities(account)
        if p == "facebook":
            from providers.facebook_api import fetch_recent_activities

            return fetch_recent_activities(account)
        if p in ("x", "twitter"):
            from providers.x_api import fetch_recent_activities

            return fetch_recent_activities(account)
    except Exception:
        return []

    return []


def analyze_social_accounts(user: User, db: Session):
    """Used by scheduler: fetch activities, predict, and store EmotionHistory and SocialActivity."""
    accounts = db.query(SocialAccount).filter(SocialAccount.user_id == user.id).all()

    for acc in accounts:
        activities = _fetch_social_activities_for_account(acc)

        for act in activities:
            # Deduplication: Check if this item already exists
            provider_item_id = act.get("provider_item_id")
            if provider_item_id:
                existing = db.query(SocialActivity).filter(
                    SocialActivity.account_id == acc.id,
                    SocialActivity.provider_item_id == provider_item_id
                ).first()
                if existing:
                    continue

            sa = SocialActivity(
                account_id=acc.id,
                provider_item_id=provider_item_id,
                activity_type=act.get("activity_type", "unknown"),
                content=act.get("content"),
                metadata=str(act.get("metadata")),
                timestamp=act.get("timestamp"),
                processed=False,
            )
            db.add(sa)
            db.commit()

            # Run prediction on content if available
            if sa.content:
                res = final_prediction(sa.content)

                eh = EmotionHistory(
                    user_id=user.id,
                    platform=f"social:{acc.provider}",
                    emotion=res.get("final_mental_state", "neutral"),
                    confidence=float(res.get("confidence", 0.0)),
                    severity=2,
                    text=sa.content,
                )
                db.add(eh)
                sa.processed = True
                db.commit()


@router.post("/sync")
def sync_account(request: Request, payload: Dict[str, Any], db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)
    account_id = payload.get("account_id")
    if not account_id:
        raise HTTPException(status_code=400, detail="account_id required")

    acc = db.query(SocialAccount).filter(SocialAccount.id == account_id, SocialAccount.user_id == user.id).first()
    if not acc:
        raise HTTPException(status_code=404, detail="Account not found")

    activities = _fetch_social_activities_for_account(acc)

    for act in activities:
        # Deduplication: Check if this item already exists
        provider_item_id = act.get("provider_item_id")
        if provider_item_id:
            existing = db.query(SocialActivity).filter(
                SocialActivity.account_id == acc.id,
                SocialActivity.provider_item_id == provider_item_id
            ).first()
            if existing:
                continue

        sa = SocialActivity(
            account_id=acc.id,
            provider_item_id=provider_item_id,
            activity_type=act.get("activity_type", "unknown"),
            content=act.get("content"),
            metadata=str(act.get("metadata")),
            timestamp=act.get("timestamp"),
            processed=False,
        )
        db.add(sa)
        db.commit()

        if sa.content:
            res = final_prediction(sa.content)

            eh = EmotionHistory(
                user_id=user.id,
                platform=f"social:{acc.provider}",
                emotion=res.get("final_mental_state", "neutral"),
                confidence=float(res.get("confidence", 0.0)),
                severity=2,
                text=sa.content,
            )
            db.add(eh)
            sa.processed = True
            db.commit()

    return {"status": "synced", "activities": len(activities)}
@router.get("/connected")
def get_connected_accounts(request: Request, db: Session = Depends(get_db)):
    """Return list of connected provider names for the authenticated user."""
    user = _resolve_user_from_request(request, db)

    accounts = db.query(SocialAccount).filter(SocialAccount.user_id == user.id).all()

    return [a.provider for a in accounts]


@router.delete("/disconnect/{platform}")
def disconnect_platform(platform: str, request: Request, db: Session = Depends(get_db)):
    """Delete the social account(s) for this platform for the user."""
    user = _resolve_user_from_request(request, db)
    platform = platform.lower().strip()

    deleted = db.query(SocialAccount).filter(
        SocialAccount.user_id == user.id, SocialAccount.provider == platform
    ).delete()
    db.commit()

    if deleted == 0:
        raise HTTPException(status_code=404, detail="Account not found")

    return {"message": f"{platform} disconnected"}


@router.post("/analyze")
def analyze_all(request: Request, db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)
    analyze_social_accounts(user, db)
    return {"status": "analysis_triggered"}


@router.post("/background-sync")
def background_sync(request: Request, db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)
    # For simplicity, call analyze which will fetch/process
    analyze_social_accounts(user, db)
    return {"status": "background_sync_started"}


@router.get("/sync-status/{platform}")
def sync_status(platform: str, request: Request, db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)
    platform = platform.lower().strip()

    account = db.query(SocialAccount).filter(SocialAccount.user_id == user.id, SocialAccount.provider == platform).first()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")

    total = db.query(SocialActivity).filter(SocialActivity.account_id == account.id).count()
    analyzed = db.query(SocialActivity).filter(SocialActivity.account_id == account.id, SocialActivity.processed == True).count()

    return {"analyzed": analyzed, "total": total}


@router.post("/retry-sync")
def retry_sync(payload: Dict[str, Any], request: Request, db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)
    platform = payload.get("platform")
    if not platform:
        raise HTTPException(status_code=400, detail="platform required")

    account = db.query(SocialAccount).filter(SocialAccount.user_id == user.id, SocialAccount.provider == platform).first()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")

    # Trigger a sync for this account
    activities = _fetch_social_activities_for_account(account)
    processed = 0
    for act in activities:
        sa = SocialActivity(
            account_id=account.id,
            activity_type=act.get("activity_type", "unknown"),
            content=act.get("content"),
            metadata=str(act.get("metadata")),
            timestamp=act.get("timestamp"),
            processed=False,
        )
        db.add(sa)
        db.commit()

        if sa.content:
            res = final_prediction(sa.content)
            eh = EmotionHistory(
                user_id=user.id,
                platform=f"social:{account.provider}",
                emotion=res.get("final_mental_state", "neutral"),
                confidence=float(res.get("confidence", 0.0)),
                severity=2,
                text=sa.content,
            )
            db.add(eh)
            sa.processed = True
            db.commit()
            processed += 1

    return {"status": "retried", "processed": processed}


@router.get("/sync-logs")
def sync_logs(request: Request, db: Session = Depends(get_db)):
    user = _resolve_user_from_request(request, db)

    logs = (
        db.query(SocialActivity)
        .join(SocialAccount, SocialAccount.id == SocialActivity.account_id)
        .filter(SocialAccount.user_id == user.id)
        .order_by(SocialActivity.timestamp.desc())
        .limit(200)
        .all()
    )

    return [
        {
            "id": l.id,
            "platform": db.query(SocialAccount).filter(SocialAccount.id == l.account_id).first().provider,
            "type": l.activity_type,
            "content": l.content,
            "processed": l.processed,
            "timestamp": l.timestamp,
        }
        for l in logs
    ]

    return {
        "message": "Social analysis completed",
        "results": results,
    }
