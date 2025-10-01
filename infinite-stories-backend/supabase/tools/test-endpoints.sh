#!/bin/bash

# Supabase Backend Edge Functions Test Script
# Usage: ./test-endpoints.sh <SUPABASE_URL> <ANON_KEY>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <SUPABASE_URL> <ANON_KEY>"
    echo "Example: $0 https://xyzxyz.supabase.co eyJhbGciOiJIUzI1NiIs..."
    exit 1
fi

SUPABASE_URL=$1
ANON_KEY=$2

echo "Testing Supabase Edge Functions..."
echo "================================="
echo "URL: $SUPABASE_URL"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test Story Generation
echo "1. Testing Story Generation..."
STORY_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/functions/v1/story-generation" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "test-hero-id",
    "event": {
      "type": "built_in",
      "data": {
        "event": "magical_forest_adventure"
      }
    },
    "target_duration": 180,
    "language": "en"
  }')

if echo "$STORY_RESPONSE" | grep -q "story_id"; then
    echo -e "${GREEN}✓ Story Generation: Working${NC}"
    STORY_ID=$(echo "$STORY_RESPONSE" | grep -o '"story_id":"[^"]*' | cut -d'"' -f4)
    echo "  Generated story ID: $STORY_ID"
else
    echo -e "${RED}✗ Story Generation: Failed${NC}"
    echo "  Response: $STORY_RESPONSE"
fi
echo ""

# Test Audio Synthesis
echo "2. Testing Audio Synthesis..."
AUDIO_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/functions/v1/audio-synthesis" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "test-story-id",
    "text": "Once upon a time in a magical forest",
    "voice": "coral",
    "language": "en"
  }')

if echo "$AUDIO_RESPONSE" | grep -q "audio_url"; then
    echo -e "${GREEN}✓ Audio Synthesis: Working${NC}"
    AUDIO_URL=$(echo "$AUDIO_RESPONSE" | grep -o '"audio_url":"[^"]*' | cut -d'"' -f4)
    echo "  Audio URL: $AUDIO_URL"
else
    echo -e "${RED}✗ Audio Synthesis: Failed${NC}"
    echo "  Response: $AUDIO_RESPONSE"
fi
echo ""

# Test Avatar Generation
echo "3. Testing Avatar Generation..."
AVATAR_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/functions/v1/avatar-generation" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "test-hero-id",
    "prompt": "A friendly blue dragon with wings",
    "size": "1024x1024",
    "quality": "high"
  }')

if echo "$AVATAR_RESPONSE" | grep -q "avatar_url"; then
    echo -e "${GREEN}✓ Avatar Generation: Working${NC}"
    AVATAR_URL=$(echo "$AVATAR_RESPONSE" | grep -o '"avatar_url":"[^"]*' | cut -d'"' -f4)
    echo "  Avatar URL: $AVATAR_URL"
else
    echo -e "${RED}✗ Avatar Generation: Failed${NC}"
    echo "  Response: $AVATAR_RESPONSE"
fi
echo ""

# Test Scene Illustrations (try both endpoints)
echo "4. Testing Scene Illustrations..."

# Try plural version first (expected by iOS)
SCENE_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/functions/v1/scene-illustrations" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "test-story-id",
    "hero_id": "test-hero-id",
    "scenes": [
      {
        "scene_number": 1,
        "text_segment": "The hero enters the magical forest",
        "illustration_prompt": "Hero walking into a bright magical forest with glowing trees",
        "timestamp_seconds": 0
      }
    ]
  }')

if echo "$SCENE_RESPONSE" | grep -q "illustrations"; then
    echo -e "${GREEN}✓ Scene Illustrations (plural): Working${NC}"
elif echo "$SCENE_RESPONSE" | grep -q "not found"; then
    echo -e "${YELLOW}⚠ Scene Illustrations (plural): Not found, trying singular...${NC}"

    # Try singular version
    SCENE_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/functions/v1/scene-illustration" \
      -H "Authorization: Bearer ${ANON_KEY}" \
      -H "Content-Type: application/json" \
      -d '{
        "story_id": "test-story-id",
        "hero_id": "test-hero-id",
        "scenes": [
          {
            "scene_number": 1,
            "text_segment": "The hero enters the magical forest",
            "illustration_prompt": "Hero walking into a bright magical forest",
            "timestamp_seconds": 0
          }
        ]
      }')

    if echo "$SCENE_RESPONSE" | grep -q "illustrations"; then
        echo -e "${YELLOW}✓ Scene Illustration (singular): Working - iOS client needs update${NC}"
        echo -e "${YELLOW}  ACTION REQUIRED: Rename function to 'scene-illustrations' or update iOS client${NC}"
    else
        echo -e "${RED}✗ Scene Illustrations: Failed${NC}"
        echo "  Response: $SCENE_RESPONSE"
    fi
else
    echo -e "${RED}✗ Scene Illustrations: Failed${NC}"
    echo "  Response: $SCENE_RESPONSE"
fi
echo ""

# Summary
echo "================================="
echo "Test Summary:"
echo "================================="
echo ""
echo "Next Steps:"
echo "1. If any tests failed, check the function logs:"
echo "   npx supabase functions logs <function-name>"
echo ""
echo "2. Verify OpenAI API key is set:"
echo "   npx supabase secrets list"
echo ""
echo "3. If scene-illustrations shows naming issue:"
echo "   Either rename the function or update iOS client"
echo ""