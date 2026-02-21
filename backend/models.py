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


# Social connection models removed (feature deprecated)
# If you need to restore them, see backend/migrations/001_drop_social_accounts.sql
# which can be reversed by restoring from backup.


# =====================================================
# 📨 UPLOADED CONTENT (explicit user uploads)
# =====================================================
class UploadedContent(Base):
    __tablename__ = "uploaded_content"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    content_type = Column(String(50), nullable=False)  # post, caption, comment, screenshot
    text = Column(Text, nullable=True)
    screenshot_base64 = Column(Text, nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user = relationship("User")


# =====================================================
# 📝 AUDIT LOG
# =====================================================
class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    action = Column(String(100), nullable=False)
    details = Column(Text, nullable=True)

    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user = relationship("User")