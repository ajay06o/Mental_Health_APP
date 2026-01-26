from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import SessionLocal
from models import User
from schemas import UserCreate, UserLogin
from security import hash_password, verify_password, create_access_token

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ==============================
# REGISTER
# ==============================
def register_user(user: UserCreate, db: Session):
    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="User already exists")

    new_user = User(
        email=user.email,
        password=hash_password(user.password)
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

# ==============================
# LOGIN
# ==============================
def login_user(user: UserLogin, db: Session):
    db_user = db.query(User).filter(User.email == user.email).first()

    if not db_user or not verify_password(user.password, db_user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )

    token = create_access_token({"sub": db_user.email})
    return token
