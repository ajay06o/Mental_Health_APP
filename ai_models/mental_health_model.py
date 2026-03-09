import os
import requests
import time

HF_API_TOKEN = os.getenv("HF_API_TOKEN")

HF_MODEL_URL = "https://router.huggingface.co/hf-inference/models/j-hartmann/emotion-english-distilroberta-base"

HEADERS = {
    "Authorization": f"Bearer {HF_API_TOKEN}"
}


# =====================================================
# TEXT NORMALIZATION
# =====================================================

def normalize_text(text: str):
    text = text.strip()
    text = " ".join(text.split())
    return text[:500]


# =====================================================
# 🚨 SUICIDAL OVERRIDE
# =====================================================

def _suicidal_override(text: str):

    t = text.lower()

    phrases = [
        "want to die",
        "kill myself",
        "end my life",
        "i don't want to live",
        "better off dead",
        "suicide",

        # Hindi
        "आत्महत्या",
        "मरना चाहता",

        # Telugu
        "చావాలని ఉంది",
        "ఆత్మహత్య"
    ]

    for p in phrases:
        if p in t:
            return "Suicidal", 0.99

    return None


# =====================================================
# 🧠 CONTEXT DETECTION
# =====================================================

def _context_override(text: str):

    t = text.lower()

    patterns = {

        "Happy": [
            "i feel great",
            "today is a good day",
            "life is good",
            "i'm really happy"
        ],

        "Sad": [
            "i feel sad",
            "i feel down",
            "i feel lonely",
            "i feel upset"
        ],

        "Depression": [
            "nothing matters",
            "life feels pointless",
            "i feel empty",
            "i feel hopeless",
            "nothing ever works out"
        ],

        "Anxiety": [
            "i feel anxious",
            "i feel worried",
            "i feel stressed",
            "i feel overwhelmed"
        ],

        "Angry": [
            "this is unfair",
            "this is frustrating",
            "i am irritated",
            "i am furious"
        ],

        "Neutral": [
            "i feel okay",
            "just another day",
            "nothing special today"
        ]
    }

    for emotion, phrases in patterns.items():
        for p in phrases:
            if p in t:
                return emotion, 0.80

    return None


# =====================================================
# SIMPLE WORD DETECTION
# =====================================================

def _simple_word_override(text: str):

    word = text.lower().strip()

    simple_map = {

        "happy": "Happy",
        "sad": "Sad",
        "depressed": "Depression",
        "anxiety": "Anxiety",
        "angry": "Angry",
        "neutral": "Neutral"
    }

    if word in simple_map:
        return simple_map[word], 0.95

    return None


# =====================================================
# 🤖 HUGGINGFACE AI
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

        if response.status_code == 503:
            time.sleep(2)

            response = requests.post(
                HF_MODEL_URL,
                headers=HEADERS,
                json=payload,
                timeout=20
            )

    except Exception:
        return "Neutral", 0.0

    if response.status_code != 200:
        return "Neutral", 0.0

    data = response.json()

    if isinstance(data, list) and len(data) > 0:

        best = max(data[0], key=lambda x: x["score"])

        label = best["label"].lower()
        score = float(best["score"])

        if label in ["joy", "love"]:
            return "Happy", score

        elif label == "sadness":
            return "Sad", score

        elif label == "anger":
            return "Angry", score

        elif label == "fear":
            return "Anxiety", score

        elif label == "neutral":
            return "Neutral", score

    return "Neutral", 0.5


# =====================================================
# EMOTION PREDICTION PIPELINE
# =====================================================

def predict_emotion(text: str):

    if not text or not text.strip():
        return {"emotion": "Neutral", "confidence": 0.0}

    text = normalize_text(text)

    suicidal = _suicidal_override(text)
    if suicidal:
        return {"emotion": suicidal[0], "confidence": suicidal[1]}

    context = _context_override(text)
    if context:
        return {"emotion": context[0], "confidence": context[1]}

    simple = _simple_word_override(text)
    if simple:
        return {"emotion": simple[0], "confidence": simple[1]}

    emotion, confidence = _call_huggingface(text)

    if confidence < 0.40:
        emotion = "Neutral"

    return {
        "emotion": emotion,
        "confidence": round(confidence, 4)
    }


# =====================================================
# SEVERITY
# =====================================================

def detect_severity(emotion, confidence):

    if emotion == "Suicidal":
        return "high"

    if confidence >= 0.85:
        return "high"

    elif confidence >= 0.65:
        return "medium"

    return "low"


# =====================================================
# RISK
# =====================================================

def detect_risk(emotion):

    if emotion == "Suicidal":
        return "critical"

    elif emotion == "Depression":
        return "high"

    elif emotion in ["Sad", "Angry", "Anxiety"]:
        return "moderate"

    return "low"


