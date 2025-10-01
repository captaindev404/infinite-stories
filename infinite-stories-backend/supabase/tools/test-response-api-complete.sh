#!/bin/bash

# Test script for Response API implementation
set -e

echo "Testing Infinite Stories Response API Implementation"
echo "===================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# API configuration
API_URL="http://127.0.0.1:54321"
AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

# Test hero ID (we'll get this from the database)
HERO_ID="c55fb8a9-2e56-4b4c-8837-52e3219a34b9"

echo ""
echo "1. Testing Story Generation (GPT-5-mini with Response API)"
echo "--------------------------------------------------------"
echo "Calling story-generation endpoint..."

STORY_RESPONSE=$(curl -X POST "${API_URL}/functions/v1/story-generation" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"hero_id\": \"${HERO_ID}\",
    \"event\": {
      \"type\": \"built_in\",
      \"data\": {
        \"name\": \"Bedtime Adventure\"
      }
    },
    \"target_duration\": 60,
    \"language\": \"en\"
  }" \
  --silent --show-error -w "\n%{http_code}")

HTTP_CODE=$(echo "$STORY_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$STORY_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Story generation successful${NC}"

    # Extract story_id for next tests
    STORY_ID=$(echo "$RESPONSE_BODY" | jq -r '.story.id')

    if [ "$STORY_ID" != "null" ]; then
        echo -e "${GREEN}✓ Story ID: ${STORY_ID}${NC}"

        # Check if scenes were extracted
        SCENE_COUNT=$(echo "$RESPONSE_BODY" | jq -r '.scenes | length')
        echo -e "${GREEN}✓ Scenes extracted: ${SCENE_COUNT}${NC}"
    else
        echo -e "${RED}✗ No story ID returned${NC}"
    fi
else
    echo -e "${RED}✗ Story generation failed with HTTP ${HTTP_CODE}${NC}"
    echo "Response: $RESPONSE_BODY"

    # Check function logs for errors
    echo ""
    echo "Checking function logs..."
    curl -s "${API_URL}/functions/v1/story-generation/_logs" | head -5
fi

echo ""
echo "2. Testing Audio Synthesis (gpt-4o-mini-tts with Response API)"
echo "------------------------------------------------------------"
echo "Calling audio-synthesis endpoint..."

AUDIO_RESPONSE=$(curl -X POST "${API_URL}/functions/v1/audio-synthesis" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": \"Once upon a time, in a magical forest, lived a brave young hero.\",
    \"voice\": \"nova\",
    \"language\": \"en\"
  }" \
  --silent --show-error -w "\n%{http_code}")

HTTP_CODE=$(echo "$AUDIO_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$AUDIO_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Audio synthesis successful${NC}"

    AUDIO_URL=$(echo "$RESPONSE_BODY" | jq -r '.audioUrl')
    if [ "$AUDIO_URL" != "null" ]; then
        echo -e "${GREEN}✓ Audio URL: ${AUDIO_URL}${NC}"
    else
        echo -e "${RED}✗ No audio URL returned${NC}"
    fi
else
    echo -e "${RED}✗ Audio synthesis failed with HTTP ${HTTP_CODE}${NC}"
    echo "Response: $RESPONSE_BODY"
fi

echo ""
echo "3. Testing Avatar Generation (GPT-5 with Response API)"
echo "-----------------------------------------------------"
echo "Calling avatar-generation endpoint..."

AVATAR_RESPONSE=$(curl -X POST "${API_URL}/functions/v1/avatar-generation" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"hero_id\": \"${HERO_ID}\",
    \"prompt\": \"A brave young hero with a kind smile\",
    \"style\": \"watercolor\",
    \"quality\": \"high\",
    \"size\": \"1024x1024\"
  }" \
  --silent --show-error -w "\n%{http_code}")

HTTP_CODE=$(echo "$AVATAR_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$AVATAR_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Avatar generation successful${NC}"

    IMAGE_URL=$(echo "$RESPONSE_BODY" | jq -r '.imageUrl')
    if [ "$IMAGE_URL" != "null" ]; then
        echo -e "${GREEN}✓ Image URL: ${IMAGE_URL}${NC}"
    else
        echo -e "${RED}✗ No image URL returned${NC}"
    fi
else
    echo -e "${RED}✗ Avatar generation failed with HTTP ${HTTP_CODE}${NC}"
    echo "Response: $RESPONSE_BODY"
fi

echo ""
echo "4. Testing Scene Illustration (GPT-5 with Response API)"
echo "------------------------------------------------------"

# Only test if we have a story_id
if [ -n "$STORY_ID" ] && [ "$STORY_ID" != "null" ]; then
    echo "Calling scene-illustration endpoint..."

    SCENE_RESPONSE=$(curl -X POST "${API_URL}/functions/v1/scene-illustration" \
      -H "Authorization: Bearer ${AUTH_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"story_id\": \"${STORY_ID}\",
        \"quality\": \"standard\",
        \"size\": \"1024x1024\"
      }" \
      --silent --show-error -w "\n%{http_code}")

    HTTP_CODE=$(echo "$SCENE_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$SCENE_RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" -eq 200 ]; then
        echo -e "${GREEN}✓ Scene illustration successful${NC}"

        ILLUSTRATIONS_COUNT=$(echo "$RESPONSE_BODY" | jq -r '.illustrations | length')
        echo -e "${GREEN}✓ Illustrations generated: ${ILLUSTRATIONS_COUNT}${NC}"
    else
        echo -e "${RED}✗ Scene illustration failed with HTTP ${HTTP_CODE}${NC}"
        echo "Response: $RESPONSE_BODY"
    fi
else
    echo -e "${YELLOW}⚠ Skipping scene illustration test (no story_id available)${NC}"
fi

echo ""
echo "===================================================="
echo "Test Summary"
echo "===================================================="

# Check if local Supabase is running
if curl -s "${API_URL}/rest/v1/" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Local Supabase is running${NC}"
else
    echo -e "${RED}✗ Local Supabase is not running${NC}"
    echo "Run 'npx supabase start' to start the local environment"
fi

echo ""
echo "Test complete. Check the output above for any failures."