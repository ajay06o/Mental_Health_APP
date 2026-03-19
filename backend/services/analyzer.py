from utils.text_cleaner import clean_text
from services.scoring import emotion_to_score
import requests
import os
import time
from functools import lru_cache

HF_API_TOKEN = os.getenv("HF_API_TOKEN")

# ✅ Updated to YOUR MODEL
MODEL_URL = "https://router.huggingface.co/hf-inference/models/cardiffnlp/twitter-xlm-roberta-base-sentiment"

HEADERS = {
    "Authorization": f"Bearer {HF_API_TOKEN}"
}


# =====================================================
# LABEL MAPPING (VERY IMPORTANT)
# =====================================================

LABEL_MAP = {
    "LABEL_0": "negative",
    "LABEL_1": "neutral",
    "LABEL_2": "positive"
}


# =====================================================
# 🚀 CACHE (BOOST PERFORMANCE)
# =====================================================

@lru_cache(maxsize=500)
def cached_prediction(text: str):
    return _predict_emotion(text)


# =====================================================
# HUGGINGFACE CALL (SAFE + RETRY)
# =====================================================

def _predict_emotion(text: str):

    payload = {"inputs": text}

    for attempt in range(2):
        try:
            response = requests.post(
                MODEL_URL,
                headers=HEADERS,
                json=payload,
                timeout=10
            )

            # Retry on cold start
            if response.status_code == 503:
                time.sleep(2)
                continue

            if response.status_code != 200:
                return "neutral", 0.5

            result = response.json()

            if isinstance(result, list) and len(result) > 0:

                scores = result[0]
                top = max(scores, key=lambda x: x["score"])

                label = LABEL_MAP.get(top["label"], "neutral")
                confidence = float(top["score"])

                return label, confidence

        except Exception:
            time.sleep(1)

    return "neutral", 0.5


# =====================================================
# PUBLIC FUNCTION
# =====================================================

def predict_emotion(text: str):
    return cached_prediction(text)


# =====================================================
# MAIN ANALYSIS FUNCTION
# =====================================================

def analyze_text(text: str):

    if not text or not text.strip():
        return {
            "emotion": "neutral",
            "confidence": 0.0,
            "score": 0
        }

    cleaned = clean_text(text)

    emotion, confidence = predict_emotion(cleaned)

    score = emotion_to_score(emotion)

    return {
        "emotion": emotion,        # keep same key (no breaking changes)
        "confidence": round(confidence, 4),
        "score": score
    }