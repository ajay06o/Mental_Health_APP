import os
from pydoc import text
import requests
import time
from langdetect import detect

HF_API_TOKEN = os.getenv("HF_API_TOKEN")

HF_MODEL_URL = "https://router.huggingface.co/hf-inference/models/cardiffnlp/twitter-xlm-roberta-base-sentiment"

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
# MIXED LANGUAGE NORMALIZATION
# =====================================================

def normalize_phrases(text):

    t = text.lower()

    replacements = {

        # Hindi / Hinglish
        "bahut":"very",
        "bohot":"very",
        "zyaada":"very",
        "accha":"good",
        "bura":"bad",
        "udaas":"sad",
        "gussa":"angry",

        # Telugu-English
        "chala":"very",
        "bagundi":"good",
        "baadha":"sad",
        "kopam":"angry",
        "bayam":"fear",

        # emotion phrases
        "ga undi":"is",
        "ga unna":"am",
        "lag raha":"feeling",
        "lag rahi":"feeling"
    }

    for k,v in replacements.items():
        t = t.replace(k,v)

    return t

# =====================================================
# SHORT NEUTRAL TEXT FILTER
# =====================================================

def neutral_short_text(text):

    short_words = ["ok","okay","hmm","haan","sare","fine"]

    if text.lower().strip() in short_words:
        return True

    return False
# =====================================================
# LANGUAGE DETECTION
# =====================================================

def detect_language(text):

    t = text.lower()

    hinglish_words = [
        "bahut","gussa","udaas","khush","tension",
        "yaar","dil","accha","bura","nahi"
    ]

    telugu_english_words = [
        "ga undi","kopam","baadha","bagundi",
        "bayam","tension ga","happy ga","sad ga"
    ]

    if any(w in t for w in hinglish_words):
        return "Hinglish"

    if any(w in t for w in telugu_english_words):
        return "Telugu-English"

    try:
        lang = detect(text)

        if lang == "hi":
            return "Hindi"

        if lang == "te":
            return "Telugu"

        if lang == "en":
            return "English"

        return "Unknown"

    except:
        return "Unknown"


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
"not","never","no longer","don't","do not",

"नहीं",
"मत",

"కాదు",
"లేదు"
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
# SARCASM DETECTION
# =====================================================

def detect_sarcasm(text):

    t = text.lower()

    sarcasm_patterns = [
        "yeah right",
        "great just great",
        "wow amazing",
        "perfect just perfect"
    ]

    if any(p in t for p in sarcasm_patterns):
        return True

    sarcasm_emojis = ["🙃","😒","😏"]

    if any(e in text for e in sarcasm_emojis):
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
    "I wish I could disappear",
    "I want everything to stop",
    "I am tired of living",
    "I can't do this anymore",
    "life is meaningless",
    "no reason to live",
    "I feel like giving up",
    "i want everything to end",

    # Hindi
    "आत्महत्या",
    "मरना चाहता हूँ",
    "जीना नहीं चाहता",

    # Telugu
    "చావాలని ఉంది",
    "ఆత్మహత్య",
    "బతకాలని అనిపించడం లేదు",
    # Hinglish
    "jeene ka mann nahi karta",
    "sab khatam karna hai",
    "mar jana chahta hoon",
    "jeena nahi hai",
    "mar jana hai",
    "life khatam karna hai",


    # Telugu-English
    "brathakali anipinchadam ledu",
    "life end cheyyali anipistundi",
    "chachipovali anipistundi",
    "brathakadam istem ledu"
]

    for p in phrases:
        if p in t:
            return "Suicidal", 0.99

    return None

# =====================================================
# PASSIVE SUICIDE SIGNAL
# =====================================================

def passive_suicide_signal(text):

    t = text.lower()

    phrases = [
        "i wish i could disappear",
        "life is pointless",
        "i am tired of everything",
        "nothing matters anymore",
        "no reason to live"
    ]

    if any(p in t for p in phrases):
        return True

    return False

# =====================================================
# MULTILINGUAL EMOTION DETECTION
# =====================================================

