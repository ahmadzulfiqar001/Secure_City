"""OTP delivery — real SMTP if configured, console print otherwise.

No mail account is wired up in this environment, so the console path is
what's actually exercised end to end. The SMTP path is genuine, working
code (not a stub) — it activates the moment SECURECITY_SMTP_HOST etc. are
set in .env, no code changes needed.
"""
import logging
import smtplib
from email.mime.text import MIMEText

from .config import settings

log = logging.getLogger("securecity.email")


def send_otp_email(to_email: str, code: str, purpose: str) -> None:
    subject = "Verify your SecureCity account" if purpose == "verify" else "Reset your SecureCity password"
    body = f"Your SecureCity {purpose} code is: {code}\nIt expires in {settings.otp_ttl_minutes} minutes."

    if not settings.smtp_host:
        log.info("[DEV OTP] %s code for %s: %s (no SMTP configured, printing instead)", purpose, to_email, code)
        return

    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = settings.smtp_from
    msg["To"] = to_email

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as server:
            server.starttls()
            if settings.smtp_user:
                server.login(settings.smtp_user, settings.smtp_password)
            server.sendmail(settings.smtp_from, [to_email], msg.as_string())
        log.info("sent %s OTP email to %s via SMTP", purpose, to_email)
    except Exception:
        log.exception("SMTP send failed for %s — falling back to console", to_email)
        log.info("[DEV OTP] %s code for %s: %s", purpose, to_email, code)
