#!/bin/bash

# Apply the event_data null constraint fix to the database
# This script can be used for both local and production environments

echo "📊 Applying event_data constraint fix..."

# Check if we're running locally or in production
if [ "$1" == "production" ]; then
    echo "🚀 Applying to production database..."
    npx supabase db push
else
    echo "🏗️ Applying to local database..."
    npx supabase migration up --local
fi

echo "✅ Migration applied successfully!"
echo ""
echo "Summary of changes:"
echo "1. Made event_data column nullable (allows NULL values)"
echo "2. Updated any existing NULL event_data values to empty object {}"
echo "3. Added default value 'built_in' for event_type column"
echo "4. Updated iOS app to always provide non-null event_data"
echo ""
echo "This fixes the 'null value in column \"event_data\" violates not-null constraint' error."