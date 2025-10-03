# Secret Management Guide for Firebase Cloud Functions

## Overview
This guide documents how to properly configure and manage API keys and secrets for the InfiniteStories Firebase backend.

## Required Secrets

### OpenAI API Key
- **Purpose**: Powers all AI features in the application
- **Models Used**:
  - `gpt-4o`: Story generation, content filtering, scene extraction
  - `gpt-4o-mini-tts`: Text-to-speech with voice instructions
  - `dall-e-3`: Avatar and scene illustration generation
- **Required Permissions**: Chat completions, images, audio/speech
- **Cost Tracking**: Monitor usage through OpenAI dashboard

### Firebase Service Account (Local Development Only)
- **Purpose**: Admin SDK operations during local development
- **Not needed in production**: Firebase provides automatic credentials
- **Generation**: Firebase Console > Project Settings > Service Accounts

## Local Development Setup

### Step 1: Create Environment File
```bash
cd functions
cp .env.example .env
```

### Step 2: Add Your OpenAI API Key
Edit `.env` and replace placeholder with your actual key:
```
OPENAI_API_KEY=sk-your-actual-api-key-here
```

### Step 3: Install Dependencies
```bash
npm install
```

### Step 4: Load Environment Variables
The functions will automatically load from `.env` during local development using `dotenv`.

### Step 5: Test with Emulator
```bash
# Start Firebase emulators
firebase emulators:start

# Your functions now have access to secrets
```

## Production Deployment

### Using Firebase Functions Configuration

#### Set Secrets
```bash
# Set OpenAI API key
firebase functions:config:set openai.key="sk-your-production-key"

# Set other configuration
firebase functions:config:set \
  storage.story_assets="story-assets" \
  storage.hero_avatars="hero-avatars" \
  storage.story_audio="story-audio" \
  storage.story_illustrations="story-illustrations"

# Set rate limits
firebase functions:config:set \
  ratelimit.story_generation="10" \
  ratelimit.audio_synthesis="15" \
  ratelimit.avatar_generation="8" \
  ratelimit.illustration_generation="25" \
  ratelimit.window_seconds="3600"
```

#### View Configuration
```bash
# View all configuration
firebase functions:config:get

# View specific configuration
firebase functions:config:get openai
```

#### Access in Code
```typescript
import * as functions from 'firebase-functions';

// Access configuration in production
const config = functions.config();
const openaiKey = config.openai?.key || process.env.OPENAI_API_KEY;
```

### Using Firebase Secret Manager (Recommended for Sensitive Data)

#### Create Secret
```bash
# Create secret in Secret Manager
firebase functions:secrets:set OPENAI_API_KEY

# You'll be prompted to enter the secret value
```

#### List Secrets
```bash
firebase functions:secrets:access OPENAI_API_KEY
```

#### Use in Functions
```typescript
import * as functions from 'firebase-functions';

export const myFunction = functions
  .runWith({
    secrets: ['OPENAI_API_KEY']
  })
  .https.onRequest(async (req, res) => {
    const apiKey = process.env.OPENAI_API_KEY;
    // Use the API key
  });
```

#### Deploy with Secrets
```bash
# Deploy functions with secret access
firebase deploy --only functions
```

## Secret Rotation Procedures

### Quarterly Rotation Schedule
1. **Generate new API key** from provider dashboard
2. **Update staging environment** first
3. **Test thoroughly** with new key
4. **Update production** during low-traffic period
5. **Revoke old key** after confirming stability

### Emergency Rotation (Compromised Key)
1. **Immediately revoke** compromised key
2. **Generate new key** from provider
3. **Deploy to production** immediately:
   ```bash
   firebase functions:config:set openai.key="new-key"
   firebase deploy --only functions
   ```
4. **Monitor logs** for any errors
5. **Document incident** for security audit

## Environment-Specific Configuration

### Development
```javascript
// .env file for local development
OPENAI_API_KEY=sk-dev-key
LOG_LEVEL=debug
USE_EMULATORS=true
```

### Staging
```bash
# Set staging configuration
firebase functions:config:set \
  env.name="staging" \
  openai.key="sk-staging-key" \
  logging.level="info"
```

### Production
```bash
# Set production configuration
firebase functions:config:set \
  env.name="production" \
  openai.key="sk-prod-key" \
  logging.level="warn"
```

## Security Best Practices

### DO's
- ✅ Use Firebase Secret Manager for sensitive data
- ✅ Rotate API keys quarterly
- ✅ Use different keys for dev/staging/prod
- ✅ Monitor usage and costs regularly
- ✅ Set up alerts for unusual activity
- ✅ Use least-privilege principle for API keys
- ✅ Document all secrets and their purposes
- ✅ Use environment-specific configuration

