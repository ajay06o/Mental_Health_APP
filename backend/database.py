import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# ==============================
# 🗄️ DATABASE URL
# ==============================
# - PostgreSQL on Render (production)
# - SQLite locally (development fallback)
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "sqlite:///./mental_health.db",
)

# ==============================
# ⚙️ ENGINE CONFIGURATION
# ==============================
connect_args = {}

# SQLite requires special thread handling
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    pool_pre_ping=True,   # prevents stale DB connections
)

# ==============================
# 🔁 SESSION FACTORY
# ==============================
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

# ==============================
# 📦 BASE MODEL
# ==============================
Base = declarative_base()
