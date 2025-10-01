#!/bin/bash

# Test Storage Operations Script
# This script tests the storage bucket operations in Edge Functions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Testing Storage Operations..."
echo "================================"

# Configuration
SUPABASE_URL="http://127.0.0.1:54321"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
USER_ID="00000000-0000-0000-0000-000000000001"
HERO_ID="11111111-1111-1111-1111-111111111111"
STORY_ID="22222222-2222-2222-2222-222222222222"

# Function to test avatar generation and storage
test_avatar_storage() {
    echo -e "\n${YELLOW}Testing Avatar Generation & Storage...${NC}"

    # Test avatar generation (which should save to storage)
    response=$(curl -s -X POST \
        "$SUPABASE_URL/functions/v1/avatar-generation" \
        -H "Authorization: Bearer $ANON_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"hero_id\": \"$HERO_ID\",
            \"prompt\": \"A friendly young explorer with curly hair and a warm smile, wearing an adventure outfit\",
            \"size\": \"1024x1024\",
            \"quality\": \"standard\"
        }")

    if echo "$response" | grep -q "avatar_url"; then
        echo -e "${GREEN}✓ Avatar generated and stored successfully${NC}"
        echo "$response" | jq -r '.avatar_url' 2>/dev/null || echo "Avatar URL extracted"
    else
        echo -e "${RED}✗ Avatar generation failed${NC}"
        echo "$response"
        return 1
    fi
}

# Function to test audio synthesis and storage
test_audio_storage() {
    echo -e "\n${YELLOW}Testing Audio Synthesis & Storage...${NC}"

    # Test audio synthesis (which should save to storage)
    response=$(curl -s -X POST \
        "$SUPABASE_URL/functions/v1/audio-synthesis" \
        -H "Authorization: Bearer $ANON_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"story_id\": \"$STORY_ID\",
            \"text\": \"Once upon a time, in a magical forest, there lived a brave little hero.\",
            \"voice\": \"coral\",
            \"language\": \"en\"
        }")

    if echo "$response" | grep -q "audio_url"; then
        echo -e "${GREEN}✓ Audio synthesized and stored successfully${NC}"
        echo "$response" | jq -r '.audio_url' 2>/dev/null || echo "Audio URL extracted"
    else
        echo -e "${RED}✗ Audio synthesis failed${NC}"
        echo "$response"
        return 1
    fi
}

# Function to test scene illustration and storage
test_scene_storage() {
    echo -e "\n${YELLOW}Testing Scene Illustration & Storage...${NC}"

    # Test scene illustration (which should save to storage)
    response=$(curl -s -X POST \
        "$SUPABASE_URL/functions/v1/scene-illustration" \
        -H "Authorization: Bearer $ANON_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"story_id\": \"$STORY_ID\",
            \"hero_id\": \"$HERO_ID\",
            \"scenes\": [
                {
                    \"scene_number\": 1,
                    \"prompt\": \"A magical forest with tall trees and glowing mushrooms, peaceful atmosphere\",
                    \"timestamp_start\": 0,
                    \"timestamp_end\": 10
                }
            ],
            \"process_async\": false
        }")

    if echo "$response" | grep -q "illustrations"; then
        echo -e "${GREEN}✓ Scene illustration generated and stored successfully${NC}"
        echo "$response" | jq -r '.illustrations[0].image_url' 2>/dev/null || echo "Illustration URL extracted"
    else
        echo -e "${RED}✗ Scene illustration failed${NC}"
        echo "$response"
        return 1
    fi
}

# Function to check storage buckets
check_storage_buckets() {
    echo -e "\n${YELLOW}Checking Storage Buckets...${NC}"

    # Check if buckets exist
    buckets=("hero-avatars" "story-audio" "story-illustrations")

    for bucket in "${buckets[@]}"; do
        # Try to list files in the bucket (will fail if bucket doesn't exist)
        response=$(curl -s -X GET \
            "$SUPABASE_URL/storage/v1/object/list/$bucket" \
            -H "Authorization: Bearer $ANON_KEY")

        if echo "$response" | grep -q "error"; then
            echo -e "${RED}✗ Bucket '$bucket' not accessible${NC}"
        else
            echo -e "${GREEN}✓ Bucket '$bucket' is accessible${NC}"
        fi
    done
}

# Function to test direct storage operations from client
test_client_storage() {
    echo -e "\n${YELLOW}Testing Client Storage Operations...${NC}"

    # Create a test file
    test_file="/tmp/test_image.png"
    # Create a simple 1x1 PNG
    echo -n -e '\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90\x77\x53\xDE\x00\x00\x00\x0C\x49\x44\x41\x54\x08\x99\x63\xF8\x0F\x00\x00\x01\x01\x00\x05\xD8\xA7\x76\x08\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82' > "$test_file"

    # Upload test file to hero-avatars bucket
    echo "Uploading test file to hero-avatars bucket..."
    response=$(curl -s -X POST \
        "$SUPABASE_URL/storage/v1/object/hero-avatars/$USER_ID/test_hero/test.png" \
        -H "Authorization: Bearer $ANON_KEY" \
        -H "Content-Type: image/png" \
        --data-binary "@$test_file")

    if echo "$response" | grep -q "error"; then
        echo -e "${YELLOW}⚠ Direct upload returned an error (might be due to RLS policies)${NC}"
        echo "$response"
    else
        echo -e "${GREEN}✓ Test file uploaded successfully${NC}"

        # Try to get public URL
        public_url="$SUPABASE_URL/storage/v1/object/public/hero-avatars/$USER_ID/test_hero/test.png"
        echo "Public URL: $public_url"

        # Clean up - delete test file
        curl -s -X DELETE \
            "$SUPABASE_URL/storage/v1/object/hero-avatars/$USER_ID/test_hero/test.png" \
            -H "Authorization: Bearer $ANON_KEY" > /dev/null
    fi

    rm -f "$test_file"
}

# Main execution
echo -e "${YELLOW}Starting storage operation tests...${NC}"
echo "Using Supabase URL: $SUPABASE_URL"
echo "Using User ID: $USER_ID"
echo ""

# Run tests
check_storage_buckets

echo -e "\n${YELLOW}Note: The following tests require OpenAI API key to be configured${NC}"
echo "If these fail, ensure OPENAI_API_KEY is set in your Edge Functions environment"
echo ""

# These will only work if OpenAI API is configured
# test_avatar_storage
# test_audio_storage
# test_scene_storage

# Test direct storage operations
test_client_storage

echo -e "\n${GREEN}Storage operation tests completed!${NC}"
echo ""
echo "To fully test the Edge Functions with storage:"
echo "1. Ensure OPENAI_API_KEY is set in .env.local"
echo "2. Run: npx supabase functions serve"
echo "3. Uncomment the Edge Function tests in this script"
echo "4. Run this script again"