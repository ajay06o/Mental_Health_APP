import smtplib
import os
from email.mime.text import MIMEText
import logging

logger = logging.getLogger("email")

SMTP_SERVER = os.getenv("SMTP_SERVER")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))
SMTP_USERNAME = os.getenv("SMTP_USERNAME")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")


def send_crisis_email(to_email: str, user_email: str):
    if not all([SMTP_SERVER, SMTP_USERNAME, SMTP_PASSWORD]):
        logger.warning("SMTP not configured.")
        return

    subject = "🚨 Mental Health Crisis Alert"

    body = f"""
    Hello,

    A high-risk emotional state was detected for user: {user_email}.

    This may indicate severe distress.

    Please check on them immediately.

    — Mental Health Monitoring System
    """

    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = SMTP_USERNAME
    msg["To"] = to_email

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)

        logger.warning(f"Crisis email sent to {to_email}")

    except Exception as e:
        logger.error(f"Email sending failed: {e}")
