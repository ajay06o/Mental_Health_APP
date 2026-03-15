
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
# INTENSITY DETECTION
# =====================================================

def detect_intensity(text):

    t = text.lower()

    strong_words = [
        "very",
        "extremely",
        "so much",
        "really",
        "too much"
    ]

    for w in strong_words:
        if w in t:
            return 1.2

    return 1.0


# =====================================================
# NEW: TEXT LENGTH BOOST
# =====================================================

def length_boost(text):

    if len(text) > 120:
        return 1.1

    return 1.0


# =====================================================
# NEW: NEGATION DETECTION
# =====================================================

def detect_negation(text):

    t = text.lower()

    negations = [
        "not",
        "never",
        "no longer",
        "don't",
        "do not",
        "isn't",
        "wasn't"
    ]

    for n in negations:
        if n in t:
            return True

    return False


# =====================================================
# NEW: EMERGENCY SIGNAL
# =====================================================

def emergency_signal(text):

    t = text.lower()

    phrases = [
        "i can't go on",
        "i can't handle this anymore",
        "i want to disappear",
        "i feel like ending everything"
    ]

    for p in phrases:
        if p in t:
            return True

    return False


# =====================================================
# NEW: COGNITIVE DISTORTION DETECTION
# =====================================================

def detect_cognitive_distortion(text):

    t = text.lower()

    distortions = [
        "nothing ever works",
        "everything is ruined",
        "i always fail",
        "everyone hates me",
        "i am useless",
        "i am a failure",
        "life is pointless"
    ]

    for d in distortions:
        if d in t:
            return True

    return False


# =====================================================
# 🚨 SUICIDAL OVERRIDE
# =====================================================

def _suicidal_override(text: str):

    t = text.lower()

    phrases = [

    # English
    "want to die",
    "kill myself",
    "end my life",
    "i want to die",
    "i wish i was dead",
    "life is not worth living",
    "i don't want to live",
    "i want to disappear",
    "i can't go on",

    # Hindi
    "आत्महत्या",
    "मरना चाहता हूँ",
    "जीना नहीं चाहता",

    # Telugu
    "చావాలని ఉంది",
    "ఆత్మహత్య",
    "బతకాలని అనిపించడం లేదు"
]

    for p in phrases:
        if p in t:
            return "Suicidal", 0.99

    return None


# =====================================================
# MULTILINGUAL EMOTION DETECTION
# =====================================================

def _multilingual_override(text):

    t = text.lower()

    patterns = {

        "Sad": [
            "dukhi hun",
            "bahut udaas",
            "naaku baadha ga undi"
        ],

        "Anxiety": [
            "tension",
            "bahut darr",
            "chala tension ga undi"
        ],

        "Happy": [
            "bahut khush",
            "chala happy ga undi"
        ]
    }

    for emotion, phrases in patterns.items():
        for p in phrases:
            if p in t:
                return emotion, 0.85

    return None

# =====================================================
# FULL MULTILINGUAL EMOTION DETECTOR
# Supports English, Hindi, Telugu
# =====================================================

def detect_multilingual_emotion(text):

    t = text.lower()

    patterns = {

        "Happy": [

            # English
            "i am happy",
            "feeling great",
            "i feel good",

            # Hindi
            "main khush hoon",
            "bahut khush hoon",
            "aaj bahut accha lag raha hai",

            # Telugu
            "నేను సంతోషంగా ఉన్నాను",
            "చాలా సంతోషంగా ఉంది",

            # transliteration
            "nenu happy ga unna",
            "chala santosham ga undi"
        ],

        "Sad": [

            # English
            "i feel sad",
            "i feel down",

            # Hindi
            "main udaas hoon",
            "bahut udaas hoon",

            # Telugu
            "నాకు బాధగా ఉంది",
            "నేను బాధగా ఉన్నాను",

            # transliteration
            "naaku baadha ga undi",
            "chala baadha ga undi"
        ],

        "Depression": [

            # English
            "life is pointless",
            "nothing matters",
            "i feel empty",

            # Hindi
            "zindagi ka koi matlab nahi",
            "sab bekaar hai",

            # Telugu
            "జీవితం అర్థం లేదు",
            "ఏదీ బాగోలేదు"
        ],

        "Anxiety": [

            # English
            "i feel anxious",
            "i am stressed",

            # Hindi
            "mujhe tension hai",
            "bahut darr lag raha hai",

            # Telugu
            "చాలా టెన్షన్ గా ఉంది",
            "నాకు భయం వేస్తోంది",

            # transliteration
            "chala tension ga undi",
            "naaku bayam vesthundi"
        ],

        "Angry": [

            # English
            "i am angry",
            "i am furious",

            # Hindi
            "mujhe gussa aa raha hai",
            "bahut gussa hai",

            # Telugu
            "నాకు కోపం వస్తోంది",
            "చాలా కోపంగా ఉంది",

            # transliteration
            "naaku kopam vastundi"
        ],

        "Neutral": [

            # English
            "i feel okay",
            "just normal",

            # Hindi
            "sab theek hai",

            # Telugu
            "సరే ఉంది"
        ]
    }

    for emotion, phrases in patterns.items():
        for p in phrases:
            if p in t:
                return emotion, 0.90

    return None

