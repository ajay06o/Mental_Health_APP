from datetime import datetime, timedelta
from typing import Optional
from passlib.context import CryptContext
from jose import jwt, JWTError

# ==============================
# 🔐 SECURITY SETTINGS
# ==============================
SECRET_KEY = "CHANGE_THIS_SECRET_KEY"  # ❗ move to env variable in production
ALGORITHM = "HS256"

ACCESS_TOKEN_EXPIRE_MINUTES = 60        # 1 hour
REFRESH_TOKEN_EXPIRE_DAYS = 7           # 7 days

# ==============================
# 🔑 PASSWORD HASHING
# ==============================
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)

# ==============================
# 🔐 PASSWORD UTILITIES
# ==============================
def hash_password(password: str) -> str:
    """
    Hash password safely using bcrypt.
    bcrypt has a strict 72-byte limit.
    """
    if not isinstance(password, str):
        raise ValueError("Password must be a string")

    password = password.strip()
    if not password:
        raise ValueError("Password cannot be empty")

    # bcrypt 72-byte protection
    if len(password.encode("utf-8")) > 72:
        password = password.encode("utf-8")[:72].decode(
            "utf-8", errors="ignore"
        )

    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify plain password against stored bcrypt hash.
    """
    if not plain_password or not hashed_password:
        return False

    plain_password = plain_password.strip()

    if len(plain_password.encode("utf-8")) > 72:
        plain_password = plain_password.encode("utf-8")[:72].decode(
            "utf-8", errors="ignore"
        )

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

    expire = datetime.utcnow() + timedelta(
        minutes=expires_minutes
        if expires_minutes is not None
        else ACCESS_TOKEN_EXPIRE_MINUTES
    )

    to_encode.update({
        "exp": expire,
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

    expire = datetime.utcnow() + timedelta(
        days=REFRESH_TOKEN_EXPIRE_DAYS
    )

    to_encode.update({
        "exp": expire,
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
        )

        if payload.get("type") != "refresh":
            return None

        return payload.get("sub")

    except JWTError:
        return None
