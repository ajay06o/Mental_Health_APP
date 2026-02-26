import re
import numpy as np
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity

# =====================================================
# GLOBAL VARIABLES
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

# Multilingual reference sentences
EMOTION_REFERENCE = {
    "Happy": [
        # English
        "I feel joyful and satisfied",
        # Hindi
        "मैं खुश और संतुष्ट महसूस कर रहा हूँ",
        # Telugu
        "నేను సంతోషంగా మరియు ప్రశాంతంగా ఉన్నాను",
    ],
    "Sad": [
        "I feel lonely and hurt",
        "मैं उदास और अकेला महसूस कर रहा हूँ",
        "నేను బాధగా మరియు ఒంటరిగా ఉన్నాను",
    ],
    "Anxiety": [
        "I feel nervous and restless",
        "मुझे घबराहट और चिंता हो रही है",
        "నాకు ఆందోళన మరియు గాబరా గా ఉంది",
    ],
    "Angry": [
        "I am furious and irritated",
        "मुझे बहुत गुस्सा आ रहा है",
        "నాకు చాలా కోపంగా ఉంది",
    ],
    "Depression": [
        "I feel hopeless and empty",
        "मैं निराश और खाली महसूस कर रहा हूँ",
        "నేను నిరాశగా మరియు ఖాళీగా ఉన్నాను",
    ],
    "Suicidal": [
        "I want to end my life",
        "मैं अपनी जान देना चाहता हूँ",
        "నేను నా జీవితం ముగించాలనుకుంటున్నాను",
    ],
    "Neutral": [
        "I feel normal",
        "मैं सामान्य महसूस कर रहा हूँ",
        "నేను సాధారణంగా ఉన్నాను",
    ]
}


# =====================================================
# LOAD MODEL (MULTILINGUAL)
# =====================================================

def _load():
    global _semantic_model, _emotion_embeddings

    if _semantic_model is None:
        _semantic_model = SentenceTransformer(
            "paraphrase-multilingual-MiniLM-L12-v2"
        )

        embeddings = []

        for emotion in EMOTIONS:
            refs = EMOTION_REFERENCE[emotion]
            emb = _semantic_model.encode(refs)
            avg_emb = np.mean(emb, axis=0)
            embeddings.append(avg_emb)

        _emotion_embeddings = np.vstack(embeddings)


# =====================================================
# TEXT CLEANING
# =====================================================

def _normalize_text(text: str) -> str:
    text = text.strip()
    return text


# =====================================================
# 🚨 SUICIDAL OVERRIDE (HIGH PRIORITY)
# =====================================================

def _suicidal_override(text: str):
    t = text.lower()

    suicidal_phrases = [
        # English
        "want to die", "kill myself", "end my life",
        # Hindi
        "आत्महत्या", "मरना चाहता हूँ",
        # Telugu
        "చావాలని ఉంది", "ఆత్మహత్య",
    ]

    for phrase in suicidal_phrases:
        if phrase in t:
            return "Suicidal", 0.99

    return None


# =====================================================
# 🧠 SEMANTIC PREDICTION
# =====================================================

def _semantic_predict(text: str):
    global _semantic_model, _emotion_embeddings

    text_embedding = _semantic_model.encode([text])
    scores = cosine_similarity(text_embedding, _emotion_embeddings)[0]

    best_idx = int(np.argmax(scores))
    best_emotion = EMOTIONS[best_idx]
    best_score = float(scores[best_idx])

    return best_emotion, best_score


# =====================================================
# 🎯 MAIN PREDICTION
# =====================================================

def predict_emotion(text: str) -> dict:
    if not text or not text.strip():
        return {"emotion": "Neutral", "confidence": 0.0}

    # 1️⃣ Suicidal override
    override = _suicidal_override(text)
    if override:
        return {
            "emotion": override[0],
            "confidence": override[1],
        }

    # 2️⃣ Semantic multilingual prediction
    _load()
    emotion, score = _semantic_predict(text)

    return {
        "emotion": emotion,
        "confidence": round(score, 4),
    }


# =====================================================
# 📊 SEVERITY
# =====================================================

def detect_severity(emotion: str, confidence: float) -> str:
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

def detect_risk(emotion: str) -> str:
    if emotion == "Suicidal":
        return "critical"
    elif emotion == "Depression":
        return "high"
    elif emotion in ["Anxiety", "Angry", "Sad"]:
        return "moderate"
    else:
        return "low"


# =====================================================
# 🧠 MENTAL HEALTH INDEX
# =====================================================

def calculate_mhi(emotion: str, severity: str, risk: str) -> int:
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
# ✅ PUBLIC API (UNCHANGED)
# =====================================================

def final_prediction(text: str) -> dict:

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