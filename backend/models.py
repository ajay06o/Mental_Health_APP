from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    DateTime,
    ForeignKey,
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from database import Base


# ==============================
# 👤 USER MODEL
# ==============================
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    # Email should be unique & indexed
    email = Column(String(255), unique=True, index=True, nullable=False)

    # Store hashed password only
    password = Column(String(255), nullable=False)

    # Auto timestamp
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationship
    emotions = relationship(
        "EmotionHistory",
        back_populates="user",
        cascade="all, delete-orphan"
    )


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

    text = Column(String(1000), nullable=False)
    emotion = Column(String(50), nullable=False)
    confidence = Column(Float, nullable=False)
    severity = Column(Integer, nullable=False)

    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user = relationship("User", back_populates="emotions")

