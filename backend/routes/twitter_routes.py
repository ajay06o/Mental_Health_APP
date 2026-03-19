from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from services.twitter_service import get_twitter_analysis
from database import get_db
from models import User  # make sure you have this model

router = APIRouter(prefix="/twitter", tags=["Twitter"])


# =========================================
# TWITTER ANALYSIS API
# =========================================
@router.get("/analysis")
def twitter_analysis(user_id: str, db: Session = Depends(get_db)):
    try:
        # 🔹 1. Get user from DB
        user = db.query(User).filter(User.twitter_id == user_id).first()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # 🔹 2. Get stored access token
        access_token = user.access_token

        if not access_token:
            raise HTTPException(status_code=400, detail="Twitter not connected")

        # 🔹 3. Get analysis
        result = get_twitter_analysis(user_id, access_token)

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))