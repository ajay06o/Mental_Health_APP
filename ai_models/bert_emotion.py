# ai_models/bert_emotion.py
# =====================================================
# ⚡ LIGHTWEIGHT EMOTION CLASSIFIER (RENDER FREE SAFE)
# =====================================================

import joblib
import os

MODEL_PATH = os.path.join(os.path.dirname(__file__), "emotion_model.pkl")

print("🧠 Loading lightweight emotion model...")

model = joblib.load(MODEL_PATH)

print("✅ Lightweight emotion model loaded")

def predict_emotion(text: str) -> dict:
    if not text or not text.strip():
        return {"emotion": "neutral", "confidence": 0.0}

    try:
        prediction = model.predict([text])[0]
        confidence = max(model.predict_proba([text])[0])

        return {
            "emotion": prediction,
            "confidence": round(float(confidence), 4),
        }

    except Exception as e:
        print("❌ Prediction error:", e)
        return {"emotion": "neutral", "confidence": 0.0}
