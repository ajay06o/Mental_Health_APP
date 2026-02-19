from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    DateTime,
    ForeignKey,
    Boolean,
    UniqueConstraint,
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from database import Base

from sqlalchemy import Boolean



# ==============================
# 👤 USER MODEL
# ==============================
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    email = Column(String(255), unique=True, index=True, nullable=False)
    password = Column(String(255), nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # 🔗 Relationships
    emotions = relationship(
        "EmotionHistory",
        back_populates="user",
        cascade="all, delete-orphan"
    )

    social_accounts = relationship(
        "SocialAccount",
        back_populates="user",
        cascade="all, delete-orphan"
    )


# ==============================
# 🌐 SOCIAL ACCOUNT MODEL
# ==============================
class SocialAccount(Base):
    __tablename__ = "social_accounts"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    platform = Column(String(50), nullable=False)

    access_token = Column(String(500), nullable=False)

    is_active = Column(Boolean, default=True, nullable=False)

    connected_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # 🔒 Prevent duplicate platform per user
    __table_args__ = (
        UniqueConstraint("user_id", "platform", name="uq_user_platform"),
    )

    user = relationship("User", back_populates="social_accounts")


# ==============================
# 🧠 EMOTION HISTORY MODEL
# ==============================
class EmotionHistory(Base):
    __tablename__ = "emotion_history"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # 🔹 Track source
    platform = Column(String(50), nullable=False, default="manual")

    # ❌ Removed raw text storage (privacy-first design)

    emotion = Column(String(50), nullable=False, index=True)

    confidence = Column(Float, nullable=False)

    severity = Column(Integer, nullable=False, index=True)

    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    user = relationship("User", back_populates="emotions")

    emergency_email = Column(String(255), nullable=True)
    emergency_name = Column(String(100), nullable=True)
    alerts_enabled = Column(Boolean, default=True)

