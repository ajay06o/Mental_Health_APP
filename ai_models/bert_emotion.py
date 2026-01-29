from transformers import pipeline
import torch

# =====================================================
# 🧠 LOAD MODEL ON STARTUP (NOT PER REQUEST)
# =====================================================
DEVICE = 0 if torch.cuda.is_available() else -1

_classifier = pipeline(
    "text-classification",
    model="bhadresh-savani/distilbert-base-uncased-emotion",
    device=DEVICE,
)

print("✅ BERT emotion model loaded")

# =====================================================
# 🔥 PREDICTION FUNCTION
# =====================================================
def predict_emotion(text: str) -> dict:
    if not text or not text.strip():
        return {
            "emotion": "neutral",
            "confidence": 0.0,
        }

    # Run inference
    result = _classifier(text, truncation=True)[0]

    emotion = result["label"].lower()
    confidence = round(float(result["score"]), 4)

    # Safety mapping
    if emotion == "joy":
        emotion = "happy"
    elif emotion == "sadness":
        emotion = "sad"
    elif emotion == "fear":
        emotion = "anxiety"
    elif emotion == "anger":
        emotion = "angry"

    return {
        "emotion": emotion,
        "confidence": confidence,
    }


# =====================================================
# 🔥 WARM-UP (VERY IMPORTANT)
# =====================================================
try:
    _ = predict_emotion("warm up")
    print("🔥 BERT warmed up successfully")
except Exception as e:
    print("⚠️ BERT warm-up failed:", e)
