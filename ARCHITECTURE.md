# Mental Health App - Architecture & Design Decisions

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           MOBILE APP (Flutter)                       │
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │   Home Screen    │  │ Emotion Analysis │  │ Social Connect   │  │
│  │   - Display      │  │ - View History   │  │ - OAuth Flow     │  │
│  │   - Analytics    │  │ - Stats          │  │ - Account List   │  │
│  └────────┬─────────┘  └─────┬────────────┘  └────────┬─────────┘  │
│           │                  │                        │              │
│           └──────┬───────────┴────────────────────────┘              │
│                  │                                                    │
│            ┌─────▼──────┐  ┌─────────────────┐                      │
│            │  ApiClient  │  │ OAuthListener   │                      │
│            │ (Parsing)   │  │ (Deep-link)     │                      │
│            └─────┬──────┘  └────────┬────────┘                      │
│                  │                   │                               │
└──────────────────┼───────────────────┼───────────────────────────────┘
                   │                   │
                   └─────────┬─────────┘
                             │
                    ┌────────▼────────┐
                    │  HTTPS/REST API │
                    │ localhost:8000  │
                    └────────┬────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│                         BACKEND (FastAPI)                            │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                        Routes Layer                          │   │
│  │                                                               │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │   │
│  │  │ Auth Routes  │  │ Social Routes │  │ OAuth Routes     │  │   │
│  │  │ - Register   │  │ - connect     │  │ - authorize      │  │   │
│  │  │ - Login      │  │ - sync        │  │ - callback       │  │   │
│  │  │ - Refresh    │  │ - accounts    │  │ - oauth-url      │  │   │
│  │  └──────────────┘  │ - analyze     │  │   (mobile)       │  │   │
│  │                    │ - disconnect  │  └──────────────────┘  │   │
│  │  ┌──────────────┐  └──────────────┘                         │   │
│  │  │Predict Routes│  ┌──────────────┐                         │   │
│  │  │ - predict    │  │Webhook Routes │                         │   │
│  │  │ - history    │  │ - facebook    │                         │   │
│  │  │ - profile    │  │   (verify)    │                         │   │
│  │  │ - update     │  │   (callback)  │                         │   │
│  │  └──────────────┘  └──────────────┘                         │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                             ▲                                        │
│                             │                                        │
│  ┌──────────────────────────┴────────────────────────────────────┐ │
│  │                      Service Layer                            │ │
│  │                                                                │ │
│  │  ┌─────────────────┐  ┌─────────────────┐                   │ │
│  │  │  Prediction     │  │   Provider      │                   │ │
│  │  │  Service        │  │   Dispatcher    │                   │ │
│  │  │ - final_pred()  │  │ - Fetch from    │                   │ │
│  │  │                 │  │   Instagram     │                   │ │
│  │  │                 │  │ - Fetch from    │                   │ │
│  │  │                 │  │   Facebook      │                   │ │
│  │  │                 │  │ - Fetch from X  │                   │ │
│  │  └────────┬────────┘  └────────┬────────┘                   │ │
│  │           │                    │                             │ │
│  │           └─────────┬──────────┘                             │ │
│  │                     │                                         │ │
│  │   ┌────────────────▼─────────────────┐                      │ │
│  │   │   Token Security (Crypto)        │                      │ │
│  │   │ - encrypt_token (Fernet)         │                      │ │
│  │   │ - decrypt_token                  │                      │ │
│  │   │ - FERNET_KEY from env            │                      │ │
│  │   └──────────────────────────────────┘                      │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────┘ │
│                             ▲                                    │
│                             │                                    │
│  ┌──────────────────────────┴──────────────────────────────────┐ │
│  │                   Data Access Layer                          │ │
│  │                  (SQLAlchemy ORM)                            │ │
│  │                                                               │ │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐     │ │
│  │  │    User     │  │SocialAccount  │  │SocialActivity  │     │ │
│  │  │  - id       │  │- user_id     │  │- account_id   │     │ │
│  │  │  - email    │  │- provider    │  │- provider_item│     │ │
│  │  │  - password │  │- access_token│  │- activity_type│     │ │
│  │  │             │  │- external_id │  │- content      │     │ │
│  │  │             │  │- last_synced │  │- processed    │     │ │
│  │  └─────────────┘  └──────────────┘  │- timestamp    │     │ │
│  │                                       └────────────────┘     │ │
│  │  ┌──────────────────────────────────────────────────────┐   │ │
│  │  │           EmotionHistory                             │   │ │
│  │  │ - user_id  - emotion   - confidence - severity       │   │ │
│  │  │ - platform (text/social:provider)                    │   │ │
│  │  └──────────────────────────────────────────────────────┘   │ │
│  └───────────────────────────────────────────────────────────┘ │
│                             ▲                                  │
└─────────────────────────────┼──────────────────────────────────┘
                              │
                   ┌──────────▼──────────┐
                   │   PostgreSQL DB    │
                   │  (mental_health_db)│
                   └────────────────────┘
