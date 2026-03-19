from collections import Counter

# =====================================================
# PRO TREND CALCULATOR
# =====================================================

def calculate_overall(results):
    """
    Advanced trend calculation

    Input:
    results = [
        {"emotion": "Sad", "score": -2, "confidence": 0.8},
        ...
    ]

    Returns:
    avg_score, dominant_emotion, insights_dict
    """

    # =====================================================
    # SAFETY CHECK
    # =====================================================
    if not results:
        return 0, "neutral", {
            "mental_health_index": 50,
            "emotion_distribution": {},
            "avg_confidence": 0
        }

    # =====================================================
    # EXTRACT VALUES
    # =====================================================
    scores = [r.get("score", 0) for r in results]
    emotions = [r.get("emotion", "neutral") for r in results]
    confidences = [r.get("confidence", 0) for r in results]

    # =====================================================
    # CORE CALCULATIONS
    # =====================================================
    avg_score = sum(scores) / len(scores)

    dominant = Counter(emotions).most_common(1)[0][0]

    avg_confidence = sum(confidences) / len(confidences) if confidences else 0

    # =====================================================
    # 📊 EMOTION DISTRIBUTION (FOR GRAPHS)
    # =====================================================
    emotion_counts = Counter(emotions)
    total = len(emotions)

    distribution = {
        emotion: round(count / total, 2)
        for emotion, count in emotion_counts.items()
    }

    # =====================================================
    # 🧠 MENTAL HEALTH INDEX (0–100)
    # =====================================================
    # score range assumed: -6 → +2
    min_score = -6
    max_score = 2

    mhi = (avg_score - min_score) / (max_score - min_score) * 100
    mhi = int(max(0, min(mhi, 100)))

    # =====================================================
    # RETURN (BACKWARD COMPATIBLE + EXTRA)
    # =====================================================
    return avg_score, dominant, {
        "mental_health_index": mhi,
        "emotion_distribution": distribution,
        "avg_confidence": round(avg_confidence, 3),
        "total_entries": len(results)
    }