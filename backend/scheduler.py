from apscheduler.schedulers.background import BackgroundScheduler
import logging

logger = logging.getLogger("scheduler")

# Scheduler retained for other jobs but social auto-analysis is disabled.
scheduler = BackgroundScheduler()

def daily_analysis():
    logger.info("Daily social analysis is disabled. No automatic social scraping will run.")


def start_scheduler():
    # Keep the scheduler running for other potential jobs, but do not schedule social analysis
    scheduler.start()
