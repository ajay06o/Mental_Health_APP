import os
import requests
from urllib.parse import urlencode

CLIENT_ID = os.getenv("FACEBOOK_CLIENT_ID")
CLIENT_SECRET = os.getenv("FACEBOOK_CLIENT_SECRET")

FACEBOOK_AUTH_BASE = "https://www.facebook.com/v16.0/dialog/oauth"
FACEBOOK_TOKEN_BASE = "https://graph.facebook.com/v16.0/oauth/access_token"
FACEBOOK_GRAPH_BASE = "https://graph.facebook.com/v16.0/me"


# =====================================================
# 🔐 Generate OAuth URL
# =====================================================
def authorize_url(
    redirect_uri: str,
    state: str = "",
    scopes: str = "public_profile,email",  # ✅ supported permissions
) -> str:
    if not CLIENT_ID:
        raise RuntimeError("FACEBOOK_CLIENT_ID not configured")

    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": redirect_uri,
        "scope": scopes,
        "response_type": "code",
        "state": state,
    }

    return f"{FACEBOOK_AUTH_BASE}?{urlencode(params)}"


# =====================================================
# 🔄 Exchange Code For Access Token
# =====================================================
def exchange_code(code: str, redirect_uri: str) -> dict:
    if not CLIENT_ID or not CLIENT_SECRET:
        raise RuntimeError("Facebook client credentials not configured")

    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": redirect_uri,
        "client_secret": CLIENT_SECRET,
        "code": code,
    }

    # 🔹 Exchange code for access token
    resp = requests.get(FACEBOOK_TOKEN_BASE, params=params, timeout=15)
    resp.raise_for_status()

    token_data = resp.json()
    access = token_data.get("access_token")

    if not access:
        raise RuntimeError("Failed to obtain Facebook access token")

    # 🔹 Get user profile (id + email)
    profile_resp = requests.get(
        FACEBOOK_GRAPH_BASE,
        params={
            "access_token": access,
            "fields": "id,email,name",
        },
        timeout=10,
    )

    profile_resp.raise_for_status()
    profile = profile_resp.json()

    external_id = profile.get("id")

    if not external_id:
        raise RuntimeError("Failed to fetch Facebook user id")

    return {
        "access_token": access,
        "refresh_token": None,  # Facebook does not issue refresh token in basic flow
        "external_id": str(external_id),
        "scopes": "public_profile,email",
    }