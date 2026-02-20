# Mental Health App - Deployment & Testing Guide

## Quick Start

### 1. Environment Setup

Create a `.env` file in the `backend/` directory with the following variables:

```bash
# Security
SECRET_KEY=your-super-secret-key-min-32-chars
FERNET_KEY=paste-base64-key-from-generation-script

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/mental_health_db

# Instagram OAuth
INSTAGRAM_CLIENT_ID=your-instagram-app-id
INSTAGRAM_CLIENT_SECRET=your-instagram-app-secret

# Facebook OAuth
FACEBOOK_CLIENT_ID=your-facebook-app-id
FACEBOOK_CLIENT_SECRET=your-facebook-app-secret

# X/Twitter OAuth
X_CLIENT_ID=your-x-app-client-id
X_CLIENT_SECRET=your-x-app-client-secret

# Webhooks
WEBHOOK_VERIFY_TOKEN=your-webhook-verification-token

# Optional
BACKEND_URL=http://localhost:8000
MOBILE_DEEP_LINK_SCHEME=myapp://
```

### 2. Generate FERNET_KEY

```python
from cryptography.fernet import Fernet
key = Fernet.generate_key()
print(key.decode())  # Copy this to FERNET_KEY in .env
```

### 3. Database Setup

```bash
# Install PostgreSQL (if not already installed)
# macOS:
brew install postgresql

# Start PostgreSQL
brew services start postgresql

# Create database
psql -c "CREATE DATABASE mental_health_db;"

# Install Python dependencies
cd backend
pip install -r requirements.txt
```

### 4. Start Backend Server

```bash
cd backend
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

The backend will automatically create all required tables on startup.

### 5. Verify Backend is Running

```bash
curl http://localhost:8000/health
# Expected response: {"status": "healthy"}
```

---

## Provider Setup (One-time)

### Instagram Integration

1. **Create Instagram App:**
   - Go to [Meta App Dashboard](https://developers.facebook.com/apps/)
   - Create a new app (type: Business)
   - Navigate to Settings > Basic and copy App ID and App Secret

2. **Configure OAuth Redirect:**
   - Go to Settings > Basic > Android/Web/iOS
   - For Web: Add `http://localhost:8000/oauth/instagram/callback` as valid redirect
   - For Mobile: Use deep-link `myapp://oauth-callback`

3. **Request Required Permissions:**
   - Instagram Basic Display
   - Instagram Graph API (for media insights, comments)

4. **Get Access Token (for testing):**
   ```bash
   # Use Instagram Graph API Explorer
   # https://developers.facebook.com/tools/explorer
   # Select your app and request scopes: instagram_basic, instagram_manage_comments
   ```

### Facebook Integration

1. **Create Facebook App:**
   - Same app as Instagram can be used
   - Add Facebook login product

2. **Configure OAuth Redirect:**
   - Add `http://localhost:8000/oauth/facebook/callback`

3. **Set Webhook Subscription:**
   - Products > Webhooks > Subscribe to "feed" and "comments"
   - Callback URL: `http://localhost:8000/webhooks/facebook`
   - Verify Token: Use your `WEBHOOK_VERIFY_TOKEN`

### X (Twitter) Integration

