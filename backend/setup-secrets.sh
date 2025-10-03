#!/bin/bash

# Setup script for configuring secrets in Firebase Cloud Functions
# Usage: ./setup-secrets.sh

set -e

echo "🔐 Firebase Cloud Functions Secret Setup"
echo "========================================"
echo ""

# Check if in backend directory
if [ ! -f "firebase.json" ]; then
    echo "❌ Error: Must run from backend directory"
    exit 1
fi

# Function to setup local development
setup_local() {
    echo "📁 Setting up local development environment..."

    cd functions

    # Check if .env already exists
    if [ -f ".env" ]; then
        echo "⚠️  .env file already exists. Backing up to .env.backup"
        cp .env .env.backup
    fi

    # Copy example file
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "✅ Created .env from .env.example"
    else
        echo "❌ .env.example not found"
        exit 1
    fi

    echo ""
    echo "📝 Please edit functions/.env and add your actual API keys:"
    echo "   - OPENAI_API_KEY: Your OpenAI API key"
    echo ""
    echo "To edit: cd functions && nano .env"

    cd ..
}

# Function to setup production secrets
setup_production() {
    echo "🚀 Setting up production secrets..."
    echo ""

    # Check if Firebase CLI is installed
    if ! command -v firebase &> /dev/null; then
        echo "❌ Firebase CLI not found. Install with: npm install -g firebase-tools"
        exit 1
    fi

    echo "This will set production secrets using Firebase config."
    echo "You'll be prompted for each secret value."
    echo ""

    read -p "Enter OpenAI API Key (sk-...): " openai_key

    if [[ ! "$openai_key" =~ ^sk- ]]; then
        echo "⚠️  Warning: API key doesn't start with 'sk-'. Are you sure it's correct?"
        read -p "Continue anyway? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            exit 1
        fi
    fi

    echo ""
    echo "Setting Firebase configuration..."

    # Set OpenAI configuration
    firebase functions:config:set openai.key="$openai_key"

    # Set default storage buckets
    firebase functions:config:set \
        storage.story_assets="story-assets" \
        storage.hero_avatars="hero-avatars" \
        storage.story_audio="story-audio" \
        storage.story_illustrations="story-illustrations"

    # Set rate limits
    firebase functions:config:set \
        ratelimit.story_generation="10" \
        ratelimit.audio_synthesis="15" \
        ratelimit.avatar_generation="8" \
        ratelimit.illustration_generation="25" \
        ratelimit.window_seconds="3600"

    # Set cache TTLs
    firebase functions:config:set \
        cache.ttl_story="86400" \
        cache.ttl_audio="604800" \
        cache.ttl_avatar="604800" \
        cache.ttl_illustration="604800" \
        cache.ttl_content_filter="7200"

    # Set content filtering
    firebase functions:config:set \
        content.filter_enabled="true" \
        content.filter_story_prompts="true" \
        content.filter_story_output="true" \
        content.filter_scene_prompts="true" \
        content.enforce_companionship="true" \
        content.min_age="3"

    # Set monitoring
    firebase functions:config:set \
        monitoring.log_level="info" \
        monitoring.enable_performance_logging="true" \
        monitoring.enable_api_usage_logging="true" \
        monitoring.enable_cost_tracking="true" \
        monitoring.budget_usd="1000" \
        monitoring.alert_threshold="80"

    echo ""
    echo "✅ Production configuration set!"
    echo ""
    echo "To view configuration: firebase functions:config:get"
    echo "To deploy: firebase deploy --only functions"
}

# Function to validate secrets
validate_secrets() {
    echo "🔍 Validating secret configuration..."
    echo ""

    # Check local .env
    if [ -f "functions/.env" ]; then
        echo "✅ Local .env file exists"

        # Check if OpenAI key is set
        if grep -q "OPENAI_API_KEY=YOUR_ACTUAL_API_KEY_HERE" functions/.env; then
            echo "⚠️  OpenAI API key not configured in .env"
        elif grep -q "OPENAI_API_KEY=sk-" functions/.env; then
            echo "✅ OpenAI API key appears to be configured"
        else
            echo "⚠️  OpenAI API key may not be properly configured"
        fi
    else
        echo "❌ Local .env file not found"
    fi

    echo ""

    # Check production config
    echo "Production configuration:"
    firebase functions:config:get || echo "❌ No production configuration set"
}

# Function to show secret management commands
show_commands() {
    echo "📚 Useful Secret Management Commands"
    echo "====================================="
    echo ""
    echo "Local Development:"
    echo "  cd functions && cp .env.example .env  # Create local config"
    echo "  nano functions/.env                    # Edit local secrets"
    echo ""
    echo "Production Secrets:"
    echo "  firebase functions:config:set openai.key=\"sk-...\"  # Set single secret"
    echo "  firebase functions:config:get                       # View all secrets"
    echo "  firebase functions:config:get openai                # View specific config"
    echo "  firebase functions:config:unset openai              # Remove config"
    echo ""
    echo "Secret Manager (Recommended for sensitive data):"
    echo "  firebase functions:secrets:set OPENAI_API_KEY       # Create secret"
    echo "  firebase functions:secrets:access OPENAI_API_KEY    # List who can access"
    echo "  firebase functions:secrets:destroy OPENAI_API_KEY   # Delete secret"
    echo ""
    echo "Deployment:"
    echo "  firebase deploy --only functions                    # Deploy with secrets"
    echo ""
}

# Main menu
echo "Select an option:"
echo "1) Setup local development secrets"
echo "2) Setup production secrets"
echo "3) Validate current configuration"
echo "4) Show secret management commands"
echo "5) Exit"
echo ""

read -p "Enter option (1-5): " option

case $option in
    1)
        setup_local
        ;;
    2)
        setup_production
        ;;
    3)
        validate_secrets
        ;;
    4)
        show_commands
        ;;
    5)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "✅ Done!"