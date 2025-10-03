# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**⚠️ IMPORTANT**: This is the **legacy Supabase backend** being phased out. For new features, use the Firebase backend at `../backend/`. This backend is maintained only for reference and migration purposes.

## Development Tools

### PRD Tool - Task Management for Migration Work

When working on migration tasks or maintaining this legacy backend, use the PRD tool at `../tools/prd/`:

```bash
# Build the tool (from project root)
cd ../tools/prd && cargo build --release

# Create migration task
./target/release/prd create "Migrate X from Supabase to Firebase" --priority high

# Track migration progress
./target/release/prd-dashboard
```

See [../tools/prd/README.md](../tools/prd/README.md) for complete documentation.

## Working Methods and Best Practices

### Development Workflow
1. **Always test Edge Functions after implementation** - Deploy and verify functionality
2. **Use proper error handling** - Comprehensive try-catch blocks and error responses
3. **Follow TypeScript conventions** - Proper types, async/await patterns
4. **Verify Supabase integration** - Test database operations and RLS policies

### Testing Commands
```bash
# Start local Supabase
npx supabase start

# Deploy Edge Functions
npx supabase functions deploy

# Test Edge Function locally
npx supabase functions serve extract-scenes

# View function logs
npx supabase functions logs extract-scenes

# Reset database with migrations
npx supabase db reset
```

### Important Development Rules
- **Function Testing**: ALWAYS test Edge Functions after implementation
- **Error Handling**: Implement comprehensive error handling with proper logging
- **Type Safety**: Use TypeScript types for all request/response interfaces
- **Performance**: Implement caching for expensive operations
- **Security**: Validate all inputs and enforce authentication

## Project Overview

This is the backend component for the Infinite Stories project - a comprehensive Supabase-based backend that replaces direct OpenAI API calls from the iOS app. The backend includes Edge Functions for story generation, audio synthesis, image generation, and content filtering, all designed with child safety as the top priority.

## Project Structure

- **`supabase/`** - Supabase project configuration and code
  - **`functions/`** - Edge Functions for OpenAI API integration
    - `story-generation/` - Story generation with scene extraction
    - `audio-synthesis/` - Text-to-speech with voice configurations
    - `avatar-generation/` - Hero avatar creation with visual consistency
    - `scene-illustration/` - Batch scene illustration generation
    - `_shared/` - Shared utilities and middleware
  - **`migrations/`** - Database schema migrations
    - `20250927230845_initial_schema.sql` - Core database tables
    - `20250927231030_rls_policies.sql` - Row Level Security policies
  - **`config.toml`** - Supabase configuration
  - **`seed.sql`** - Database seed data
- **`package.json`** - Supabase CLI dependency
- **`DEPLOYMENT.md`** - Comprehensive deployment guide
- **`.env.example`** - Environment configuration template
- **`.gitignore`** - Git ignore rules for sensitive files

## Development Commands

### Core Supabase Commands
```bash
# Start local development environment
npx supabase start

# Check status of services
npx supabase status

# Stop local environment
npx supabase stop

# Reset database (apply all migrations)
npx supabase db reset

# Generate TypeScript types
npx supabase gen types typescript
```

### Database Management
```bash
# Create new migration
npx supabase migration new <migration_name>

# Push local changes to remote
npx supabase db push

# Pull remote changes to local
npx supabase db pull
```

### Edge Functions
```bash
# Deploy all functions
npx supabase functions deploy

# Deploy specific function
npx supabase functions deploy story-generation

# Serve functions locally
npx supabase functions serve

# View function logs
npx supabase functions logs story-generation

# Test function locally
curl -X POST http://127.0.0.1:54321/functions/v1/story-generation \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### Environment Management
```bash
# Set production secrets
npx supabase secrets set OPENAI_API_KEY=sk-...

# List all secrets
npx supabase secrets list

