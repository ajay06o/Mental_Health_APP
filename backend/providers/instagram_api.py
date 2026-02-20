import requests
from typing import List, Dict, Any, Optional
from utils.crypto import decrypt_token
import time
import logging

logger = logging.getLogger("instagram_api")


def _get_json_with_backoff(url: str, params: dict, max_retries: int = 4, timeout: int = 15) -> Optional[dict]:
    delay = 1.0
    for attempt in range(max_retries):
        try:
            resp = requests.get(url, params=params, timeout=timeout)
            if resp.status_code == 429:
                # rate limited — honor Retry-After if present
                ra = resp.headers.get("Retry-After")
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
            logger.debug(f"Request error to {url}: {e}")
            time.sleep(delay)
            delay *= 2
    return None


def fetch_recent_activities(account, limit: int = 50) -> List[Dict[str, Any]]:
    """Fetch recent media and comments for the connected Instagram account with paging and backoff.

    Returns a list of activity dicts with keys: activity_type, content, metadata, timestamp
    """
    try:
        token = decrypt_token(account.access_token)
    except Exception:
        logger.warning("Failed to decrypt Instagram token")
        return []

    activities: List[Dict[str, Any]] = []

    media_url = "https://graph.instagram.com/me/media"
    params = {"fields": "id,caption,media_type,timestamp", "access_token": token, "limit": 25}

    collected = 0
    next_url = media_url
    next_params = params

    while next_url and collected < limit:
        data = _get_json_with_backoff(next_url, next_params)
        if not data:
            break

        items = data.get("data", [])
        for item in items:
            if collected >= limit:
                break

            media_id = item.get("id")
            caption = item.get("caption")
            timestamp = item.get("timestamp")
            media_type = item.get("media_type")

            activities.append(
                {
                    "provider_item_id": f"instagram_{media_id}",
                    "activity_type": "post",
                    "content": caption,
                    "metadata": {"media_id": media_id, "media_type": media_type},
                    "timestamp": timestamp,
                }
            )
            collected += 1

            # Comments paging for this media
            comments_next = f"https://graph.facebook.com/v16.0/{media_id}/comments"
            comments_params = {"access_token": token, "fields": "text,from,created_time", "limit": 50}

            while comments_next:
                cdata = _get_json_with_backoff(comments_next, comments_params)
                if not cdata:
                    break

                comments = cdata.get("data", [])
                for c in comments:
                    text = c.get("text") or c.get("message") or ""
                    ct = c.get("created_time") or c.get("timestamp")
                    comment_id = c.get("id", "")
                    activities.append(
                        {
                            "provider_item_id": f"instagram_comment_{comment_id}",
                            "activity_type": "comment",
                            "content": text,
                            "metadata": {"media_id": media_id, "from": c.get("from")},
                            "timestamp": ct,
                        }
                    )

                paging = cdata.get("paging", {})
                comments_next = paging.get("next")
                # if next exists as URL, clear params to use next URL directly
                if comments_next:
                    comments_params = {}

        paging = data.get("paging", {})
        next_url = paging.get("next")
        if next_url:
            # when next is full URL, we will call it without params
            next_params = {}

    return activities
