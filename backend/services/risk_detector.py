# =====================================================
# PRO RISK DETECTOR
# =====================================================

def detect_risk(
    avg_score: float,
    dominant_emotion: str = None,
    confidence: float = None
) -> str:
    """
    Advanced risk detection using:
    - Average score
    - Dominant emotion
    - Confidence (optional)
    """

    # =====================================================
    # SAFETY CHECK
    # =====================================================
    if avg_score is None:
        return "LOW"

    # Normalize emotion
    emotion = (dominant_emotion or "").lower()

    # =====================================================
    # 🚨 CRITICAL CONDITIONS (HIGHEST PRIORITY)
    # =====================================================
    if emotion in ["suicidal"]:
        return "CRITICAL"

    if emotion in ["depression"] and avg_score <= -2:
        return "HIGH"

    # =====================================================
    # SCORE-BASED LOGIC (BACKWARD COMPATIBLE)
    # =====================================================
    if avg_score <= -3:
        return "HIGH"

    elif avg_score <= -2:
        return "HIGH"

    elif avg_score <= -1:
        return "MEDIUM"

    # =====================================================
    # POSITIVE / STABLE
    # =====================================================
    risk = "LOW"

    # =====================================================
    # OPTIONAL: CONFIDENCE BOOST
    # =====================================================
    if confidence is not None:

        if confidence > 0.85 and avg_score < -1:
            risk = "HIGH"

        elif confidence > 0.75 and avg_score < 0:
            risk = "MEDIUM"

    return risk


# =====================================================
# OPTIONAL: NUMERIC RISK SCORE (FOR ANALYTICS)
# =====================================================

def risk_to_score(risk: str) -> int:
    """
    Convert risk level to numeric score (for graphs / DB)
    """
    mapping = {
        "LOW": 1,
        "MEDIUM": 2,
        "HIGH": 3,
        "CRITICAL": 4
    }
    return mapping.get(risk.upper(), 1)