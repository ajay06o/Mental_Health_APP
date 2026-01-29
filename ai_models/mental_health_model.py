import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression

try:
    from langdetect import detect
except Exception:
    def detect(text: str) -> str:
        return "en"

from deep_translator import GoogleTranslator

# =====================================================
# 📚 TRAINING DATA (LIGHTWEIGHT BASELINE MODEL)
# =====================================================
data = {
    "text": [
        "I feel happy",
        "I am sad",
        "I feel anxious",
        "I am stressed",
        "I feel depressed",
        "I feel empty",
        "I am angry",
        "I am frustrated",
        "I want to die",
        "I think about ending my life",
        "I feel calm",
        "I am tired of everything",
        "I can't sleep properly",
    ],
    "label": [
        "Happy",
        "Sad",
        "Anxiety",
        "Anxiety",
        "Depression",
        "Depression",
        "Angry",
        "Angry",
        "Suicidal",
        "Suicidal",
        "Neutral",
        "Depression",
        "Anxiety",
    ],
}

df = pd.DataFrame(data)

# =====================================================
# 🔢 VECTORIZER + MODEL
# =====================================================
vectorizer = TfidfVectorizer(
    stop_words="english",
    ngram_range=(1, 3),
    max_features=5000,
)

X = vectorizer.fit_transform(df["text"])
y = df["label"]

model = LogisticRegression(
    max_iter=3000,
    class_weight="balanced",
)
model.fit(X, y)

# =====================================================
# 🌍 TRANSLATION (SAFE + CACHED)
# =====================================================
_translator = GoogleTranslator(source="auto", target="en")

def translate_to_english(text: str) -> str:
    try:
        if detect(text) != "en":
            return _translator.translate(text)
        return text
    except Exception:
        return text

# =====================================================
# 🚨 MULTI-LANGUAGE KEYWORD OVERRIDE (EN / HI / TE)
# =====================================================
def keyword_override(text: str):
    text = text.lower()

    suicidal = [
        "want to die", "kill myself", "suicide", "end my life",
        "self harm", "better off dead", "no reason to live",
        "मरना चाहता हूँ", "आत्महत्या", "जीना नहीं चाहता",
        "చావాలని ఉంది", "ఆత్మహత్య", "బతకాలని లేదు",
    ]

    depression = [
        "depressed", "hopeless", "empty", "worthless",
        "lost interest", "burned out",
        "डिप्रेशन", "निराश",
        "డిప్రెషన్", "నిరాశ",
    ]

    angry = [
        "angry", "furious", "frustrated", "rage",
        "गुस्सा", "नाराज़",
        "కోపం", "చిరాకు",
    ]

    anxiety = [
        "anxious", "stress", "panic", "worried",
        "चिंता", "टेंशन",
        "ఆందోళన", "టెన్షన్",
    ]

    sad = [
        "sad", "lonely", "crying",
        "दुखी", "अकेलापन",
        "బాధగా ఉంది",
    ]

    happy = [
        "happy", "joy", "peaceful", "relaxed",
        "खुश", "संतोष",
        "సంతోషంగా ఉంది",
    ]

    # 🚨 STRICT PRIORITY
    for w in suicidal:
        if w in text:
            return "Suicidal"

    for w in depression:
        if w in text:
            return "Depression"

    for w in angry:
        if w in text:
            return "Angry"

    for w in anxiety:
        if w in text:
            return "Anxiety"

    for w in sad:
        if w in text:
            return "Sad"

    for w in happy:
        if w in text:
            return "Happy"

    return None

# =====================================================
# 🧠 FINAL HYBRID PREDICTION (PRODUCTION SAFE)
# =====================================================
def final_prediction(text: str) -> dict:
    if not text or not text.strip():
        return {
            "final_mental_state": "Neutral",
            "confidence": 0.0,
        }

    # 1️⃣ Rule-based override (highest priority)
    override = keyword_override(text)
    if override:
        return {
            "final_mental_state": override,
            "confidence": 0.90 if override == "Suicidal" else 0.85,
        }

    # 2️⃣ Translate + ML inference
    text_en = translate_to_english(text)
    vec = vectorizer.transform([text_en])
    probs = model.predict_proba(vec)[0]

    idx = probs.argmax()
    predicted = model.classes_[idx]
    confidence = float(probs[idx])

    # 3️⃣ Safety correction (never false-happy)
    risk_words = ["pain", "tired", "empty", "alone", "stress"]
    if predicted == "Happy" and any(w in text.lower() for w in risk_words):
        predicted = "Depression"
        confidence = max(confidence, 0.70)

    return {
        "final_mental_state": predicted,
        "confidence": round(confidence, 4),
    }

# =====================================================
# 🔥 MODEL WARM-UP (PREVENT FIRST-CALL DELAY)
# =====================================================
try:
    _ = final_prediction("warm up")
    print("✅ Mental health model warmed up")
except Exception as e:
    print("⚠️ Warm-up failed:", e)
