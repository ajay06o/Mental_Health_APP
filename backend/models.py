from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from database import Base   # ✅ FIXED IMPORT


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password = Column(String, nullable=False)

    emotions = relationship("EmotionHistory", back_populates="user")


class EmotionHistory(Base):
    __tablename__ = "emotion_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    text = Column(String, nullable=False)
    emotion = Column(String, nullable=False)
    confidence = Column(Float, nullable=False)
    severity = Column(Integer, nullable=False)

    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now()
    )

    user = relationship("User", back_populates="emotions")



