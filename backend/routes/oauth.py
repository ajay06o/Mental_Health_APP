from fastapi import APIRouter, Request, Depends, HTTPException
from fastapi.responses import RedirectResponse
from typing import Dict, Any
from sqlalchemy.orm import Session
import os
import base64
import urllib.parse

from dependencies import get_db
from models import SocialAccount, User
from utils.crypto import encrypt_token
from security import verify_access_token

from providers import instagram, facebook, x as x_provider

router = APIRouter(prefix="/oauth", tags=["oauth"])


@router.get("/{provider}/authorize")
def authorize(provider: str, redirect_uri: str, state: str = ""):
    if provider == "instagram":
        url = instagram.authorize_url(redirect_uri=redirect_uri, state=state)
    elif provider == "facebook":
        url = facebook.authorize_url(redirect_uri=redirect_uri, state=state)
    elif provider == "x":
        url = x_provider.authorize_url(redirect_uri=redirect_uri, state=state)
    else:
        raise HTTPException(status_code=404, detail="Unknown provider")

    return {"url": url}


@router.get("/{provider}/callback")
def provider_callback(provider: str, request: Request, code: str = None, state: str = None):
    """Provider will redirect here with `code` and `state`.
    State is expected to contain client_redirect and the user's access token encoded.
    After exchanging code and storing tokens, redirect to the deep link.
    """
    if not code:
        raise HTTPException(status_code=400, detail="Missing code")

    if not state:
        raise HTTPException(status_code=400, detail="Missing state")

    try:
        decoded = base64.urlsafe_b64decode(state.encode()).decode()
        client_redirect, token = decoded.split("|", 1)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid state")

    # Exchange code server-side by calling provider helper
    base = str(request.base_url).rstrip("/")
    redirect_uri = f"{base}/oauth/{provider}/callback"

    if provider == "instagram":
        tokens = instagram.exchange_code(code=code, redirect_uri=redirect_uri)
    elif provider == "facebook":
        tokens = facebook.exchange_code(code=code, redirect_uri=redirect_uri)
    elif provider == "x":
        tokens = x_provider.exchange_code(code=code, redirect_uri=redirect_uri)
    else:
        raise HTTPException(status_code=404, detail="Unknown provider")

    access = tokens.get("access_token")
    refresh = tokens.get("refresh_token")
    external_id = tokens.get("external_id")
    scopes = tokens.get("scopes")

    # Validate token (from state) and resolve user
    email = verify_access_token(token)
    if not email:
        # Redirect back to client with error
        redirect_err = f"{client_redirect}?platform={provider}&status=error&error=invalid_session"
        return RedirectResponse(url=redirect_err)

    # Now persist SocialAccount for the user
    from database import SessionLocal
    from models import User, SocialAccount

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            redirect_err = f"{client_redirect}?platform={provider}&status=error&error=user_not_found"
            return RedirectResponse(url=redirect_err)

        from utils.crypto import encrypt_token

        enc_access = encrypt_token(access) if access else None
        enc_refresh = encrypt_token(refresh) if refresh else None

        sa = db.query(SocialAccount).filter(SocialAccount.user_id == user.id, SocialAccount.provider == provider, SocialAccount.external_id == external_id).first()
        if sa:
            if enc_access:
                sa.access_token = enc_access
            if enc_refresh:
                sa.refresh_token = enc_refresh
            sa.scopes = scopes
        else:
            sa = SocialAccount(
                user_id=user.id,
                provider=provider,
                external_id=external_id,
                access_token=enc_access or "",
                refresh_token=enc_refresh,
                scopes=scopes,
            )
            db.add(sa)

        db.commit()
    finally:
        db.close()

    # Redirect to client deep link signaling success
    redirect_success = f"{client_redirect}?platform={provider}&status=success"
    return RedirectResponse(url=redirect_success)


@router.post("/{provider}/exchange")
def exchange(provider: str, payload: Dict[str, Any], request: Request, db: Session = Depends(get_db)):
    code = payload.get("code")
    redirect_uri = payload.get("redirect_uri")

    if not code or not redirect_uri:
        raise HTTPException(status_code=400, detail="code and redirect_uri required")

    # Resolve user from Authorization header
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
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")

    # Exchange code
    if provider == "instagram":
        tokens = instagram.exchange_code(code=code, redirect_uri=redirect_uri)
    elif provider == "facebook":
        tokens = facebook.exchange_code(code=code, redirect_uri=redirect_uri)
    elif provider == "x":
        tokens = x_provider.exchange_code(code=code, redirect_uri=redirect_uri)
    else:
        raise HTTPException(status_code=404, detail="Unknown provider")

    access = tokens.get("access_token")
    refresh = tokens.get("refresh_token")
    external_id = tokens.get("external_id")
    scopes = tokens.get("scopes")

    if not access:
        raise HTTPException(status_code=400, detail="Failed to obtain access token from provider")

    enc_access = encrypt_token(access)
    enc_refresh = encrypt_token(refresh) if refresh else None

    # Upsert SocialAccount
    sa = db.query(SocialAccount).filter(SocialAccount.user_id == user.id, SocialAccount.provider == provider, SocialAccount.external_id == external_id).first()
    if sa:
        sa.access_token = enc_access
        sa.refresh_token = enc_refresh
        sa.scopes = scopes
    else:
        sa = SocialAccount(
            user_id=user.id,
            provider=provider,
            external_id=external_id,
            access_token=enc_access,
            refresh_token=enc_refresh,
            scopes=scopes,
        )
        db.add(sa)

    db.commit()

    return {"status": "connected", "provider": provider}