1. **Create X OAuth App:**
   - Go to [X Developer Portal](https://developer.twitter.com/en/portal/dashboard)
   - Create new app with OAuth 2.0 settings

2. **Configure OAuth Settings:**
   - Callback URL: `http://localhost:8000/oauth/x/callback`
   - Client ID and Secret in environment

3. **Request Credentials:**
   - Current implementation requires bearer token auth
   - For production, implement PKCE flow

---

## Testing Scenarios

### Test 1: User Registration & Login

```bash
# Register user
curl -X POST http://localhost:8000/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "securepassword123"
  }'

# Response:
# {"user_id": 1, "email": "test@example.com", "access_token": "..."}

# Save the access_token for subsequent requests
```

### Test 2: OAuth Flow (Manual Testing)

```bash
# 1. Get the OAuth URL for Instagram
curl http://localhost:8000/social/oauth-url/instagram \
  -H "Authorization: Bearer <access_token>"

# Response:
# {"url": "https://api.instagram.com/oauth/authorize?client_id=..."}

# 2. Open URL in browser and authorize
# 3. You'll be redirected to myapp://oauth-success?platform=instagram&status=success

# 4. Verify account was created
curl http://localhost:8000/social/connected \
  -H "Authorization: Bearer <access_token>"

# Response:
# ["instagram"]
```

### Test 3: Manual Sync

```bash
# Trigger sync for all connected accounts
curl -X POST http://localhost:8000/social/analyze \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{}'

# Response:
# {"analyzed": 5, "error_count": 0}

# Check activities
sqlite3 backend.db "SELECT * FROM social_activities LIMIT 5;"
```

### Test 4: Webhook Verification

```bash
# Verify webhook endpoint responds to Facebook challenge
curl "http://localhost:8000/webhooks/facebook?hub.mode=subscribe&hub.verify_token=your-token&hub.challenge=test-challenge"

# Expected response: test-challenge (as integer)
```

### Test 5: Emotion Prediction from Social

```bash
# After sync completes, check emotion history
curl http://localhost:8000/emotion-history \
  -H "Authorization: Bearer <access_token>"

# Should contain entries with platform = "social:instagram", etc.
```

---

## Mobile App Testing

### Prerequisites
- Build and run Flutter app on device/emulator
- Ensure app is configured with deep-link scheme `myapp://`

### Test Flow

1. **Login to app**
   - Enter test user credentials

2. **Navigate to Social Connect**
   - Tap "Connect Instagram"

3. **Complete OAuth**
   - App opens browser with provider auth
   - Authorize and grant permissions
   - App receives deep-link callback

4. **Verify Connection**
   - Social Connect screen shows "Connected" status
   - Check backend database for `SocialAccount` record

5. **Trigger Sync**
   - Tap "Sync Now" button (if available)
   - Monitor logs for fetch operations

6. **View Results**
   - Home screen shows emotion insights from social
   - Emotion history includes items from social accounts

---

## Database Inspection

### View Connected Accounts

```sql
SELECT 
  sa.id,
  u.email,
  sa.provider,
  sa.external_id,
  sa.last_synced
FROM social_accounts sa
JOIN users u ON sa.user_id = u.id;
```

### View Synced Activities

```sql
SELECT 
  sa.id,
  acc.provider,
  sa.activity_type,
  sa.content,
  sa.processed,
  sa.timestamp
FROM social_activities sa
JOIN social_accounts acc ON sa.account_id = acc.id
ORDER BY sa.timestamp DESC
LIMIT 20;
```

### View Emotion Predictions from Social

```sql
SELECT 
  eh.id,
  u.email,
  eh.platform,
  eh.emotion,
  eh.confidence,
  eh.created_at
FROM emotion_history eh
JOIN users u ON eh.user_id = u.id
WHERE eh.platform LIKE 'social:%'
ORDER BY eh.created_at DESC
LIMIT 20;
```

### Check for Deduplication

```sql
SELECT 
  provider_item_id,
  COUNT(*) as count
FROM social_activities
GROUP BY provider_item_id
HAVING count > 1;

-- Should return no results (means dedup is working)
```

---

## Troubleshooting

### Common Issues

**Issue: "FERNET_KEY not configured"**
```
Error: Cannot decrypt token
Fix: Generate and set FERNET_KEY in .env
```

**Issue: "Invalid OAuth signature"**
```
Error: Webhook signature verification failed
Fix: Ensure FACEBOOK_CLIENT_SECRET matches app settings
Fix: For testing, disable signature verification (temporarily)
```

**Issue: Tokens stored in plaintext**
```
Symptom: Tokens visible in database
Fix: Ensure crypto.py is imported and decrypt_token is called
Fix: Check that all tokens are encrypted before storage
```

**Issue: Duplicate activities**
```
Symptom: Same activity appears multiple times
Fix: Check that provider_item_id is being set
Fix: Database migration added provider_item_id column
Run: DELETE FROM social_activities WHERE provider_item_id IS NULL;
```

**Issue: Mobile deep-link not working**
```
Symptom: OAuth succeeds but app doesn't receive callback
Fix: Verify deep-link scheme in app.json
Fix: Check mobile deep-link listener is configured
Fix: Test with proper scheme: myapp://oauth-success?platform=instagram
```

---

## Production Deployment Checklist

- [ ] All environment variables set securely
- [ ] Database backed up and migrated
- [ ] FERNET_KEY rotated regularly
- [ ] SSL/TLS enabled for all endpoints
- [ ] CORS origins properly configured
- [ ] Rate limiting configured
- [ ] Monitoring/logging enabled
- [ ] Error handling production-ready
- [ ] Webhook signature verification enabled
- [ ] OAuth PKCE enabled for X/Twitter
- [ ] Data retention policy implemented
- [ ] User consent screens added
- [ ] Privacy policy updated
- [ ] Load testing completed
- [ ] Security audit completed

---

## Performance Monitoring

### Check Backend Health

```bash
curl http://localhost:8000/health
```

### Monitor Sync Performance

```bash
curl http://localhost:8000/social/sync-logs \
  -H "Authorization: Bearer <access_token>"
```

### Database Query Performance

```sql
-- Slow query log
SELECT 
  query,
  total_time,
  calls,
  mean_time
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;
```

---

## Next Steps

1. **Implement Token Refresh**
   - Add refresh token logic to prevent expiration
   - Update scheduler to refresh tokens before sync

2. **Add PKCE Support**
   - Critical for X/Twitter security
   - Generate code_verifier, code_challenge

3. **Secure OAuth State**
   - Move from JWT in state to server-side state storage
   - Generate one-time tokens for each OAuth flow

4. **Implement Data Retention**
   - Auto-delete activities older than 30 days
   - Add user export functionality

5. **Add Monitoring**
   - Track sync success rate by provider
   - Monitor prediction confidence scores
   - Alert on failed syncs

---

## Support

For issues or questions:
- Check logs: `tail -f backend.log`
- Review error messages in sync-logs endpoint
- Verify provider API credentials
- Check network connectivity
- Test with curl before using mobile app

