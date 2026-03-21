from fastapi import APIRouter
import os, base64, requests, secrets, hashlib
from fastapi.responses import RedirectResponse
from fastapi.responses import HTMLResponse

router = APIRouter()

CLIENT_ID = os.getenv("TWITTER_CLIENT_ID")
CLIENT_SECRET = os.getenv("TWITTER_CLIENT_SECRET")

REDIRECT_URI = "https://mental-health-app-zpng.onrender.com/auth/twitter/callback"


@router.get("/auth/twitter")
def twitter_login():
    code_verifier = secrets.token_urlsafe(64)

    code_challenge = hashlib.sha256(code_verifier.encode()).digest()
    code_challenge = base64.urlsafe_b64encode(code_challenge).decode().replace("=", "")

    os.environ["CODE_VERIFIER"] = code_verifier

    url = (
        "https://twitter.com/i/oauth2/authorize?"
        f"response_type=code&client_id={CLIENT_ID}"
        f"&redirect_uri={REDIRECT_URI}"
        "&scope=tweet.read users.read offline.access"
        "&state=abc123"
        f"&code_challenge={code_challenge}"
        "&code_challenge_method=S256"
    )

    return {"url": url}


@router.get("/auth/twitter/callback")
def twitter_callback(code: str):

    code_verifier = os.getenv("CODE_VERIFIER")

    basic_auth = base64.b64encode(
        f"{CLIENT_ID}:{CLIENT_SECRET}".encode()
    ).decode()

    headers = {
        "Authorization": f"Basic {basic_auth}",
        "Content-Type": "application/x-www-form-urlencoded",
    }

    data = {
        "code": code,
        "grant_type": "authorization_code",
        "redirect_uri": REDIRECT_URI,
        "code_verifier": code_verifier,
    }

    token_res = requests.post(
        "https://api.twitter.com/2/oauth2/token",
        headers=headers,
        data=data,
    )

    token_json = token_res.json()
    access_token = token_json.get("access_token")

    if not access_token:
        return {"error": token_json}

    headers = {"Authorization": f"Bearer {access_token}"}

    user_res = requests.get(
        "https://api.twitter.com/2/users/me",
        headers=headers
    )

    user_id = user_res.json()["data"]["id"]

    tweet_res = requests.get(
        f"https://api.twitter.com/2/users/{user_id}/tweets?max_results=10",
        headers=headers
    )

    tweets = tweet_res.json().get("data", [])
    texts = [t["text"] for t in tweets]

    from services.analyzer import analyze_text
    results = [analyze_text(t) for t in texts]

    html_content = f"""
    <h2>Twitter Mental Health Analysis</h2>

    <h3>Tweets:</h3>
    <ul>
    {''.join(f"<li>{t}</li>" for t in texts)}
    </ul>

    <h3>Analysis:</h3>
    <ul>
    {''.join(f"<li>{r}</li>" for r in results)}
    </ul>
    """

    return HTMLResponse(content=html_content)