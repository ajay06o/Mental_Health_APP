import os
import logging
import time
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import NullPool

# =====================================================
# 🔧 LOGGING SETUP
# =====================================================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# =====================================================
# 🗄️ DATABASE URL
# =====================================================
DATABASE_URL = os.getenv("DATABASE_URL")

# =====================================================
# ⚠️ LOCAL FALLBACK (ONLY FOR DEVELOPMENT)
# =====================================================
if not DATABASE_URL:
    logger.warning("⚠️ DATABASE_URL not set. Using local SQLite.")
    DATABASE_URL = "sqlite:///./mental_health.db"

# =====================================================
# 🔧 FIX POSTGRES URL FORMAT (Render issue)
# =====================================================
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

# =====================================================
# ⚙️ ENGINE CONFIGURATION
# =====================================================
def create_db_engine():
    try:
        if DATABASE_URL.startswith("sqlite"):
            engine = create_engine(
                DATABASE_URL,
                connect_args={"check_same_thread": False},
                echo=False,
            )
        else:
            engine = create_engine(
                DATABASE_URL,
                poolclass=NullPool,  # 🔥 CRITICAL for Render
                connect_args={
                    "sslmode": "require",
                    "connect_timeout": 10,
                },
                echo=False,
            )

        logger.info("✅ Database engine created successfully")
        return engine

    except Exception as e:
        logger.error(f"❌ Engine creation failed: {e}")
        raise

engine = create_db_engine()

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
# 🔄 FASTAPI DATABASE DEPENDENCY
# =====================================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    except Exception as e:
        logger.error(f"❌ DB Session Error: {e}")
        db.rollback()
        raise
    finally:
        db.close()

# =====================================================
# 🔥 SAFE QUERY EXECUTION (RETRY LOGIC)
# =====================================================
def safe_db_execute(db, query):
    retries = 2

    for attempt in range(retries):
        try:
            return db.execute(query)
        except Exception as e:
            logger.warning(f"⚠️ Query failed (attempt {attempt+1}): {e}")

            if attempt == retries - 1:
                raise

            time.sleep(1)

# =====================================================
# 🧪 DATABASE HEALTH CHECK (WITH RETRY)
# =====================================================
def check_db_connection():
    retries = 2

    for attempt in range(retries):
        try:
            with engine.connect() as connection:
                connection.execute(text("SELECT 1"))

            logger.info("✅ Database connection successful")
            return True

        except Exception as e:
            logger.warning(f"⚠️ DB check failed (attempt {attempt+1}): {e}")
            time.sleep(1)

    logger.error("❌ Database connection failed after retries")
    return False