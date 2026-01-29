from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
import os

from passlib.context import CryptContext
from jose import jwt, JWTError
from dotenv import load_dotenv

# ==============================
# 🔐 LOAD ENV VARIABLES
# ==============================
load_dotenv()

# ==============================
# 🔐 SECURITY SETTINGS
# ==============================
SECRET_KEY = os.getenv("SECRET_KEY")

if not SECRET_KEY:
    raise RuntimeError("❌ SECRET_KEY not set in environment variables")

ALGORITHM = os.getenv("ALGORITHM", "HS256")

ACCESS_TOKEN_EXPIRE_MINUTES = int(
    os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30)
)

REFRESH_TOKEN_EXPIRE_DAYS = int(
    os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", 7)
)

JWT_ISSUER = "mental-health-api"

# ==============================
# 🔑 PASSWORD HASHING (ARGON2)
# ==============================
pwd_context = CryptContext(
    schemes=["argon2"],
    deprecated="auto",
)

# ==============================
# 🔐 PASSWORD UTILITIES
# ==============================
def hash_password(password: str) -> str:
    """
    Hash password using Argon2.
    - No 72-byte limit
    - Unicode safe
    - Memory-hard (GPU resistant)
    """
    if not isinstance(password, str):
        raise ValueError("Password must be a string")

    password = password.strip()

    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")

    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify password against Argon2 hash.
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
    data: Dict[str, Any],
    expires_minutes: Optional[int] = None,
) -> str:
    """
    Create short-lived access token.
    """
    if not isinstance(data, dict):
        raise ValueError("Token payload must be a dictionary")

    if "sub" not in data:
        raise ValueError("Token payload must contain 'sub'")

    now = datetime.now(timezone.utc)
    expire = now + timedelta(
        minutes=expires_minutes
        if expires_minutes is not None
        else ACCESS_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "sub": data["sub"],
        "exp": expire,
        "iat": now,
        "iss": JWT_ISSUER,
        "type": "access",
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

# ==============================
# 🔁 REFRESH TOKEN
# ==============================
def create_refresh_token(data: Dict[str, Any]) -> str:
    """
    Create long-lived refresh token.
    """
    if not isinstance(data, dict):
        raise ValueError("Token payload must be a dictionary")

    if "sub" not in data:
        raise ValueError("Token payload must contain 'sub'")

    now = datetime.now(timezone.utc)
    expire = now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)

    payload = {
        "sub": data["sub"],
        "exp": expire,
        "iat": now,
        "iss": JWT_ISSUER,
        "type": "refresh",
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

# ==============================
# 🔍 VERIFY ACCESS TOKEN
# ==============================
def verify_access_token(token: str) -> Optional[str]:
    """
    Verify access token and return subject (user id / email).
    """
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
            options={"verify_aud": False},
        )

        if payload.get("iss") != JWT_ISSUER:
            return None

        if payload.get("type") != "access":
            return None

        return payload.get("sub")

    except JWTError:
        return None

# ==============================
# 🔍 VERIFY REFRESH TOKEN
# ==============================
def verify_refresh_token(token: str) -> Optional[str]:
    """
    Verify refresh token and return subject.
    """
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
