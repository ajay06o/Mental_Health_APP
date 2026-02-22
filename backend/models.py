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

    # 👤 Full Name
    name = Column(
        String(255),
        nullable=True,
    )

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

    # 🖼 Profile Image URL (stores "/uploads/user_1.jpg")
    profile_image = Column(
        String(500),
        nullable=True,
    )

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

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationship with Emotion History
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

    platform = Column(
        String(50),
        default="manual",
        nullable=False,
    )

    emotion = Column(String(50), nullable=False)

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

    user = relationship(
        "User",
        back_populates="emotions",
    )