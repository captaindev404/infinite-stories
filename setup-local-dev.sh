#!/bin/bash

# InfiniteStories Local Development Setup Script
# This script sets up the local development environment for both backend and iOS app

set -e  # Exit on error

echo "🚀 Setting up InfiniteStories Local Development Environment"
echo "==========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Check prerequisites
echo ""
echo "📋 Checking prerequisites..."

if ! command_exists supabase; then
    echo -e "${RED}❌ Supabase CLI not found${NC}"
    echo "Installing Supabase CLI..."
    npm install -g supabase
fi

if ! command_exists npm; then
    echo -e "${RED}❌ npm not found. Please install Node.js first${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# 2. Setup backend
echo ""
echo "🔧 Setting up backend..."
cd infinite-stories-backend

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing backend dependencies..."
    npm install
fi

# Check if .env.local exists
if [ ! -f "supabase/.env.local" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  No .env.local file found${NC}"
    echo "Please enter your OpenAI API key:"
    read -s OPENAI_KEY
    echo "OPENAI_API_KEY=$OPENAI_KEY" > supabase/.env.local
    echo -e "${GREEN}✅ Created .env.local file${NC}"
else
    echo -e "${GREEN}✅ .env.local file exists${NC}"
fi

# Start Supabase
echo ""
echo "🐘 Starting Supabase services..."
npx supabase stop 2>/dev/null || true  # Stop if already running
npx supabase start

# Get local credentials
echo ""
echo "📝 Local Supabase Credentials:"
echo "=============================="
npx supabase status | grep -E "API URL|anon key|service_role key"

# Apply migrations
echo ""
echo "📊 Applying database migrations..."
npx supabase db reset --linked

# Serve functions
echo ""
echo "⚡ Starting Edge Functions (in background)..."
npx supabase functions serve --env-file supabase/.env.local &
FUNCTIONS_PID=$!
echo "Edge Functions PID: $FUNCTIONS_PID"

# 3. Configure iOS App
echo ""
echo "📱 Configuring iOS App..."
cd ../InfiniteStories

# Create local configuration file if it doesn't exist
if [ ! -f "InfiniteStories/Configuration/LocalConfig.swift" ]; then
    cat > InfiniteStories/Configuration/LocalConfig.swift << 'EOF'
//
//  LocalConfig.swift
//  InfiniteStories
//
//  Local development configuration
//  ⚠️ DO NOT COMMIT THIS FILE
//

import Foundation

extension SupabaseConfig {
    // Override with your local Supabase credentials
    // Get these from 'npx supabase status' output
    static let localOverride = SupabaseConfig(
        url: "http://127.0.0.1:54321",
        anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0",
        serviceRoleKey: nil
    )
}
EOF
    echo -e "${GREEN}✅ Created LocalConfig.swift${NC}"
fi

# Add to .gitignore if not already there
if ! grep -q "LocalConfig.swift" .gitignore 2>/dev/null; then
    echo "InfiniteStories/Configuration/LocalConfig.swift" >> .gitignore
    echo -e "${GREEN}✅ Added LocalConfig.swift to .gitignore${NC}"
fi

# 4. Test the setup
echo ""
echo "🧪 Testing the setup..."
cd ../infinite-stories-backend

# Test story generation endpoint
echo "Testing story generation endpoint..."
curl -X POST http://127.0.0.1:54321/functions/v1/story-generation \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "00000000-0000-0000-0000-000000000001",
    "event": {"type": "built_in", "data": {"event": "bedtime"}},
    "target_duration": 300,
    "language": "en"
  }' \
  --max-time 10 \
  --silent \
  --show-error \
  | head -c 100

echo ""
echo ""
echo "✨ ============================================= ✨"
echo "   Local Development Environment Setup Complete!"
echo "✨ ============================================= ✨"
echo ""
echo "📝 Next Steps:"
echo "1. In Xcode, set the scheme to Debug"
echo "2. In the iOS app Settings, switch to 'Supabase' AI Service"
echo "3. Build and run the app"
echo ""
echo "🔗 Service URLs:"
echo "   Supabase Studio: http://127.0.0.1:54323"
echo "   Edge Functions:  http://127.0.0.1:54321/functions/v1/"
echo "   Database:        postgresql://postgres:postgres@127.0.0.1:54322/postgres"
echo ""
echo "⚠️  Keep this terminal open for Edge Functions to work!"
echo "   Press Ctrl+C to stop all services"
echo ""

# Keep script running
echo "Press Ctrl+C to stop services..."
wait $FUNCTIONS_PID