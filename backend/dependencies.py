from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy import create_engine
import os

# =====================================================
# DATABASE CONFIG
# =====================================================

DATABASE_URL = os.getenv("DATABASE_URL")

# Fallback to SQLite (for local dev)
if not DATABASE_URL:
    DATABASE_URL = "sqlite:///./mental_health.db"

# SQLite specific config
connect_args = {}
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

# =====================================================
# ENGINE
# =====================================================

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
)

# =====================================================
# SESSION
# =====================================================

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

# =====================================================
# DEPENDENCY (USED IN FASTAPI)
# =====================================================

def get_db() -> Session:
    """
    FastAPI dependency for DB session.
    Ensures:
    - Open session
    - Close after request
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()