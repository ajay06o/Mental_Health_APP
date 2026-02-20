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

    # Email
    email = Column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )

    # Hashed password
    password = Column(
        String(255),
        nullable=False,
    )

    # Optional safety settings
    emergency_email = Column(
        String(255),
        nullable=True,
    )

    emergency_name = Column(
        String(255),
        nullable=True,
    )

    alerts_enabled = Column(
        Boolean,
        default=False,
        nullable=False,
    )

    # Account created timestamp
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationship
    emotions = relationship(
        "EmotionHistory",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
        lazy="selectin",   # efficient loading
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

    # Source platform
    platform = Column(
        String(50),
        default="manual",
        nullable=False,
    )

    # AI result
    emotion = Column(
        String(50),
        nullable=False,
    )

    confidence = Column(
        Float,
        nullable=False,
        default=0.0,
    )

    severity = Column(
        Integer,
        nullable=False,
        default=1,
    )

    text = Column(
        Text,
        nullable=True,
    )

    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    # Relationship
    user = relationship(
        "User",
        back_populates="emotions",
    )