```

---

## Data Flow: Social Content Ingestion

```
1. USER CONNECTS PLATFORM
   ┌──────────────┐
   │ Social Conn  │────────┐
   │ Screen (UI)  │        │
   └──────────────┘        │
                           │
                 ┌─────────▼────────┬──────────┐
                 │   OAuth Flow     │          │
                 │ 1. Get auth URL  │          │
                 │ 2. User login    │          │
                 │ 3. Grant perms   │          │
                 └────────┬─────────┘          │
                          │                    │
                 ┌────────▼──────────┐         │
                 │  OAuth Callback   │         │
                 │ 1. Exchange code  │         │
                 │ 2. Encrypt token  │         │
                 │ 3. Store account  │         │
                 └────────┬──────────┘         │
                          │                    │
            ┌─────────────▼────────────────────▼─────┐
            │     SocialAccount created in DB         │
            │ - provider: instagram/facebook/x        │
            │ - access_token: encrypted               │
            │ - external_id: user's account ID        │
            │ - last_synced: NULL                     │
            └─────────────────────────────────────────┘

2. SYNC ACTIVITIES (Manual or Webhook)
   ┌────────────────────┐
   │ Webhook from       │  OR  ┌──────────────────┐
   │ Provider (FB/IG)   │      │ Manual Sync Call │
   │ - Real-time update │      │ /social/analyze  │
   └────────┬───────────┘      └────────┬─────────┘
            │                           │
            └───────────┬───────────────┘
                        │
            ┌───────────▼───────────┐
            │  Fetch Activities     │
            │  Provider-specific    │
            │  Fetcher (Instagram/  │
            │  Facebook/X API)      │
            │ Returns:              │
            │ - provider_item_id    │
            │ - activity_type       │
            │ - content             │
            │ - metadata            │
            │ - timestamp           │
            └───────────┬───────────┘
                        │
            ┌───────────▼──────────────┐
            │  Deduplication Check     │
            │  SELECT WHERE            │
            │  provider_item_id ==     │
            │  fetched_id              │
            └───────────┬──────────────┘
                        │
                    ┌───┴────┐
                    │         │
            ┌───────▼──┐ ┌────▼────────┐
            │  Exists  │ │ New Item    │
            │  (Skip)  │ │ (Process)   │
            └──────────┘ └────┬────────┘
                              │
                  ┌───────────▼────────────┐
                  │  Store SocialActivity   │
                  │ - account_id            │
                  │ - provider_item_id      │
                  │ - activity_type         │
                  │ - content (text)        │
                  │ - processed: FALSE      │
                  └───────────┬────────────┘
                              │
                  ┌───────────▼────────────┐
                  │ Run Prediction         │
                  │ final_prediction()     │
                  │ Returns:               │
                  │ - emotion              │
                  │ - confidence           │
                  └───────────┬────────────┘
                              │
                  ┌───────────▼────────────┐
                  │  Store EmotionHistory   │
                  │ - user_id               │
                  │ - emotion               │
                  │ - confidence            │
                  │ - platform: social:ig   │
                  │ - text (original post)  │
                  └────────────────────────┘

3. DISPLAY RESULTS
   ┌─────────────────────┐
   │  Home Screen        │
   │ - Show emotions     │
   │ - Aggregated stats  │
   │ - Timeline          │
   └─────────────────────┘
```

---

## Key Design Decisions

### 1. **Token Encryption**

**Decision:** Use Fernet (symmetric encryption) for storing provider tokens in database

**Rationale:**
- Tokens are sensitive credentials
- Fernet provides authenticated encryption
- Key management via environment variable
- Prevents accidental database exposure

**Implementation:**
```python
# In utils/crypto.py
from cryptography.fernet import Fernet

def encrypt_token(token: str, key: str = FERNET_KEY) -> str:
    f = Fernet(key.encode())
    return f.encrypt(token.encode()).decode()

def decrypt_token(encrypted: str, key: str = FERNET_KEY) -> str:
    f = Fernet(key.encode())
    return f.decrypt(encrypted.encode()).decode()
```

### 2. **Deduplication Strategy**

**Decision:** Track unique provider item IDs to prevent reprocessing

**Rationale:**
- Webhooks and manual sync can overlap
- Prevents duplicate emotion entries
- Simple query-based check

**Implementation:**
```python
# In social.py and webhooks.py
provider_item_id = act.get("provider_item_id")  # e.g., "instagram_123456"
existing = db.query(SocialActivity).filter(
    SocialActivity.account_id == acc.id,
    SocialActivity.provider_item_id == provider_item_id
).first()
if existing:
    continue  # Skip duplicate
```

### 3. **Mobile OAuth Flow**

**Decision:** Server-side callback with deep-link redirect

**Pros:**
- User never sees backend in browser
- Single-step authorization from app perspective
- Works with native browser on all platforms

**Flow:**
1. Mobile calls `/social/oauth-url/{provider}`
2. Backend returns provider auth URL with state (encoded JWT + deep-link)
3. User authorizes in browser
4. Provider redirects to `/oauth/{provider}/callback`
5. Backend exchanges code, stores encrypted token
6. Backend redirects to `myapp://oauth-success?platform=...`
7. Mobile receives deep-link, updates UI

