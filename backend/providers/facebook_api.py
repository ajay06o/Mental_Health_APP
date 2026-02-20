import requests
from typing import List, Dict, Any, Optional
from utils.crypto import decrypt_token
import time
import logging

logger = logging.getLogger("facebook_api")


def _get_json_with_backoff(url: str, params: dict, max_retries: int = 4, timeout: int = 15) -> Optional[dict]:
    delay = 1.0
    for attempt in range(max_retries):
        try:
            resp = requests.get(url, params=params, timeout=timeout)
            if resp.status_code == 429:
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
            logger.debug(f"Facebook request error to {url}: {e}")
            time.sleep(delay)
            delay *= 2
    return None


def fetch_recent_activities(account, limit: int = 50) -> List[Dict[str, Any]]:
    """Fetch recent Facebook posts and comments for the connected account with pagination and backoff."""
    try:
        token = decrypt_token(account.access_token)
    except Exception:
        logger.warning("Failed to decrypt Facebook token")
        return []

    activities: List[Dict[str, Any]] = []

    # Resolve user id
    me_url = "https://graph.facebook.com/me"
    me_data = _get_json_with_backoff(me_url, {"access_token": token})
    if not me_data:
        return []
    user_id = me_data.get("id")

    posts_url = f"https://graph.facebook.com/v16.0/{user_id}/posts"
    params = {"fields": "id,message,created_time", "access_token": token, "limit": 25}

    collected = 0
    next_url = posts_url
    next_params = params

    while next_url and collected < limit:
        data = _get_json_with_backoff(next_url, next_params)
        if not data:
            break

        items = data.get("data", [])
        for item in items:
            if collected >= limit:
                break

            post_id = item.get("id")
            message = item.get("message")
            timestamp = item.get("created_time")

            activities.append(
                {
                    "provider_item_id": f"facebook_{post_id}",
                    "activity_type": "post",
                    "content": message,
                    "metadata": {"post_id": post_id},
                    "timestamp": timestamp,
                }
            )
            collected += 1

            # Comments paging for this post
            comments_next = f"https://graph.facebook.com/v16.0/{post_id}/comments"
            comments_params = {"access_token": token, "fields": "message,from,created_time", "limit": 50}

            while comments_next:
                cdata = _get_json_with_backoff(comments_next, comments_params)
                if not cdata:
                    break

                comments = cdata.get("data", [])
                for c in comments:
                    text = c.get("message") or ""
                    ct = c.get("created_time")
                    comment_id = c.get("id", "")
                    activities.append(
                        {
                            "provider_item_id": f"facebook_comment_{comment_id}",
                            "activity_type": "comment",
                            "content": text,
                            "metadata": {"post_id": post_id, "from": c.get("from")},
                            "timestamp": ct,
                        }
                    )

                paging = cdata.get("paging", {})
                comments_next = paging.get("next")
                if comments_next:
                    comments_params = {}

        paging = data.get("paging", {})
        next_url = paging.get("next")
        if next_url:
            next_params = {}

    return activities