# Copy environment template
cp .env.example .env.local
```

## Architecture Overview

### Backend Services
- **Database**: PostgreSQL with comprehensive schema for heroes, stories, scenes, and usage tracking
- **Authentication**: Supabase Auth with JWT tokens and Row Level Security
- **Storage**: Supabase Storage for audio files, images, and avatars
- **Functions**: TypeScript Edge Functions running on Deno runtime
- **Caching**: Database-backed caching system for performance

### Edge Functions Architecture
- **story-generation**: Generates bedtime stories using GPT-5 (`gpt-5`) with configurable reasoning and scene extraction
- **audio-synthesis**: Creates TTS audio using gpt-4o-mini-tts with enhanced voice quality and instructions
- **avatar-generation**: Generates hero avatars using GPT-5 (`gpt-5`) with enhanced visual consistency
- **scene-illustration**: Batch processes scene illustrations with generation ID chaining
- **_shared**: Common utilities for auth, validation, caching, and content filtering

### Content Safety System
- **Rule-based filtering**: Comprehensive word/phrase replacement for child safety
- **AI-powered filtering**: GPT-5 analyzes content for appropriateness
- **Image prompt sanitization**: Ensures all images are child-friendly
- **Companionship enforcement**: Prevents children from being shown alone

### Key Features
- **Visual Consistency**: Generation ID chaining for character consistency across images
- **Multi-language Support**: 5 languages (English, Spanish, French, German, Italian)
- **Voice Configurations**: 7 specialized voices with custom instructions
- **Usage Tracking**: Comprehensive API usage and cost tracking
- **Error Handling**: Standardized error responses with retry logic

## Development Workflow

### Local Development Setup
1. **Environment Setup**:
   ```bash
   cp .env.example .env.local
   # Add your OpenAI API key to .env.local
   ```

2. **Start Services**:
   ```bash
   npx supabase start
   npx supabase functions serve
   ```

3. **Verify Setup**:
   ```bash
   npx supabase status
   # All services should show as running
   ```

### Making Changes

#### Database Changes
1. Create migration: `npx supabase migration new feature_name`
2. Write SQL in the generated migration file
3. Apply locally: `npx supabase db reset`
4. Test thoroughly
5. Deploy: `npx supabase db push`

#### Function Changes
1. Edit function code in `supabase/functions/`
2. Test locally with `curl` or Postman
3. Deploy: `npx supabase functions deploy function-name`
4. Monitor logs: `npx supabase functions logs function-name`

#### Shared Utility Changes
1. Edit files in `supabase/functions/_shared/`
2. Test with functions that use the utilities
3. Deploy all affected functions

### Testing Strategy
- **Unit Testing**: Test shared utilities individually
- **Integration Testing**: Test complete function workflows
- **Content Safety Testing**: Verify all content filtering works correctly
- **Visual Consistency Testing**: Verify generation ID chaining works

### Deployment Process
1. **Test Locally**: Ensure all functions work in local environment
2. **Environment Setup**: Configure production secrets
3. **Database Migration**: Push schema changes first
4. **Function Deployment**: Deploy functions with zero downtime
5. **Verification**: Test all endpoints in production
6. **Monitoring**: Watch logs and usage metrics

## Code Patterns and Standards

### Function Structure
```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { withEdgeFunctionWrapper } from '../_shared/index.ts';

serve(async (req) => {
  return withEdgeFunctionWrapper(req, 'function_name', async ({ userId, supabase, requestId }) => {
    // Function logic here
    return response;
  });
});
```

### Error Handling
- Use standardized `APIError` class
- Always include request ID for tracing
- Log errors with appropriate category
- Return consistent error format

### Content Filtering
- Always filter user-generated content
- Use both rule-based and AI filtering
- Ensure children are never shown alone
- Maintain bright, positive atmosphere

### Database Operations
- Use parameterized queries
- Respect RLS policies
- Include user_id in all user-specific operations
- Handle errors gracefully

### Caching Strategy
- Cache expensive operations (story generation, image generation)
- Use appropriate TTL for each content type
- Include cache hit/miss in logs
- Invalidate cache when needed

## Security Considerations

### Authentication
- All functions require valid JWT
- User isolation through RLS
- Service role key only for system operations

### Content Safety
- Multiple layers of content filtering
- Child-appropriate content validation
- Image prompt sanitization
- Audio content filtering

### API Security
- Input validation on all endpoints
- CORS properly configured
- Secrets stored securely

### Data Protection
- User data isolation
- Secure storage of generated content
- Usage tracking for compliance
- Audit trails for all operations

## Monitoring and Maintenance

### Key Metrics
- Function response times
- Error rates by function
- OpenAI API costs
- Content filtering effectiveness

### Log Analysis
- Request/response logging
- Performance metrics
- Error categorization
- Usage patterns

### Maintenance Tasks
- Cache cleanup (expired entries)
- Usage data aggregation
- Cost optimization review

## Integration with iOS App

The backend provides complete API compatibility with the existing iOS app expectations:

### Request/Response Formats
- Exact data model matching
- Same error code structure
- Compatible authentication flow
- Maintained field names and types

### Migration Strategy
- Feature flags for gradual rollout
- Parallel operation during transition
- Fallback to direct OpenAI calls
- Progressive user migration

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Edge Function Deployment Failures

**Problem**: Functions fail to deploy with import errors
```
Error: Module not found: npm:openai
```

**Solution**:
```bash
# Update Supabase CLI
npm update -g supabase

