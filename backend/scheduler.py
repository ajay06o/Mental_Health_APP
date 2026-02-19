from apscheduler.schedulers.background import BackgroundScheduler
from database import SessionLocal
from models import User, SocialAccount
from routes.social import analyze_social_accounts
import logging

logger = logging.getLogger("scheduler")

scheduler = BackgroundScheduler()

def daily_analysis():
    db = SessionLocal()
    try:
        users = db.query(User).all()

        for user in users:
            logger.info(f"Auto analyzing user {user.id}")
            analyze_social_accounts(user=user, db=db)

    except Exception as e:
        logger.error(f"Scheduler error: {e}")
    finally:
        db.close()

def start_scheduler():
    scheduler.add_job(
        daily_analysis,
        trigger="interval",
        hours=24
    )
    scheduler.start()
