<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**InfiniteStories** is a SwiftUI iOS/macOS app that generates personalized AI-powered audio bedtime stories for children. Parents create hero characters with customizable traits, then generate stories for different events or custom scenarios. Stories are converted to high-quality audio with AI-generated illustrations.

## ⚠️ API-Only Architecture

**CRITICAL**: App requires active internet connection. Hero/Story data are NOT persisted locally.

### Key Principles
1. **No Local Persistence**: Hero/Story data fetched from backend API only
2. **Network Required**: App blocks usage when offline
3. **URLCache for Media**: Images/audio cached automatically by iOS
4. **Loading States**: Show loading indicators, not optimistic updates
5. **Error Handling**: Network errors block actions until connection restored

### Data Flow
```
User Action → Repository → APIClient → Backend API → Update View State
                ↑ Network Error? → Show Error → Block Usage ↓
```

## Architecture

### Core Data Models

**SwiftData Usage:**
- **Hero/Story/CustomStoryEvent**: NOT persisted - transient objects from API (managed via repositories)
- **Local-only SwiftData**: HeroVisualProfile, StoryIllustration (preferences/cache)

**Key Models:**
- **Hero**: Character with traits, appearance, AI-generated avatar (via HeroRepository)
- **Story**: Content with illustrations, audio sync (via StoryRepository)
- **StoryIllustration**: Audio-synced visuals with timestamps, DALL-E prompts
- **HeroVisualProfile**: Character consistency for illustrations
- **CustomStoryEvent**: User-defined scenarios with AI enhancement
- **CharacterTrait/StoryEvent**: Enums for personality and story contexts

### Services & Repositories

**Repository Layer (API-only):**
- **HeroRepository**: CRUD operations, avatar generation via backend
- **StoryRepository**: Story/audio/illustration generation (GPT-4o, gpt-4o-mini-tts)
- **CustomEventRepository**: CRUD operations, AI enhancement via backend

**Network & Error Handling:**
- **NetworkMonitor**: Real-time connectivity status, blocks offline operations
- **APIClient**: HTTP client with retry logic, auth injection, rate limit handling
- **RetryPolicy**: Exponential backoff (default: 3 retries, 1s base delay)
- **ErrorView**: User-friendly error display with retry
- **NetworkRequiredView**: Shown when offline

**AI Services:**
- **IllustrationGenerator**: Multi-scene generation with audio sync
- **HeroVisualConsistencyService**: Character appearance consistency
- **ContentPolicyFilter**: Child-safe content filtering (multi-language)
- **AudioService**: MP3 playback with lock screen controls, speed control
- **IllustrationSyncManager**: Real-time audio-illustration sync
- **CustomEventAIAssistant**: AI-powered event enhancement
- **EventPictogramGenerator**: Visual pictogram creation
- **Logger**: Structured logging with categories and levels

**System Services:**
- **IdleTimerManager**: Screen sleep prevention during playback
- **BackgroundTaskManager**: iOS background task management
- **ThemeSettings**: Dark/light/system theme

### Views & ViewModels

**Main Views:**
- **ImprovedContentView**: Magical UI with FAB (floating action button), Reading Journey button
- **HeroCreationView**: Multi-step wizard for heroes
- **StoryGenerationView**: Event selection, story generation
- **AudioPlayerView**: Lock screen controls, playback speed, queue navigation
- **ReadingJourneyView**: Statistics, charts, analytics
- **CustomEventCreationView**: Custom scenarios with AI enhancement

**Illustration Components:**
- **IllustrationCarouselView**: Ken Burns effect visual display
- **IllustrationSyncView**: Audio-synced viewer with timeline
- **IllustrationLoadingView/PlaceholderView**: Progress and error handling

**ViewModels:**
- **StoryViewModel**: Business logic, story/audio coordination, queue management

**Utilities:**
- **KeychainHelper**: Secure storage
- **PromptLocalizer**: Multi-language support
- **AccessibilityEnhancements**: WCAG AA, VoiceOver, Dynamic Type
- **ColorTheme**: Light/dark mode definitions

## Key Features