# =====================================================
# MENTAL HEALTH INDEX
# =====================================================

def calculate_mhi(emotion, severity, risk):

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
# 📈 EMOTION TREND INTELLIGENCE
# =====================================================

def analyze_emotion_trend(history):

    emotion_scores = {
        "Happy": 5,
        "Neutral": 4,
        "Angry": 3,
        "Anxiety": 3,
        "Sad": 2,
        "Depression": 1,
        "Suicidal": 0
    }

    if len(history) < 3:
        return "insufficient_data"

    scores = [emotion_scores.get(e, 3) for e in history]

    change = scores[-1] - scores[0]

    if change <= -2:
        return "declining"

    elif change >= 2:
        return "improving"

    return "stable"


# =====================================================
# 🔮 PREDICT FUTURE MENTAL HEALTH RISK
# =====================================================

def predict_future_risk(history):

    emotion_scores = {
        "Happy": 5,
        "Neutral": 4,
        "Angry": 3,
        "Anxiety": 3,
        "Sad": 2,
        "Depression": 1,
        "Suicidal": 0
    }

    if len(history) < 4:
        return {
            "prediction": "insufficient_data",
            "message": "Need more emotional history"
        }

    scores = [emotion_scores.get(e, 3) for e in history]

    recent = scores[-4:]

    decline_rate = recent[-1] - recent[0]

    # 🚨 Critical risk
    if history[-1] == "Suicidal":
        return {
            "prediction": "critical_risk",
            "message": "🚨 Immediate mental health risk detected"
        }

    # ⚠ Depression pattern
    if history[-3:] == ["Sad", "Sad", "Depression"]:
        return {
            "prediction": "depression_likely",
            "message": "⚠ High probability of depression soon"
        }

    if history[-2:] == ["Depression", "Depression"]:
        return {
            "prediction": "persistent_depression",
            "message": "⚠ Persistent depression detected"
        }

    # 📉 declining trend
    if decline_rate <= -2:
        return {
            "prediction": "declining",
            "message": "⚠ Mental health likely declining"
        }

    # 📈 improving trend
    if decline_rate >= 2:
        return {
            "prediction": "improving",
            "message": "😊 Mental health improving"
        }

    return {
        "prediction": "stable",
        "message": "🟡 Mental state stable"
    }

# =====================================================
# 🧠 ADAPTIVE MENTAL HEALTH AI
# =====================================================

def adaptive_user_analysis(history):

    emotion_scores = {
        "Happy": 5,
        "Neutral": 4,
        "Angry": 3,
        "Anxiety": 3,
        "Sad": 2,
        "Depression": 1,
        "Suicidal": 0
    }

    if len(history) < 5:
        return {
            "baseline": None,
            "current_score": None,
            "deviation": None,
            "adaptive_risk": "insufficient_data"
        }

    scores = [emotion_scores.get(e, 3) for e in history]

    # User baseline (average past mood)
    baseline = sum(scores[:-1]) / (len(scores) - 1)

    current = scores[-1]

    deviation = current - baseline

    # Risk classification
    if deviation <= -2:
        risk = "high_risk"

    elif deviation <= -1:
        risk = "moderate_risk"

    elif deviation >= 1:
        risk = "improving"

    else:
        risk = "stable"

    return {
        "baseline_score": round(baseline, 2),
        "current_score": current,
        "deviation": round(deviation, 2),
        "adaptive_risk": risk
    }

# =====================================================
# FINAL API
# =====================================================

def final_prediction(text, emotion_history=None):

    result = predict_emotion(text)

    emotion = result["emotion"]
    confidence = result["confidence"]

    severity = detect_severity(emotion, confidence)
    risk = detect_risk(emotion)

    mhi = calculate_mhi(emotion, severity, risk)

    trend = None
    prediction = None
    adaptive = None

    if emotion_history:

        trend = analyze_emotion_trend(emotion_history)

        prediction = predict_future_risk(emotion_history)

        adaptive = adaptive_user_analysis(emotion_history)

    return {

        "final_mental_state": emotion,
        "confidence": confidence,
        "severity": severity,
        "risk": risk,
        "mental_health_index": mhi,
        "trend": trend,
        "future_prediction": prediction,
        "adaptive_analysis": adaptive
    }

# =====================================================
# TESTING
# =====================================================

if __name__ == "__main__":

    history = ["Happy", "Neutral", "Sad"]

    tests = [
        "I want to die.",
        "This situation is frustrating and unfair.",
        "I feel irritated and annoyed.",
        "Why does this always happen to me?",
        "I am upset and furious right now.",
        "I feel happy today"
    ]

    for t in tests:
        print("\nText:", t)
        print(final_prediction(t, history))