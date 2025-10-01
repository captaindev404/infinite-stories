#!/bin/bash

# Test the extract-scenes Edge Function with sample data

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing extract-scenes Edge Function...${NC}"

# Sample story content for testing
STORY_CONTENT="Once upon a time, there was a brave little hero named Luna. She loved exploring magical forests with her best friend, a talking rabbit named Hoppy. One sunny morning, they discovered a hidden path that led to a sparkling waterfall. Behind the waterfall was a secret cave filled with glowing crystals. Luna and Hoppy decided to explore the cave together. They found ancient drawings on the walls that told stories of old adventures. As the sun began to set, they made their way back home, excited to share their discovery with their friends. That night, Luna fell asleep dreaming of more adventures to come."

# Create the request body
REQUEST_BODY=$(cat <<EOF
{
  "story_content": "$STORY_CONTENT",
  "story_duration": 120,
  "hero": {
    "id": "test-hero-id",
    "name": "Luna"
  },
  "event_context": "Test Adventure"
}
EOF
)

echo -e "${YELLOW}Request Body:${NC}"
echo "$REQUEST_BODY" | jq . 2>/dev/null || echo "$REQUEST_BODY"

echo -e "\n${YELLOW}Sending request to extract-scenes...${NC}"

# Get the anon key for local development
ANON_KEY="sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

# Make the API call
RESPONSE=$(curl -s -X POST \
  'http://127.0.0.1:54321/functions/v1/extract-scenes' \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "apikey: $ANON_KEY" \
  -d "$REQUEST_BODY")

# Check if the response is valid JSON
if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    echo -e "\n${GREEN}Response received:${NC}"
    echo "$RESPONSE" | jq .

    # Check if there's an error in the response
    if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
        ERROR=$(echo "$RESPONSE" | jq -r '.error')
        echo -e "\n${RED}Error: $ERROR${NC}"
        exit 1
    else
        # Count the scenes
        SCENE_COUNT=$(echo "$RESPONSE" | jq -r '.scene_count // 0')
        echo -e "\n${GREEN}Success! Extracted $SCENE_COUNT scenes.${NC}"
    fi
else
    echo -e "\n${RED}Invalid JSON response:${NC}"
    echo "$RESPONSE"
    exit 1
fi