# Clear function cache
rm -rf supabase/.temp

# Redeploy
npx supabase functions deploy --no-verify-jwt
```

#### 2. Database Migration Errors

**Problem**: Migration fails with permission errors

**Solution**:
```bash
# Reset database
npx supabase db reset

# Apply migrations manually
npx supabase db push --include-all
```

#### 3. Authentication Issues

**Problem**: JWT validation fails

**Solution**:
```typescript
// Verify JWT configuration
const jwt = await verifyJWT(token, {
  secret: Deno.env.get('SUPABASE_JWT_SECRET'),
  audience: 'authenticated'
});
```

#### 4. Content Filtering Issues

**Problem**: Inappropriate content passing through

**Solution**:
```typescript
// Enable strict filtering
const filtered = await contentFilter.filterContent(content, {
  strictMode: true,
  aiAnalysis: true,
  logViolations: true
});
```

#### 5. Storage Upload Failures

**Problem**: Files fail to upload to storage

**Solution**:
```bash
# Check bucket configuration
npx supabase storage ls

# Verify bucket policies
npx supabase storage policies list story-assets

# Create missing buckets
npx supabase storage create story-assets --public
```

#### 6. OpenAI API Errors

**Problem**: OpenAI requests failing

**Solution**:
```typescript
// Implement retry logic
const response = await retryWithBackoff(async () => {
  return await openai.createCompletion({
    model: 'gpt-5',
    ...params
  });
}, {
  maxRetries: 3,
  initialDelay: 1000,
  maxDelay: 10000
});
```

#### 7. Performance Issues

**Problem**: Slow response times

**Solution**:
```sql
-- Add missing indexes
CREATE INDEX idx_stories_user_created
ON stories(user_id, created_at DESC);

-- Analyze query performance
EXPLAIN ANALYZE
SELECT * FROM stories
WHERE user_id = 'uuid'
ORDER BY created_at DESC
LIMIT 10;
```

### Debug Commands

```bash
# View function logs
npx supabase functions logs story-generation --tail

# Check service status
npx supabase status

# Test function locally
npx supabase functions serve story-generation --env-file .env.local

# Database console
npx supabase db shell

# View current configuration
npx supabase inspect
```

### Performance Monitoring

```sql
-- Monitor API usage
SELECT
  function_name,
  COUNT(*) as calls,
  AVG(response_time_ms) as avg_time,
  MAX(response_time_ms) as max_time,
  SUM(CASE WHEN status = 'error' THEN 1 ELSE 0 END) as errors
FROM api_usage
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY function_name;

-- Check cache effectiveness
SELECT
  DATE(created_at) as date,
  COUNT(*) as total_requests,
  SUM(CASE WHEN cached = true THEN 1 ELSE 0 END) as cache_hits,
  ROUND(100.0 * SUM(CASE WHEN cached = true THEN 1 ELSE 0 END) / COUNT(*), 2) as hit_rate
FROM api_usage
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

## Best Practices

### Code Quality
- Use TypeScript for type safety
- Implement comprehensive error handling
- Add detailed logging for debugging
- Write unit tests for utilities
- Document all functions and APIs

### Security
- Never expose service role keys
- Validate all inputs
- Sanitize user-generated content
- Use parameterized queries

### Performance
- Cache expensive operations
- Use database indexes effectively
- Implement connection pooling
- Optimize image sizes
- Use CDN for static assets

### Monitoring
- Track all API calls
- Monitor error rates
- Alert on anomalies
- Review costs regularly
- Analyze usage patterns