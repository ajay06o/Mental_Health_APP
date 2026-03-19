from fastapi import APIRouter, HTTPException
from models.schemas import SocialTextInput, SocialAnalysisResponse, AnalysisResult
from services.analyzer import analyze_text
from services.trends import calculate_overall
from services.risk_detector import detect_risk

router = APIRouter()


@router.post("/analyze-social", response_model=SocialAnalysisResponse)
def analyze_social(data: SocialTextInput):

    # =====================================================
    # VALIDATION
    # =====================================================
    if not data.texts or len(data.texts) == 0:
        raise HTTPException(status_code=400, detail="No texts provided")

    results = []

    # =====================================================
    # ANALYZE EACH TEXT
    # =====================================================
    for text in data.texts:
        try:
            res = analyze_text(text)

            # Ensure consistent structure
            results.append({
                "emotion": res.get("emotion", "neutral"),
                "confidence": res.get("confidence", 0.0),
                "score": res.get("score", 0)
            })

        except Exception as e:
            # fail-safe: don't break whole request
            results.append({
                "emotion": "neutral",
                "confidence": 0.0,
                "score": 0
            })

    # =====================================================
    # TREND ANALYSIS (UPDATED)
    # =====================================================
    avg_score, dominant, insights = calculate_overall(results)

    # =====================================================
    # RISK DETECTION (PRO)
    # =====================================================
    risk = detect_risk(
        avg_score=avg_score,
        dominant_emotion=dominant,
        confidence=insights.get("avg_confidence", 0)
    )

    # =====================================================
    # FINAL RESPONSE (BACKWARD COMPATIBLE)
    # =====================================================
    return {
        "overall_score": round(avg_score, 3),
        "dominant_emotion": dominant,
        "risk_level": risk,
        "results": results,

        # 🔥 NEW (does NOT break existing frontend)
        "mental_health_index": insights.get("mental_health_index"),
        "emotion_distribution": insights.get("emotion_distribution"),
        "avg_confidence": insights.get("avg_confidence"),
        "total_entries": insights.get("total_entries")
    }