# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**InfiniteStories** is a SwiftUI iOS/macOS app that generates personalized audio bedtime stories for children. Parents create hero characters with customizable traits, then generate AI-powered stories for different daily events or custom scenarios. Each story is converted to high-quality audio for playback during bedtime, with support for multiple languages and themes.

## Architecture

### Core Data Models (SwiftData)
- **Hero**: Character with name, personality traits, appearance, special abilities, and AI-generated avatar
  - Avatar images stored in Documents/Avatars directory with URL reference in model
  - File existence validation with fallback to icon-based avatar
  - Relationships: stories (one-to-many), visualProfile (one-to-one)
  - Computed properties: avatarURL, hasAvatar, traitsDescription, fullDescription
- **Story**: Enhanced story content with comprehensive illustration support
  - Auto-regenerates audio when content changes via didSet observers
  - Supports both built-in and custom events with dual relationship pattern
  - Advanced illustration management with timeline synchronization
  - Progress tracking, error handling, and retry mechanisms for illustrations
  - Computed properties: eventTitle, eventPromptSeed, hasIllustrations, illustrationProgress
  - Methods: importScenes, updateIllustration, resetFailedIllustrations
- **StoryIllustration**: NEW - Visual storytelling system
  - Audio-synced illustrations with precise timestamps
  - DALL-E prompt storage and image path management
  - Comprehensive error tracking with retry mechanisms
  - Display order management for carousel navigation
  - File existence validation and cleanup support
- **HeroVisualProfile**: NEW - Character consistency system
  - Detailed visual characteristics (hair, eyes, skin, clothing)
  - Canonical and simplified prompts for consistent generation
  - Art style and color palette definitions
  - Methods: generateSceneCharacterDescription, generateStyleConsistencyPrompt
- **CustomStoryEvent**: Enhanced user-defined scenarios with pictogram support
  - Categories, age ranges, and tone settings with comprehensive enums
  - AI-powered prompt enhancement and keyword generation
  - Visual pictogram generation for event representation
  - Usage tracking and favorite management
  - Methods: incrementUsage, updateWithAIEnhancement, toggleFavorite, generatePictogram
- **CharacterTrait**: Enum defining personality options (brave, kind, curious, etc.) with descriptions
- **StoryEvent**: Enum for story contexts (bedtime, school day, birthday, etc.) with icons and prompts

### Services Layer

#### AI Integration (OpenAI Exclusive)
- **AIService**: Centralized OpenAI API integration with enhanced scene extraction
  - **Story Generation**: GPT-4o model (temperature: 0.8, max tokens: 2000)
  - **Scene Extraction**: AI-powered story segmentation for illustration timing
  - **Audio Synthesis**: tts-1-hd model with 7 specialized children's voices
  - **Avatar Generation**: DALL-E 3 (1024x1024, standard quality) with prompt optimization
  - **Illustration Generation**: Multi-scene DALL-E integration with consistency
  - Multi-language support (English, Spanish, French, German, Italian)
  - Secure API key storage in iOS Keychain
  - Comprehensive error handling with typed errors
  - No mock services or fallbacks - OpenAI API required

- **IllustrationGenerator**: NEW - Multi-illustration generation service
  - Scene-based illustration creation with audio timestamp synchronization
  - Hero visual consistency using HeroVisualProfile integration
  - Error-tolerant generation with retry mechanisms
  - File system management for illustration storage
  - Progress tracking and status reporting

- **HeroVisualConsistencyService**: NEW - Character appearance management
  - AI-powered visual characteristic extraction from avatar prompts
  - Consistent character descriptions for scene illustrations
  - Visual profile creation and enhancement with GPT-4
  - Canonical prompt management for character consistency

- **ContentPolicyFilter**: NEW - Child safety and content filtering
  - Comprehensive DALL-E prompt filtering for content policy compliance
  - Multi-language safety term replacement (English, French, Spanish, German, Italian)
  - Isolation term filtering critical for child safety
  - Pre-validation with risk level assessment
  - Detailed logging and replacement tracking

