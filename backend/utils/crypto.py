from cryptography.fernet import Fernet
import os

FERNET_KEY = os.getenv("FERNET_KEY")

if not FERNET_KEY:
    raise RuntimeError("FERNET_KEY not set")

cipher = Fernet(FERNET_KEY.encode())


def encrypt_token(token: str) -> str:
    return cipher.encrypt(token.encode()).decode()


def decrypt_token(token: str) -> str:
    return cipher.decrypt(token.encode()).decode()
