from datetime import datetime, timedelta, timezone
from typing import Optional
import os

from passlib.context import CryptContext
from jose import jwt, JWTError

# 🔥 PROOF LOG (REMOVE AFTER DEBUG)
print("🔥 UPDATED security.py LOADED 🔥")

# ==============================
# 🔐 SECURITY SETTINGS
# ==============================
SECRET_KEY = os.getenv(
    "SECRET_KEY",
    "CHANGE_THIS_SECRET_KEY",  # ❗ set in Render ENV for production
)

ALGORITHM = "HS256"

ACCESS_TOKEN_EXPIRE_MINUTES = 60        # 1 hour
REFRESH_TOKEN_EXPIRE_DAYS = 7           # 7 days

JWT_ISSUER = "mental-health-api"

# ==============================
# 🔑 PASSWORD HASHING
# ==============================
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
)

# ==============================
# 🔐 PASSWORD UTILITIES
# ==============================
def hash_password(password: str) -> str:
    """
    Hash password safely.
    Rules:
    - Do NOT modify user input
    - Reject passwords > 72 bytes (bcrypt limit)
    """
    if not isinstance(password, str):
        raise ValueError("Password must be a string")

    raw = password.encode("utf-8")

    # bcrypt hard limit
    if len(raw) > 72:
        raise ValueError(
            "Password is too long. Please use 72 bytes or fewer (avoid emojis)."
        )

    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify plain password against stored bcrypt hash.
    """
    if not plain_password or not hashed_password:
        return False

    try:
        return pwd_context.verify(plain_password, hashed_password)
    except Exception:
        return False

# ==============================
# 🎟️ ACCESS TOKEN
# ==============================
def create_access_token(
    data: dict,
    expires_minutes: Optional[int] = None,
) -> str:
    if not isinstance(data, dict):
        raise ValueError("Token data must be a dictionary")

    now = datetime.now(timezone.utc)
    expire = now + timedelta(
        minutes=expires_minutes
        if expires_minutes is not None
        else ACCESS_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        **data,
        "exp": expire,
        "iat": now,
        "iss": JWT_ISSUER,
        "type": "access",
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

# ==============================
# 🔁 REFRESH TOKEN
# ==============================
def create_refresh_token(data: dict) -> str:
    if not isinstance(data, dict):
        raise ValueError("Token data must be a dictionary")

    now = datetime.now(timezone.utc)
    expire = now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)

    payload = {
        **data,
        "exp": expire,
        "iat": now,
        "iss": JWT_ISSUER,
        "type": "refresh",
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

# ==============================
# 🔍 VERIFY REFRESH TOKEN
# ==============================
def verify_refresh_token(token: str) -> Optional[str]:
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
            options={"verify_aud": False},
        )

        if payload.get("iss") != JWT_ISSUER:
            return None

        if payload.get("type") != "refresh":
            return None

        return payload.get("sub")

    except JWTError:
        return None

