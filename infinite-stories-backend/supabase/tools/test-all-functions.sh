#!/bin/bash

# Test all Supabase Edge Functions with Response API implementation
# This script tests story generation, audio synthesis, avatar generation, and scene illustration

set -e

echo "=========================================="
echo "Testing All Edge Functions with Response API"
echo "=========================================="

# Test authentication token (demo token)
AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
BASE_URL="http://127.0.0.1:54321/functions/v1"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local endpoint=$1
    local data=$2
    local description=$3

    echo -e "\n${YELLOW}Testing: $description${NC}"
    echo "Endpoint: $endpoint"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/$endpoint" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$data" 2>&1)

    http_code=$(echo "$response" | tail -n 1)
    response_body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Success (HTTP $http_code)${NC}"
        echo "Response preview:"
        echo "$response_body" | jq -r '.' 2>/dev/null | head -20 || echo "$response_body" | head -20
    else
        echo -e "${RED}✗ Failed (HTTP $http_code)${NC}"
        echo "Error response:"
        echo "$response_body" | jq -r '.' 2>/dev/null || echo "$response_body"
    fi

    return 0
}

# Test 1: Story Generation (uses GPT-5-mini with Response API)
echo -e "\n${YELLOW}=== TEST 1: Story Generation (GPT-5-mini Response API) ===${NC}"
test_endpoint "story-generation" '{
    "hero_id": "c55fb8a9-2e56-4b4c-8837-52e3219a34b9",
    "event": {
        "type": "built_in",
        "data": {
            "name": "Bedtime Adventure"
        }
    },
    "target_duration": 60,
    "language": "en"
}' "Story Generation with GPT-5-mini via Response API"

sleep 2

# Test 2: Audio Synthesis (uses GPT-4o-mini-tts)
echo -e "\n${YELLOW}=== TEST 2: Audio Synthesis (GPT-4o-mini-tts) ===${NC}"
test_endpoint "audio-synthesis" '{
    "story_id": "00000000-0000-0000-0000-000000000001",
    "content": "Once upon a time, in a magical forest...",
    "voice_id": "nova",
    "language": "en"
}' "Audio Synthesis with GPT-4o-mini-tts"

sleep 2

# Test 3: Avatar Generation (uses DALL-E 3)
echo -e "\n${YELLOW}=== TEST 3: Avatar Generation (DALL-E 3) ===${NC}"
test_endpoint "avatar-generation" '{
    "hero_id": "c55fb8a9-2e56-4b4c-8837-52e3219a34b9",
    "prompt": "A brave blue gazelle that can jump super high",
    "style": "watercolor",
    "quality": "standard",
    "size": "1024x1024"
}' "Avatar Generation with DALL-E 3"

sleep 2

# Test 4: Scene Illustration (uses GPT-5 for images)
echo -e "\n${YELLOW}=== TEST 4: Scene Illustration (GPT-5) ===${NC}"
test_endpoint "scene-illustration" '{
    "story_id": "00000000-0000-0000-0000-000000000001",
    "scenes": [{
        "scene_number": 1,
        "illustration_prompt": "A magical forest with glowing fireflies",
        "timestamp_seconds": 0
    }]
}' "Scene Illustration with GPT-5"

echo -e "\n${YELLOW}=========================================="
echo "Test Suite Complete"
echo -e "==========================================${NC}"