- **AudioService**: Advanced MP3 audio management with comprehensive media controls
  - Lock screen integration via MPNowPlayingInfoCenter and MPRemoteCommandCenter
  - Background audio session management with interruption handling
  - Automatic idle timer management during playback
  - MP3 file management with timestamp-based naming
  - Playback speed control (0.5x to 2.0x) and seeking capabilities
  - Audio route change detection (headphones disconnection)
  - Navigation delegate for story queue management
  - Protocol-based design (AIServiceProtocol, AudioServiceProtocol) for testability

- **IllustrationSyncManager**: NEW - Audio-illustration synchronization
  - Real-time illustration switching based on audio timestamp
  - Smooth transitions between story scenes
  - Progress tracking for illustration display
  - Performance optimization for large illustration sets

- **CustomEventAIAssistant**: AI-powered helper for custom events
  - Title generation from descriptions
  - Prompt seed enhancement based on context
  - Keyword and similar event suggestions

- **EventPictogramGenerator**: NEW - Visual pictogram creation for custom events
  - AI-powered emoji and symbol generation
  - Smart pictogram combinations for complex concepts
  - Fallback system for graceful error handling
  - Context-aware symbol selection based on event metadata

- **PictogramCacheManager**: NEW - Efficient pictogram storage and retrieval
  - In-memory and persistent caching strategies
  - Automatic cache invalidation and cleanup
  - Performance optimization for frequently used pictograms
  - Thread-safe operations for concurrent access

- **AvatarPromptAssistant**: DALL-E prompt generation for hero avatars
  - Automatic prompt enhancement based on hero traits
  - Age-appropriate illustration styles

#### System Services
- **IdleTimerManager**: Prevents screen sleep during audio playback with reference counting
- **BackgroundTaskManager**: Manages iOS background tasks for audio and story processing
- **NetworkService**: Monitors network connectivity and handles network-dependent operations
- **ThemeSettings**: Manages dark/light/system theme preferences
- **Logger**: NEW - Comprehensive logging system
  - Structured logging with categories (story, audio, avatar, illustration, api, cache, ui)
  - Log levels (debug, info, warning, error, success, network)
  - Session tracking and request ID correlation
  - Optional file logging with performance considerations
  - Production-ready with verbose mode controls

### View Architecture (MVVM)

#### Main Views
- **ImprovedContentView**: Enhanced magical UI with integrated floating action button
  - **Floating Action Button**: Inline implementation (64x64pt orange gradient) with continuous animations
  - **Reading Journey Button**: Integrated compact stats button in navigation bar
  - Removed Quick Actions section for cleaner layout
  - Bottom padding (100pt) for floating button clearance
  - Support for magical UI elements (floating clouds, rotating stars, sparkle animations)

- **ContentView**: Original dashboard (deprecated, use ImprovedContentView)

#### Hero Management
- **HeroCreationView**: Multi-step wizard for creating/editing heroes
- **HeroListView**: Complete hero management with edit/delete capabilities
- **HeroAvatarImageView**: Reusable avatar display with async loading
- **AvatarGenerationView**: AI-powered avatar creation workflow
- **AdaptiveHeroGridView**: Responsive hero display grid

#### Story Features
- **StoryGenerationView**: Event selection and story generation interface with illustration support
- **StoryEditView**: In-app story editor with auto-formatting
  - Character/word count tracking
  - Automatic audio regeneration on save
- **ImprovedStoryLibraryView**: Enhanced story list with filtering and sorting
- **HeroSelectionForStoryView**: Hero picker for story generation
- **EnhancedEventPickerView**: Improved event selection with custom events

#### NEW: Illustration Components
- **IllustrationCarouselView**: Visual story display with Ken Burns effect
- **IllustrationSyncView**: Audio-synced illustration viewer with timeline
- **IllustrationLoadingView**: Generation progress with detailed status
- **IllustrationPlaceholderView**: Error handling with retry mechanisms
- **IllustrationThumbnailStrip**: Quick navigation between story scenes

