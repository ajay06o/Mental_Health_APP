# Mental Health App - Quick Reference Card

## 🚀 Getting Started (5 minutes)

### 1. Set Environment Variables
```bash
cd backend
cat > .env << 'EOF'
SECRET_KEY=your-secret-key-min-32-chars
FERNET_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
DATABASE_URL=postgresql://localhost/mental_health_db
INSTAGRAM_CLIENT_ID=your-id
INSTAGRAM_CLIENT_SECRET=your-secret
FACEBOOK_CLIENT_ID=your-id
FACEBOOK_CLIENT_SECRET=your-secret
X_CLIENT_ID=your-id
X_CLIENT_SECRET=your-secret
WEBHOOK_VERIFY_TOKEN=your-token
EOF
```

### 2. Start Database & Backend
```bash
# Terminal 1: Start PostgreSQL
brew services start postgresql  # or your OS equivalent

# Terminal 2: Start backend
cd backend
pip install -r requirements.txt
uvicorn app:app --reload
```

### 3. Verify it Works
```bash
curl http://localhost:8000/health
# Response: {"status": "healthy"}
```

---

## 📱 Key Endpoints

### Authentication
```bash
POST   /register                          # Create account
POST   /login                             # Get JWT token
POST   /refresh-token                     # Refresh JWT
```

### Social Integration
```bash
GET    /social/connected                  # List connected providers
GET    /social/oauth-url/{provider}       # Get auth URL (mobile)
POST   /social/connect                    # Finalize connection
DELETE /social/disconnect/{platform}      # Remove connection
POST   /social/sync                       # Manual sync
POST   /social/analyze                    # Analyze all activities
GET    /social/sync-status/{platform}     # Check progress
```

### Emotion Tracking
```bash
POST   /predict                           # Analyze text & predict emotion
GET    /emotion-history                   # View all predictions
```

---

## 🔑 Environment Variables

### Required
```
SECRET_KEY              # JWT signing key (min 32 chars)
FERNET_KEY             # Token encryption key (base64)
DATABASE_URL           # PostgreSQL connection string
WEBHOOK_VERIFY_TOKEN   # Facebook webhook verification
```

### Provider Credentials (One per provider)
```
INSTAGRAM_CLIENT_ID, INSTAGRAM_CLIENT_SECRET
FACEBOOK_CLIENT_ID, FACEBOOK_CLIENT_SECRET
X_CLIENT_ID, X_CLIENT_SECRET
```

---

## 🗄️ Database

### Create Database
```bash
createdb mental_health_db
```

### Inspect Tables
```bash
# Connected accounts
psql -d mental_health_db -c "SELECT * FROM social_accounts;"

# Synced activities
psql -d mental_health_db -c "SELECT * FROM social_activities ORDER BY timestamp DESC LIMIT 10;"

# Emotion history
psql -d mental_health_db -c "SELECT * FROM emotion_history WHERE platform LIKE 'social:%' LIMIT 10;"
```

---

## 🧪 Testing

### Register User
```bash
curl -X POST http://localhost:8000/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### Get OAuth URL
```bash
curl http://localhost:8000/social/oauth-url/instagram \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

### Manual Sync
```bash
curl -X POST http://localhost:8000/social/analyze \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Predict Emotion
```bash
curl -X POST http://localhost:8000/predict \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"text":"I am feeling happy and excited!"}'
```

---

## 🔒 Security

### Token Encryption
- Method: Fernet (AES-128)
- Key: `FERNET_KEY` environment variable
- Storage: Database (encrypted)

### Webhook Verification
- Method: HMAC-SHA256
- Secret: `FACEBOOK_CLIENT_SECRET`
- Header: `X-Hub-Signature-256`

### API Authentication
- Method: JWT Bearer Token
- Header: `Authorization: Bearer <token>`

---

## 🐛 Troubleshooting

### Backend won't start
```bash
# Check if port 8000 is in use
lsof -i :8000

# Check environment variables
echo $FERNET_KEY  # Should output base64 string
```

### OAuth fails
```bash
# Verify credentials in .env
env | grep CLIENT_ID

# Check callback URL matches provider settings
```

### Activities not syncing
```bash
# Check sync logs
curl http://localhost:8000/social/sync-logs \
  -H "Authorization: Bearer <JWT>"

# Verify tokens are encrypted
psql -d mental_health_db -c "SELECT access_token FROM social_accounts LIMIT 1;" 
# Should show binary data, not plain text
```

### Duplicates appearing
```bash
# Check provider_item_id is populated
psql -d mental_health_db -c \
  "SELECT provider_item_id, COUNT(*) FROM social_activities GROUP BY provider_item_id HAVING COUNT(*) > 1;"
# Should return empty (no duplicates)
```

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `PROJECT_SUMMARY.md` | Executive summary & feature list |
| `IMPLEMENTATION_STATUS.md` | Complete feature checklist |
| `DEPLOYMENT_GUIDE.md` | Testing & deployment instructions |
| `ARCHITECTURE.md` | Design decisions & system overview |
| `RENDER.md` | Original project info |

---

## 🏗️ Architecture Overview

```
Mobile App (Flutter)
    ↓ HTTP/REST (JSON)
