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

    # ✅ Normalize email safely
    email = user.email.strip().lower()

    # Extra defensive validation (prevents silent bad data)
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email cannot be empty",
        )

    if not user.password or not user.password.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password cannot be empty",
        )

    # ✅ Check existing user
    existing = db.query(User).filter(User.email == email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    # ✅ Create user with hashed password
    new_user = User(
        email=email,
        password=hash_password(user.password.strip()),
    )

    db.add(new_user)

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error during registration",
        )

    db.refresh(new_user)

    return new_user


# =====================================================
# LOGIN USER (SERVICE LAYER)
# =====================================================
def login_user(*, email: str, password: str, db: Session) -> dict:
    email = email.strip().lower()

    print("LOGIN ATTEMPT:", email)

    user = db.query(User).filter(User.email == email).first()

    if not user:
        print("USER NOT FOUND")
    
    if user and not verify_password(password, user.password):
        print("PASSWORD MISMATCH")

    if not user or not verify_password(password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    print("LOGIN SUCCESS:", user.id)

    token_payload = {
        "sub": user.email,
    }

    return {
    "access_token": create_access_token({"sub": user.email}),
    "refresh_token": create_refresh_token({"sub": user.email}),
    "token_type": "bearer",
}
    # =====================================================
# 🐦 TWITTER LOGIN / REGISTER (SERVICE LAYER)
# =====================================================
def twitter_login_user(
    *,
    twitter_id: str,
    username: str,
    access_token: str,
    db: Session,
) -> dict:
    """
    Handles Twitter login:
    - If user exists → update token
    - If not → create new user
    """

    if not twitter_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid Twitter ID",
        )

    # 🔹 1. Check if user already exists (by twitter_id)
    user = db.query(User).filter(User.twitter_id == twitter_id).first()

    if user:
        # ✅ Update token (important)
        user.twitter_access_token = access_token
        user.twitter_username = username

        db.commit()
        db.refresh(user)

    else:
        # 🔹 2. Create new user (Twitter-based account)
        user = User(
            name=username,
            email=f"{twitter_id}@twitter.com",  # dummy email (required field)
            password=hash_password(twitter_id),  # dummy password
            twitter_id=twitter_id,
            twitter_username=username,
            twitter_access_token=access_token,
        )

        db.add(user)

        try:
            db.commit()
        except Exception:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Database error during Twitter login",
            )

        db.refresh(user)

    # 🔹 3. Generate JWT tokens
    return {
        "access_token": create_access_token({"sub": user.email}),
        "refresh_token": create_refresh_token({"sub": user.email}),
        "token_type": "bearer",
        "user_id": user.id,
        "twitter_connected": True,
    }