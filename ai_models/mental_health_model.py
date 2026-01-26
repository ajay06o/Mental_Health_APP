import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
try:
    from langdetect import detect  # optional; may not have a wheel on some Python versions
except Exception:
    def detect(text: str) -> str:
        # Fallback: assume English for safety when langdetect isn't available
        return "en"

from deep_translator import GoogleTranslator

# =====================================================
# TRAINING DATA (MINIMAL – KEYWORDS HANDLE MOST CASES)
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

vectorizer = TfidfVectorizer(
    stop_words="english",
    ngram_range=(1, 3)
)

X = vectorizer.fit_transform(df["text"])
y = df["label"]

model = LogisticRegression(
    max_iter=3000,
    class_weight="balanced"
)
model.fit(X, y)

# =====================================================
# TRANSLATION (AUTO-DETECT)
# =====================================================
def translate_to_english(text: str) -> str:
    try:
        if detect(text) != "en":
            try:
                return GoogleTranslator(source="auto", target="en").translate(text)
            except Exception:
                return text
        return text
    except Exception:
        return text

# =====================================================
# 🚨 MULTI-LANGUAGE KEYWORD OVERRIDE (EN / HI / TE)
# =====================================================
def keyword_override(text: str):
    text = text.lower()

    # ================= SUICIDAL (DIRECT + INDIRECT) =================
    suicidal = [
        # English
        "want to die", "kill myself", "suicide",
        "end my life", "ending my life",
        "self harm", "self-harm",
        "no reason to live", "better off dead",
        "can't go on", "can't handle this anymore",
        "everything should end", "i give up on life",
        "life is unbearable",

        # Hindi
        "मरना चाहता हूँ", "आत्महत्या", "जीना नहीं चाहता",
        "खुद को मारना", "मेरी जिंदगी बेकार है",
        "अब और नहीं सह सकता", "सब खत्म हो जाए",

        # Telugu
        "చావాలని ఉంది", "ఆత్మహత్య",
        "బతకాలని లేదు", "నా జీవితం వ్యర్థం",
        "ఇంకా భరించలేకపోతున్నాను",
    ]

    # ================= DEPRESSION =================
    depression = [
        # English
        "depressed", "hopeless", "empty", "numb",
        "worthless", "tired of life",
        "lost interest", "no motivation",
        "mentally exhausted", "burned out",
        "nothing matters", "emotionally drained",

        # Hindi
        "डिप्रेशन", "उदास", "निराश",
        "थक गया हूँ", "मन नहीं लग रहा",
        "कुछ भी अच्छा नहीं लग रहा",

        # Telugu
        "డిప్రెషన్", "నిరాశ", "ఖాళీగా ఉంది",
        "జీవితం మీద ఆసక్తి లేదు",
        "మానసికంగా అలసిపోయాను",
    ]

    # ================= ANGER =================
    angry = [
        # English
        "angry", "furious", "frustrated",
        "irritated", "mad", "annoyed",
        "rage", "fed up", "angry at everyone",

        # Hindi
        "गुस्सा", "बहुत गुस्सा",
        "चिढ़", "नाराज़",

        # Telugu
        "కోపంగా ఉంది", "చాలా కోపం",
        "చిరాకు", "విసుగు",
    ]

    # ================= ANXIETY / STRESS =================
    anxiety_stress = [
        # English
        "anxious", "anxiety", "stressed",
        "stress", "worried", "panic",
        "overthinking", "nervous",
        "heart racing", "restless",
        "can't relax", "fearful",

        # Hindi
        "चिंता", "टेंशन", "डर लग रहा है",
        "घबराहट", "परेशान",
        "नींद नहीं आ रही",

        # Telugu
        "ఆందోళన", "టెన్షన్",
        "భయం గా ఉంది", "ఒత్తిడి",
        "నిద్ర రావడం లేదు",
    ]

    # ================= SAD =================
    sad = [
        # English
        "sad", "feeling low", "down",
        "lonely", "unhappy", "crying",
        "miss someone", "heart feels heavy",

        # Hindi
        "दुखी", "अकेलापन",
        "रोना आ रहा है",

        # Telugu
        "బాధగా ఉంది", "ఒంటరిగా ఉంది",
        "ఏడవాలనిపిస్తుంది",
    ]

    # ================= HAPPY / CALM =================
    happy = [
        # English
        "happy", "excited", "joy",
        "peaceful", "content",
        "grateful", "relaxed",
        "feeling good", "positive",

        # Hindi
        "खुश", "खुशी", "संतोष",
        "शांत महसूस कर रहा हूँ",

        # Telugu
        "సంతోషంగా ఉంది", "ఆనందంగా ఉంది",
        "ప్రశాంతంగా ఉంది", "హ్యాపీగా ఉంది",
    ]

    # 🚨 PRIORITY ORDER (MOST IMPORTANT)
    for w in suicidal:
        if w in text:
            return "Suicidal"

    for w in depression:
        if w in text:
            return "Depression"

    for w in angry:
        if w in text:
            return "Angry"

    for w in anxiety_stress:
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
# FINAL PREDICTION (SAFE HYBRID)
# =====================================================
def final_prediction(text: str) -> dict:
    if not text or not text.strip():
        return {
            "final_mental_state": "Neutral",
            "confidence": 0.0
        }

    # 1️⃣ Rule-based override FIRST
    forced = keyword_override(text)
    if forced:
        return {
            "final_mental_state": forced,
            "confidence": 0.90
        }

    # 2️⃣ Translate → ML predict
    text_en = translate_to_english(text)
    vec = vectorizer.transform([text_en])
    probs = model.predict_proba(vec)[0]
    idx = probs.argmax()

    predicted = model.classes_[idx]

    # 3️⃣ SAFE fallback (never default to Happy)
    if predicted == "Happy" and any(
        k in text.lower()
        for k in ["pain", "tired", "empty", "alone", "stress"]
    ):
        predicted = "Depression"

    return {
        "final_mental_state": predicted,
        "confidence": float(probs[idx])
    }