#### Reading Journey
- **ReadingJourneyView**: Comprehensive reading statistics and progress
  - Header stats cards (total stories, listening time, streak, favorites)
  - Activity charts with SwiftUI Charts framework
  - Hero performance analytics
  - Milestones and achievements system
  - Recent activity timeline
  - Reading insights and patterns

#### Audio Playback
- **AudioPlayerView**: Advanced story playback with comprehensive controls
  - Lock screen integration with artwork and metadata
  - Previous/Next story navigation with queue management
  - Dynamic UI updates when switching stories
  - Enhanced audio export with metadata
  - Playback speed control (0.5x to 2.0x)
  - Skip forward/backward 15 seconds

#### Custom Events
- **CustomEventCreationView**: Multi-step wizard for custom scenarios
  - AI-powered enhancement options
  - Category and tone customization
  - Integrated pictogram generation
- **CustomEventManagementView**: NEW - Comprehensive event organization
  - Grid/list view toggle for event display
  - Search and filter capabilities
  - Batch operations for event management
  - Usage statistics visualization
- **CustomEventDetailView**: NEW - Detailed event information display
  - Full event metadata and statistics
  - Pictogram display with regeneration option
  - Event editing and deletion controls
  - Related events and suggestions
- **PictogramGenerationView**: NEW - Visual pictogram creation workflow
  - Real-time AI generation with progress indicators
  - Multiple pictogram suggestions
  - Manual selection and customization
  - Fallback emoji picker for edge cases

#### Settings
- **SettingsView**: API configuration, theme selection, and language preferences

### ViewModels
- **StoryViewModel**: Core business logic and state management
  - Story generation and audio playback coordination
  - Custom events and AI enhancement integration
  - Story queue management for sequential playback
  - Lock screen Now Playing info updates
  - Audio navigation delegate implementation

### Utilities
- **KeychainHelper**: Secure storage for API keys and sensitive data
- **PromptLocalizer**: Multi-language prompt generation and localization
- **AccessibilityEnhancements**: WCAG AA compliance and VoiceOver optimizations
  - Dynamic type support
  - Motion-aware animations
  - High contrast mode detection
- **DataMigrationHelper**: Database migration utilities for app updates
- **ColorExtensions**: Color utility functions for theme support

### Theme System
- **ColorTheme**: Centralized color definitions for light/dark modes
- **ThemeSettings**: User theme preference management (system/light/dark)
- Adaptive UI that responds to system appearance settings

## Key Features

1. **Hero Creation**: Step-by-step character building with AI-generated avatars
2. **Story Generation**: AI-powered stories using OpenAI GPT-4o with scene extraction
3. **Visual Storytelling**: NEW - AI-generated illustrations synchronized with audio
4. **Visual Consistency**: NEW - Character appearance maintained across all illustrations using GPT-Image-1 multi-turn generation
5. **Multi-Turn Image Generation**: NEW - Each illustration references the previous image for perfect visual consistency
6. **Custom Events**: User-defined scenarios with AI enhancement, pictograms, and usage tracking
7. **Multi-Language Support**: 5 languages with localized prompts and voices
8. **Audio Generation**: High-quality MP3 synthesis via tts-1-hd
9. **Story Editing**: In-app editing with automatic audio regeneration
10. **Reading Journey**: Comprehensive statistics and progress tracking with charts
11. **Advanced Audio Playback**: Full-featured player with lock screen controls and queue management
12. **Content Safety**: NEW - Comprehensive child-safe content filtering
13. **Error Resilience**: NEW - Graceful failure handling with retry mechanisms
14. **Theme Support**: Light, dark, and system theme preferences
15. **Accessibility**: Full VoiceOver and Dynamic Type support (WCAG AA)
16. **Hero Management**: Complete CRUD operations with avatar and visual profile support
17. **Background Processing**: Continued operation when app is backgrounded
18. **Performance Optimization**: Device-specific adaptations for smooth operation