FastAPI Backend
    ├── OAuth Routes → Provider APIs
    ├── Social Routes → Fetchers
    ├── Webhook Routes ← Providers
    └── Prediction Routes → AI Model
    ↓
PostgreSQL Database
    ├── users
    ├── social_accounts (encrypted tokens)
    ├── social_activities (synced content)
    └── emotion_history (predictions)
```

---

## 📊 Data Flow

```
1. User connects Instagram account
   ↓
2. Stores encrypted access token
   ↓
3. Manual or automatic sync triggers
   ↓
4. Fetches recent posts/comments from Instagram API
   ↓
5. Checks deduplication (provider_item_id)
   ↓
6. Stores SocialActivity in database
   ↓
7. Runs AI prediction on content
   ↓
8. Stores EmotionHistory entry
   ↓
9. Returns results to mobile app
```

---

## ⚡ Performance

### Expected Response Times
- OAuth flow: 3 seconds
- Manual sync: 5-10 seconds
- Webhook processing: < 2 seconds
- Emotion prediction: < 500ms

### Scalability
- ~1000 users per backend instance
- ~100 items/sec webhook throughput
- Database: < 50ms per query

---

## 🔄 Deduplication Strategy

```python
# When syncing activities:
provider_item_id = f"{provider}_{item_id}"  # e.g., "instagram_12345"

existing = db.query(SocialActivity).filter(
    SocialActivity.account_id == account_id,
    SocialActivity.provider_item_id == provider_item_id
).first()

if existing:
    continue  # Skip duplicate
else:
    create_new_activity()
```

---

## 🎯 Common Tasks

### Monitor Active Syncs
```bash
curl http://localhost:8000/social/sync-status/instagram \
  -H "Authorization: Bearer <JWT>"
```

### Retry Failed Syncs
```bash
curl -X POST http://localhost:8000/social/retry-sync \
  -H "Authorization: Bearer <JWT>"
```

### View Emotion Trends
```bash
psql -d mental_health_db -c \
  "SELECT DATE(created_at), emotion, COUNT(*) 
   FROM emotion_history 
   WHERE user_id = 1 
   GROUP BY DATE(created_at), emotion 
   ORDER BY created_at DESC 
   LIMIT 30;"
```

### Disconnect Platform
```bash
curl -X DELETE http://localhost:8000/social/disconnect/instagram \
  -H "Authorization: Bearer <JWT>"
```

### List All Connections
```bash
curl http://localhost:8000/social/connected \
  -H "Authorization: Bearer <JWT>"
```

---

## 🚨 Status Checks

### Is Backend Running?
```bash
curl http://localhost:8000/health
```

### Is Database Connected?
```bash
curl http://localhost:8000/  # Check root endpoint
```

### Are Providers Reachable?
```bash
# Check sync status
curl http://localhost:8000/social/sync-status/instagram \
  -H "Authorization: Bearer <JWT>"
```

---

## 📞 Support

### Logs Location
```bash
# Backend logs
tail -f backend/app.log

# System logs
journalctl -u mental-health-app -f
```

### Common Error Codes
```
400 - Missing required fields
401 - Invalid or expired token
403 - Invalid webhook signature
404 - Resource not found
429 - Rate limited by provider
500 - Internal server error (check logs)
```

---

## 🎓 Learning Resources

### Key Files to Review
1. `backend/routes/social.py` - Social management logic
2. `backend/providers/instagram_api.py` - Example fetcher
3. `backend/models.py` - Database schema
4. `ARCHITECTURE.md` - Design patterns

### External Resources
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy Docs](https://docs.sqlalchemy.org/)
- [Instagram Graph API](https://developers.facebook.com/docs/instagram-api)
- [Facebook Graph API](https://developers.facebook.com/docs/facebook-api)
- [X API Documentation](https://developer.twitter.com/en/docs)

---

## ✅ Pre-Launch Checklist

- [ ] All environment variables set
- [ ] PostgreSQL database created
- [ ] Provider apps configured with OAuth callbacks
- [ ] Backend starts without errors
- [ ] Health check endpoint responds
- [ ] Can register and login
- [ ] Can connect one provider account
- [ ] Manual sync fetches activities
- [ ] Emotion predictions appear in database
- [ ] Mobile app receives webhook deep-link
- [ ] Deduplication prevents duplicates

---

## 🎯 Next Steps

1. **Configure Providers** (30 min)
   - Create apps in provider dashboards
   - Set OAuth redirect URLs
   - Get client IDs and secrets

2. **Run End-to-End Test** (30 min)
   - Register user account
   - Connect one social account
   - Trigger manual sync
   - Verify emotion history

3. **Load Testing** (1 hour)
   - Test with multiple accounts
   - Test with webhook overload
   - Monitor performance

4. **Security Review** (1 hour)
   - Verify token encryption works
   - Verify webhook signatures verify
   - Check for SQL injection risks

5. **Production Deployment**
   - Set up monitoring
   - Configure backups
   - Enable HTTPS
   - Scale database

