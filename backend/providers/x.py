import os
import requests

# Twitter / X OAuth2 scaffolding. Note: production should implement PKCE and proper headers.
CLIENT_ID = os.getenv("X_CLIENT_ID")
CLIENT_SECRET = os.getenv("X_CLIENT_SECRET")


def authorize_url(redirect_uri: str, state: str = "", scopes: str = "tweet.read users.read offline.access") -> str:
    if not CLIENT_ID:
        raise RuntimeError("X_CLIENT_ID not configured")

    return (
        f"https://twitter.com/i/oauth2/authorize?response_type=code&client_id={CLIENT_ID}"
        f"&redirect_uri={redirect_uri}&scope={scopes}&state={state}"
    )


def exchange_code(code: str, redirect_uri: str) -> dict:
    # Placeholder implementation: real X/Twitter integration must handle PKCE and client auth.
    if not CLIENT_ID or not CLIENT_SECRET:
        raise RuntimeError("X client credentials not configured")

    url = "https://api.twitter.com/2/oauth2/token"
    data = {
        "code": code,
        "grant_type": "authorization_code",
        "client_id": CLIENT_ID,
        "redirect_uri": redirect_uri,
    }

    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
    }

    resp = requests.post(url, data=data, headers=headers, auth=(CLIENT_ID, CLIENT_SECRET), timeout=15)
    resp.raise_for_status()
    j = resp.json()

    access = j.get("access_token")
    refresh = j.get("refresh_token")

    # Try to retrieve user id if possible
    external_id = None
    if access:
        try:
            me = requests.get("https://api.twitter.com/2/users/me", headers={"Authorization": f"Bearer {access}"}, timeout=10)
            external_id = me.json().get("data", {}).get("id")
        except Exception:
            external_id = None

    return {
        "access_token": access,
        "refresh_token": refresh,
        "external_id": str(external_id) if external_id else None,
        "scopes": None,
    }
