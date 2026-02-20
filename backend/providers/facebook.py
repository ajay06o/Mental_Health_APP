import os
import requests

CLIENT_ID = os.getenv("FACEBOOK_CLIENT_ID")
CLIENT_SECRET = os.getenv("FACEBOOK_CLIENT_SECRET")


def authorize_url(redirect_uri: str, state: str = "", scopes: str = "public_profile") -> str:
    if not CLIENT_ID:
        raise RuntimeError("FACEBOOK_CLIENT_ID not configured")

    return (
        f"https://www.facebook.com/v16.0/dialog/oauth?client_id={CLIENT_ID}"
        f"&redirect_uri={redirect_uri}&scope={scopes}&response_type=code&state={state}"
    )


def exchange_code(code: str, redirect_uri: str) -> dict:
    if not CLIENT_ID or not CLIENT_SECRET:
        raise RuntimeError("Facebook client credentials not configured")

    url = (
        f"https://graph.facebook.com/v16.0/oauth/access_token?client_id={CLIENT_ID}"
        f"&redirect_uri={redirect_uri}&client_secret={CLIENT_SECRET}&code={code}"
    )

    resp = requests.get(url, timeout=15)
    resp.raise_for_status()
    j = resp.json()

    access = j.get("access_token")

    # Get user id
    me = requests.get(f"https://graph.facebook.com/me?access_token={access}", timeout=10).json()
    external_id = me.get("id")

    return {
        "access_token": access,
        "refresh_token": None,
        "external_id": str(external_id),
        "scopes": None,
    }
