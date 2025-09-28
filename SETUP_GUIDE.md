# 🚀 InfiniteStories Setup & Configuration Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Backend Configuration](#backend-configuration)
   - [Option A: Supabase Backend (Recommended)](#option-a-supabase-backend-recommended)
   - [Option B: Direct OpenAI (Legacy)](#option-b-direct-openai-legacy)
4. [Build & Run](#build--run)
5. [Troubleshooting](#troubleshooting)
6. [Advanced Configuration](#advanced-configuration)
7. [Backend Development](#backend-development)

---

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **macOS** | 15.0 (Sequoia) | Latest |
| **Xcode** | 16.0 | 16.1+ |
| **iOS Target** | 18.0 | 18.1+ |
| **Swift** | 6.0 | Latest |
| **RAM** | 8GB | 16GB+ |
| **Storage** | 15GB free | 30GB+ free |

### Required Accounts

1. **Apple Developer Account** (for device testing)
   - Free account works for personal use
   - Paid account ($99/year) required for App Store distribution
   - Sign up at [developer.apple.com](https://developer.apple.com)

2. **Backend Options** - Choose one:

   **A. Supabase Account (Recommended)**
   - Sign up at [supabase.com](https://supabase.com)
   - Free tier includes 500MB database, 1GB storage
   - OpenAI API key configured in Supabase environment
   - Typical cost: $0-25/month depending on usage

   **B. OpenAI Account (Legacy/Direct)**
   - Sign up at [platform.openai.com](https://platform.openai.com)
   - Add payment method for API usage
   - Direct API calls from iOS app
   - Typical cost: $10-20/month for moderate use

---

## Initial Setup

### Step 1: Clone the Repository

```bash
# Using HTTPS
git clone https://github.com/yourusername/infinite-stories.git

# Using SSH
git clone git@github.com:yourusername/infinite-stories.git

# Navigate to project
cd infinite-stories/InfiniteStories
```

### Step 2: Open in Xcode

```bash
# Open the project
open InfiniteStories.xcodeproj

# Or double-click InfiniteStories.xcodeproj in Finder
```

### Step 3: Configure Signing

1. Select the project in Xcode navigator
2. Select "InfiniteStories" target
3. Go to "Signing & Capabilities" tab
4. Enable "Automatically manage signing"
5. Select your Team (Apple ID)
6. Bundle Identifier: `com.yourcompany.infinitestories`

<details>
<summary>📸 Screenshot: Signing Configuration</summary>

```
┌─────────────────────────────────────┐
│ Signing & Capabilities              │
├─────────────────────────────────────┤
│ ☑ Automatically manage signing      │
│ Team: Your Name (Personal Team)     │
│ Bundle ID: com.yourname.infinite... │
│ Signing Certificate: Apple Devel... │
└─────────────────────────────────────┘
```

</details>

### Step 4: Select Target Device

1. Click the scheme selector (next to play button)
2. Choose either:
   - Physical device (if connected)
   - Simulator (iPhone 14 Pro or newer recommended)

```bash
# List available simulators from terminal
xcrun simctl list devices
```

---

## Backend Configuration

### Option A: Supabase Backend (Recommended)

#### Step 1: Create Supabase Project

1. Go to [app.supabase.com](https://app.supabase.com)
2. Click "New Project"
3. Configure:
   - **Project Name**: `infinite-stories`
   - **Database Password**: Generate strong password
   - **Region**: Choose closest to your users
   - **Pricing Plan**: Free tier to start

4. Save these values:
   - **Project URL**: `https://[project-ref].supabase.co`
   - **Anon Key**: `eyJ...` (public key)
   - **Service Role Key**: `eyJ...` (keep secret!)

#### Step 2: Deploy Backend Functions

```bash
# Clone backend repository
git clone https://github.com/yourusername/infinite-stories.git
cd infinite-stories/infinite-stories-backend

# Install dependencies
npm install

# Link to your project
npx supabase link --project-ref [your-project-ref]

# Set up environment variables
cp .env.example .env.local
# Edit .env.local with your OpenAI API key

# Deploy database schema
npx supabase db push

# Deploy edge functions
npx supabase functions deploy

# Verify deployment
npx supabase functions list
```

#### Step 3: Configure iOS App

1. Open `InfiniteStories.xcodeproj`
2. Edit scheme environment variables:
   - `SUPABASE_URL`: Your project URL
   - `SUPABASE_ANON_KEY`: Your anon key

3. Or configure in Settings view:
   ```swift
   // Settings will store in Keychain
   Supabase URL: https://[project-ref].supabase.co
   Supabase Key: eyJ...
   ```

#### Step 4: Test Connection

```bash
# Test story generation endpoint
curl -X POST https://[project-ref].supabase.co/functions/v1/story-generation \
  -H "Authorization: Bearer [anon-key]" \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

### Option B: Direct OpenAI (Legacy)

#### Step 1: Get Your API Key

1. Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Click "Create new secret key"
3. Name it "InfiniteStories"
4. Copy the key (starts with `sk-`)
5. **Important**: Save this key securely - you won't see it again!

### Step 2: Add Credits to Your Account

1. Navigate to [platform.openai.com/billing](https://platform.openai.com/billing)
2. Add payment method
3. Add initial credits ($10 recommended)
4. Set usage limits (optional but recommended)

#### Step 3: Configure in iOS App

1. Run the app
2. Tap the gear icon (Settings)
3. Select "Direct OpenAI" mode
4. Enter your API key
5. Tap "Save API Key"
6. The key is stored securely in iOS Keychain

**Note**: Direct mode sends API calls directly from the device, which is less secure than using Supabase backend.

### API Usage Estimates

#### With Supabase Backend (Cached)

| Activity | Cost (First Time) | Cost (Cached) |
|----------|-------------------|---------------|
| Generate Story | $0.04 | $0.00 |
| Generate Audio | $0.06 | $0.00 |
| Generate Avatar | $0.04 | $0.00 |
| Scene Illustrations (5) | $0.20 | $0.00 |
| **Total per Complete Story** | **$0.34** | **$0.00** |

#### Direct OpenAI (No Caching)

| Activity | Tokens/Chars | Cost |
|----------|-------------|------|
| Generate Story | ~2000 tokens | $0.06 |
| Generate Audio (7 min) | ~3000 chars | $0.09 |
| Generate Avatar | 1 image | $0.04 |
| Scene Illustrations (5) | 5 images | $0.20 |
| **Total per Complete Story** | - | **$0.39** |

Monthly estimates (30 stories):
- Supabase with 50% cache hits: $5.10
- Direct OpenAI: $11.70

---

## Build & Run

### Command Line Build

```bash
# Debug build for simulator
xcodebuild -project InfiniteStories.xcodeproj \
           -scheme InfiniteStories \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           build

# Release build for device
xcodebuild -project InfiniteStories.xcodeproj \
           -scheme InfiniteStories \
           -destination 'generic/platform=iOS' \
           -configuration Release \
           build

# Run tests
xcodebuild test -project InfiniteStories.xcodeproj \
                -scheme InfiniteStories \
                -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Xcode Build

1. Select target device/simulator
2. Press `Cmd + B` to build
3. Press `Cmd + R` to run
4. Press `Cmd + U` to run tests

### First Run Checklist

- [ ] App launches without crashes
- [ ] Settings accessible via gear icon
- [ ] Backend mode selection available (Supabase/Direct)
- [ ] API configuration fields appear
- [ ] Connection test passes
- [ ] Can create first hero with avatar
- [ ] Story generation button (FAB) appears
- [ ] Story generates with illustrations
- [ ] Audio playback works with lock screen controls
- [ ] Reading Journey dashboard accessible

---

## Troubleshooting

### Common Issues & Solutions

#### Issue: "No account for team" error

**Solution:**
```bash
# Sign in to Xcode
Xcode → Settings → Accounts → Add Apple ID
```

#### Issue: "Invalid API Key" error

**Solution:**
1. Verify key starts with `sk-`
2. Check for extra spaces
3. Ensure API key has not been revoked
4. Verify billing is active on OpenAI account

#### Issue: Build fails with "Module not found"

**Solution:**
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData

# Or in Xcode
Product → Clean Build Folder (Shift + Cmd + K)
```

#### Issue: Simulator not available

**Solution:**
```bash
# Download simulator
Xcode → Settings → Platforms → iOS → Download
```

#### Issue: Audio not playing

**Solution:**
1. Check device volume
2. Ensure not in silent mode
3. Force quit and restart app
4. Check audio file exists in Documents

### Debug Mode

Enable verbose logging:

```swift
// In AppConfiguration.swift
struct AppConfiguration {
    static let debugMode = true  // Enable debug logs
    static let useImprovedUI = true
}
```

View logs in Xcode console or:
```bash
# View device logs
xcrun simctl spawn booted log stream --level debug | grep InfiniteStories
```

---

## Backend Development

### Local Supabase Development

```bash
# Start local Supabase
cd infinite-stories-backend
npx supabase start

# Get local credentials
npx supabase status

# Serve functions locally
npx supabase functions serve

# Test with local endpoint
curl http://localhost:54321/functions/v1/story-generation \
  -H "Authorization: Bearer [local-anon-key]" \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

### Database Management

```bash
# Create new migration
npx supabase migration new add_custom_events

# Apply migrations
npx supabase db reset  # Local
npx supabase db push   # Remote

# Access database console
npx supabase db shell
```

### Function Development

```typescript
// supabase/functions/story-generation/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from '@supabase/supabase-js'

serve(async (req) => {
  try {
    // Validate JWT
    const jwt = req.headers.get('Authorization')?.replace('Bearer ', '')
    const { user } = await validateJWT(jwt)

    // Rate limiting
    const limited = await checkRateLimit(user.id, 'story-generation')
    if (limited) {
      return new Response(
        JSON.stringify({ error: 'Rate limit exceeded' }),
        { status: 429 }
      )
    }

    // Process request
    const { hero_id, event } = await req.json()
    const story = await generateStory(hero_id, event)

    return new Response(
      JSON.stringify({ story }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    )
  }
})
```

## Advanced Configuration

### Environment Variables

Create `.xcconfig` file for environment-specific settings:

```bash
// Config/Debug.xcconfig
OPENAI_API_ENDPOINT = https://api.openai.com
API_TIMEOUT = 30
MAX_STORY_LENGTH = 2000
```

### Feature Flags

Edit `AppConfiguration.swift`:

```swift
struct AppConfiguration {
    // UI Settings
    static let useImprovedUI = true  // Enhanced magical UI
    static let enableFloatingAnimations = true
    static let showStatsDashboard = true

    // Backend Settings
    static let useSupabaseBackend = true  // Primary backend
    static let enableBackendFallback = true  // Fall back to direct OpenAI

    // Feature Flags
    static let enableIllustrations = true  // Visual storytelling
    static let enableLockScreenControls = true  // Media controls
    static let enableReadingJourney = true  // Analytics dashboard
    static let enableCustomEvents = true  // Custom story events
    static let enableVoiceInput = false  // Future: iOS 18 Speech
    static let enableOfflineMode = false  // Future: Downloadable packs

    // Performance
    static let maxConcurrentIllustrations = 3
    static let illustrationCacheSize = 100  // MB
    static let audioCacheExpirationDays = 30
    static let enableProMotion = true  // 120Hz displays
}
```

### Custom Schemes

Create different schemes for different configurations:

1. **Development**
   ```
   - Debug mode enabled
   - Verbose logging
   - Mock data available
   ```

2. **Staging**
   ```
   - Production-like environment
   - Real API calls
   - Limited logging
   ```

3. **Production**
   ```
   - Release optimizations
   - No debug code
   - Analytics enabled
   ```

### Build Configurations

```bash
# Debug configuration
xcodebuild -configuration Debug

# Release configuration
xcodebuild -configuration Release

# Custom configuration
xcodebuild -configuration Staging
```

### CI/CD Setup

#### GitHub Actions Example

```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode.app
    
    - name: Build
      run: |
        xcodebuild -project InfiniteStories.xcodeproj \
                   -scheme InfiniteStories \
                   -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
                   build
    
    - name: Test
      run: |
        xcodebuild test -project InfiniteStories.xcodeproj \
                        -scheme InfiniteStories \
                        -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Performance Profiling

```bash
# Profile with Instruments
instruments -t "Time Profiler" \
            -D ~/Desktop/trace.trace \
            InfiniteStories.app
```

### Memory Management

Monitor memory usage:
```swift
// Add to AppDelegate
func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    print("⚠️ Memory Warning - Clearing caches")
    // Clear image caches
    // Clear audio caches
}
```

### Network Configuration

Custom URLSession configuration:
```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30
configuration.timeoutIntervalForResource = 60
configuration.waitsForConnectivity = true
```

### Localization Setup

```bash
# Add language
# In Xcode: Project → Info → Localizations → Add Language

# Export for translation
xcodebuild -exportLocalizations -localizationPath ./Localizations

# Import translations
xcodebuild -importLocalizations -localizationPath ./Localizations/es.xliff
```

---

## Production Deployment

### Pre-flight Checklist

- [ ] Remove all debug code
- [ ] Update version and build numbers
- [ ] Test on multiple devices
- [ ] Verify API endpoints are production
- [ ] Remove or disable console logs
- [ ] Update screenshots for App Store
- [ ] Prepare marketing materials
- [ ] Test In-App Purchases (if applicable)
- [ ] Submit for App Store review

### Archive for App Store

1. Select "Any iOS Device" as target
2. Product → Archive
3. Window → Organizer
4. Select archive → Distribute App
5. Follow App Store Connect workflow

### TestFlight Distribution

```bash
# Upload to TestFlight
xcrun altool --upload-app \
             --type ios \
             --file InfiniteStories.ipa \
             --username "your@email.com" \
             --password "app-specific-password"
```

---

## Backup & Recovery

### Backing Up User Data

User data locations:
- Stories: SwiftData (automatic iCloud backup)
- Audio files: `Documents/` directory
- Settings: UserDefaults + Keychain

### Export User Data

```swift
func exportUserData() -> URL? {
    // Create backup package
    let backupURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("InfiniteStories_Backup.zip")
    
    // Add stories, settings, audio files
    // Return backup file URL
}
```

### Restore from Backup

```swift
func restoreFromBackup(url: URL) {
    // Validate backup file
    // Extract contents
    // Restore to appropriate locations
    // Restart app
}
```

---

## Support Resources

### Documentation

- [README](README.md) - Project overview
- [API Documentation](API_DOCUMENTATION.md) - Technical API reference
- [UI/UX Guide](UI_UX_GUIDE.md) - Design system
- [Contributing](CONTRIBUTING.md) - Contribution guidelines

### Getting Help

1. **GitHub Issues**: [Report bugs](https://github.com/yourusername/infinite-stories/issues)
2. **Discussions**: [Ask questions](https://github.com/yourusername/infinite-stories/discussions)
3. **Email**: support@infinitestories.app
4. **Discord**: [Join community](https://discord.gg/infinitestories)

### Useful Links

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [OpenAI API Reference](https://platform.openai.com/docs)
- [App Store Guidelines](https://developer.apple.com/app-store/guidelines/)

### Monitoring and Analytics

#### Supabase Dashboard

1. **Function Metrics**
   - Navigate to Functions tab
   - View invocation count, errors, duration
   - Set up alerts for failures

2. **Database Analytics**
   ```sql
   -- Story generation stats
   SELECT
     DATE(created_at) as date,
     COUNT(*) as stories_created,
     COUNT(DISTINCT user_id) as unique_users,
     AVG(word_count) as avg_word_count
   FROM stories
   WHERE created_at > NOW() - INTERVAL '30 days'
   GROUP BY DATE(created_at)
   ORDER BY date DESC;

   -- Popular events
   SELECT
     event_type,
     COUNT(*) as usage_count,
     AVG(play_count) as avg_plays
   FROM stories
   GROUP BY event_type
   ORDER BY usage_count DESC;
   ```

3. **Cost Monitoring**
   - Check OpenAI usage via platform.openai.com
   - Monitor Supabase usage in project settings
   - Set up billing alerts

#### iOS App Analytics

```swift
// Track key events
Analytics.track("story_generated", properties: [
    "hero_id": hero.id,
    "event_type": event.rawValue,
    "has_illustrations": true,
    "backend_mode": AppConfiguration.useSupabaseBackend ? "supabase" : "direct"
])

Analytics.track("audio_playback_started", properties: [
    "story_id": story.id,
    "duration": story.estimatedDuration,
    "voice": selectedVoice
])
```

### Performance Optimization

#### iOS Optimizations

1. **Image Caching**
   ```swift
   // Use URLCache for illustrations
   URLCache.shared.memoryCapacity = 50 * 1024 * 1024  // 50 MB
   URLCache.shared.diskCapacity = 200 * 1024 * 1024   // 200 MB
   ```

2. **Lazy Loading**
   - Use `LazyVStack` for story lists
   - Load illustrations on demand
   - Prefetch next story in queue

3. **Background Processing**
   - Generate audio while user reads story
   - Preload next illustration
   - Cache upcoming stories

#### Backend Optimizations

1. **Edge Function Caching**
   ```typescript
   // Cache story generation
   const cacheKey = `story:${hero_id}:${event}:${language}`
   const cached = await cache.get(cacheKey)
   if (cached) return cached

   const story = await generateStory(...)
   await cache.set(cacheKey, story, { expiresIn: 86400 })  // 24 hours
   ```

2. **Database Indexes**
   ```sql
   CREATE INDEX idx_stories_user_created ON stories(user_id, created_at DESC);
   CREATE INDEX idx_heroes_user_active ON heroes(user_id, is_active);
   CREATE INDEX idx_illustrations_story ON story_illustrations(story_id, scene_number);
   ```

---

*Last updated: December 2024*
*Setup Guide Version: 2.0.0*