# Supabase Backend Deployment Guide

## Prerequisites

1. **Supabase CLI** installed and configured
2. **OpenAI API Key** with access to GPT-4o and GPT-Image-1
3. **Supabase Project** created at https://app.supabase.com

## Local Development Setup

### 1. Environment Configuration

```bash
# Copy environment template
cp .env.example .env.local

# Edit .env.local and add your OpenAI API key
# OPENAI_API_KEY=sk-your-openai-api-key-here
```

### 2. Start Local Supabase

```bash
# Start Supabase services
npx supabase start

# This will output local credentials:
# API URL: http://127.0.0.1:54321
# Anon Key: your-anon-key
# Service Role Key: your-service-role-key
```

### 3. Apply Database Migrations

```bash
# Reset database and apply all migrations
npx supabase db reset

# Or apply specific migration
npx supabase migration up
```

### 4. Set Up Edge Function Secrets

```bash
# Set OpenAI API key for local functions
npx supabase secrets set OPENAI_API_KEY=sk-your-openai-api-key-here --env-file .env.local
```

### 5. Deploy Edge Functions Locally

```bash
# Serve all functions locally
npx supabase functions serve --env-file .env.local

# Or serve specific function
npx supabase functions serve story-generation --env-file .env.local
```

## Production Deployment

### 1. Link to Production Project

```bash
# Link to your Supabase project
npx supabase link --project-ref your-project-ref
```

### 2. Set Production Secrets

```bash
# Set OpenAI API key in production
npx supabase secrets set OPENAI_API_KEY=sk-your-openai-api-key-here
```

### 3. Push Database Schema

```bash
# Push all migrations to production
npx supabase db push

# Verify migration status
npx supabase migration list
```

### 4. Deploy Edge Functions

```bash
# Deploy all functions
npx supabase functions deploy

# Or deploy specific functions
npx supabase functions deploy story-generation
npx supabase functions deploy audio-synthesis
npx supabase functions deploy avatar-generation
npx supabase functions deploy scene-illustration
```

### 5. Verify Deployment

```bash
# Check function status
npx supabase functions list

# View function logs
npx supabase functions logs story-generation
```

## Function Rename Fix (IMPORTANT)

The iOS client expects `scene-illustrations` (plural) but the function is named `scene-illustration` (singular). To fix:

```bash
# Option 1: Rename the function directory
mv supabase/functions/scene-illustration supabase/functions/scene-illustrations

# Then redeploy
npx supabase functions deploy scene-illustrations

# Option 2: Create an alias (if supported by your setup)
# Or update the iOS client to use 'scene-illustration'
```

## Testing Endpoints

### Test Story Generation

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/story-generation \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "hero-uuid",
    "event": {
      "type": "built_in",
      "data": {
        "event": "magical_forest_adventure"
      }
    },
    "target_duration": 180,
    "language": "en"
  }'
```

### Test Audio Synthesis

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/audio-synthesis \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "story-uuid",
    "text": "Once upon a time...",
    "voice": "coral",
    "language": "en"
  }'
```

### Test Avatar Generation

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/avatar-generation \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "hero-uuid",
    "prompt": "A friendly dragon with green scales",
    "size": "1024x1024",
    "quality": "high"
  }'
```

### Test Scene Illustrations

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-illustrations \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "story-uuid",
    "hero_id": "hero-uuid",
    "scenes": [
      {
        "scene_number": 1,
        "text_segment": "The hero enters the forest",
        "illustration_prompt": "Hero walking into magical forest",
        "timestamp_seconds": 0
      }
    ]
  }'
```

## Monitoring

### View Function Logs

```bash
# Real-time logs
npx supabase functions logs story-generation --tail

# Historical logs
npx supabase functions logs audio-synthesis --limit 100
```

### Check Database Usage

```sql
-- Check API usage
SELECT
  function_name,
  COUNT(*) as calls,
  AVG(response_time_ms) as avg_time,
  SUM(CASE WHEN status = 'error' THEN 1 ELSE 0 END) as errors
FROM api_usage
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY function_name;

-- Check cache effectiveness
SELECT
  COUNT(*) as total,
  SUM(CASE WHEN cached THEN 1 ELSE 0 END) as cache_hits,
  ROUND(100.0 * SUM(CASE WHEN cached THEN 1 ELSE 0 END) / COUNT(*), 2) as hit_rate
FROM cache_entries
WHERE created_at > NOW() - INTERVAL '24 hours';
```

## Troubleshooting

### Function Not Found

If iOS app gets 404 for functions:
1. Verify function is deployed: `npx supabase functions list`
2. Check function name matches exactly
3. Ensure authentication headers are correct

### OpenAI API Errors

If OpenAI calls fail:
1. Verify API key is set: `npx supabase secrets list`
2. Check API key has correct permissions
3. Monitor rate limits in OpenAI dashboard

### Storage Upload Failures

If file uploads fail:
1. Verify buckets exist: `npx supabase storage ls`
2. Check RLS policies are correct
3. Ensure file size limits are appropriate

## Rollback Procedures

### Rollback Function

```bash
# Deploy previous version
git checkout previous-commit-hash
npx supabase functions deploy function-name
```

### Rollback Database

```bash
# Revert last migration
npx supabase migration down

# Or reset to specific migration
npx supabase db reset --to-migration 20250927230845
```