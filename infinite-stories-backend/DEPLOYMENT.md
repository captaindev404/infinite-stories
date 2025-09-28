# Infinite Stories Backend Deployment Guide

Comprehensive deployment guide for the InfiniteStories Supabase backend. This document covers local development, staging, and production deployment with best practices for security, monitoring, and maintenance.

## Prerequisites

### Required Tools
- **[Supabase CLI](https://supabase.com/docs/guides/cli)** (v1.100.0 or higher)
- **[Node.js](https://nodejs.org/)** (v18.0.0 or higher)
- **[Deno](https://deno.land/)** (v1.37.0 or higher)
- **[Docker Desktop](https://www.docker.com/products/docker-desktop)** (for local development)
- **Git** (for version control)

### Required Accounts
- **Supabase Account** with project created
- **OpenAI Account** with API access to:
  - GPT-4o (text generation)
  - TTS-1 / TTS-1-HD (audio synthesis)
  - DALL-E 3 (image generation)

### System Requirements
- **Memory**: 8GB RAM minimum (16GB recommended)
- **Storage**: 10GB free space
- **Network**: Stable internet connection
- **OS**: macOS, Linux, or Windows with WSL2

## Quick Start

### 1. Environment Setup

```bash
# Copy environment template
cp .env.example .env.local

# Add your OpenAI API key
echo "OPENAI_API_KEY=sk-your-actual-openai-api-key" >> .env.local

# Start Supabase locally
npx supabase start
```

### 2. Deploy to Production

```bash
# Link to your Supabase project
npx supabase link --project-ref your-project-ref

# Set OpenAI API key
npx supabase secrets set OPENAI_API_KEY=sk-your-actual-openai-api-key

# Deploy database schema
npx supabase db push

# Deploy all Edge Functions
npx supabase functions deploy
```

## Configuration

### Required Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `OPENAI_API_KEY` | OpenAI API key with gpt-4o access | ✅ |

### Supabase Configuration (Auto-set)

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anonymous key |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key |

### Optional Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_AI_CONTENT_FILTERING` | true | Use AI for content filtering |
| `DEFAULT_VOICE` | coral | Default TTS voice |
| `LOG_LEVEL` | info | Logging level |
| `DEBUG_MODE` | false | Enable debug logging |

## AI Models Configuration

### Text Generation
- **Primary Model**: `gpt-4o`
- **Fallback Model**: `gpt-4o-mini`
- **Parameters**: Temperature 0.7-0.9, Max tokens 2000-4000
- **Use Cases**: Story generation, scene extraction, content analysis

### Text-to-Speech
- **Models**: `tts-1` (faster) / `tts-1-hd` (higher quality)
- **Voices Available**:
  - `coral` - Warm, nurturing (default)
  - `nova` - Cheerful, engaging
  - `fable` - Wise, grandfather-like
  - `alloy` - Clear, neutral
  - `echo` - Soft, dreamy
  - `onyx` - Deep, reassuring
  - `shimmer` - Bright, melodic

### Image Generation
- **Model**: `dall-e-3`
- **Sizes**: 1024x1024 (square), 1024x1792 (portrait), 1792x1024 (landscape)
- **Quality**: Standard or HD
- **Style**: Natural or Vivid

## Function Endpoints

Once deployed, your functions will be available at:

```
https://your-project-ref.supabase.co/functions/v1/story-generation
https://your-project-ref.supabase.co/functions/v1/audio-synthesis
https://your-project-ref.supabase.co/functions/v1/avatar-generation
https://your-project-ref.supabase.co/functions/v1/scene-illustration
```

## Testing Deployment

### Run Validation Tests

```bash
# Test gpt-4o integration
cd supabase/functions/test
deno test --allow-all gpt5-mini-validation.ts
```

### Test Story Generation

```bash
curl -X POST https://your-project-ref.supabase.co/functions/v1/story-generation \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "uuid-of-hero",
    "event": {
      "type": "built_in",
      "data": { "event": "magical_forest_adventure" }
    },
    "target_duration": 300,
    "language": "en"
  }'
```

## Storage Configuration

The functions automatically create these storage buckets:

- `story-assets` - General story assets
- `hero-avatars` - Hero avatar images
- `story-audio` - Generated audio files
- `story-illustrations` - Scene illustration images

## Monitoring

### View Function Logs

```bash
npx supabase functions logs story-generation
npx supabase functions logs audio-synthesis
npx supabase functions logs avatar-generation
npx supabase functions logs scene-illustration
```

### Monitor Usage

Check the `api_usage` table for usage tracking:

```sql
SELECT
  function_name,
  COUNT(*) as requests,
  SUM(cost_estimate) as total_cost,
  AVG(response_time_ms) as avg_response_time
FROM api_usage
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY function_name;
```

### Monitor gpt-4o Performance

```sql
SELECT
  function_name,
  AVG(response_time_ms) as avg_response_time,
  SUM(tokens_used) as total_tokens,
  SUM(cost_estimate) as total_cost
FROM api_usage
WHERE created_at > NOW() - INTERVAL '1 hour'
  AND status = 'success'
GROUP BY function_name;
```

## Rate Limiting

Rate limits are enforced per user:

- Story Generation: 10 requests/hour
- Audio Synthesis: 15 requests/hour
- Avatar Generation: 8 requests/hour
- Scene Illustration: 25 requests/hour

## Content Safety

All content goes through comprehensive safety filtering:

1. **Rule-based filtering**: Removes unsafe terms and phrases
2. **AI-powered filtering**: gpt-4o analyzes content for child safety
3. **Image prompt sanitization**: Ensures child-appropriate images
4. **Companionship enforcement**: Children never shown alone

## Deployment Environments

### Local Development

#### Initial Setup
```bash
# Clone repository
git clone https://github.com/your-org/infinite-stories.git
cd infinite-stories/infinite-stories-backend

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env.local

# Start Supabase locally
npx supabase start

# Apply migrations
npx supabase db reset

# Serve functions locally
npx supabase functions serve --env-file .env.local
```

#### Local Testing
```bash
# Test story generation
curl -X POST http://localhost:54321/functions/v1/story-generation \
  -H "Authorization: Bearer $(npx supabase status --output json | jq -r .auth.anon_key)" \
  -H "Content-Type: application/json" \
  -d @test/fixtures/story-request.json

# Run integration tests
deno test --allow-all supabase/functions/test/
```

### Staging Environment

#### Setup Staging Project
```bash
# Create staging project on Supabase
npx supabase projects create infinite-stories-staging --region us-east-1

# Link to staging
npx supabase link --project-ref your-staging-ref

# Set staging secrets
npx supabase secrets set OPENAI_API_KEY=$OPENAI_API_KEY --project-ref staging
npx supabase secrets set ENVIRONMENT=staging --project-ref staging

# Deploy to staging
npx supabase db push --project-ref staging
npx supabase functions deploy --project-ref staging
```

### Production Deployment

#### Pre-Deployment Checklist
- [ ] All tests passing
- [ ] Security audit completed
- [ ] Performance benchmarks met
- [ ] Backup strategy in place
- [ ] Monitoring configured
- [ ] Rate limits appropriate
- [ ] Content filters tested
- [ ] Documentation updated

#### Production Deployment Steps

```bash
# 1. Create production project
npx supabase projects create infinite-stories-prod --region us-east-1

# 2. Link to production
npx supabase link --project-ref your-prod-ref

# 3. Set production secrets
npx supabase secrets set OPENAI_API_KEY=$OPENAI_API_KEY_PROD
npx supabase secrets set ENVIRONMENT=production
npx supabase secrets set LOG_LEVEL=warn
npx supabase secrets set ENABLE_AI_CONTENT_FILTERING=true

# 4. Deploy database schema
npx supabase db push --project-ref prod

# 5. Deploy Edge Functions
npx supabase functions deploy --project-ref prod

# 6. Configure storage buckets
npx supabase storage create story-assets --public --project-ref prod
npx supabase storage create hero-avatars --public --project-ref prod
npx supabase storage create story-audio --public --project-ref prod
npx supabase storage create story-illustrations --public --project-ref prod

# 7. Apply RLS policies
npx supabase db push --include-policies --project-ref prod

# 8. Verify deployment
curl https://your-prod-ref.supabase.co/functions/v1/health
```

## Security Configuration

### Environment Variables

```bash
# Production secrets (never commit these)
OPENAI_API_KEY=sk-proj-...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SENTRY_DSN=https://...
SLACK_WEBHOOK_URL=https://...

# Configuration variables
ENVIRONMENT=production
LOG_LEVEL=warn
DEBUG_MODE=false
ENABLE_AI_CONTENT_FILTERING=true
DEFAULT_VOICE=coral
MAX_STORY_LENGTH=5000
MAX_SCENE_COUNT=6
CACHE_TTL=86400
RATE_LIMIT_WINDOW=3600
```

### API Key Rotation

```bash
# Rotate OpenAI API key
npx supabase secrets set OPENAI_API_KEY=$NEW_OPENAI_KEY
npx supabase functions deploy --no-verify-jwt

# Verify new key works
curl -X POST https://your-project.supabase.co/functions/v1/health \
  -H "X-Health-Check: true"
```

### Network Security

```typescript
// CORS configuration
const corsHeaders = {
  'Access-Control-Allow-Origin': process.env.ALLOWED_ORIGINS || '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

// Rate limiting per IP
const rateLimiter = new RateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
});
```

## Monitoring and Maintenance

### Health Checks

```bash
# Create health check endpoint
cat > supabase/functions/health/index.ts << 'EOF'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (req) => {
  const checks = {
    database: await checkDatabase(),
    storage: await checkStorage(),
    openai: await checkOpenAI(),
  };

  const allHealthy = Object.values(checks).every(c => c.status === 'healthy');

  return new Response(
    JSON.stringify({
      status: allHealthy ? 'healthy' : 'degraded',
      checks,
      timestamp: new Date().toISOString(),
    }),
    {
      status: allHealthy ? 200 : 503,
      headers: { 'Content-Type': 'application/json' },
    }
  );
});
EOF

# Deploy health check
npx supabase functions deploy health
```

### Monitoring Setup

```yaml
# monitoring-config.yaml
monitors:
  - name: API Health
    type: http
    url: https://your-project.supabase.co/functions/v1/health
    interval: 60s
    timeout: 10s

  - name: Story Generation
    type: synthetic
    script: |
      const response = await fetch('/functions/v1/story-generation', {
        method: 'POST',
        headers: { 'Authorization': 'Bearer ${MONITOR_TOKEN}' },
        body: JSON.stringify(testPayload),
      });
      assert(response.status === 200);
    interval: 5m

  - name: Database Performance
    type: query
    query: SELECT COUNT(*) FROM stories WHERE created_at > NOW() - INTERVAL '1 hour'
    threshold: 100ms
    interval: 1m

alerts:
  - condition: monitor.status == 'down'
    channels: [slack, email]
  - condition: error_rate > 0.05
    channels: [pagerduty]
  - condition: response_time_p95 > 5000
    channels: [slack]
```

### Backup Strategy

```bash
# Automated daily backups
crontab -e
# Add: 0 2 * * * /usr/local/bin/backup-supabase.sh

# backup-supabase.sh
#!/bin/bash
DATE=$(date +%Y%m%d)
PROJECT_REF="your-project-ref"

# Database backup
pg_dump $DATABASE_URL > backups/db-$DATE.sql
gzip backups/db-$DATE.sql

# Storage backup
aws s3 sync s3://your-bucket s3://backup-bucket/storage-$DATE/

# Upload to secure location
aws s3 cp backups/db-$DATE.sql.gz s3://backup-bucket/database/

# Clean old backups (keep 30 days)
find backups/ -name "*.sql.gz" -mtime +30 -delete
```

### Performance Optimization

```sql
-- Create indexes for common queries
CREATE INDEX idx_stories_user_created ON stories(user_id, created_at DESC);
CREATE INDEX idx_api_usage_function_created ON api_usage(function_name, created_at DESC);
CREATE INDEX idx_cache_key_expires ON cache_entries(key, expires_at);

-- Vacuum and analyze tables regularly
VACUUM ANALYZE stories;
VACUUM ANALYZE api_usage;

-- Monitor slow queries
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Maintenance Tasks

```bash
# Weekly maintenance script
#!/bin/bash

# Clean expired cache entries
psql $DATABASE_URL -c "DELETE FROM cache_entries WHERE expires_at < NOW();"

# Clean old rate limit records
psql $DATABASE_URL -c "DELETE FROM rate_limits WHERE window_end < NOW() - INTERVAL '7 days';"

# Optimize database
psql $DATABASE_URL -c "VACUUM ANALYZE;"

# Archive old logs
find logs/ -name "*.log" -mtime +30 -exec gzip {} \;
mv logs/*.gz archive/

# Generate usage report
psql $DATABASE_URL -f reports/weekly-usage.sql > reports/usage-$(date +%Y%W).txt
```

## Troubleshooting

### Common Issues and Solutions

#### OpenAI API Issues
```bash
# Test OpenAI connectivity
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# Check rate limits
curl -i https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"test"}]}'
```

#### Database Connection Issues
```sql
-- Check active connections
SELECT count(*) FROM pg_stat_activity;

-- Kill idle connections
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
  AND state_change < NOW() - INTERVAL '10 minutes';
```

#### Storage Issues
```bash
# Check bucket sizes
npx supabase storage list --project-ref prod

# Clean orphaned files
psql $DATABASE_URL -c "
  SELECT s.path FROM storage.objects s
  LEFT JOIN story_illustrations si ON s.path = si.image_url
  WHERE si.id IS NULL;
"
```

#### Performance Debugging
```typescript
// Add performance timing
const startTime = Date.now();
try {
  const result = await processRequest();
  console.log(`Processing time: ${Date.now() - startTime}ms`);
  return result;
} catch (error) {
  console.error(`Failed after ${Date.now() - startTime}ms:`, error);
  throw error;
}
```

## Production Readiness Checklist

### Pre-Launch Requirements

#### Security
- [ ] All secrets stored in Supabase Secrets (never in code)
- [ ] RLS policies enabled on all tables
- [ ] CORS configured for allowed origins only
- [ ] Rate limiting tested and configured
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention verified
- [ ] XSS protection implemented

#### Performance
- [ ] Database indexes created
- [ ] Caching strategy implemented
- [ ] CDN configured for static assets
- [ ] Connection pooling enabled
- [ ] Query optimization completed
- [ ] Load testing passed (1000+ concurrent users)

#### Reliability
- [ ] Error handling comprehensive
- [ ] Retry logic implemented
- [ ] Fallback models configured
- [ ] Circuit breakers in place
- [ ] Graceful degradation tested
- [ ] Backup strategy automated

#### Monitoring
- [ ] Health checks configured
- [ ] Metrics dashboard created
- [ ] Log aggregation set up
- [ ] Alert rules defined
- [ ] On-call rotation established
- [ ] Incident response plan documented

#### Content Safety
- [ ] Rule-based filtering tested
- [ ] AI content analysis enabled
- [ ] Image prompt sanitization verified
- [ ] Companionship enforcement working
- [ ] Age-appropriate content validated
- [ ] Violation logging active

#### Documentation
- [ ] API documentation complete
- [ ] Deployment guide updated
- [ ] Runbook created
- [ ] Architecture diagrams current
- [ ] Change log maintained
- [ ] Team trained on procedures

### Launch Day Checklist

```bash
# 1. Final health check
curl https://prod.supabase.co/functions/v1/health

# 2. Verify all functions
for func in story-generation audio-synthesis avatar-generation scene-illustration; do
  echo "Testing $func..."
  curl -X POST https://prod.supabase.co/functions/v1/$func \
    -H "Authorization: Bearer $TEST_TOKEN" \
    -H "X-Test-Mode: true"
done

# 3. Monitor initial traffic
watch -n 5 'psql $DATABASE_URL -c "SELECT function_name, COUNT(*), AVG(response_time_ms) FROM api_usage WHERE created_at > NOW() - INTERVAL '"'"'5 minutes'"'"' GROUP BY function_name;"'

# 4. Check error rates
psql $DATABASE_URL -c "SELECT function_name, COUNT(*) as errors FROM api_usage WHERE status = 'error' AND created_at > NOW() - INTERVAL '1 hour' GROUP BY function_name;"

# 5. Verify caching
psql $DATABASE_URL -c "SELECT COUNT(*) as cache_hits FROM api_usage WHERE cached = true AND created_at > NOW() - INTERVAL '1 hour';"
```

### Post-Launch Monitoring

```bash
# First 24 hours
- Monitor error rates every hour
- Check response times every 30 minutes
- Review content filtering logs
- Verify cost tracking
- Check rate limit effectiveness

# First week
- Daily usage reports
- Performance trend analysis
- User feedback review
- Cost optimization review
- Security audit

# Ongoing
- Weekly performance reviews
- Monthly cost analysis
- Quarterly security audits
- Regular dependency updates
- Continuous optimization
```

## Disaster Recovery

### Incident Response Plan

```yaml
incident_levels:
  P0: # Complete outage
    response_time: 5 minutes
    escalation: [oncall-primary, oncall-secondary, engineering-lead, cto]

  P1: # Major feature broken
    response_time: 15 minutes
    escalation: [oncall-primary, engineering-lead]

  P2: # Degraded performance
    response_time: 1 hour
    escalation: [oncall-primary]

  P3: # Minor issues
    response_time: 4 hours
    escalation: [on-duty-engineer]

runbooks:
  api_outage:
    - Check Supabase status page
    - Verify OpenAI API status
    - Check database connectivity
    - Review recent deployments
    - Initiate rollback if needed

  high_error_rate:
    - Check error logs
    - Identify error patterns
    - Review recent changes
    - Scale resources if needed
    - Apply hotfix if required
```

### Rollback Procedures

```bash
# Edge Functions rollback
git checkout previous-release-tag
npx supabase functions deploy --project-ref prod

# Database rollback
psql $DATABASE_URL < backups/pre-deployment-backup.sql

# Quick disable problematic function
npx supabase functions delete problematic-function --project-ref prod
```

## Cost Optimization

### OpenAI API Cost Management

```typescript
// Implement token limits
const MAX_TOKENS = {
  story_generation: 2000,
  scene_extraction: 1000,
  content_filtering: 500,
};

// Use appropriate models for each task
const MODEL_SELECTION = {
  complex_tasks: 'gpt-4o',
  simple_tasks: 'gpt-4o-mini',
  filtering: 'gpt-4o-mini',
};

// Implement caching aggressively
const CACHE_TTL = {
  stories: 24 * 60 * 60, // 24 hours
  audio: 7 * 24 * 60 * 60, // 7 days
  images: 30 * 24 * 60 * 60, // 30 days
};
```

### Database Optimization

```sql
-- Partition large tables
CREATE TABLE api_usage_2024_q1 PARTITION OF api_usage
FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

-- Archive old data
INSERT INTO api_usage_archive
SELECT * FROM api_usage
WHERE created_at < NOW() - INTERVAL '90 days';

DELETE FROM api_usage
WHERE created_at < NOW() - INTERVAL '90 days';
```

## Support and Resources

### Documentation
- **Supabase Documentation**: [https://supabase.com/docs](https://supabase.com/docs)
- **OpenAI API Reference**: [https://platform.openai.com/docs](https://platform.openai.com/docs)
- **Deno Documentation**: [https://deno.land/manual](https://deno.land/manual)
- **PostgreSQL Documentation**: [https://www.postgresql.org/docs/](https://www.postgresql.org/docs/)

### Community Support
- **Supabase Discord**: [https://discord.supabase.com](https://discord.supabase.com)
- **GitHub Discussions**: [https://github.com/supabase/supabase/discussions](https://github.com/supabase/supabase/discussions)
- **Stack Overflow**: Tag: `supabase`, `deno`, `openai-api`

### Professional Support
- **Supabase Pro Support**: Available with Pro/Team plans
- **OpenAI Enterprise Support**: For high-volume API users
- **Consulting Services**: Contact development team

### Useful Commands Reference

```bash
# Supabase CLI
npx supabase --help
npx supabase functions --help
npx supabase db --help
npx supabase storage --help

# Database access
psql $DATABASE_URL
npx supabase db remote commit
npx supabase db diff

# Logs and monitoring
npx supabase functions logs <function-name> --tail
npx supabase inspect db-size
npx supabase inspect db-health

# Secrets management
npx supabase secrets list
npx supabase secrets set KEY=value
npx supabase secrets unset KEY
```

---

This comprehensive deployment guide provides everything needed to deploy, operate, and maintain the InfiniteStories Supabase backend in production. For additional assistance, consult the team documentation or reach out to the development team.