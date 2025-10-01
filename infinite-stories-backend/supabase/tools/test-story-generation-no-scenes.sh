#!/bin/bash

# Test script for story generation without scenes
# This script tests the updated story-generation edge function

echo "Testing Story Generation Edge Function (without scenes)..."
echo "==========================================="

# Set your Supabase URL and anon key
SUPABASE_URL="http://127.0.0.1:54321"
ANON_KEY=$(cat ~/.supabase/config.json 2>/dev/null | grep anon_key | cut -d'"' -f4 || echo "YOUR_ANON_KEY_HERE")

# Test user token (development only)
AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImF1dGhlbnRpY2F0ZWQiLCJleHAiOjE5ODMwNjQyMzAsInN1YiI6ImQwMGQ2YTZlLTdjMTgtNDhlYy04MDczLTZmNDJhZDNmYjUwNyJ9.0zxPLqV4TwuMhECGRVMm5fKRGjqdKe3jVQ3S0RWMb4U"

# Test payload
PAYLOAD=$(cat <<EOF
{
  "hero_id": "123e4567-e89b-12d3-a456-426614174000",
  "event": {
    "type": "built_in",
    "data": {
      "name": "Bedtime Adventure"
    }
  },
  "target_duration": 180,
  "language": "en"
}
EOF
)

echo "Request payload:"
echo "$PAYLOAD" | jq '.' 2>/dev/null || echo "$PAYLOAD"
echo ""

# Make the request
echo "Sending request to story-generation function..."
RESPONSE=$(curl -s -X POST \
  "${SUPABASE_URL}/functions/v1/story-generation" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo ""
echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"

# Check if response has scenes field
if echo "$RESPONSE" | jq -e '.scenes' > /dev/null 2>&1; then
  echo ""
  echo "❌ ERROR: Response still contains 'scenes' field!"
  echo "The story-generation function should no longer return scenes."
else
  echo ""
  echo "✅ SUCCESS: Response does not contain 'scenes' field."
  echo "Story generation is working correctly without scene extraction."
fi

# Check required fields
echo ""
echo "Checking required fields..."
if echo "$RESPONSE" | jq -e '.story_id, .title, .content, .estimated_duration, .word_count' > /dev/null 2>&1; then
  echo "✅ All required fields present"
else
  echo "❌ Missing required fields"
fi