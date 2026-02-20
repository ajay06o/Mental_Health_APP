import requests
from typing import List, Dict, Any, Optional
from utils.crypto import decrypt_token
import time
import logging

logger = logging.getLogger("x_api")


def _get_json_with_backoff(url: str, headers: dict, params: dict = None, max_retries: int = 4, timeout: int = 15) -> Optional[dict]:
    delay = 1.0
    for attempt in range(max_retries):
        try:
            resp = requests.get(url, headers=headers, params=params, timeout=timeout)
            if resp.status_code == 429:
                ra = resp.headers.get("retry-after") or resp.headers.get("x-rate-limit-reset")
                try:
                    wait = int(ra) if ra and ra.isdigit() else delay
                except Exception:
                    wait = delay
                time.sleep(wait)
                delay *= 2
                continue

            resp.raise_for_status()
            return resp.json()
        except requests.RequestException as e:
            logger.debug(f"X API request error to {url}: {e}")
            time.sleep(delay)
            delay *= 2
    return None


def fetch_recent_activities(account, limit: int = 50) -> List[Dict[str, Any]]:
    """Fetch recent tweets and mentions with pagination and backoff.

    Returns list of activity dicts with keys: activity_type, content, metadata, timestamp
    """
    try:
        token = decrypt_token(account.access_token)
    except Exception:
        logger.warning("Failed to decrypt X token")
        return []

    activities: List[Dict[str, Any]] = []
    headers = {"Authorization": f"Bearer {token}"}

    # Get authenticated user id
    me = _get_json_with_backoff("https://api.twitter.com/2/users/me", headers)
    if not me:
        return []
    user_id = me.get("data", {}).get("id")
    if not user_id:
        return []

    # Helper to page through tweets/mentions
    def page_through(url: str, params: dict, activity_type: str):
        nonlocal activities
        next_token = None
        collected = 0
        while True:
            p = dict(params)
            if next_token:
                p["pagination_token"] = next_token
            data = _get_json_with_backoff(url, headers, params=p)
            if not data:
                break
            items = data.get("data", [])
            for it in items:
                if len(activities) >= limit:
                    return
                tweet_id = it.get("id", "")
                activities.append(
                    {
                        "provider_item_id": f"x_{tweet_id}",
                        "activity_type": activity_type,
                        "content": it.get("text"),
                        "metadata": {"id": tweet_id},
                        "timestamp": it.get("created_at"),
                    }
                )

            meta = data.get("meta", {})
            next_token = meta.get("next_token")
            if not next_token:
                break

    # Page tweets
    tweets_url = f"https://api.twitter.com/2/users/{user_id}/tweets"
    page_through(tweets_url, {"max_results": 100, "tweet.fields": "created_at,conversation_id"}, "tweet")

    # Page mentions
    mentions_url = f"https://api.twitter.com/2/users/{user_id}/mentions"
    page_through(mentions_url, {"max_results": 100, "tweet.fields": "created_at"}, "mention")

    return activities[:limit]