## Recent UI Changes

### Floating Action Button (FAB)
- **Implementation**: Integrated directly in ImprovedContentView (not separate component)
- **Position**: Bottom-right corner (20pt right, 30pt bottom from safe area)
- **Design**: Orange gradient circle (64x64pt) with shadow and blur effects
- **Animation**: Continuous rotation and scale feedback on press with haptic feedback
- **Visibility**: Only shown when heroes exist
- **Performance**: Conditional rendering based on device capabilities

### Navigation Updates
- **Reading Journey Button**: Moved to top navigation bar (right side)
  - Compact capsule design with chart icon and streak display
  - Opens full-screen Reading Journey view
- **Story Library**: Moved to Recent Adventures section header
  - Inline button placement for better context

### Layout Improvements
- Removed Quick Actions section entirely for cleaner interface
- Removed Compact Journey Card from main view
- Increased bottom padding (100pt) for FAB clearance
- Expanded Recent Stories to show 6 items (up from 3)
- Enhanced magical UI elements with ambient animations
- Responsive grid layouts for different device sizes
- Illustration carousel integration in story views

## OpenAI API Integration Details

### API Endpoints and Models

#### Story Generation (GPT-4o)
- **Temperature**: 0.8 for creative but coherent output
- **Max Tokens**: 2000 for stories, varies for other uses
- **Enhanced Features**: Scene extraction with timestamps for illustration synchronization
- **Use Cases**:
  - Main story generation with character traits
  - Custom event story generation
  - AI-powered content enhancement
  - Scene segmentation for visual storytelling
  - Visual characteristic extraction for character consistency

#### Audio Synthesis (tts-1-hd)
- **Format**: MP3 exclusively (no fallback TTS)
- **Voices**: 7 specialized children's storytelling voices
- **Features**:
  - Voice-specific narration instructions
  - Multi-language support (5 languages)
  - Background generation support

#### Avatar Generation (GPT-Image-1)
- **Resolution**: 1024x1024, 1024x1536, or 1536x1024 pixels
- **Quality**: Low, medium, or high (mapped from standard/hd)
- **Response**: Base64 encoded (always)
- **Storage**: Documents/Avatars directory with URL reference
- **Content Filtering**: Comprehensive safety filtering before API calls
- **Visual Profiles**: Automatic extraction of character characteristics for consistency
- **New Features**: Background control (auto/transparent/opaque), output format selection (PNG/JPEG)

#### NEW: Illustration Generation (GPT-Image-1 with Multi-Turn)
- **Multi-Scene Support**: Generate multiple illustrations per story
- **Audio Synchronization**: Timestamp-based illustration display
- **Visual Consistency**: Character appearance maintained across scenes using generation ID chaining
- **Multi-Turn Generation**: Each illustration references the previous image for consistency
- **Sequential Processing**: Illustrations generated one by one to maintain generation chain
- **Generation ID Storage**: Persistent generation IDs for future consistency
- **Error Handling**: Retry mechanisms with graceful failure modes and chain recovery
- **Content Safety**: Child-safe content filtering with multi-language support
- **Storage**: Documents/StoryIllustrations directory with organized file management
- **Enhanced Quality**: Improved instruction following and text rendering capabilities

### Security and Best Practices
- API keys stored in iOS Keychain (never hardcoded)
- All communications over HTTPS
- Comprehensive error handling with user-friendly messages
- No silent failures - explicit error reporting
- Rate limit detection (HTTP 429) - needs retry logic implementation

### Cost Optimization
- **Average Monthly Cost**: ~$0.45-0.55 per user (10 stories) - reduced with GPT-Image-1
- **Story Generation**: ~$0.02-0.03 per story
- **Audio Generation**: ~$0.01-0.02 per story
- **Avatar Generation**: $0.02-0.19 per image (low/medium/high quality with GPT-Image-1)
- **Illustration Generation**: $0.02-0.19 per image (token-based pricing)

