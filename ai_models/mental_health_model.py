def _keyword_override(text: str):
    t = text.lower()

    # =========================
    # 🚨 SUICIDAL (High Priority)
    # =========================
    suicidal = [
        # English (direct)
        "want to die", "kill myself", "suicide", "end my life",
        "no reason to live", "better off dead", "i give up on life",
        "i don't want to exist", "i can't go on", "self harm",
        "cut myself", "overdose", "hang myself",
        "i wish i was dead", "i hope i die",
        "life is not worth living",
        "i don't see a future",
        "i am done with life",
        "nothing matters anymore",
        "i feel like ending everything",
        "i want to disappear forever",

        # English (indirect but serious)
        "what's the point of living",
        "i am tired of living",
        "i can't handle this anymore",
        "i don't want to wake up",
        "i feel trapped forever",

        # Hindi
        "आत्महत्या", "मरना चाहता", "जीना नहीं चाहता",
        "खुद को मार", "जान देना", "मर जाना बेहतर",
        "अब जीने का मन नहीं", 
        "जीने का कोई मतलब नहीं",
        "मैं खत्म हो जाना चाहता हूँ",
        "सब खत्म कर देना चाहता हूँ",
        "अब सहन नहीं होता",

        # Telugu
        "చావాలని ఉంది", "జీవించాలనిపించడం లేదు",
        "ఆత్మహత్య", "నాకు బ్రతకడం ఇష్టం లేదు",
        "ఇక బ్రతకలేను",
        "జీవితం వృథా",
        "అన్నీ ముగించాలి అనిపిస్తోంది",
        "ఇంకా బతకడం అవసరం లేదు",
    ]

    # =========================
    # 😞 DEPRESSION
    # =========================
    depression = [
        # English
        "depressed", "hopeless", "empty", "worthless",
        "lost interest", "no motivation", "numb",
        "tired of everything", "emotionally exhausted",
        "feel nothing", "no energy",
        "feel useless", "i hate myself",
        "i am a failure",
        "nothing makes me happy",
        "i feel broken",
        "i feel dead inside",
        "everything feels pointless",
        "i feel stuck in life",
        "i feel lost",
        "no purpose in life",

        # Hindi
        "डिप्रेशन", "निराश", "उदास", "खालीपन",
        "कुछ अच्छा नहीं लगता",
        "मैं बेकार हूँ",
        "सब बेकार लगता है",
        "जीवन बेकार है",

        # Telugu
        "డిప్రెషన్", "నిరాశ", "చాలా దిగులు",
        "ఏమీ ఆసక్తి లేదు",
        "నేను పనికిరానివాడిని",
        "జీవితం నిరాశగా ఉంది",
        "ఏదీ సంతోషం ఇవ్వడం లేదు",
    ]

    # =========================
    # 😰 ANXIETY
    # =========================
    anxiety = [
        # English
        "anxious", "stress", "panic", "panic attack",
        "overthinking", "worried", "can't breathe",
        "heart racing", "restless", "fear",
        "scared", "nervous", "overwhelmed",
        "shaking", "sweating", "i feel pressure",
        "i can't relax",
        "i am constantly thinking",
        "i feel tension",
        "mind won't stop",
        "i feel uneasy",
        "i feel unsafe",

        # Hindi
        "चिंता", "घबराहट", "डर लग रहा",
        "बेचैनी",
        "दिल तेज धड़क रहा",
        "सांस नहीं आ रही",
        "बहुत टेंशन है",

        # Telugu
        "ఆందోళన", "భయం", "గాబరా",
        "బెంగ",
        "గుండె బాగా కొట్టుకుంటుంది",
        "చాలా టెన్షన్ గా ఉంది",
        "శాంతిగా ఉండలేకపోతున్నాను",
    ]

    # =========================
    # 😡 ANGER
    # =========================
    angry = [
        # English
        "angry", "furious", "rage", "hate everyone",
        "irritated", "annoyed", "frustrated",
        "mad at", "can't control anger",
        "i want to scream",
        "i feel aggressive",
        "i am pissed",
        "so much anger",
        "i feel violent",
        "i hate this",

        # Hindi
        "गुस्सा", "चिढ़", "नफरत",
        "बहुत गुस्सा आ रहा",
        "कंट्रोल नहीं हो रहा",

        # Telugu
        "కోపం", "చిరాకు", "ద్వేషం",
        "చాలా కోపంగా ఉంది",
        "అసహనం",
    ]

    # =========================
    # 😢 SADNESS
    # =========================
    sad = [
        # English
        "sad", "crying", "lonely", "heartbroken",
        "miss someone", "feeling down",
        "upset", "hurt inside",
        "i feel alone",
        "i miss you so much",
        "tears won't stop",
        "i feel abandoned",
        "i feel rejected",
        "i feel ignored",

        # Hindi
        "दुख", "अकेला", "रोना आ रहा",
        "दिल टूट गया",
        "बहुत उदास हूँ",
        "कोई साथ नहीं है",

        # Telugu
        "బాధ", "ఒంటరిగా", "ఎడుస్తున్నా",
        "హృదయం పగిలింది",
        "చాలా బాధగా ఉంది",
        "ఎవరూ లేరు నా కోసం",
    ]

    # =========================
    # 😊 HAPPY
    # =========================
    happy = [
        # English
        "happy", "joy", "peaceful", "excited",
        "grateful", "blessed", "motivated",
        "feeling good", "content",
        "i feel amazing",
        "life is good",
        "i feel confident",
        "i am proud",
        "i feel strong",
        "things are going well",

        # Hindi
        "खुश", "संतुष्ट", "शांति",
        "बहुत अच्छा लग रहा है",
        "मैं खुश हूँ",

        # Telugu
        "సంతోష", "శాంతి", "ఆనందం",
        "చాలా సంతోషంగా ఉంది",
        "బాగుంది",
    ]

    # =====================================================
    # PRIORITY ORDER (VERY IMPORTANT)
    # =====================================================
    for w in suicidal:
        if w in t:
            return "Suicidal", 0.95

    for w in depression:
        if w in t:
            return "Depression", 0.88

    for w in anxiety:
        if w in t:
            return "Anxiety", 0.85

    for w in angry:
        if w in t:
            return "Angry", 0.80

    for w in sad:
        if w in t:
            return "Sad", 0.75

    for w in happy:
        if w in t:
            return "Happy", 0.75

    return None

# =====================================================
# 📊 SEVERITY DETECTION
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
# 🚨 RISK LEVEL DETECTION
# =====================================================
def detect_risk(emotion: str) -> str:
    if emotion == "Suicidal":
        return "critical"
    elif emotion in ["Depression"]:
        return "high"
    elif emotion in ["Anxiety", "Angry", "Sad"]:
        return "moderate"
    else:
        return "low"


# =====================================================
# 🧠 MENTAL HEALTH INDEX CALCULATION
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
# 🧠 BASE PREDICTION (INTERNAL)
# =====================================================
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


# =====================================================
# ✅ PUBLIC API (WHAT app.py EXPECTS)
# =====================================================
def final_prediction(text: str) -> dict:
    """
    Stable public interface for FastAPI.
    DO NOT REMOVE — app.py depends on this.
    """

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