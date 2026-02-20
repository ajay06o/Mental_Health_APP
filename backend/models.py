# =====================================================
# IMPORTS
# =====================================================
from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    DateTime,
    Boolean,
    ForeignKey,
    Text,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from database import Base


# =====================================================
# 👤 USER MODEL
# =====================================================
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    email = Column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )

    password = Column(
        String(255),
        nullable=False,
    )

    emergency_email = Column(String(255), nullable=True)
    emergency_name = Column(String(255), nullable=True)

    alerts_enabled = Column(Boolean, default=False, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    emotions = relationship(
        "EmotionHistory",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
        lazy="selectin",
    )


# =====================================================
# 🧠 EMOTION HISTORY MODEL
# =====================================================
class EmotionHistory(Base):
    __tablename__ = "emotion_history"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    platform = Column(String(50), default="manual", nullable=False)

    emotion = Column(String(50), nullable=False)
    confidence = Column(Float, nullable=False, default=0.0)
    severity = Column(Integer, nullable=False, default=1)

    text = Column(Text, nullable=True)

    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    user = relationship("User", back_populates="emotions")


# =====================================================
# 🔗 SOCIAL ACCOUNT
# =====================================================
class SocialAccount(Base):
    __tablename__ = "social_accounts"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    provider = Column(String(50), nullable=False)
    external_id = Column(String(255), nullable=False, index=True)

    access_token = Column(Text, nullable=False)
    refresh_token = Column(Text, nullable=True)
    scopes = Column(Text, nullable=True)

    last_synced = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user = relationship("User")


# =====================================================
# 🗂 SOCIAL ACTIVITY
# =====================================================
class SocialActivity(Base):
    __tablename__ = "social_activities"

    id = Column(Integer, primary_key=True, index=True)

    account_id = Column(
        Integer,
        ForeignKey("social_accounts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    provider_item_id = Column(String(255), nullable=True, index=True)
    activity_type = Column(String(50), nullable=False)
    content = Column(Text, nullable=True)

    # ✅ FIXED (renamed from metadata)
    activity_metadata = Column(Text, nullable=True)

    processed = Column(Boolean, default=False, nullable=False)

    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    account = relationship("SocialAccount")