1. **AI Story Generation**: GPT-4o stories with multi-turn illustration consistency
2. **Audio Playback**: MP3 synthesis (gpt-4o-mini-tts) with lock screen controls
3. **Visual Storytelling**: Audio-synced illustrations with character consistency
4. **Custom Events**: User-defined scenarios with AI enhancement and pictograms
5. **Multi-Language**: 5 languages with localized prompts/voices
6. **Content Safety**: Child-safe filtering (multi-language)
7. **Reading Journey**: Statistics dashboard with charts
8. **Accessibility**: VoiceOver, Dynamic Type (WCAG AA)
9. **Theme Support**: Light/dark/system modes

## Technical Details

**OpenAI Integration:** See `docs/OPENAI_INTEGRATION.md` for API details, cost optimization, and multi-turn image generation.

**Development Guide:** See `docs/DEVELOPMENT.md` for build commands, configuration, and best practices.

**Task Management:** Use PRD Skills (e.g., `/prd-task-management`, `/prd-project-overview`) for task management. See `tools/prd/README.md` for CLI details.

## Key Technologies

SwiftUI, SwiftData, AVFoundation, MediaPlayer, BackgroundTasks, Combine, URLSession, Network, Security (Keychain), Charts

## File Structure

```
infinite-stories-ios/InfiniteStories/
├── Models/           # Hero, Story, StoryIllustration, HeroVisualProfile, CustomStoryEvent
├── Views/            # HeroCreation, StoryGeneration, AudioPlayer, ReadingJourney, CustomEvents
├── Services/         # AI, Audio, Network, Illustration, Logger
├── Repositories/     # Hero, Story, CustomEvent (API-only)
├── Network/          # APIClient, Endpoint, APIError, RetryPolicy
├── ViewModels/       # StoryViewModel
├── Utilities/        # KeychainHelper, PromptLocalizer, Accessibility
└── Theme/            # ColorTheme
```

See code for detailed structure.

## Critical Development Rules

**Architecture:**
- **API-Only**: Hero/Story NOT persisted locally - use repositories only
- **SwiftData**: Only for preferences (CustomStoryEvent, HeroVisualProfile, StoryIllustration)
- **Network**: Check `NetworkMonitor.shared.isConnected` before API calls
- **Error Handling**: Show ErrorView with retry for all API failures
- **Loading States**: Use `@State` with loading/error/data, not optimistic updates
- **No Mocks**: Backend API only, never mock services
- **Security**: API keys in Keychain, never hardcode

**Task Management with PRD Skills:**
Use PRD Skills (slash commands) for all task management - they provide the correct context and formatting.

Available PRD Skills:
- `/prd-task-management` - Create, update, list tasks with priorities and statuses
- `/prd-project-overview` - View project stats, epic progress, task summaries
- `/prd-dependencies` - Manage task dependencies and blockers
- `/prd-agent-management` - Create agents, assign tasks, sync work
- `/prd-automation` - Git integration, hooks, file watching
- `/prd-database-management` - Initialize DB, run migrations
- `/breakdown` - Break down tasks into smaller subtasks
- `/auto-vibe` - Iterate through next tasks automatically

Quick Reference:
- Database: `tools/prd.db`
- Binary: `tools/prd/target/release/prd`
- Always prefer skills over direct CLI commands

**Best Practices:**
- URLCache handles media caching automatically
- Disable idle timer during audio playback
- 44pt minimum touch targets
- VoiceOver and Dynamic Type support
- Test offline error handling

**General:**
- Do what was asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files
- NEVER proactively create documentation files

<!-- nx configuration start-->
<!-- Leave the start & end comments to automatically receive updates. -->

# General Guidelines for working with Nx

- When running tasks (for example build, lint, test, e2e, etc.), always prefer running the task through `nx` (i.e. `nx run`, `nx run-many`, `nx affected`) instead of using the underlying tooling directly
- You have access to the Nx MCP server and its tools, use them to help the user
- When answering questions about the repository, use the `nx_workspace` tool first to gain an understanding of the workspace architecture where applicable.
- When working in individual projects, use the `nx_project_details` mcp tool to analyze and understand the specific project structure and dependencies
- For questions around nx configuration, best practices or if you're unsure, use the `nx_docs` tool to get relevant, up-to-date docs. Always use this instead of assuming things about nx configuration
- If the user needs help with an Nx configuration or project graph error, use the `nx_workspace` tool to get any errors

<!-- nx configuration end-->