### Multi-Turn Image Generation Implementation
- **Generation ID Chaining**: Each illustration references the previous image's generation ID
- **Avatar Integration**: First illustration uses hero avatar's generation ID for consistency
- **Sequential Processing**: Illustrations generated one-by-one to maintain visual chain
- **Error Recovery**: Graceful fallback to previous generation IDs when chain breaks
- **Persistent Storage**: Generation IDs stored in Hero and StoryIllustration models
- **API Integration**: `previous_generation_id` parameter added to GPT-Image-1 requests

### Areas for Improvement
- Implement exponential backoff for rate limiting (partially addressed with error handling)
- Add request queuing and batching for non-chained generation scenarios
- Implement usage monitoring and cost tracking with token-based pricing
- Develop content caching strategy for illustrations
- Optimize illustration file size and compression
- Add illustration preloading for better performance

## Development Commands

### Building and Testing
```bash
# Build (requires Xcode installation)
xcodebuild -project InfiniteStories.xcodeproj -scheme InfiniteStories build

# Run tests
xcodebuild -project InfiniteStories.xcodeproj -scheme InfiniteStories test

# Run on simulator (default: iPhone 17)
xcrun simctl boot "iPhone 17"
xcodebuild -project InfiniteStories.xcodeproj -scheme InfiniteStories \
  -destination 'platform=iOS Simulator,name=iPhone 17' run
```

### API Configuration
1. Configure OpenAI API key in Settings view (stored in Keychain)
2. OpenAI API is mandatory - no mock services or fallbacks
3. Audio uses tts-1-hd with voice-specific instructions
4. Multi-language support via prompt localization

## Key Technologies

- **SwiftUI**: Declarative UI with navigation, sheets, and animations
- **SwiftData**: Model persistence with relationships and migrations
- **AVFoundation**: MP3 audio playback and management
- **MediaPlayer**: Lock screen and remote control integration
- **BackgroundTasks**: iOS background processing for long operations
- **Combine**: Reactive programming for ViewModels
- **URLSession**: HTTP requests for OpenAI APIs
- **Network**: Connectivity monitoring
- **Security**: Keychain Services for secure storage
- **Charts**: Native SwiftUI charts for Reading Journey

## File Structure

