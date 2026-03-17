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