#!/bin/bash

echo "Testing Story Generation with Response API"
echo "=========================================="

# Valid UUID (lowercase format)
HERO_ID="75b37c04-50eb-4f95-af92-04adfb71e0a1"
AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

echo ""
echo "Test 1: Story Generation (GPT-5-mini via Response API)"
echo "------------------------------------------------------"
curl -X POST http://127.0.0.1:54321/functions/v1/story-generation \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  --data-raw "{
    \"hero_id\": \"${HERO_ID}\",
    \"event\": {
      \"type\": \"built_in\",
      \"data\": {
        \"name\": \"Bedtime Adventure\"
      }
    },
    \"target_duration\": 60,
    \"language\": \"en\"
  }" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Response received (JSON parsing may have failed due to size)"

echo ""
echo "Test complete!"