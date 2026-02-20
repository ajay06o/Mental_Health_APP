import os
import requests

CLIENT_ID = os.getenv("INSTAGRAM_CLIENT_ID")
CLIENT_SECRET = os.getenv("INSTAGRAM_CLIENT_SECRET")


def authorize_url(redirect_uri: str, state: str = "", scopes: str = "user_profile,user_media") -> str:
    if not CLIENT_ID:
        raise RuntimeError("INSTAGRAM_CLIENT_ID not configured")

    return (
        f"https://api.instagram.com/oauth/authorize?client_id={CLIENT_ID}"
        f"&redirect_uri={redirect_uri}&scope={scopes}&response_type=code&state={state}"
    )


def exchange_code(code: str, redirect_uri: str) -> dict:
    if not CLIENT_ID or not CLIENT_SECRET:
        raise RuntimeError("Instagram client credentials not configured")

    url = "https://api.instagram.com/oauth/access_token"
    data = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri,
        "code": code,
    }

    resp = requests.post(url, data=data, timeout=15)
    resp.raise_for_status()
    j = resp.json()

    # Response contains access_token and user_id
    return {
        "access_token": j.get("access_token"),
        "refresh_token": None,
        "external_id": str(j.get("user_id")),
        "scopes": None,
    }