# =====================================================
# CONTEXT DETECTION
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
            "i feel overwhelmed",
            "panic attack",
            "i am scared",
            "i feel terrified"
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
# HUGGINGFACE MODEL
# =====================================================

def _call_huggingface(text: str):

    payload = {"inputs": text}

    for attempt in range(2):

        try:

            response = requests.post(
                HF_MODEL_URL,
                headers=HEADERS,
                json=payload,
                timeout=20
            )

            if response.status_code == 503:
                time.sleep(2)
                continue

            if response.status_code != 200:
                return "Neutral", 0.5

            data = response.json()

            if isinstance(data, list) and len(data) > 0:

                emotions = data[0]

                if not emotions:
                    return "Neutral", 0.5

                best = max(emotions, key=lambda x: x.get("score", 0))

                label = best.get("label", "").lower()
                score = float(best.get("score", 0))

                if label == "joy":
                    return "Happy", score

                elif label == "sadness":
                    if score > 0.85:
                        return "Depression", score
                    return "Sad", score

                elif label == "anger":
                    return "Angry", score

                elif label == "fear":
                    return "Anxiety", score

                elif label == "neutral":
                    return "Neutral", score

                elif label == "disgust":
                    return "Angry", score

        except Exception:
            time.sleep(1)

    return "Neutral", 0.5


# =====================================================
# MIXED EMOTION DETECTION
# =====================================================

def detect_mixed_emotion(text):

    t = text.lower()

    positive_words = [
        "happy", "great", "good", "excited", "joy"
    ]

    negative_words = [
        "sad", "depressed", "anxious", "worried",
        "angry", "upset", "tired"
    ]

    has_positive = any(w in t for w in positive_words)
    has_negative = any(w in t for w in negative_words)

    # If both exist → prioritize negative emotion
    if has_positive and has_negative:

        if "depressed" in t:
            return "Depression", 0.90

        if "anxious" in t or "worried" in t:
            return "Anxiety", 0.85

        if "sad" in t:
            return "Sad", 0.85

        if "angry" in t:
            return "Angry", 0.85

    return None


def emotion_synonyms(text):

    t = text.lower()

    synonyms = {

        "Happy": [
            "delighted", "excited", "joyful", "thrilled", "pleased"
        ],

        "Sad": [
            "unhappy", "miserable", "down", "gloomy"
        ],

        "Depression": [
            "hopeless", "worthless", "empty", "numb"
        ],

        "Anxiety": [
            "worried", "nervous", "panicking", "uneasy"
        ],

        "Angry": [
            "furious", "frustrated", "irritated", "annoyed"
        ]
    }

    for emotion, words in synonyms.items():
        for w in words:
            if w in t:
                return emotion, 0.88

    return None


# =====================================================
# EMOTION PREDICTION PIPELINE
# =====================================================

def predict_emotion(text: str):

    if not text or not text.strip():
        return {"emotion": "Neutral", "confidence": 0.0}

    text = normalize_text(text)

    if emergency_signal(text):
        return {"emotion": "Suicidal", "confidence": 0.98}

    if detect_cognitive_distortion(text):
        return {"emotion": "Depression", "confidence": 0.9}

    suicidal = _suicidal_override(text)
    if suicidal:
        return {"emotion": suicidal[0], "confidence": suicidal[1]}

    multi = _multilingual_override(text)
    if multi:
        return {"emotion": multi[0], "confidence": multi[1]}

    multi2 = detect_multilingual_emotion(text)
    if multi2:
        return {"emotion": multi2[0], "confidence": multi2[1]}

    context = _context_override(text)
    if context:
        return {"emotion": context[0], "confidence": context[1]}

    simple = _simple_word_override(text)
    if simple:
        return {"emotion": simple[0], "confidence": simple[1]}

# NEW: synonym detection
    syn = emotion_synonyms(text)
    if syn:
       return {"emotion": syn[0], "confidence": syn[1]}

    mixed = detect_mixed_emotion(text)
    if mixed:
        return {"emotion": mixed[0], "confidence": mixed[1]}

    emotion, confidence = _call_huggingface(text)

    confidence *= detect_intensity(text)
    confidence *= length_boost(text)

    confidence = min(confidence, 1.0)

    if detect_negation(text) and emotion == "Happy":
        emotion = "Sad"

    if confidence < 0.40:
        emotion = "Neutral"

    return {
        "emotion": emotion,
        "confidence": round(confidence, 4)
    }
  


# =====================================================
# EMOTION MEMORY
# =====================================================

def emotion_memory_adjustment(current_emotion, history):

    if not history:
        return current_emotion

    last_two = history[-2:]

    if last_two == ["Sad", "Sad"] and current_emotion == "Sad":
        return "Depression"

    sad_count = history[-3:].count("Sad")

    if sad_count >= 2 and current_emotion == "Sad":
        return "Depression"

    return current_emotion


# =====================================================
# MOOD VOLATILITY
# =====================================================