def _multilingual_override(text):

    t = text.lower()

    patterns = {

        "Happy":[

            # Hinglish
            "bahut khush hoon",
            "aaj bahut accha lag raha hai",
            "life mast hai",
            "feeling awesome yaar",
            "bahut happy hoon",

            # Telugu-English
            "nenu happy ga unna",
            "chala happy ga undi",
            "life chala bagundi",
            "today chala happy ga unna"
        ],

        "Sad":[

            # Hinglish
            "bahut udaas hoon",
            "dil bahut heavy hai",
            "mood off hai",
            "life boring lag rahi hai",

            # Telugu-English
            "naaku baadha ga undi",
            "chala sad ga unna",
            "life chala boring ga undi",
            "mood off ga undi"
        ],

        "Depression":[

            # Hinglish
            "life ka koi matlab nahi",
            "sab bekaar lag raha hai",
            "andar se empty feel ho raha",

            # Telugu-English
            "life lo meaning ledu",
            "life pointless ga undi",
            "nenu empty ga feel avutunna"
        ],

        "Anxiety":[

            # Hinglish
            "bahut tension hai",
            "bahut stress hai",
            "bahut darr lag raha hai",
            "panic ho raha hai",

            # Telugu-English
            "chala tension ga undi",
            "naaku bayam vesthundi",
            "chala stress ga undi"
        ],

        "Angry":[

            # Hinglish
            "bahut gussa aa raha hai",
            "bahut irritate ho raha hoon",
            "yeh bahut frustrating hai",

            # Telugu-English
            "naaku kopam vastundi",
            "chala kopam ga undi",
            "chala irritate ga undi"
        ],

        "Neutral":[

            # Hinglish
            "sab theek hai",
            "normal hai",
            "kuch special nahi",

            # Telugu-English
            "normal ga undi",
            "sare undi",
            "just normal ga undi"
        ]
    }

    for emotion, phrases in patterns.items():
        for p in phrases:
            if p in t:
                return emotion, 0.86

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
            "chala santosham ga undi",
            "chala happy ga undi",
            "chala anandham ga unanu",
            # Hinglish
            "bahut khush hoon",
            "life mast hai",
            "feeling awesome",

            # Telugu-English
            "nenu happy ga unna",
            "chala happy ga undi"
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
            "chala baadha ga undi",
            
            # Hinglish
            "mood off hai",
            "bahut udaas hoon",

            # Telugu-English
            "chala sad ga unna",
            "life boring ga undi"
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
            "ఏదీ బాగోలేదు",
            # Hinglish
            "life ka matlab nahi",
            "sab bekaar hai",

            # Telugu-English
            "life pointless ga undi",
            "life lo meaning ledu"
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
            "naaku bayam vesthundi",
            # Hinglish
            "bahut tension hai",
            "bahut stress hai",

            # Telugu-English
            "chala tension ga undi",
            "chala stress ga undi"
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
            "naaku kopam vastundi",
            # Hinglish
            "bahut gussa hai",
            "bahut irritate ho raha hoon",

            # Telugu-English
            "chala kopam ga undi",
            "naaku kopam vastundi"
        ],

        "Neutral": [

            # English
            "i feel okay",
            "just normal",

            # Hindi
            "sab theek hai",

            # Telugu
            "సరే ఉంది",
            # Hinglish
            "sab normal hai",

            # Telugu-English
            "just normal ga undi"
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
                return "Neutral", 0.45

            data = response.json()

            if not isinstance(data, list) or len(data) == 0:
                return "Neutral", 0.5

            emotions = data[0]

            if not emotions:
                return "Neutral", 0.5

            best = max(emotions, key=lambda x: x.get("score", 0))

            label = best.get("label", "").lower()
            score = float(best.get("score", 0))

            t = text.lower()

            # -----------------------------
            # ENGLISH MODEL LABELS
            # -----------------------------

            if label == "joy":
                return "Happy", score

            if label == "sadness":
                if score > 0.85:
                    return "Depression", score
                return "Sad", score

            if label == "anger":
                return "Angry", score

            if label == "fear":
                return "Anxiety", score

            if label == "disgust":
                return "Angry", score

            # -----------------------------
            # MULTILINGUAL MODEL LABELS
            # -----------------------------

            if label == "positive":
                return "Happy", score

            if label == "neutral":
                return "Neutral", score

            if label == "negative":

                if any(w in t for w in [
                    "hopeless", "worthless", "empty",
                    "जीवन बेकार", "जिंदगी बेकार",
                    "జీవితం అర్థం లేదు"
                ]):
                    return "Depression", score

                if any(w in t for w in [
                    "worried", "panic", "nervous",
                    "चिंता", "टेंशन",
                    "టెన్షన్", "భయం"
                ]):
                    return "Anxiety", score

                if any(w in t for w in [
                    "angry", "furious", "rage",
                    "गुस्सा",
                    "కోపం"
                ]):
                    return "Angry", score

                return "Sad", score

        except Exception:
            time.sleep(1)

    return "Neutral", 0.5


# =====================================================
# MIXED EMOTION DETECTION
# =====================================================

def detect_mixed_emotion(text):

    t = text.lower()

    transition_words = [
        "but","however","although",
        "lekin","par","magar",
        "kani","but kani"
    ]

    if any(w in t for w in transition_words):

        if any(w in t for w in ["anxious","worried","tension","stress","fear"]):
            return "Anxiety",0.9

        if any(w in t for w in ["sad","down","bad","depressed"]):
            return "Sad",0.9

        if any(w in t for w in ["angry","rage","frustrated"]):
            return "Angry",0.9

    return None


def emotion_synonyms(text):

    t = text.lower()

    synonyms = {

            "Happy":[
            "delighted","excited","joyful","thrilled","pleased",
            "khush","accha","bagundi","happy ga"
            ],

            "Sad":[
            "unhappy","miserable","down","gloomy",
            "udaas","dukhi","baadha","sad ga"
            ],

            "Depression":[
            "hopeless","worthless","empty","numb",
            "life pointless","meaning ledu","andar se empty"
            ],

            "Anxiety":[
            "worried","nervous","panicking","uneasy",
            "tension","stress","bayam"
            ],

            "Angry":[
            "furious","frustrated","irritated","annoyed",
            "gussa","kopam"
            ]

        }

    for emotion, words in synonyms.items():
        for w in words:
            if w in t:
                return emotion, 0.88

    return None

# =====================================================
# CONTEXT EMOTION BOOST
# =====================================================

def context_emotion_boost(text):

    t = text.lower()

    context_map = {

        "Depression":[
            "drained",
            "empty inside",
            "lost in life",
            "no motivation",
            "no energy"
        ],

        "Anxiety":[
            "overwhelmed",
            "heart racing",
            "cant relax",
            "constant worry"
        ],

        "Sad":[
            "feeling low",
            "heartbroken",
            "feeling down today"
        ]
    }

    for emotion, words in context_map.items():
        for w in words:
            if w in t:
                return emotion, 0.87

    return None


# =====================================================
# EMOJI EMOTION DETECTION
# =====================================================

# =====================================================
# ADVANCED EMOJI EMOTION DETECTOR (100+ EMOJIS)
# =====================================================

def detect_emoji_emotion(text):

    emoji_map = {

        "Happy": [
            "😊","😁","😄","😃","🙂","☺️","🥰","😍","🤩","😺",
            "😸","😹","🎉","🥳","😆","😋","😎","🌞","🌈","💖"
        ],

        "Sad": [
            "😔","😞","😢","😥","☹️","🙁","😿","🥺","😓",
            "😟","😣","😖","😭","💧","🌧️"
        ],

        "Depression": [
            "💔","🥀","🖤","😞","😔","😢","😭","🥺",
            "🌑","🌧","💭","😶","😑","😐"
        ],

        "Anxiety": [
            "😰","😨","😟","😬","😧","😦","😱","🫨",
            "😳","😖","😓","😵","😵‍💫"
        ],

        "Angry": [
            "😡","🤬","😠","👿","💢","😤","🔥",
            "😾","🤯","👊"
        ],

        "Suicidal": [
            "💀","☠️","⚰️","🪦","🩸","🔪","🆘"
        ],

        "Neutral": [
            "😐","😶","🤔","🫤","🙃","😑"
        ]
    }
    


    # -------------------------------------------------
    # Detect emoji presence
    # -------------------------------------------------
    detected = []

    for emotion, emojis in emoji_map.items():
        if any(e in text for e in emojis):
           detected.append(emotion)

    if detected:
       # majority vote
       emotion = max(set(detected), key=detected.count)
       return emotion, 0.92

    return None


# =====================================================
# EMOJI INTENSITY BOOST
# =====================================================

def emoji_intensity(text):

    strong_emojis = ["😭", "💔", "😢"]

    count = sum(text.count(e) for e in strong_emojis)

    if count >= 3:
        return 1.3

    if count == 2:
        return 1.15

    return 1.0


# =====================================================
# EMOTION PREDICTION PIPELINE
# =====================================================
def predict_emotion(text: str):

    if not text or not text.strip():
        return {"emotion": "Neutral", "confidence": 0.0}
    if neutral_short_text(text):
        return {"emotion": "Neutral", "confidence": 0.9}

    text = normalize_text(text)
    text = normalize_phrases(text)

    # EMOJI DETECTION
    emoji = detect_emoji_emotion(text)

# -------------------------------------------------
# Emoji-only messages
# -------------------------------------------------
    if emoji and len(text.strip()) <= 6:
      emotion = emoji[0]
      confidence = emoji[1] * emoji_intensity(text)

      return {
        "emotion": emotion,
        "confidence": min(confidence, 1.0)
    }

# -------------------------------------------------
# Emoji mixed with text (save for later influence)
# -------------------------------------------------
    emoji_conf = None
    emoji_emotion = None

    if emoji:
        emoji_emotion = emoji[0]
        emoji_conf = emoji[1] * emoji_intensity(text)

    # Continue normal pipeline
    if emergency_signal(text):
        return {"emotion": "Suicidal", "confidence": 0.98}
    
    if passive_suicide_signal(text):
        return {"emotion": "Depression", "confidence": 0.92}

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
    context_boost = context_emotion_boost(text)
    if context_boost:
        return {"emotion": context_boost[0], "confidence": context_boost[1]}

    mixed = detect_mixed_emotion(text)
    if mixed:
        return {"emotion": mixed[0], "confidence": mixed[1]}

    emotion, confidence = _call_huggingface(text)

    # ML smoothing
    confidence = (confidence * 0.85) + 0.15
    
    emotion_weights = {
    "Happy":1.0,
    "Neutral":0.9,
    "Sad":1.05,
    "Anxiety":1.05,
    "Angry":1.05,
    "Depression":1.1,
    "Suicidal":1.15
    }

    confidence *= emotion_weights.get(emotion,1.0)

    confidence *= detect_intensity(text)
    confidence *= length_boost(text)
    confidence *= emoji_intensity(text)

    confidence = min(confidence + 0.1, 1.0)

# -------------------------------------------------
# Emoji influence
# -------------------------------------------------
    if emoji_conf is not None:

        # emoji supports text emotion
        if emoji_emotion == emotion:
            confidence = max(confidence, emoji_conf)

        # emoji disagrees with text
        elif emoji_conf > confidence * 0.85:
            emotion = emoji_emotion
            confidence = emoji_conf

# ==========================================
# NEGATION CORRECTION
# ==========================================
    if detect_negation(text):

        if emotion == "Happy":
            emotion = "Sad"

        elif emotion == "Sad":
            emotion = "Neutral"

        elif emotion == "Anxiety":
            emotion = "Neutral"

        elif emotion == "Angry":
            emotion = "Neutral"

    return {
        "emotion": emotion,
        "confidence": round(confidence, 4)
    }
  
# =====================================================
# SENTENCE EMOTION ANALYSIS
# =====================================================

import re
from collections import Counter

def sentence_emotion_analysis(text):

    sentences = re.split(r'[.!?]', text)

    emotions = []

    for s in sentences:

        s = s.strip()

        if len(s) < 4:
            continue

        result = predict_emotion(s)

        emotions.append(result["emotion"])

    return emotions


def dominant_emotion(emotions):

    if not emotions:
        return None

    return Counter(emotions).most_common(1)[0][0]

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
    language = detect_language(text)

    sentence_emotions = sentence_emotion_analysis(text)
    dominant = dominant_emotion(sentence_emotions)

    emotion = dominant if dominant else result["emotion"]
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
        "emotion_explanation": explain_emotion(emotion),
        "language": language,
        "sarcasm_detected": detect_sarcasm(text),
        "sentence_emotions": sentence_emotions
    }
