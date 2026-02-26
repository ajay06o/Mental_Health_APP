import numpy as np
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity

# =====================================================
# GLOBAL VARIABLES (DO NOT LOAD MODEL HERE)
# =====================================================

_semantic_model = None
_emotion_embeddings = None

EMOTIONS = [
    "Happy",
    "Sad",
    "Anxiety",
    "Angry",
    "Depression",
    "Suicidal",
    "Neutral"
]

# Multilingual references (light but effective)
EMOTION_REFERENCE = {
    "Happy": [
        "I feel happy",
        "मैं खुश हूँ",
        "నేను సంతోషంగా ఉన్నాను",
    ],
    "Sad": [
        "I feel sad",
        "मैं उदास हूँ",
        "నేను బాధగా ఉన్నాను",
    ],
    "Anxiety": [
        "I feel anxious",
        "मुझे चिंता हो रही है",
        "నాకు ఆందోళనగా ఉంది",
    ],
    "Angry": [
        "I am angry",
        "मुझे गुस्सा आ रहा है",
        "నాకు కోపంగా ఉంది",
    ],
    "Depression": [
        "I feel depressed",
        "मैं निराश हूँ",
        "నేను నిరాశగా ఉన్నాను",
    ],
    "Suicidal": [
        "I want to die",
        "मैं मरना चाहता हूँ",
        "నేను చావాలని ఉంది",
    ],
    "Neutral": [
        "I feel normal",
        "मैं सामान्य हूँ",
        "నేను సాధారణంగా ఉన్నాను",
    ]
}

# =====================================================
# SAFE MODEL LOADER
# =====================================================

def _load_model():
    global _semantic_model, _emotion_embeddings

    if _semantic_model is None:
        print("Loading lightweight multilingual model...")

        # 🔥 USE LIGHT MODEL (IMPORTANT)
        _semantic_model = SentenceTransformer(
            "paraphrase-multilingual-MiniLM-L3-v2"
        )

        embeddings = []

        for emotion in EMOTIONS:
            emb = _semantic_model.encode(
                EMOTION_REFERENCE[emotion]
            )
            embeddings.append(np.mean(emb, axis=0))

        _emotion_embeddings = np.vstack(embeddings)

        print("Model loaded successfully.")

# =====================================================
# 🚨 SUICIDAL PRIORITY
# =====================================================

def _suicidal_override(text: str):
    t = text.lower()

    phrases = [
        "want to die",
        "kill myself",
        "end my life",
        "आत्महत्या",
        "చావాలని ఉంది",
    ]

    for p in phrases:
        if p in t:
            return "Suicidal", 0.99

    return None

# =====================================================
# SEMANTIC PREDICTION
# =====================================================

def _semantic_predict(text: str):
    text_embedding = _semantic_model.encode([text])
    scores = cosine_similarity(
        text_embedding,
        _emotion_embeddings
    )[0]

    best_idx = int(np.argmax(scores))
    return EMOTIONS[best_idx], float(scores[best_idx])

# =====================================================
# MAIN PREDICTION
# =====================================================

def predict_emotion(text: str):

    if not text or not text.strip():
        return {"emotion": "Neutral", "confidence": 0.0}

    # 🚨 Safety first
    override = _suicidal_override(text)
    if override:
        return {
            "emotion": override[0],
            "confidence": override[1],
        }

    # 🔥 Load only when needed
    if _semantic_model is None:
        _load_model()

    emotion, score = _semantic_predict(text)

    return {
        "emotion": emotion,
        "confidence": round(score, 4),
    }

# =====================================================
# SEVERITY
# =====================================================

def detect_severity(emotion: str, confidence: float):
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

def detect_risk(emotion: str):
    if emotion == "Suicidal":
        return "critical"
    elif emotion == "Depression":
        return "high"
    elif emotion in ["Anxiety", "Angry", "Sad"]:
        return "moderate"
    return "low"

# =====================================================
# MHI
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
# PUBLIC API
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