```
InfiniteStories/
├── Models/
│   ├── Hero.swift                  # Character model with avatar and visual profile support
│   ├── HeroVisualProfile.swift     # NEW - Character consistency model
│   ├── Story.swift                 # Enhanced story model with illustration management
│   ├── StoryIllustration.swift     # NEW - Visual storytelling model
│   ├── CustomStoryEvent.swift      # Enhanced custom event model with usage tracking
│   └── CharacterTraits.swift       # Enums for traits/events with descriptions
├── Views/
│   ├── HeroCreation/
│   │   └── HeroCreationView.swift  # Hero creation wizard
│   ├── HeroManagement/
│   │   └── HeroListView.swift      # Hero CRUD operations
│   ├── AvatarGeneration/
│   │   └── AvatarGenerationView.swift # AI avatar creation
│   ├── Components/
│   │   ├── HeroAvatarImageView.swift  # Avatar display component
│   │   ├── IllustrationCarouselView.swift # NEW - Visual story display
│   │   ├── IllustrationSyncView.swift # NEW - Audio-synced illustration viewer
│   │   ├── IllustrationLoadingView.swift # NEW - Generation progress
│   │   ├── IllustrationPlaceholderView.swift # NEW - Error handling
│   │   └── IllustrationThumbnailStrip.swift # NEW - Quick navigation
│   ├── ReadingJourney/
│   │   └── ReadingJourneyView.swift   # Statistics and progress
│   ├── StoryGeneration/
│   │   ├── StoryGenerationView.swift  # Story creation
│   │   ├── HeroSelectionForStoryView.swift # Hero picker
│   │   └── EnhancedEventPickerView.swift  # Event selection
│   ├── CustomEvents/
│   │   ├── CustomEventCreationView.swift  # Custom event wizard
│   │   ├── CustomEventManagementView.swift # NEW - Event organization
│   │   ├── CustomEventDetailView.swift    # NEW - Event details
│   │   └── PictogramGenerationView.swift  # NEW - Pictogram creation
│   ├── StoryEdit/
│   │   └── StoryEditView.swift     # Story content editor
│   ├── StoryLibrary/
│   │   └── ImprovedStoryLibraryView.swift # Enhanced library
│   ├── AudioPlayer/
│   │   └── AudioPlayerView.swift   # Audio playback UI
│   ├── HeroDisplay/
│   │   └── AdaptiveHeroGridView.swift # Responsive hero grid
│   ├── Settings/
│   │   └── SettingsView.swift      # App configuration
│   ├── ContentView.swift           # Original dashboard (deprecated)
│   └── ImprovedContentView.swift   # Enhanced magical UI with FAB
├── Services/
│   ├── AIService.swift             # Enhanced OpenAI integration with scene extraction
│   ├── IllustrationGenerator.swift # NEW - Multi-illustration generation
│   ├── HeroVisualConsistencyService.swift # NEW - Character consistency
│   ├── ContentPolicyFilter.swift   # NEW - Child safety filtering
│   ├── IllustrationSyncManager.swift # NEW - Audio-illustration sync
│   ├── Logger.swift                # NEW - Comprehensive logging system
│   ├── AudioService.swift          # Audio generation/playback with protocol design
│   ├── CustomEventAIAssistant.swift # AI event enhancement
│   ├── EventPictogramGenerator.swift # NEW - Visual pictogram generation
│   ├── PictogramCacheManager.swift # NEW - Pictogram caching system
│   ├── AvatarPromptAssistant.swift # Avatar prompt generation
│   ├── IdleTimerManager.swift      # Screen sleep prevention
│   ├── BackgroundTaskManager.swift # Background processing
│   ├── NetworkService.swift        # Network monitoring
│   └── ThemeSettings.swift         # Theme management
├── ViewModels/
│   └── StoryViewModel.swift        # Core business logic
├── Utilities/
│   ├── KeychainHelper.swift        # Secure storage
│   ├── PromptLocalizer.swift       # Multi-language support
│   ├── AccessibilityEnhancements.swift # A11y utilities
│   ├── DataMigrationHelper.swift   # DB migrations
│   └── ColorExtensions.swift       # Color utilities
├── Theme/
│   └── ColorTheme.swift            # Color definitions
├── AppConfiguration.swift          # App feature flags
└── InfiniteStoriesApp.swift        # App entry point
```

## Configuration Options

### AppConfiguration.swift
- `useImprovedUI`: Toggle between original and enhanced magical UI (default: true)
- `enableFloatingAnimations`: Control performance-heavy animations
- `maxRecentStories`: Number of stories on home screen (default: 6)
- `enableHapticFeedback`: Haptic feedback for interactions
- `showStatsDashboard`: Display statistics on home screen

### UserDefaults Settings (NEW)
- `allowIllustrationFailures: true`: Graceful illustration failure handling
- `showIllustrationErrors: false`: Error visibility control
- `maxIllustrationRetries: 3`: Retry attempt limits for failed illustrations
- `enableDetailedLogging: true`: Comprehensive logging for debugging

### Theme Preferences
- System: Follow device appearance
- Light: Force light mode
- Dark: Force dark mode

### Language Support
- English, Spanish, French, German, Italian
- Localized AI prompts
- Language-specific voice synthesis

## Development Notes

### Model Management
- SwiftData `@Model` and `@Relationship` for persistence
- Automatic audio regeneration on content changes
- AI enhancement and usage tracking for custom events
- Hero deletion preserves stories (nullify relationship)
- Avatar images stored separately with URL reference

### View Architecture
- SwiftUI patterns with `@State`, `@Query`, `@Environment`
- Enhanced views for magical UI experience
- Multi-step wizards for complex workflows
- Adaptive layouts for all screen sizes
- Floating action button pattern for primary CTA
- Computed properties for reactive UI updates

