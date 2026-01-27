import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# ==============================
# 📂 BASE DIRECTORY
# ==============================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ==============================
# 🗄️ DATABASE URL
# ==============================
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    f"sqlite:///{os.path.join(BASE_DIR, 'mental_health.db')}"
)

# ==============================
# ⚙️ ENGINE CONFIGURATION
# ==============================
if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        pool_pre_ping=True,
    )
else:
    # PostgreSQL (Render / Production)
    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
    )

# ==============================
# 🔁 SESSION
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