def detect_mood_volatility(history):

    if not history or len(history) < 4:
        return "stable"

    changes = 0

    for i in range(1, len(history)):
        if history[i] != history[i-1]:
            changes += 1

    if changes >= len(history) / 2:
        return "high_volatility"

    return "stable"


# =====================================================
# NEW: BURNOUT DETECTION
# =====================================================

def detect_burnout(history):

    if len(history) < 3:
        return False

    pattern = history[-3:]

    if pattern == ["Anxiety", "Anxiety", "Sad"]:
        return True

    return False


# =====================================================
# NEW: EMOTIONAL STABILITY
# =====================================================

def emotional_stability(history):

    if not history or len(history) < 4:
        return "unknown"

    unique = len(set(history))

    if unique >= 4:
        return "unstable"

    elif unique == 3:
        return "moderate"

    return "stable"


# =====================================================
# NEW: EMOTION EXPLANATION
# =====================================================

def explain_emotion(emotion):

    messages = {

        "Happy": "User shows positive emotional signals",
        "Sad": "User expresses sadness or disappointment",
        "Anxiety": "User shows stress or worry",
        "Angry": "User expresses frustration or anger",
        "Depression": "User shows strong depressive signals",
        "Suicidal": "Critical emotional distress detected"
    }

    return messages.get(emotion, "General emotional state detected")


# =====================================================
# SEVERITY DETECTION
# =====================================================

def detect_severity(emotion, confidence):

    if emotion == "Suicidal":
        return "critical"

    if emotion == "Depression":
        return "high"

    if emotion in ["Sad", "Anxiety", "Angry"]:
        if confidence >= 0.75:
            return "moderate"
        return "low"

    return "low"


# =====================================================
# RISK DETECTION
# =====================================================

def detect_risk(emotion):

    risk_map = {

        "Happy": "low",
        "Neutral": "low",

        "Sad": "medium",
        "Anxiety": "medium",
        "Angry": "medium",

        "Depression": "high",

        "Suicidal": "critical"
    }

    return risk_map.get(emotion, "low")


# =====================================================
# MENTAL HEALTH INDEX (0 - 100)
# =====================================================

def calculate_mhi(emotion, severity, risk):

    score = 80

    emotion_penalty = {

        "Happy": 0,
        "Neutral": 5,
        "Sad": 15,
        "Anxiety": 20,
        "Angry": 15,
        "Depression": 40,
        "Suicidal": 70
    }

    score -= emotion_penalty.get(emotion, 10)

    if severity == "high":
        score -= 10

    if severity == "critical":
        score -= 20

    if risk == "critical":
        score -= 20

    score = max(0, min(score, 100))

    return score


# =====================================================
# EMOTION TREND ANALYSIS
# =====================================================

def analyze_emotion_trend(history):

    if not history or len(history) < 3:
        return "stable"

    negative = ["Sad", "Depression", "Anxiety"]

    recent = history[-3:]

    if all(e in negative for e in recent):
        return "declining"

    if "Happy" in recent and "Sad" in history[-4:-1]:
        return "improving"

    return "stable"


# =====================================================
# FUTURE RISK PREDICTION
# =====================================================

def predict_future_risk(history):

    if not history:
        return "unknown"

    negative = ["Sad", "Depression", "Anxiety"]

    last = history[-5:]

    count = sum(1 for e in last if e in negative)

    if count >= 4:
        return "high_risk"

    if count >= 2:
        return "watch"

    return "low_risk"


# =====================================================
# ADAPTIVE USER ANALYSIS
# =====================================================

def adaptive_user_analysis(history):

    if not history:
        return "unknown"

    happy = history.count("Happy")
    sad = history.count("Sad")
    anxiety = history.count("Anxiety")
    depression = history.count("Depression")

    negative_total = sad + anxiety + depression

    if negative_total > happy:
        return "user_under_stress"

    if happy > negative_total:
        return "emotionally_positive"

    return "mixed_emotional_pattern"


# =====================================================
# FINAL API
# =====================================================

def final_prediction(text, emotion_history=None):

    result = predict_emotion(text)

    emotion = result["emotion"]
    confidence = result["confidence"]

    if emotion_history:
        emotion = emotion_memory_adjustment(emotion, emotion_history)

    severity = detect_severity(emotion, confidence)
    risk = detect_risk(emotion)

    mhi = calculate_mhi(emotion, severity, risk)

    trend = None
    prediction = None
    adaptive = None
    volatility = None
    burnout = None
    stability = None

    if emotion_history:

        trend = analyze_emotion_trend(emotion_history)
        prediction = predict_future_risk(emotion_history)
        adaptive = adaptive_user_analysis(emotion_history)
        volatility = detect_mood_volatility(emotion_history)

        burnout = detect_burnout(emotion_history)
        stability = emotional_stability(emotion_history)

    return {

        "final_mental_state": emotion,
        "confidence": confidence,
        "severity": severity,
        "risk": risk,
        "mental_health_index": mhi,
        "trend": trend,
        "future_prediction": prediction,
        "adaptive_analysis": adaptive,
        "mood_volatility": volatility,
        "burnout_risk": burnout,
        "emotional_stability": stability,
        "emotion_explanation": explain_emotion(emotion)
    }