### Service Layer
- Protocol-based clean architecture
- Centralized OpenAI integration
- MP3 files in Documents with timestamp naming
- Background processing for long operations
- Media controls via MPNowPlayingInfoCenter
- Navigation delegate for queue management

### Error Handling
- User-friendly API failure messages
- No silent fallbacks - explicit errors
- Network monitoring for optimal UX
- Graceful feature degradation
- Typed errors for audio export

### Security
- Keychain storage for API keys
- No hardcoded credentials
- HTTPS for all API calls
- Encrypted storage at rest

### Performance
- Idle timer disabled during playback
- Reference counting for resources
- Background task registration
- Device-adaptive performance
- Lazy loading for story queues
- Conditional rendering for animations

### Accessibility
- Full VoiceOver support
- Dynamic Type scaling
- Motion preference respect
- WCAG AA compliance
- 44pt minimum touch targets

### Testing
- Unit tests for critical services
- UI tests for user flows
- Test coverage for core paths

## Recent Updates

### Latest Features
- **Custom Event Pictograms**: NEW - AI-generated visual representations for custom events
- **Event Management System**: NEW - Comprehensive event organization and statistics
- **Pictogram Caching**: NEW - Efficient storage and retrieval of generated pictograms
- **Story Illustrations**: AI-generated visual storytelling with audio synchronization
- **Visual Consistency**: Character appearance maintained across all story scenes
- **Content Safety**: Comprehensive child-safe content filtering system
- **Enhanced Logging**: Structured logging with categories and request tracking
- **Error Resilience**: Graceful failure handling with retry mechanisms
- **Performance Optimization**: Device-specific adaptations for smooth operation
- **Floating Action Button**: Primary CTA at bottom-right with haptic feedback
- **Reading Journey**: Comprehensive statistics dashboard with charts
- **AI Avatars**: DALL-E generated hero illustrations with visual profiles
- **Enhanced UI**: Magical interface with ambient animations
- **Navigation Updates**: Streamlined button placement and inline components
- **Multi-Language**: 5 language support with safety filtering
- **Custom Events**: AI-enhanced story scenarios with usage tracking
- **Story Editing**: In-app editor with auto-audio regeneration
- **Advanced Audio**: Lock screen controls and queue management

### App Info.plist Configuration
- Background modes: audio, processing, fetch
- Privacy descriptions for microphone (if needed)
- URL schemes for deep linking (if implemented)

### Known Limitations
- OpenAI API required (no offline mode)
- Network required for generation
- Local MP3 and illustration storage consumption
- iOS scheduling for background tasks
- Limited retry logic for rate limits (partial implementation)
- Limited caching strategy for illustrations (TODO)
- Illustration generation can be slow for complex scenes
- Device storage requirements increased with visual storytelling

## Important Instructions for Development

- **Always** use SwiftData for model persistence
- **Never** use mock services - OpenAI API only
- **Store** API keys in Keychain, never hardcode
- **Handle** errors explicitly with user messages
- **Disable** idle timer during audio playback
- **Enable** background modes for audio/processing
- **Follow** SwiftUI patterns and best practices
- **Maintain** 44pt minimum touch targets
- **Support** VoiceOver and Dynamic Type
- **Test** on both iPhone and iPad devices

## Cost and Usage Guidelines

- Monitor API usage to control costs (increased with illustration generation)
- Implement caching where appropriate (especially for illustrations)
- Consider batch operations for efficiency
- Track user usage patterns for optimization
- Plan for ~$0.65-0.85 per active user monthly (reduced with GPT-Image-1 migration)
- Illustration generation adds ~$0.15-0.25 per story with visual content (reduced costs)
- Content filtering reduces API rejections and associated costs
- Token-based pricing provides better cost predictability

## Important Instruction Reminders

Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.

IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context unless it is highly relevant to your task.
- AppStore validation preparation
- Always fix the build