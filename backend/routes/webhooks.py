import os
import hmac
import hashlib
import json
import logging
from fastapi import APIRouter, Request, HTTPException
from database import SessionLocal
from models import SocialAccount, SocialActivity, EmotionHistory
from ai_models.mental_health_model import final_prediction

logger = logging.getLogger("webhooks")

router = APIRouter(prefix="/webhooks", tags=["webhooks"])

# Verification token for webhook setup (set this in your app config)
VERIFY_TOKEN = os.getenv("WEBHOOK_VERIFY_TOKEN")
FB_APP_SECRET = os.getenv("FACEBOOK_CLIENT_SECRET")


def _verify_signature(raw_body: bytes, header_sig: str) -> bool:
    """Verify X-Hub-Signature or X-Hub-Signature-256 using app secret."""
    if not FB_APP_SECRET or not header_sig:
        return False

    try:
        if header_sig.startswith("sha1="):
            sig = header_sig.split("=", 1)[1]
            mac = hmac.new(FB_APP_SECRET.encode(), raw_body, hashlib.sha1)
            return hmac.compare_digest(mac.hexdigest(), sig)

        if header_sig.startswith("sha256="):
            sig = header_sig.split("=", 1)[1]
            mac = hmac.new(FB_APP_SECRET.encode(), raw_body, hashlib.sha256)
            return hmac.compare_digest(mac.hexdigest(), sig)

    except Exception:
        return False

    return False


@router.get("/facebook")
async def verify_facebook(hub_mode: str = None, hub_verify_token: str = None, hub_challenge: str = None):
    """Verify webhook subscription from Facebook/Instagram (GET)."""
    if hub_mode != "subscribe":
        raise HTTPException(status_code=400, detail="Invalid mode")

    if VERIFY_TOKEN is None:
        raise HTTPException(status_code=500, detail="WEBHOOK_VERIFY_TOKEN not configured")

    if hub_verify_token != VERIFY_TOKEN:
        raise HTTPException(status_code=403, detail="Verification token mismatch")

    return int(hub_challenge)


@router.post("/facebook")
async def facebook_webhook(request: Request):
    """Receive webhook callbacks from Facebook/Instagram.

    This handler verifies the request signature, finds matching SocialAccount(s) by external id,
    triggers a fetch of recent activities for the account, stores activities and runs predictions.
    """
    raw_body = await request.body()
    header_sig = request.headers.get("X-Hub-Signature-256") or request.headers.get("X-Hub-Signature")

    if FB_APP_SECRET:
        if not _verify_signature(raw_body, header_sig):
            logger.warning("Invalid webhook signature")
            raise HTTPException(status_code=403, detail="Invalid signature")

    try:
        payload = json.loads(raw_body.decode())
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    # payload may contain 'entry' with entries pointing to Instagram or Page IDs
    entries = payload.get("entry", [])
    if not entries:
        return {"status": "no_entries"}

    db = SessionLocal()
    processed = 0
    try:
        for entry in entries:
            obj_id = entry.get("id")
            # Find social accounts with matching external_id
            accounts = db.query(SocialAccount).filter(SocialAccount.external_id == str(obj_id)).all()
            for acc in accounts:
                try:
                    # Call provider-specific fetcher to get new items
                    if acc.provider.lower() == "instagram":
                        from providers.instagram_api import fetch_recent_activities

                        activities = fetch_recent_activities(acc, limit=20)
                    else:
                        # For facebook pages, use facebook_api
                        from providers.facebook_api import fetch_recent_activities

                        activities = fetch_recent_activities(acc, limit=20)

                    for act in activities:
                        # Deduplication: Check if this item already exists
                        provider_item_id = act.get("provider_item_id")
                        if provider_item_id:
                            existing = db.query(SocialActivity).filter(
                                SocialActivity.account_id == acc.id,
                                SocialActivity.provider_item_id == provider_item_id
                            ).first()
                            if existing:
                                logger.info(f"Skipping duplicate activity {provider_item_id}")
                                continue

                        # Persist activity
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
                                user_id=acc.user_id,
                                platform=f"social:{acc.provider}",
                                emotion=res.get("final_mental_state", "neutral"),
                                confidence=float(res.get("confidence", 0.0)),
                                severity=2,
                                text=sa.content,
                            )
                            db.add(eh)
                            sa.processed = True
                            db.commit()
                            processed += 1
                except Exception as e:
                    logger.error(f"Error processing account {acc.id}: {e}")
                    db.rollback()

    finally:
        db.close()

    return {"processed": processed}
