import os
import joblib
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(BASE_DIR, "emotion_model.pkl")
VECTORIZER_PATH = os.path.join(BASE_DIR, "vectorizer.pkl")

_model = None
_vectorizer = None


def _load():
    global _model, _vectorizer
    if _model is None or _vectorizer is None:
        print("🧠 Loading emotion model (lightweight)...")
        _model = joblib.load(MODEL_PATH)
        _vectorizer = joblib.load(VECTORIZER_PATH)
        print("✅ Emotion model loaded")


# ===============================
# 🚨 KEYWORD OVERRIDE (FAST + SAFE)
# ===============================
def _keyword_override(text: str):
    t = text.lower()

    suicidal = [
        "want to die", "kill myself", "suicide", "end my life",
        "आत्महत्या", "मरना चाहता", "చావాలని ఉంది",
    ]

    depression = [
        "depressed", "hopeless", "empty",
        "डिप्रेशन", "డిప్రెషన్",
    ]

    anxiety = [
        "anxious", "stress", "panic",
        "चिंता", "ఆందోళన",
    ]

    angry = ["angry", "furious", "rage", "गुस्सा", "కోపం"]
    sad = ["sad", "crying", "दुख", "బాధ"]
    happy = ["happy", "joy", "peaceful", "खुश", "సంతోష"]

    for w in suicidal:
        if w in t:
            return "Suicidal", 0.90
    for w in depression:
        if w in t:
            return "Depression", 0.85
    for w in angry:
        if w in t:
            return "Angry", 0.80
    for w in anxiety:
        if w in t:
            return "Anxiety", 0.80
    for w in sad:
        if w in t:
            return "Sad", 0.75
    for w in happy:
        if w in t:
            return "Happy", 0.75

    return None


# ===============================
# 🧠 FINAL PREDICTION
# ===============================
def predict_emotion(text: str) -> dict:
    if not text or not text.strip():
        return {"emotion": "Neutral", "confidence": 0.0}

    override = _keyword_override(text)
    if override:
        return {
            "emotion": override[0],
            "confidence": override[1],
        }

    _load()

    vec = _vectorizer.transform([text])
    probs = _model.predict_proba(vec)[0]

    idx = int(np.argmax(probs))
    emotion = _model.classes_[idx]
    confidence = float(probs[idx])

    return {
        "emotion": emotion,
        "confidence": round(confidence, 4),
    }
