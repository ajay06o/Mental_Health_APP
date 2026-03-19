import os
import logging
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

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

try:
    engine = create_engine(
        DATABASE_URL,
        connect_args=connect_args,
        pool_pre_ping=True,     # avoids stale connections
        pool_recycle=280,       # prevents timeout issues (Render fix)
        pool_size=5,
        max_overflow=10,
        echo=False,             # set True for SQL debugging
    )
    logger.info("✅ Database engine created successfully")

except Exception as e:
    logger.error(f"❌ Error creating database engine: {e}")
    raise

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
# 🧪 OPTIONAL: DATABASE HEALTH CHECK
# =====================================================
def check_db_connection():
    try:
        with engine.connect() as connection:
            connection.execute("SELECT 1")
        logger.info("✅ Database connection successful")
        return True
    except Exception as e:
        logger.error(f"❌ Database connection failed: {e}")
        return False