### DON'Ts
- ❌ Never commit secrets to version control
- ❌ Never log API keys or secrets
- ❌ Never expose secrets in client-side code
- ❌ Never share API keys via email or chat
- ❌ Never use production keys in development
- ❌ Never hardcode secrets in source code
- ❌ Never store secrets in plain text files

## Monitoring and Alerts

### Cost Monitoring
```typescript
// Track API usage and costs
async function trackAPIUsage(
  model: string,
  tokens: number,
  cost: number
) {
  await firestore.collection('api_usage').add({
    model,
    tokens,
    cost,
    timestamp: FieldValue.serverTimestamp()
  });
}
```

### Set Up Alerts
1. **Budget Alerts**: Firebase Console > Billing > Budgets & alerts
2. **Function Errors**: Firebase Console > Functions > Logs
3. **API Rate Limits**: Monitor 429 errors in logs
4. **Cost Anomalies**: Daily cost tracking dashboard

## Troubleshooting

### Secret Not Loading
```bash
# Check if secret is set
firebase functions:config:get openai

# Redeploy functions
firebase deploy --only functions

# Check function logs
firebase functions:log
```

### Permission Denied
```bash
# Grant Secret Manager access
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:PROJECT_ID@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Local Development Issues
```javascript
// Ensure dotenv is loaded early
import * as dotenv from 'dotenv';
dotenv.config(); // Must be first import

// Then import other modules
import * as functions from 'firebase-functions';
```

## Secret Configuration Structure

### Complete Configuration Object
```javascript
{
  "openai": {
    "key": "sk-...",
    "base_url": "https://api.openai.com/v1"
  },
  "storage": {
    "story_assets": "story-assets",
    "hero_avatars": "hero-avatars",
    "story_audio": "story-audio",
    "story_illustrations": "story-illustrations"
  },
  "ratelimit": {
    "story_generation": "10",
    "audio_synthesis": "15",
    "avatar_generation": "8",
    "illustration_generation": "25",
    "window_seconds": "3600"
  },
  "cache": {
    "ttl_story": "86400",
    "ttl_audio": "604800",
    "ttl_avatar": "604800",
    "ttl_illustration": "604800"
  },
  "content": {
    "filter_enabled": "true",
    "min_age": "3",
    "enforce_companionship": "true"
  },
  "monitoring": {
    "budget_usd": "1000",
    "alert_threshold": "80"
  }
}
```

## Migration from Supabase

### Current Supabase Secrets (Reference)
The legacy Supabase backend used these environment variables:
- `OPENAI_API_KEY`: Same key can be reused
- `SUPABASE_URL`: Not needed in Firebase
- `SUPABASE_ANON_KEY`: Not needed in Firebase
- `SUPABASE_SERVICE_ROLE_KEY`: Not needed in Firebase

### Firebase Equivalents
- OpenAI API Key: Same, configured via Secret Manager
- Database: Firestore (automatic authentication)
- Storage: Firebase Storage (automatic authentication)
- Auth: Firebase Auth (automatic authentication)

## CI/CD Integration

### GitHub Actions
```yaml
- name: Deploy to Firebase
  env:
    FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
  run: |
    firebase functions:config:set openai.key="${{ secrets.OPENAI_API_KEY }}"
    firebase deploy --only functions
```

### Environment Variables in CI
Set these in GitHub Secrets:
- `FIREBASE_TOKEN`: For deployment authentication
- `OPENAI_API_KEY`: Production API key
- `FIREBASE_PROJECT_ID`: Target project

## Compliance and Audit

### Secret Access Logging
```typescript
// Log secret access for audit
function logSecretAccess(secretName: string, userId: string) {
  console.log(JSON.stringify({
    event: 'secret_access',
    secret: secretName,
    user: userId,
    timestamp: new Date().toISOString(),
    // Never log the actual secret value
  }));
}
```

### Regular Audits
- Monthly: Review secret access logs
- Quarterly: Rotate all API keys
- Annually: Security assessment of secret management

## Support and Resources

### Documentation Links
- [Firebase Functions Configuration](https://firebase.google.com/docs/functions/config-env)
- [Firebase Secret Manager](https://firebase.google.com/docs/functions/config-env#secret-manager)
- [OpenAI API Keys](https://platform.openai.com/api-keys)

### Emergency Contacts
- Firebase Support: Via Firebase Console
- Security Incidents: Immediate key rotation required
- Cost Anomalies: Check OpenAI dashboard first