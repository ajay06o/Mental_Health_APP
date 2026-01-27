from datetime import datetime, timedelta
from typing import Optional
import os

from passlib.context import CryptContext
from jose import jwt, JWTError

# ==============================
# 🔐 SECURITY SETTINGS
# ==============================
SECRET_KEY = os.getenv(
    "SECRET_KEY",
    "CHANGE_THIS_SECRET_KEY",  # ❗ override in production (Render ENV)
)

ALGORITHM = "HS256"

ACCESS_TOKEN_EXPIRE_MINUTES = 60        # 1 hour
REFRESH_TOKEN_EXPIRE_DAYS = 7           # 7 days

JWT_ISSUER = "mental-health-api"

# ==============================
# 🔑 PASSWORD HASHING
# ==============================
pwd_context = CryptContext(
    schemes=["bcrypt"],   # ✅ keep ONE algorithm
    deprecated="auto"
)

# ==============================
# 🔐 PASSWORD UTILITIES
# ==============================
def hash_password(password: str) -> str:
    """
    Hash password safely.
    IMPORTANT:
    - Do NOT strip
    - Do NOT lowercase
    - Do NOT normalize user input
    """
    if not isinstance(password, str):
        raise ValueError("Password must be a string")

    # bcrypt hard limit: 72 bytes
    if len(password.encode("utf-8")) > 72:
        password = password[:72]

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
    """
    Create a JWT access token.
    """
    if not isinstance(data, dict):
        raise ValueError("Token data must be a dictionary")

    to_encode = data.copy()

    now = datetime.utcnow()
    expire = now + timedelta(
        minutes=expires_minutes
        if expires_minutes is not None
        else ACCESS_TOKEN_EXPIRE_MINUTES
    )

    to_encode.update({
        "exp": expire,
        "iat": now,
        "iss": JWT_ISSUER,
        "type": "access",
    })

    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# ==============================
# 🔁 REFRESH TOKEN
# ==============================
def create_refresh_token(data: dict) -> str:
    """
    Create a JWT refresh token.
    """
    if not isinstance(data, dict):
        raise ValueError("Token data must be a dictionary")

    to_encode = data.copy()

    now = datetime.utcnow()
    expire = now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)

    to_encode.update({
        "exp": expire,
        "iat": now,
        "iss": JWT_ISSUER,
        "type": "refresh",
    })

    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def verify_refresh_token(token: str) -> Optional[str]:
    """
    Verify refresh token and return user email (sub).
    """
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
            options={"verify_aud": False},
        )

        if payload.get("type") != "refresh":
            return None

        return payload.get("sub")

    except JWTError:
        return None
