import os
import requests

HF_API_TOKEN = os.getenv("HF_API_TOKEN")

HF_MODEL_URL = "https://router.huggingface.co/hf-inference/models/j-hartmann/emotion-english-distilroberta-base"

HEADERS = {
    "Authorization": f"Bearer {HF_API_TOKEN}"
}

# =====================================================
# 🚨 SUICIDAL OVERRIDE (ALWAYS FIRST)
# =====================================================

def _suicidal_override(text: str):
    t = text.lower()

    phrases = [
        "want to die",
        "kill myself",
        "end my life",
        "i don't want to live",
        "life is meaningless",
        "आत्महत्या",
        "मरना चाहता",
        "చావాలని",
        "ఆత్మహత్య",
    ]

    for p in phrases:
        if p in t:
            return "Suicidal", 0.99

    return None


# =====================================================
# 🧠 SIMPLE WORD SUPPORT (single word inputs)
# =====================================================

def _simple_word_override(text: str):
    word = text.lower().strip()

    simple_map = {
        "happy": "Happy",
        "joy": "Happy",
        "sad": "Sad",
        "depressed": "Depression",
        "depression": "Depression",
        "anxiety": "Anxiety",
        "anxious": "Anxiety",
        "anger": "Angry",
        "angry": "Angry",
        "neutral": "Neutral"
    }

    if word in simple_map:
        return simple_map[word], 0.95

    return None


# =====================================================
# 🤖 HUGGINGFACE CALL
# =====================================================

def _call_huggingface(text: str):

    payload = {"inputs": text}

    try:
        response = requests.post(
            HF_MODEL_URL,
            headers=HEADERS,
            json=payload,
            timeout=20
        )
    except Exception as e:
        print("HF Exception:", e)
        return "Neutral", 0.0

    if response.status_code != 200:
        print("HF ERROR:", response.status_code, response.text)
        return "Neutral", 0.0

    data = response.json()

    # If model still loading or error
    if isinstance(data, dict) and "error" in data:
        print("HF Model Loading/Error:", data)
        return "Neutral", 0.0

    # Model returns list of emotions with scores
    if isinstance(data, list) and len(data) > 0:
        predictions = data[0]
        best = max(predictions, key=lambda x: x["score"])

        label = best["label"].lower()
        score = float(best["score"])

        # Map model labels → your system labels
        if label in ["joy", "love"]:
            return "Happy", score
        elif label == "sadness":
            return "Sad", score
        elif label == "anger":
            return "Angry", score
        elif label == "fear":
            return "Anxiety", score
        elif label == "disgust":
            return "Depression", score
        elif label == "neutral":
            return "Neutral", score

    return "Neutral", 0.5


# =====================================================
# 🎯 MAIN PREDICTION
# =====================================================

def predict_emotion(text: str):

    if not text or not text.strip():
        return {"emotion": "Neutral", "confidence": 0.0}

    # 1️⃣ Suicidal override
    override = _suicidal_override(text)
    if override:
        return {
            "emotion": override[0],
            "confidence": override[1],
        }

    # 2️⃣ Single word override
    simple_override = _simple_word_override(text)
    if simple_override:
        return {
            "emotion": simple_override[0],
            "confidence": simple_override[1],
        }

    # 3️⃣ HuggingFace AI prediction
    emotion, confidence = _call_huggingface(text)

    # 4️⃣ Confidence threshold protection
    if confidence < 0.40:
        emotion = "Neutral"

    return {
        "emotion": emotion,
        "confidence": round(confidence, 4),
    }


# =====================================================
# 📊 SEVERITY
# =====================================================

def detect_severity(emotion: str, confidence: float):

    if emotion == "Suicidal":
        return "high"

    if confidence >= 0.85:
        return "high"
    elif confidence >= 0.65:
        return "medium"
    else:
        return "low"


# =====================================================
# 🚨 RISK
# =====================================================

def detect_risk(emotion: str):

    if emotion == "Suicidal":
        return "critical"
    elif emotion == "Depression":
        return "high"
    elif emotion in ["Anxiety", "Angry", "Sad"]:
        return "moderate"
    else:
        return "low"


# =====================================================
# 🧠 MHI
# =====================================================

def calculate_mhi(emotion: str, severity: str, risk: str):

    base_scores = {
        "Happy": 85,
        "Neutral": 70,
        "Anxiety": 45,
        "Sad": 40,
        "Angry": 50,
        "Depression": 25,
        "Suicidal": 5
    }

    score = base_scores.get(emotion, 60)

    if severity == "high":
        score -= 10

    if risk == "critical":
        score = min(score, 10)

    return max(0, min(score, 100))


# =====================================================
# ✅ PUBLIC API
# =====================================================

def final_prediction(text: str):

    result = predict_emotion(text)

    emotion = result["emotion"]
    confidence = result["confidence"]

    severity = detect_severity(emotion, confidence)
    risk = detect_risk(emotion)
    mhi = calculate_mhi(emotion, severity, risk)

    return {
        "final_mental_state": emotion,
        "confidence": confidence,
        "severity": severity,
        "risk": risk,
        "mental_health_index": mhi
    }
if __name__ == "__main__":
    print(final_prediction("I want to die."))
    print(final_prediction("This situation is frustrating and unfair."))
    print(final_prediction("I feel irritated and annoyed."))
    print(final_prediction("Why does this always happen to me?"))
    print(final_prediction("I am upset and furious right now."))
