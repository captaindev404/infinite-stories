#!/bin/bash

# Test Response API implementation
set -e

echo "Testing Story Generation with Response API..."

# Test story generation
curl -X POST http://127.0.0.1:54321/functions/v1/story-generation \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json" \
  -d '{"hero_id":"c55fb8a9-2e56-4b4c-8837-52e3219a34b9","event":{"type":"built_in","data":{"name":"Bedtime Adventure"}},"target_duration":60,"language":"en"}' \
  -w "\nHTTP Status: %{http_code}\n" \
  -o /tmp/story-response.json

echo "Response saved to /tmp/story-response.json"
cat /tmp/story-response.json | jq '.'

# Check if story was generated successfully
if [ -f /tmp/story-response.json ]; then
    STORY_ID=$(cat /tmp/story-response.json | jq -r '.story.id // empty')
    if [ -n "$STORY_ID" ]; then
        echo "✓ Story generated successfully with ID: $STORY_ID"
        echo "✓ Story content length: $(cat /tmp/story-response.json | jq -r '.story.content' | wc -c) characters"

        # Check scene extraction
        SCENE_COUNT=$(cat /tmp/story-response.json | jq -r '.scenes | length // 0')
        echo "✓ Scenes extracted: $SCENE_COUNT"
    else
        echo "✗ Story generation failed - no story ID returned"
    fi
fi
