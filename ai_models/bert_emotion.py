# =====================================================
# 🧠 DISTILBERT EMOTION MODEL (PRODUCTION SAFE)
# =====================================================

import os

# 🚨 FORCE CPU (VERY IMPORTANT FOR RENDER)
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
os.environ["TRANSFORMERS_NO_ADVISORY_WARNINGS"] = "1"

from transformers import pipeline

# =====================================================
# GLOBAL MODEL (LAZY LOADED)
# =====================================================
_classifier = None


def _load_model():
    """
    Load DistilBERT emotion model ONLY ONCE.
    This prevents out-of-memory crashes on Render.
    """
    global _classifier

    if _classifier is None:
        print("🧠 Loading DistilBERT emotion model (CPU only)...")

        _classifier = pipeline(
            task="text-classification",
            model="bhadresh-savani/distilbert-base-uncased-emotion",
            device=-1,              # ✅ CPU ONLY
            truncation=True,
        )

        print("✅ DistilBERT emotion model loaded")

    return _classifier


# =====================================================
# 🔥 PREDICTION FUNCTION
# =====================================================
def predict_emotion(text: str) -> dict:
    """
    Predict emotion from user text.
    Safe for production and low-memory servers.
    """

    if not text or not text.strip():
        return {
            "emotion": "neutral",
            "confidence": 0.0,
        }

    classifier = _load_model()

    # Limit text length (VERY IMPORTANT)
    result = classifier(text[:512])[0]

    raw_emotion = result["label"].lower()
    confidence = round(float(result["score"]), 4)

    # =================================================
    # 🛡️ EMOTION NORMALIZATION (APP STANDARD)
    # =================================================
    emotion_map = {
        "joy": "happy",
        "sadness": "sad",
        "fear": "anxiety",
        "anger": "angry",
        "love": "happy",
        "surprise": "neutral",
    }

    emotion = emotion_map.get(raw_emotion, raw_emotion)

    return {
        "emotion": emotion,
        "confidence": confidence,
    }
