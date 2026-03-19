# =====================================================
# UNIFIED EMOTION → SCORE MAPPING (PRO LEVEL)
# Supports:
# - Sentiment model (positive/neutral/negative)
# - Emotion model (joy, sadness, etc.)
# - Mental health model (Happy, Depression, etc.)
# =====================================================

def emotion_to_score(emotion: str) -> float:

    if not emotion:
        return 0

    e = emotion.lower()

    # =====================================================
    # SENTIMENT MODEL (NEW)
    # =====================================================
    sentiment_map = {
        "positive": 2,
        "neutral": 0,
        "negative": -2
    }

    if e in sentiment_map:
        return sentiment_map[e]

    # =====================================================
    # OLD EMOTION MODEL (BACKWARD COMPATIBILITY)
    # =====================================================
    emotion_map = {
        "joy": 2,
        "sadness": -2,
        "anger": -2,
        "fear": -3,
        "disgust": -2
    }

    if e in emotion_map:
        return emotion_map[e]

    # =====================================================
    # MENTAL HEALTH MODEL (ADVANCED)
    # =====================================================
    mental_map = {
        "happy": 2,
        "neutral": 0,
        "sad": -2,
        "anxiety": -2,
        "angry": -2,
        "depression": -4,
        "suicidal": -6
    }

    if e in mental_map:
        return mental_map[e]

    # =====================================================
    # FALLBACK
    # =====================================================
    return 0


# =====================================================
# OPTIONAL: NORMALIZED SCORE (0 → 100)
# =====================================================

def normalize_score(score: float) -> int:
    """
    Convert score (-6 → +2) into 0–100 mental index
    """
    min_score = -6
    max_score = 2

    normalized = (score - min_score) / (max_score - min_score) * 100
    return int(max(0, min(normalized, 100)))