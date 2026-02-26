import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# =====================================================
# ✅ LOAD STABLE MULTILINGUAL MODEL
# =====================================================

MODEL_NAME = "cardiffnlp/twitter-xlm-roberta-base-sentiment"

print("Loading multilingual sentiment model...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_NAME)
model.eval()
print("Model loaded successfully.\n")


# =====================================================
# 🚨 SUICIDAL OVERRIDE (HIGH PRIORITY)
# =====================================================

def _suicidal_override(text: str):
    t = text.lower()

    suicidal_phrases = [
        # English
        "want to die", "kill myself", "end my life",
        "i don't want to live", "better off dead",

        # Hindi
        "आत्महत्या", "मरना चाहता", "जीना नहीं चाहता",

        # Telugu
        "చావాలని ఉంది", "ఆత్మహత్య", "బతకాలని లేదు",
    ]

    for phrase in suicidal_phrases:
        if phrase in t:
            return "Suicidal", 0.99

    return None


# =====================================================
# 🤖 LOCAL MODEL INFERENCE
# =====================================================

def _call_model(text: str):

    inputs = tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=128
    )

    with torch.no_grad():
        outputs = model(**inputs)

    probs = F.softmax(outputs.logits, dim=1)
    confidence, predicted_class = torch.max(probs, dim=1)

    label_id = predicted_class.item()
    score = confidence.item()

    # Cardiff mapping
    label_map = {
        0: "Sad",       # Negative
        1: "Neutral",   # Neutral
        2: "Happy"      # Positive
    }

    emotion = label_map.get(label_id, "Neutral")

    return emotion, score


# =====================================================
# 🎯 MAIN PREDICTION
# =====================================================

def predict_emotion(text: str):

    if not text.strip():
        return {"emotion": "Neutral", "confidence": 0.0}

    override = _suicidal_override(text)
    if override:
        return {"emotion": override[0], "confidence": override[1]}

    emotion, confidence = _call_model(text)

    if confidence < 0.40:
        emotion = "Neutral"

    return {
        "emotion": emotion,
        "confidence": round(confidence, 4)
    }


# =====================================================
# 📊 SEVERITY DETECTION
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
# 🚨 RISK DETECTION
# =====================================================

def detect_risk(emotion: str):

    if emotion == "Suicidal":
        return "critical"

    elif emotion == "Depression":
        return "high"

    elif emotion in ["Sad", "Anxiety", "Angry"]:
        return "moderate"

    else:
        return "low"


# =====================================================
# 🧠 MENTAL HEALTH INDEX
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
# ✅ FINAL PUBLIC API
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


# =====================================================
# 🧪 TESTING
# =====================================================

if __name__ == "__main__":

    print("\n--- English ---")
    print(final_prediction("I am very happy today"))
    print(final_prediction("I feel tired of living like this"))

    print("\n--- Hindi ---")
    print(final_prediction("मैं बहुत खुश हूँ"))
    print(final_prediction("मुझे जीने का मन नहीं करता"))

    print("\n--- Telugu ---")
    print(final_prediction("నేను చాలా సంతోషంగా ఉన్నాను"))
    print(final_prediction("నాకు బతకాలని లేదు"))