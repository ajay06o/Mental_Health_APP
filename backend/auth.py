from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models import User
from schemas import UserCreate
from security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
)

# =====================================================
# REGISTER USER (SERVICE LAYER)
# =====================================================
def register_user(user: UserCreate, db: Session) -> User:
    """
    Create a new user with normalized email and hashed password.
    """
    email = user.email.strip().lower()

    existing = db.query(User).filter(User.email == email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    new_user = User(
        email=email,
        password=hash_password(user.password),
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user

# =====================================================
# LOGIN USER (INTERNAL USE)
# =====================================================
def login_user(
    *,
    email: str,
    password: str,
    db: Session,
) -> dict:
    """
    Validate credentials and return access + refresh tokens.

    NOTE:
    This is NOT used by OAuth2PasswordRequestForm directly.
    It is a reusable service helper for routes, tests, or CLI.
    """
    email = email.strip().lower()

    user = db.query(User).filter(User.email == email).first()

    if not user or not verify_password(password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    return {
        "access_token": create_access_token({"sub": user.email}),
        "refresh_token": create_refresh_token({"sub": user.email}),
        "token_type": "bearer",
    }
