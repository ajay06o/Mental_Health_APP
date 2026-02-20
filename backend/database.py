import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# =====================================================
# 🗄️ DATABASE URL
# =====================================================
DATABASE_URL = os.getenv("DATABASE_URL")

# =====================================================
# ⚠️ LOCAL FALLBACK (ONLY FOR DEVELOPMENT)
# =====================================================
if not DATABASE_URL:
    print("⚠️ DATABASE_URL not set. Using local SQLite.")
    DATABASE_URL = "sqlite:///./mental_health.db"

# =====================================================
# 🔒 FORCE SSL FOR POSTGRESQL (Render Requirement)
# =====================================================
if DATABASE_URL.startswith("postgresql"):
    if "sslmode" not in DATABASE_URL:
        if "?" in DATABASE_URL:
            DATABASE_URL += "&sslmode=require"
        else:
            DATABASE_URL += "?sslmode=require"

# =====================================================
# ⚙️ ENGINE CONFIGURATION
# =====================================================
connect_args = {}

if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    pool_pre_ping=True,
    pool_recycle=280,
    pool_size=5,
    max_overflow=10,
)

# =====================================================
# 🔁 SESSION FACTORY
# =====================================================
SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
)

# =====================================================
# 📦 BASE MODEL
# =====================================================
Base = declarative_base()

# =====================================================
# 🔄 FASTAPI DATABASE DEPENDENCY (THIS WAS MISSING)
# =====================================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()