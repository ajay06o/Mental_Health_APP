# ai_models/bert_emotion.py
# =====================================================
# 🧠 DISTILBERT EMOTION MODEL (RENDER-STABLE)
# =====================================================

import os

# 🚨 FORCE CPU (MANDATORY FOR RENDER)
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
os.environ["TRANSFORMERS_NO_ADVISORY_WARNINGS"] = "1"

from transformers import pipeline

print("🧠 Loading DistilBERT emotion model at startup (CPU only)...")

# =====================================================
# ✅ LOAD MODEL ONCE AT STARTUP
# =====================================================
classifier = pipeline(
    task="text-classification",
    model="bhadresh-savani/distilbert-base-uncased-emotion",
    device=-1,          # CPU ONLY
    truncation=True,
)

print("✅ DistilBERT emotion model loaded successfully")

# =====================================================
# 🔥 PREDICTION FUNCTION (FAST & SAFE)
# =====================================================
def predict_emotion(text: str) -> dict:
    """
    Predict emotion from user text.
    Safe for low-memory servers.
    """

    if not text or not text.strip():
        return {
            "emotion": "neutral",
            "confidence": 0.0,
        }

    try:
        # Limit input length (CRITICAL)
        result = classifier(text[:512])[0]

        raw_emotion = result["label"].lower()
        confidence = round(float(result["score"]), 4)

        # =============================================
        # 🛡️ EMOTION NORMALIZATION (APP STANDARD)
        # =============================================
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

    except Exception as e:
        print("❌ Emotion prediction error:", e)
        return {
            "emotion": "neutral",
            "confidence": 0.0,
        }
