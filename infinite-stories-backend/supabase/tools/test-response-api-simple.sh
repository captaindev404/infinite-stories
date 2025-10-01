#!/bin/bash

# Simple test script for OpenAI Response API implementation
# Tests the most critical functionality

echo "🚀 Testing OpenAI Response API Implementation"
echo "============================================"

# Check if OPENAI_API_KEY is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY environment variable is not set"
    echo "Please set it using: export OPENAI_API_KEY=your_api_key"
    exit 1
fi

# Test GPT-5 with Response API
echo ""
echo "📝 Test 1: GPT-5-mini with Response API"
echo "----------------------------------------"
curl -s -X POST http://localhost:54321/functions/v1/story-generation \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "test-hero-id",
    "event_type": "bedtime",
    "story_length": 3,
    "language": "English",
    "test_mode": true,
    "model_override": "gpt-5-mini"
  }' | jq '.'

echo ""
echo "📝 Test 2: GPT-4o with Traditional API"
echo "---------------------------------------"
curl -s -X POST http://localhost:54321/functions/v1/story-generation \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "test-hero-id",
    "event_type": "school_day",
    "story_length": 3,
    "language": "English",
    "test_mode": true,
    "model_override": "gpt-4o"
  }' | jq '.'

echo ""
echo "✅ Tests completed. Check the responses above for any errors."