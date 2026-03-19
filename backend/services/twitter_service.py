import requests
from typing import List, Dict

from ai_models.mental_health_model import predict_emotion


# =========================================
# GET USER TWEETS FROM TWITTER API
# =========================================
def get_user_tweets(user_id: str, access_token: str) -> List[Dict]:
    try:
        url = f"https://api.twitter.com/2/users/{user_id}/tweets"

        headers = {
            "Authorization": f"Bearer {access_token}"
        }

        params = {
            "max_results": 10,  # you can increase up to 100
            "tweet.fields": "created_at,text"
        }

        response = requests.get(url, headers=headers, params=params)

        # 🔴 Handle API errors
        if response.status_code != 200:
            print("Twitter API Error:", response.text)
            return []

        data = response.json()

        return data.get("data", [])

    except Exception as e:
        print("Error fetching tweets:", str(e))
        return []


# =========================================
# ANALYZE TWEETS USING ML MODEL
# =========================================
def analyze_tweets(tweets: List[Dict]) -> List[Dict]:
    results = []

    try:
        for tweet in tweets:
            text = tweet.get("text", "")

            if not text:
                continue

            emotion = predict_emotion(text)

            results.append({
                "text": text,
                "emotion": emotion
            })

    except Exception as e:
        print("Error analyzing tweets:", str(e))

    return results


# =========================================
# MAIN FUNCTION (COMBINED FLOW)
# =========================================
def get_twitter_analysis(user_id: str, access_token: str) -> Dict:
    tweets = get_user_tweets(user_id, access_token)

    analysis = analyze_tweets(tweets)

    return {
        "total": len(analysis),
        "data": analysis
    }