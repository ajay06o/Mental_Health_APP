import logging
from utils.email_service import send_crisis_email

logger = logging.getLogger("alerts")

def trigger_crisis_alert(user):

    if not user.alerts_enabled:
        logger.info("Alerts disabled for user.")
        return

    if not user.emergency_email:
        logger.warning("No emergency contact set.")
        return

    logger.warning(
        f"🚨 CRISIS ALERT triggered for user {user.email}"
    )

    send_crisis_email(
        to_email=user.emergency_email,
        user_email=user.email,
    )