### 4. **Webhook Processing**

**Decision:** Async processing with deduplication and prediction

**Rationale:**
- Real-time updates from provider
- Automatic emotion detection
- Non-blocking (future: queue to job processor)

**Security:**
- Signature verification (HMAC-SHA256)
- Token validation via WEBHOOK_VERIFY_TOKEN

### 5. **Rate Limiting & Backoff**

**Decision:** Per-provider exponential backoff with Retry-After support

**Implementation:**
```python
def _get_json_with_backoff(url, params, max_retries=4):
    delay = 1.0
    for attempt in range(max_retries):
        resp = requests.get(url, params=params)
        if resp.status_code == 429:
            wait = int(resp.headers.get("Retry-After", delay))
            time.sleep(wait)
            delay *= 2
            continue
        return resp.json()
```

### 6. **Pagination**

**Decision:** Cursor-based pagination where available, limit-offset as fallback

**Rationale:**
- Efficient for large result sets
- Follows provider API conventions
- Handles rate limits better

---

## Security Considerations

### 1. **Token Storage**
- ✅ Encrypted with Fernet (AES-128)
- ✅ Key stored in environment variable
- ✅ Never logged or exposed in response

### 2. **OAuth Security**
- ✅ State parameter includes timestamp (prevent CSRF)
- ⏳ Should implement PKCE for X/Twitter
- ⏳ Should store state server-side instead of JWT

### 3. **Webhook Security**
- ✅ Signature verification (HMAC)
- ✅ Token validation
- ⏳ Rate limiting not yet implemented

### 4. **Data Privacy**
- ⏳ No data retention policy yet
- ⏳ User consent screens needed
- ⏳ Export/deletion functionality needed

---

## Performance Optimizations

### Current Implementation
- Connection pooling (SQLAlchemy default)
- Query indexing on frequently searched columns
- Activity deduplication prevents redundant processing

### Recommended Future Improvements
1. **Caching**
   - Cache connected accounts list
   - Cache recent emotion history
   - TTL-based invalidation

2. **Background Processing**
   - Move sync to task queue (Celery/RQ)
   - Parallel provider fetching
   - Batch emotion prediction

3. **Database**
   - Partition emotion_history by date
   - Archive old social_activities
   - Query optimization for aggregate stats

---

## Testing Strategy

### Unit Tests
- Provider fetcher logic
- Token encryption/decryption
- Deduplication logic
- Emotion prediction

### Integration Tests
- OAuth flow (mock provider)
- Webhook processing
- Database transactions
- API endpoint validation

### End-to-End Tests
- Mobile app OAuth flow
- Social content sync
- Emotion history display
- Multi-provider scenarios

---

## Deployment Architecture

### Development
```
Local Machine
├── PostgreSQL (local)
├── FastAPI backend (uvicorn)
└── Flutter app (emulator/device)
```

### Production (Recommended)
```
Cloud Platform (e.g., AWS/GCP/Azure)
├── Load Balancer (HTTPS)
├── FastAPI (multiple instances)
│   └── Managed Database (PostgreSQL)
├── Message Queue (for webhooks)
└── CDN (for static assets)
```

---

## Monitoring & Logging

### Current
- Basic logging to console/file
- Error handling with try/catch

### Recommended
- Structured logging (JSON format)
- Metrics collection (Prometheus)
- Distributed tracing (Jaeger)
- Error tracking (Sentry)

---

## API Endpoints Summary

### Authentication
- `POST /register` - User registration
- `POST /login` - User login
- `POST /refresh-token` - Refresh JWT

### Social Management
- `GET /social/connected` - List connected providers
- `GET /social/oauth-url/{provider}` - Get provider auth URL
- `POST /social/connect` - Finalize connection
- `POST /social/sync` - Manual sync
- `DELETE /social/disconnect/{platform}` - Remove connection
- `POST /social/analyze` - Analyze all activities
- `GET /social/sync-status/{platform}` - Sync progress

### OAuth Callbacks
- `GET /oauth/{provider}/authorize` - Generate auth URL
- `GET /oauth/{provider}/callback` - Handle provider callback

### Webhooks
- `GET /webhooks/facebook` - Webhook verification
- `POST /webhooks/facebook` - Webhook payload

### Emotion Tracking
- `POST /predict` - Predict emotion from text
- `GET /emotion-history` - View emotion history
- `GET /profile` - User profile

---

## Future Enhancements

1. **Multi-language Support**
   - Emotion detection in different languages
   - UI localization

2. **Advanced Analytics**
   - Trend analysis
   - Pattern recognition
   - Mood predictions

3. **Recommendation System**
   - Suggest activities based on mood
   - Recommend content
   - Wellness tips

4. **Integration with Health Services**
   - Wearable device support (heart rate, sleep)
   - Medication reminders
   - Therapist communication

5. **Communities & Support**
   - User groups
   - Peer support
   - Share insights (anonymized)

