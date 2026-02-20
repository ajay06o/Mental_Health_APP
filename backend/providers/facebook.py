import os
import requests
from urllib.parse import urlencode

CLIENT_ID = os.getenv("FACEBOOK_CLIENT_ID")
CLIENT_SECRET = os.getenv("FACEBOOK_CLIENT_SECRET")

FACEBOOK_AUTH_BASE = "https://www.facebook.com/v18.0/dialog/oauth"
FACEBOOK_TOKEN_BASE = "https://graph.facebook.com/v18.0/oauth/access_token"
FACEBOOK_GRAPH_BASE = "https://graph.facebook.com/v18.0/me"


# =====================================================
# 🔐 Generate OAuth URL
# =====================================================
def authorize_url(
    redirect_uri: str,
    state: str = "",
    scopes: str = "public_profile,email",
) -> str:
    """
    Generates Facebook OAuth authorization URL.
    """

    if not CLIENT_ID:
        raise RuntimeError("FACEBOOK_CLIENT_ID not configured")

    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": scopes,
        "state": state,
    }

    return f"{FACEBOOK_AUTH_BASE}?{urlencode(params)}"


# =====================================================
# 🔄 Exchange Code For Access Token
# =====================================================
def exchange_code(code: str, redirect_uri: str) -> dict:
    """
    Exchanges authorization code for access token
    and retrieves user profile.
    """

    if not CLIENT_ID or not CLIENT_SECRET:
        raise RuntimeError("Facebook client credentials not configured")

    # 🔹 Step 1: Exchange code for access token
    token_params = {
        "client_id": CLIENT_ID,
        "redirect_uri": redirect_uri,
        "client_secret": CLIENT_SECRET,
        "code": code,
    }

    token_resp = requests.get(
        FACEBOOK_TOKEN_BASE,
        params=token_params,
        timeout=15,
    )

    if token_resp.status_code != 200:
        raise RuntimeError(
            f"Facebook token exchange failed: {token_resp.text}"
        )

    token_data = token_resp.json()
    access_token = token_data.get("access_token")

    if not access_token:
        raise RuntimeError("No access_token returned by Facebook")

    # 🔹 Step 2: Fetch user profile
    profile_params = {
        "access_token": access_token,
        "fields": "id,name,email",  # email only returned if granted
    }

    profile_resp = requests.get(
        FACEBOOK_GRAPH_BASE,
        params=profile_params,
        timeout=10,
    )

    if profile_resp.status_code != 200:
        raise RuntimeError(
            f"Facebook profile fetch failed: {profile_resp.text}"
        )

    profile = profile_resp.json()
    external_id = profile.get("id")

    if not external_id:
        raise RuntimeError("Failed to fetch Facebook user ID")

    return {
        "access_token": access_token,
        "refresh_token": None,
        "external_id": str(external_id),
        "scopes": "public_profile,email",
    }