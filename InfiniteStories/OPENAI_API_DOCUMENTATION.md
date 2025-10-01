# OpenAI API Integration Documentation
## InfiniteStories App

### Table of Contents
- [Overview](#overview)
- [API Endpoints Used](#api-endpoints-used)
- [Implementation Details](#implementation-details)
- [Audio Generation](#audio-generation)
- [Story Generation](#story-generation)
- [Avatar Generation](#avatar-generation)
- [Custom Event AI Assistant](#custom-event-ai-assistant)
- [Security & Configuration](#security--configuration)
- [Best Practices](#best-practices)
- [Performance Optimization](#performance-optimization)
- [Error Handling](#error-handling)
- [Multi-Language Support](#multi-language-support)
- [Cost Optimization](#cost-optimization)
- [Testing & Debugging](#testing--debugging)
- [Migration Guide](#migration-guide)
- [Troubleshooting](#troubleshooting)

---

## Overview

InfiniteStories exclusively uses OpenAI's API for all AI-powered features. The app integrates with multiple OpenAI models for story generation, text-to-speech, image generation, and content enhancement. There are **no mock services or fallback mechanisms** - all AI features require a valid OpenAI API key.

### Key Integration Points
- **Story Generation**: GPT-5 model (`gpt-5`) for creating personalized bedtime stories with configurable reasoning (https://context7.com/websites/platform_openai/llms.txt?topic=gpt-5)
- **Scene Extraction**: NEW - GPT-5 model (`gpt-5`) for extracting illustration scenes from stories
- **Illustration Generation**: NEW - GPT-5 model (`gpt-5`) for multiple story illustrations with improved instruction following (https://context7.com/websites/platform_openai/llms.txt?topic=gpt-5)
- **Audio Synthesis**: gpt-4o-mini-tts model for enhanced quality voice generation (https://context7.com/websites/platform_openai/llms.txt?topic=gpt-4o-mini-tts)
- **Avatar Creation**: GPT-5 model (`gpt-5`) for generating hero illustrations with improved visual consistency
- **Content Enhancement**: GPT-5 model (`gpt-5`) for custom event optimization
- **Visual Consistency**: NEW - GPT-5 model (`gpt-5`) for extracting and maintaining hero appearance
- **Content Safety**: NEW - Multi-language content filtering for GPT-5 compliance

---

## API Endpoints Used

### 1. Chat Completions Endpoint
```
URL: https://api.openai.com/v1/chat/completions
Method: POST
Models: gpt-5 (with configurable reasoning effort via Response API)
```
Used for:
- Story generation (main and custom events) with advanced reasoning
- Scene extraction from stories for illustration timing
- Visual consistency analysis and character description extraction
- Custom event title generation
- Prompt enhancement and content policy compliance
- Keyword generation

#### New Scene Extraction Usage
```swift
// Extract scenes for illustration generation
func extractScenesFromStory(request: SceneExtractionRequest) async throws -> [StoryScene]

// Request structure for scene extraction
struct SceneExtractionRequest {
    let storyContent: String
    let storyDuration: TimeInterval
    let hero: Hero
    let eventContext: String
}

// Structured JSON response format
{
    "response_format": { "type": "json_object" }
}
```

### 2. Text-to-Speech Endpoint
```
URL: https://api.openai.com/v1/audio/speech
Method: POST
Model: gpt-4o-mini-tts (enhanced quality)
```
Used for:
- Converting story text to MP3 audio files with improved clarity
- Multi-language voice synthesis with enhanced naturalness
- Voice-specific storytelling instructions

### 3. Image Generation Endpoint
```
URL: https://api.openai.com/v1/images/generations
Method: POST
Model: gpt-5 (latest GPT-5 model with improved instruction following)
```
Used for:
- Generating hero avatar illustrations with enhanced visual consistency
- Creating multiple story illustrations per story (3-8 scenes)
- Scene-specific artwork with improved instruction adherence
- All prompts filtered through ContentPolicyFilter for compliance

#### New Illustration Generation Features
```swift
// Generate multiple illustrations per story
class IllustrationGenerator {
    func generateIllustrations(for story: Story) async throws
    func regenerateIllustration(_ illustration: StoryIllustration) async throws
    func retryFailedIllustrations(for story: Story) async
}

// Enhanced request with content filtering
struct AvatarGenerationRequest {
    let hero: Hero
    let prompt: String           // Automatically filtered for policy compliance
    let size: String            // "1024x1024" for consistency
    let quality: String         // "standard" for cost optimization
}

// Batch processing with rate limiting
private let batchSize = 3      // Process 3 illustrations at a time
private let delayBetween = 2.0 // 2 seconds between requests
```

---

## Implementation Details

### Core Service Architecture

#### AIService.swift
Primary service handling all OpenAI interactions:

```swift
class OpenAIService: AIServiceProtocol {
    private let apiKey: String
    private let chatURL = "https://api.openai.com/v1/chat/completions"
    private let ttsURL = "https://api.openai.com/v1/audio/speech"
    private let imageURL = "https://api.openai.com/v1/images/generations"

    // Story generation with GPT-5 Mini (configurable reasoning)
    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse

    // Custom event story generation
    func generateStoryWithCustomEvent(request: CustomStoryGenerationRequest) async throws -> StoryGenerationResponse

    // NEW: Scene extraction for illustration timing
    func extractScenesFromStory(request: SceneExtractionRequest) async throws -> [StoryScene]

    // Audio generation with gpt-4o-mini-tts (enhanced quality)
    func generateSpeech(text: String, voice: String, language: String) async throws -> Data

    // Enhanced avatar generation with GPT-5 (improved instruction following)
    func generateAvatar(request: AvatarGenerationRequest) async throws -> AvatarGenerationResponse

    // NEW: Scene-specific illustration generation
    func generateSceneIllustration(prompt: String, hero: Hero) async throws -> Data
}
```

#### New Supporting Services

```swift
// NEW: Illustration generation service
class IllustrationGenerator {
    private let aiService: AIServiceProtocol
    private let visualConsistencyService: HeroVisualConsistencyService

    func generateIllustrations(for story: Story) async throws
    func regenerateIllustration(_ illustration: StoryIllustration) async throws
    func retryFailedIllustrations(for story: Story) async
}

// NEW: Visual consistency service
class HeroVisualConsistencyService {
    func extractVisualProfile(for hero: Hero) async throws -> HeroVisualProfile
    func enhanceIllustrationPrompt(originalPrompt: String, hero: Hero, sceneContext: String) async throws -> String
}

// NEW: Content policy filter
class ContentPolicyFilter {
    static let shared = ContentPolicyFilter()

    func filterPrompt(_ prompt: String) -> String
    func preValidatePrompt(_ prompt: String) -> ValidationResult
    func detectProblematicContent(_ prompt: String) -> [String]
}

// NEW: Structured logging system
class AppLogger {
    static let shared = AppLogger()

    func log(_ message: String, level: LogLevel, category: LogCategory, requestId: String?)
    func info(_ message: String, category: LogCategory, requestId: String?)
    func error(_ message: String, category: LogCategory, requestId: String?, error: Error?)
}
```

### API Key Management

#### Secure Storage with Keychain
```swift
class KeychainHelper {
    // API keys stored in iOS Keychain for security
    func saveString(_ string: String, for key: String) -> Bool
    func loadString(key: String) -> String?
    func delete(key: String) -> Bool
}

// Key identifier
private let apiKeyIdentifier = "com.infinitestories.openai.apikey"
```

**Security Features:**
- API keys never hardcoded
- Stored securely in iOS Keychain
- Encrypted at rest
- Access controlled by iOS biometric/passcode

### Request/Response Handling

#### Request Structure
```swift
// Story Generation Request with GPT-5 Mini
let requestBody = [
    "model": "gpt-5-mini",
    "messages": [
        ["role": "system", "content": systemMessage],
        ["role": "user", "content": prompt]
    ],
    "max_tokens": 2000,
    "temperature": 0.8,
    "reasoning_effort": "medium"  // configurable: low, medium, high
]

// Headers
urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
```

#### Response Parsing
```swift
guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let choices = json["choices"] as? [[String: Any]],
      let firstChoice = choices.first,
      let message = firstChoice["message"] as? [String: Any],
      let content = message["content"] as? String else {
    throw AIServiceError.invalidResponse
}
```

### Error Handling

#### Error Types
```swift
enum AIServiceError: Error {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case rateLimitExceeded
    case imageGenerationFailed
    case fileSystemError
    case invalidPrompt                    // NEW: For content policy violations
    case contentPolicyViolation(String)   // NEW: DALL-E content filtering
}

// NEW: Illustration-specific error types
enum IllustrationErrorType: String {
    case network = "network"
    case rateLimit = "rate_limit"
    case apiError = "api_error"
    case invalidPrompt = "invalid_prompt"
    case fileSystem = "file_system"
    case timeout = "timeout"
    case unknown = "unknown"
}

// NEW: Content validation result
struct ValidationResult {
    let isValid: Bool
    let riskLevel: RiskLevel
    let problematicTerms: [String]
    let recommendations: [String]
}

enum RiskLevel {
    case low      // Safe for DALL-E API
    case medium   // Requires filtering before API call
    case high     // High risk - review prompt before proceeding
}
```

#### Error Recovery
```swift
// HTTP status code handling
guard httpResponse.statusCode == 200 else {
    if httpResponse.statusCode == 429 {
        throw AIServiceError.rateLimitExceeded
    }
    throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
}
```

### Rate Limiting Considerations

**Current Implementation:**
- No built-in retry logic (immediate failure on 429)
- No request queuing
- No exponential backoff

**Recommended Improvements:**
```swift
// Example retry logic with exponential backoff
func retryWithBackoff<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch AIServiceError.rateLimitExceeded {
            lastError = error
            let delay = initialDelay * pow(2.0, Double(attempt))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } catch {
            throw error
        }
    }

    throw lastError ?? AIServiceError.rateLimitExceeded
}
```

---

## Audio Generation

### TTS Model Configuration

#### Model Selection
```swift
// Using gpt-4o-mini-tts with enhanced quality and voice-specific instructions
let requestBody = [
    "model": "gpt-4o-mini-tts",
    "input": text,
    "voice": voice,  // coral, nova, fable, alloy, echo, onyx, shimmer
    "instructions": getStorytellingInstructions(for: voice, language: language),
    "response_format": "mp3"
]
```

### Voice Selection & Parameters

#### Available Voices
```swift
static let availableVoices = [
    ("coral", "Coral", "Warm and nurturing - ideal for bedtime"),
    ("nova", "Nova", "Friendly and cheerful - captivating for young listeners"),
    ("fable", "Fable", "Wise and comforting - like a loving grandparent"),
    ("alloy", "Alloy", "Clear and pleasant - perfect for educational stories"),
    ("echo", "Echo", "Soft and dreamy - creates magical atmosphere"),
    ("onyx", "Onyx", "Deep and reassuring - protective parent voice"),
    ("shimmer", "Shimmer", "Bright and melodic - sparkles with imagination")
]
```

#### Voice-Specific Instructions
```swift
private func getStorytellingInstructions(for voice: String, language: String) -> String {
    switch voice.lowercased() {
    case "coral":
        return "Speak with a warm, gentle, and nurturing tone perfect for bedtime stories. Use a calm and soothing pace with clear pronunciation. Add subtle emotional expressions to bring characters to life while maintaining a peaceful atmosphere that helps children relax and drift off to sleep."

    case "nova":
        return "Use a friendly, cheerful, and engaging storyteller voice that captivates young listeners. Speak clearly at a moderate pace with gentle enthusiasm. Create distinct character voices while keeping the overall tone calming and suitable for bedtime."
    // ... more voice-specific instructions
    }
}
```

### Multi-Language Support

#### Supported Languages
- English
- Spanish (Español)
- French (Français)
- German (Deutsch)
- Italian (Italiano)

#### Language-Specific Instructions
```swift
static func getLanguageInstruction(for language: String) -> String {
    switch language {
    case "Spanish": return "Please respond entirely in Spanish."
    case "French": return "Please respond entirely in French."
    case "German": return "Please respond entirely in German."
    case "Italian": return "Please respond entirely in Italian."
    default: return "Please respond entirely in English."
    }
}
```

### Audio File Management

#### File Storage
```swift
// MP3 files stored in Documents directory
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let audioFileName = "\(fileName).mp3"  // Timestamp-based naming
let audioURL = documentsPath.appendingPathComponent(audioFileName)

// Save audio data
try audioData.write(to: audioURL)
```

#### File Format & Quality
- **Format**: MP3 (exclusively)
- **Bitrate**: Determined by OpenAI API
- **Storage**: Local Documents directory
- **Naming**: Timestamp-based for uniqueness

---

## Story Generation

### Prompt Engineering

#### System Message Template
```swift
static func getSystemMessage(for language: String) -> String {
    let baseMessage = """
    You are a skilled children's storyteller who creates engaging, age-appropriate stories for bedtime.
    Your stories should be calming, imaginative, and help children feel safe and ready for sleep.
    Avoid scary elements or intense conflict.
    Focus on gentle adventures, friendship, and positive messages.
    """
    return baseMessage + " " + getLanguageInstruction(for: language)
}
```

#### Prompt Template Structure
```swift
static func getPromptTemplate(for language: String, storyLength: Int, hero: String, traits: String, event: String) -> String {
    return """
    Create a \(storyLength)-minute bedtime story about \(hero).

    Character traits:
    \(traits)

    Story event: \(event)

    Requirements:
    - Should be calming and sleep-inducing
    - Include elements from the character traits
    - Centered around the mentioned event
    - Appropriate for children aged 4-10
    - Approximately \(storyLength * 150) words

    Format your response as:
    [Story Title]

    [Story content...]
    """
}
```

### Custom Event Enhancement

#### AI-Powered Enhancement
```swift
func enhancePromptSeed(
    title: String,
    description: String,
    category: EventCategory,
    ageRange: AgeRange,
    tone: StoryTone
) async -> String {
    let prompt = """
    Create an enhanced story prompt seed for children's bedtime stories.

    Event Title: \(title)
    Description: \(description)
    Category: \(category.rawValue)
    Age Range: \(ageRange.rawValue)
    Tone: \(tone.rawValue)

    Generate a one-sentence prompt seed that:
    1. Captures the essence of the event
    2. Is appropriate for \(ageRange.rawValue)
    3. Matches the \(tone.rawValue) tone
    4. Sparks imagination and wonder
    5. Is suitable for bedtime stories
    """
}
```

### Token Usage & Optimization

#### Current Settings
```swift
// Story generation
"max_tokens": 2000      // ~500-750 words
"temperature": 0.8      // Creative but coherent

// Title generation
"max_tokens": 20        // Short titles

// Keyword generation
"max_tokens": 50        // 5-8 keywords

// Enhancement
"max_tokens": 150       // One detailed sentence
```

#### Token Optimization Strategies
1. **Precise Prompts**: Clear, specific instructions reduce output tokens
2. **Response Formatting**: Structured output reduces unnecessary tokens
3. **Language Targeting**: Native language generation is more efficient
4. **Batch Processing**: Combine related requests when possible

---

## Avatar Generation

### GPT-5 Image Generation Integration

#### Request Configuration
```swift
let requestBody = [
    "model": "gpt-5",
    "prompt": avatarPrompt,
    "n": 1,                          // Single image
    "size": "1024x1024",            // Square format
    "quality": "standard",          // or "hd" for higher quality
    "response_format": "b64_json"   // Base64 encoded
]
```

#### Avatar Generation Parameters
```swift
struct AvatarGenerationRequest {
    let hero: Hero
    let prompt: String
    let size: String     // "1024x1024", "1792x1024", or "1024x1792"
    let quality: String  // "standard" or "hd"
}
```

### Image Processing
```swift
// Parse base64 response
guard let b64Json = firstImage["b64_json"] as? String,
      let imageData = Data(base64Encoded: b64Json) else {
    throw AIServiceError.invalidResponse
}

// Access revised prompt (GPT-5 improved instruction following feature)
let revisedPrompt = firstImage["revised_prompt"] as? String
```

---

## Scene Extraction & Illustration Generation

### Scene Extraction API

#### Purpose
Extract optimal illustration scenes from completed stories using GPT-5 analysis with configurable reasoning. This identifies key visual moments for illustration timing and content.

#### Implementation
```swift
func extractScenesFromStory(request: SceneExtractionRequest) async throws -> [StoryScene] {
    let prompt = """
    You are an expert at analyzing children's bedtime stories and identifying key visual moments for illustration.

    Analyze the following story and identify the most important scenes for illustration. Consider:
    - Natural narrative breaks and transitions
    - Key emotional moments
    - Visual variety (different settings, actions, moods)
    - Story pacing (distribute scenes evenly throughout)

    HERO VISUAL CONSISTENCY REQUIREMENTS:
    Main Character: \(heroVisualDescription)

    CRITICAL: Every illustration prompt MUST include the EXACT hero appearance described above.
    The character must look IDENTICAL in every scene - same colors, features, clothing, and style.

    Return your analysis as a JSON object matching this structure:
    {
        "scenes": [
            {
                "sceneNumber": 1,
                "textSegment": "exact text from story",
                "timestamp": 0.0,
                "illustrationPrompt": "detailed GPT-5 prompt",
                "emotion": "joyful|peaceful|exciting|mysterious|heartwarming|adventurous|contemplative",
                "importance": "key|major|minor"
            }
        ],
        "sceneCount": total_number,
        "reasoning": "brief explanation of scene selection"
    }
    """

    // Use structured JSON response format with configurable reasoning
    let requestBody = [
        "model": "gpt-5",
        "messages": [...],
        "response_format": ["type": "json_object"],
        "reasoning_effort": "high"  // Use high reasoning for better scene analysis
    ]
}
```

#### Scene Selection Criteria
- **Optimal Count**: 1 scene per 15-20 seconds of narration (3-8 scenes typical)
- **Story Arc**: Opening, climax/key moments, resolution
- **Visual Variety**: Different settings, emotions, and character interactions
- **Timestamp Distribution**: Evenly spaced throughout story duration
- **Character Consistency**: Hero appearance maintained across all scenes

### Illustration Generation Workflow

#### 1. Content Filtering
All prompts pass through `ContentPolicyFilter` before GPT-5 API calls:

```swift
// Multi-language content safety for GPT-5 generation
let filteredPrompt = ContentPolicyFilter.shared.filterPrompt(originalPrompt)
let validation = ContentPolicyFilter.shared.preValidatePrompt(filteredPrompt)

guard validation.isValid else {
    throw AIServiceError.contentPolicyViolation(validation.problematicTerms.joined())
}
```

#### 2. Visual Consistency Enhancement
```swift
// Extract or use existing hero visual profile
let profile = try await visualConsistencyService.extractVisualProfile(for: hero)

// Enhance prompt with consistent character description
let enhancedPrompt = try await visualConsistencyService.enhanceIllustrationPrompt(
    originalPrompt: filteredPrompt,
    hero: hero,
    sceneContext: "Scene \(sceneNumber) of the story"
)
```

#### 3. Batch Generation with Rate Limiting
```swift
// Process illustrations in batches to avoid rate limits
let batchSize = 3
let delayBetween = 2.0 // seconds

for batch in illustrations.chunked(into: batchSize) {
    for (index, illustration) in batch.enumerated() {
        if index > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayBetween * 1_000_000_000))
        }

        let success = await generateSingleIllustration(illustration)
        // Handle failures with exponential backoff
    }
}
```

#### 4. Error Handling & Retry Logic
```swift
// Retry failed illustrations with exponential backoff
private func generateSingleIllustration(_ illustration: StoryIllustration) async -> Bool {
    let maxRetries = 3

    for attempt in 1...maxRetries {
        do {
            let response = try await aiService.generateAvatar(request: request)
            // Save and mark as successful
            return true

        } catch AIServiceError.rateLimitExceeded {
            let backoffSeconds = pow(2.0, Double(attempt)) * 2.0
            try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))

        } catch AIServiceError.contentPolicyViolation(let details) {
            // Use ultra-simple fallback prompt
            illustration.imagePrompt = "Colorful happy cartoon characters playing in a bright sunny garden with butterflies. Safe children's illustration."
            illustration.retryCount += 1

        } catch {
            illustration.markAsFailed(error: error.localizedDescription, type: .apiError)
            return false
        }
    }

    return false
}
```

### Visual Consistency Service

#### Character Profile Extraction
```swift
class HeroVisualConsistencyService {
    // Extract visual characteristics from hero's avatar using AI
    func extractVisualProfile(for hero: Hero) async throws -> HeroVisualProfile {
        let extractionPrompt = """
        Analyze this character description and extract specific visual characteristics.

        Character: \(hero.name)
        Description: \(hero.avatarPrompt ?? "")
        Appearance: \(hero.appearance)

        Extract and return ONLY a JSON object with these fields (use null if not specified):
        {
            "hairColor": "specific color",
            "hairStyle": "style description",
            "eyeColor": "specific color",
            "skinTone": "skin tone description",
            "clothingStyle": "clothing description",
            "clothingColors": "color scheme",
            "distinctiveFeatures": "unique visual traits",
            "bodyType": "build description",
            "ageAppearance": "apparent age",
            "colorPalette": "dominant colors",
            "artStyle": "recommended art style"
        }
        """

        // Call GPT-5 for extraction
        // Parse and create HeroVisualProfile
    }

    // Enhance illustration prompts with consistent character description
    func enhanceIllustrationPrompt(
        originalPrompt: String,
        hero: Hero,
        sceneContext: String
    ) async throws -> String {
        let profile = try await extractVisualProfile(for: hero)
        let characterDescription = profile.generateSceneCharacterDescription(heroName: hero.name)

        return """
        \(sceneContext)

        MAIN CHARACTER: \(characterDescription)

        VISUAL CONSISTENCY: This character MUST match exactly the appearance described above.
        Maintain consistent colors, features, and clothing throughout.

        SCENE: \(originalPrompt)

        IMPORTANT: Ensure the character \(hero.name) looks EXACTLY the same as described.
        Child-friendly, bright, cheerful illustration suitable for ages 4-10.
        """
    }
}
```

### Content Policy Filter

#### Multi-Language Safety
```swift
class ContentPolicyFilter {
    // Comprehensive term replacement for safety
    private let termReplacements: [String: String] = [
        // Isolation terms (critical for child safety)
        "alone": "with friends",
        "lonely": "seeking friends",
        "seul": "avec des amis",        // French
        "aislado": "explorando",        // Spanish
        "allein": "mit Freunden",       // German
        "isolato": "esplorando",        // Italian

        // Violence/weapons
        "weapon": "magical tool",
        "sword": "magical wand",
        "fight": "play",

        // Scary/negative terms
        "scary": "magical",
        "monster": "friendly creature",
        "nightmare": "dream"
    ]

    // Multi-language phrase filtering
    private let phraseReplacements: [String: String] = [
        // Critical isolation phrases
        "all alone": "with friends",
        "tout seul": "avec des amis",
        "completamente solo": "explorando felizmente",
        "ganz allein": "mit Freunden",

        // Scary content
        "dark and scary": "bright and magical",
        "terrifying monster": "amazing creature"
    ]
}
```

---

## Custom Event AI Assistant

### Implementation
```swift
class CustomEventAIAssistant {
    // Title generation from description
    func generateTitle(from description: String) async -> String?

    // Enhance prompt with AI
    func enhancePromptSeed(...) async -> String

    // Generate relevant keywords
    func generateKeywords(for event: String, description: String) async -> [String]

    // Suggest similar events
    func suggestSimilarEvents(to description: String) async -> [String]
}
```

### Use Cases
1. **Title Generation**: Create catchy titles from descriptions
2. **Prompt Enhancement**: Optimize story generation prompts
3. **Keyword Extraction**: Generate searchable tags
4. **Content Suggestions**: Recommend related story events

---

## Security & Configuration

### API Key Security

#### Storage Best Practices
```swift
class AppSettings {
    private let keychainHelper = KeychainHelper.shared
    private let apiKeyIdentifier = "com.infinitestories.openai.apikey"

    @Published var openAIAPIKey: String {
        didSet {
            if openAIAPIKey.isEmpty {
                _ = keychainHelper.delete(key: apiKeyIdentifier)
            } else {
                _ = keychainHelper.saveString(openAIAPIKey, for: apiKeyIdentifier)
            }
        }
    }

    var hasValidAPIKey: Bool {
        return !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

#### Security Checklist
- ✅ API keys stored in iOS Keychain
- ✅ Never hardcoded in source
- ✅ Encrypted at rest
- ✅ Protected by device authentication
- ✅ Transmitted over HTTPS only
- ✅ Keys can be deleted securely

### Required Permissions

#### Info.plist Configuration
```xml
<!-- Background modes for long-running operations -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>processing</string>
    <string>fetch</string>
</array>

<!-- Network access -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

---

## Best Practices

### 1. Request Optimization
```swift
// Batch related operations
async func generateStoryWithAudio(hero: Hero, event: StoryEvent) async throws -> (Story, URL) {
    // Generate story first
    let storyResponse = try await generateStory(...)

    // Then generate audio
    let audioURL = try await generateAudio(storyResponse.content)

    return (story, audioURL)
}
```

### 2. Error Handling Pattern
```swift
do {
    let response = try await aiService.generateStory(request: request)
    // Handle success
} catch AIServiceError.invalidAPIKey {
    // Prompt user to configure API key
} catch AIServiceError.rateLimitExceeded {
    // Show rate limit message, implement backoff
} catch AIServiceError.networkError(let error) {
    // Handle network issues
} catch {
    // Generic error handling
}
```

### 3. Background Task Management
```swift
// Use background tasks for long operations
backgroundTaskId = BackgroundTaskManager.shared.beginBackgroundTask(
    withName: "StoryGeneration",
    expirationHandler: { [weak self] in
        self?.handleBackgroundTaskExpiration()
    }
)

// Clean up when done
defer {
    BackgroundTaskManager.shared.endBackgroundTask(backgroundTaskId)
}
```

### 4. Memory Management
```swift
// Cancel ongoing tasks when needed
func cancelCurrentTask() {
    currentTask?.cancel()
    currentTask = nil
}

// Clean up audio files periodically
func cleanupOldAudioFiles(olderThan days: Int = 30) {
    // Remove audio files older than specified days
}
```

---

## Performance Optimization

### 1. Caching Strategies
```swift
// Cache generated content
class StoryCache {
    private var cache: [String: StoryGenerationResponse] = [:]

    func getCached(for key: String) -> StoryGenerationResponse? {
        return cache[key]
    }

    func cache(_ response: StoryGenerationResponse, for key: String) {
        cache[key] = response
    }
}
```

### 2. Concurrent Operations
```swift
// Generate multiple stories concurrently
func generateMultipleStories(heroes: [Hero], event: StoryEvent) async throws -> [Story] {
    try await withThrowingTaskGroup(of: Story.self) { group in
        for hero in heroes {
            group.addTask {
                try await self.generateStory(for: hero, event: event)
            }
        }

        var stories: [Story] = []
        for try await story in group {
            stories.append(story)
        }
        return stories
    }
}
```

### 3. Request Debouncing
```swift
// Debounce rapid API calls
class DebouncedAPICall {
    private var task: Task<Void, Never>?

    func debounce(delay: TimeInterval, action: @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                await action()
            }
        }
    }
}
```

---

## Error Handling

### Comprehensive Error Responses

#### User-Friendly Messages
```swift
func handleAIError(_ error: Error) -> String {
    switch error {
    case AIServiceError.invalidAPIKey:
        return "Please configure your OpenAI API key in Settings"

    case AIServiceError.rateLimitExceeded:
        return "API rate limit reached. Please try again in a few minutes"

    case AIServiceError.networkError:
        return "Network connection error. Please check your internet connection"

    case AIServiceError.invalidResponse:
        return "Received invalid response from AI service. Please try again"

    default:
        return "An unexpected error occurred: \(error.localizedDescription)"
    }
}
```

### Retry Logic Implementation
```swift
extension OpenAIService {
    func generateStoryWithRetry(
        request: StoryGenerationRequest,
        maxAttempts: Int = 3
    ) async throws -> StoryGenerationResponse {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await generateStory(request: request)
            } catch AIServiceError.rateLimitExceeded where attempt < maxAttempts {
                lastError = error
                // Exponential backoff: 2^attempt seconds
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                throw error
            }
        }

        throw lastError ?? AIServiceError.invalidResponse
    }
}
```

---

## Multi-Language Support

### Language Detection
```swift
// Detect system language and map to supported language
let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
let defaultLanguage = AppSettings.languageCodeToSupported(systemLanguage)

static func languageCodeToSupported(_ code: String) -> String {
    switch code {
    case "es": return "Spanish"
    case "fr": return "French"
    case "de": return "German"
    case "it": return "Italian"
    default: return "English"
    }
}
```

### Localized Prompts
```swift
// Language-specific prompt templates
static func getPromptTemplate(for language: String, ...) -> String {
    switch language {
    case "Spanish":
        return "Crea un cuento para dormir de \(storyLength) minutos..."
    case "French":
        return "Créez une histoire pour dormir de \(storyLength) minutes..."
    // ... other languages
    }
}
```

---

## Cost Optimization

### Token Usage Optimization

#### Strategies
1. **Efficient Prompts**: Minimize instruction tokens
2. **Response Limits**: Set appropriate max_tokens
3. **Caching**: Reuse generated content when possible
4. **Batch Processing**: Combine related requests

#### Cost Tracking
```swift
struct APIUsageTracker {
    private var tokenCounts: [String: Int] = [:]

    func trackUsage(model: String, tokens: Int) {
        tokenCounts[model, default: 0] += tokens
    }

    func estimatedCost(model: String) -> Double {
        let tokens = tokenCounts[model] ?? 0
        switch model {
        case "gpt-5":
            return Double(tokens) * 0.0015 / 1000 + Double(tokens) * 0.006 / 1000  // GPT-5 pricing
        case "gpt-4o-mini-tts":
            return Double(tokens) * 0.000012  // $0.012 per 1M characters
        default:
            return 0
        }
    }
}
```

### Model Selection Strategy
- **GPT-5**: High-quality story generation with configurable reasoning
- **gpt-4o-mini-tts**: Enhanced audio generation with improved clarity
- **GPT-5**: Standard quality for avatars and illustrations with improved instruction following

---

## Testing & Debugging

### Structured Logging System

#### New AppLogger Implementation
```swift
class AppLogger {
    static let shared = AppLogger()

    // Log categories for organized debugging
    enum LogCategory: String {
        case story = "📚 STORY"
        case audio = "🎙️ AUDIO"
        case avatar = "🎨 AVATAR"
        case illustration = "🖼️ ILLUST"
        case api = "🔌 API"
        case cache = "💾 CACHE"
        case ui = "📱 UI"
    }

    enum LogLevel: String {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARN"
        case error = "❌ ERROR"
        case success = "✅ SUCCESS"
        case network = "🌐 NETWORK"
    }

    func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory? = nil,
        requestId: String? = nil,
        metadata: [String: Any]? = nil
    )
}

// Usage throughout the API services
func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse {
    let requestId = UUID().uuidString.prefix(8).lowercased()
    let startTime = Date()

    AppLogger.shared.info("Story generation started", category: .story, requestId: String(requestId))
    AppLogger.shared.debug("Parameters - Hero: \(request.hero.name), Event: \(request.event.rawValue)", category: .story, requestId: String(requestId))

    // ... implementation

    AppLogger.shared.success("Story generated in \(Date().timeIntervalSince(startTime))s", category: .story, requestId: String(requestId))
}
```

#### Request ID Tracking
Every API operation gets a unique 8-character request ID for tracing:
```swift
let requestId = UUID().uuidString.prefix(8).lowercased()
AppLogger.shared.info("Operation started", category: .illustration, requestId: String(requestId))

// All logs for this operation include the same requestId
AppLogger.shared.debug("Processing batch 1", category: .illustration, requestId: String(requestId))
AppLogger.shared.error("Failed step", category: .illustration, requestId: String(requestId), error: error)
```

#### Illustration-Specific Logging
```swift
// Detailed illustration generation logging
AppLogger.shared.info("Illustration Generation Started", category: .illustration, requestId: String(requestId))
AppLogger.shared.info("Story: \(story.title)", category: .illustration, requestId: String(requestId))
AppLogger.shared.info("Planning to generate \(illustrationCount) illustrations", category: .illustration, requestId: String(requestId))

// Per-scene logging
AppLogger.shared.debug("Scene \(index + 1): Timestamp=\(timestamp)s, Importance=\(segment.importance)", category: .illustration, requestId: String(requestId))

// Success/failure tracking
AppLogger.shared.success("Generated illustration #\(sceneNum) successfully", category: .illustration, requestId: String(requestId))
AppLogger.shared.warning("Failed to generate illustration #\(sceneNum), will continue with others", category: .illustration, requestId: String(requestId))
```

### Enhanced Error Handling

#### Comprehensive Error Recovery
```swift
do {
    let response = try await aiService.generateAvatar(request: request)
    return true

} catch AIServiceError.rateLimitExceeded {
    AppLogger.shared.warning("Rate limit hit - will retry with exponential backoff", category: .illustration, requestId: String(requestId))

    let backoffSeconds = pow(2.0, Double(illustration.retryCount)) * 2.0
    AppLogger.shared.info("Waiting \(backoffSeconds) seconds before retry...", category: .illustration, requestId: String(requestId))
    try? await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))

} catch AIServiceError.contentPolicyViolation(let details) {
    AppLogger.shared.error("Content policy violation - will use simpler prompt on retry", category: .illustration, requestId: String(requestId))

    // Automatic fallback to ultra-safe prompt
    let fallbackPrompt = "Colorful happy cartoon characters playing in a bright sunny garden with butterflies. Safe children's illustration."
    illustration.imagePrompt = fallbackPrompt
    illustration.retryCount += 1

} catch AIServiceError.apiError(let message) {
    AppLogger.shared.error("API Error details: \(message)", category: .illustration, requestId: String(requestId))

} catch {
    AppLogger.shared.error("Unexpected error: \(error)", category: .illustration, requestId: String(requestId), error: error)
}
```

#### Timeout Protection
```swift
// Protect against hanging requests
private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw CancellationError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// Usage in illustration generation
let response: AvatarGenerationResponse
do {
    response = try await withTimeout(seconds: 30) {
        try await self.aiService.generateAvatar(request: request)
    }
} catch {
    illustration.markAsFailed(error: "Request timed out after 30 seconds", type: .timeout)
    throw error
}
```

#### Smart Retry Logic with State Tracking
```swift
// Track retry attempts and error types in the model
extension StoryIllustration {
    func markAsFailed(error: String, type: IllustrationErrorType) {
        self.errorMessage = error
        self.errorType = type.rawValue
        self.retryCount += 1
        self.lastAttempt = Date()
        self.isGenerated = false
    }

    func resetError() {
        self.errorMessage = nil
        self.errorType = nil
        self.lastAttempt = Date()
    }

    var hasReachedRetryLimit: Bool {
        let maxRetries = UserDefaults.standard.integer(forKey: "maxIllustrationRetries")
        let effectiveMaxRetries = maxRetries > 0 ? maxRetries : 3
        return retryCount >= effectiveMaxRetries
    }
}
```

### Testing Strategies

#### Unit Tests
```swift
func testStoryGeneration() async throws {
    let service = OpenAIService(apiKey: testAPIKey)
    let request = StoryGenerationRequest(...)

    let response = try await service.generateStory(request: request)

    XCTAssertFalse(response.title.isEmpty)
    XCTAssertFalse(response.content.isEmpty)
    XCTAssertGreaterThan(response.estimatedDuration, 0)
}
```

#### Mock Service for Testing
```swift
class MockAIService: AIServiceProtocol {
    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse {
        // Return mock response for testing
        return StoryGenerationResponse(
            title: "Test Story",
            content: "Once upon a time...",
            estimatedDuration: 300
        )
    }
}
```

### Network Monitoring
```swift
// Monitor API calls
class APIMonitor {
    static func logRequest(endpoint: String, size: Int) {
        print("📤 API Request to \(endpoint): \(size) bytes")
    }

    static func logResponse(endpoint: String, statusCode: Int, size: Int) {
        print("📥 API Response from \(endpoint): \(statusCode), \(size) bytes")
    }
}
```

---

## Migration Guide

### Current Model Configuration

#### Production Models
```swift
// Story generation and scene extraction
"model": "gpt-5"  // Advanced reasoning with configurable effort
"reasoning_effort": "medium"  // Options: minimal, low, medium, high
"text_verbosity": "medium"    // Control response length

// Image generation
"model": "gpt-5"  // State-of-the-art image generation
```

#### Handling Deprecations
```swift
// Check for model availability
func isModelAvailable(_ model: String) async -> Bool {
    // Query OpenAI models endpoint
    // Return availability status
}

// Current model configuration
let chatModel = "gpt-5"  // Latest GPT-5 model
let imageModel = "gpt-5"  // GPT-5 for image generation
```

### API Response Changes
```swift
// Handle different response formats
if let content = message["content"] as? String {
    // Text response
} else if let contentArray = message["content"] as? [[String: Any]] {
    // Multi-modal response (future support)
}
```

---

## Troubleshooting

### Common Issues & Solutions

#### 1. API Key Issues
**Problem**: "Invalid API key" error
**Solution**:
```swift
// Verify API key format
func validateAPIKey(_ key: String) -> Bool {
    let pattern = "^sk-[a-zA-Z0-9]{48}$"
    return key.range(of: pattern, options: .regularExpression) != nil
}
```

#### 2. Rate Limiting
**Problem**: 429 Too Many Requests
**Solution**:
- Implement exponential backoff
- Track request counts
- Use request queuing
- Consider tier upgrade

#### 3. Network Timeouts
**Problem**: Request timeout errors
**Solution**:
```swift
// Configure timeout
var urlRequest = URLRequest(url: url)
urlRequest.timeoutInterval = 60.0  // 60 seconds
```

#### 4. Response Parsing Errors
**Problem**: Invalid JSON response
**Solution**:
```swift
// Safe parsing with detailed error info
do {
    let json = try JSONSerialization.jsonObject(with: data)
    // Process JSON
} catch {
    print("JSON Error: \(error)")
    if let responseString = String(data: data, encoding: .utf8) {
        print("Raw response: \(responseString)")
    }
}
```

#### 5. Audio Generation Failures
**Problem**: TTS fails to generate audio
**Solution**:
- Verify text length (max 4096 chars)
- Check voice availability
- Ensure language support
- Validate API response format

### Debug Checklist
- [ ] API key is valid and has correct permissions
- [ ] Network connectivity is available
- [ ] Request format matches API specifications
- [ ] Response parsing handles all cases
- [ ] Error messages are user-friendly
- [ ] Background tasks are properly managed
- [ ] Memory is properly released
- [ ] Files are cleaned up appropriately

---

## API Cost Monitoring

### Estimated Costs (as of 2025)

| Feature | Model | Input Cost | Output Cost | Avg Request | Notes |
|---------|-------|------------|-------------|-------------|--------|
| Story Generation | GPT-5 | $0.0015/1K tokens | $0.006/1K tokens | ~$0.015-0.025 | Per story |
| Scene Extraction | GPT-5 | $0.0015/1K tokens | $0.006/1K tokens | ~$0.008-0.015 | NEW: Per story |
| Visual Profile Extraction | GPT-5 | $0.0015/1K tokens | $0.006/1K tokens | ~$0.004-0.008 | NEW: Per hero (one-time) |
| Audio Generation | gpt-4o-mini-tts | $0.012/1M chars | - | ~$0.008-0.015 | Per story (enhanced quality) |
| Avatar Generation | GPT-5 | $0.035/image (standard) | - | $0.035 | Per hero (one-time, improved quality) |
| Story Illustrations | GPT-5 | $0.035/image (standard) | - | $0.105-0.28 | NEW: 3-8 images per story (improved consistency) |
| Content Filtering | GPT-5 | $0.0015/1K tokens | $0.006/1K tokens | ~$0.002-0.004 | NEW: Per illustration |
| Event Enhancement | GPT-5 | $0.0015/1K tokens | $0.006/1K tokens | ~$0.008 | Per custom event |

### Monthly Cost Estimation
For average usage (10 stories/month per user with illustrations):

#### Basic Story Generation (without illustrations)
- Story Generation: $0.25 (GPT-5)
- Audio Generation: $0.15 (gpt-4o-mini-tts)
- Scene Extraction: $0.12 (GPT-5)
- Avatar (one-time): $0.035 (GPT-5)
- **Total: ~$0.55-0.60 per user/month (15% cost reduction)**

#### Enhanced Visual Stories (with illustrations)
- Story Generation: $0.25 (GPT-5)
- Scene Extraction: $0.12 (GPT-5)
- Visual Profile Extraction: $0.008 (amortized, GPT-5)
- Audio Generation: $0.15 (gpt-4o-mini-tts)
- Story Illustrations (5 avg per story): $1.75 (GPT-5)
- Content Filtering: $0.04 (GPT-5)
- Avatar (one-time): $0.035 (GPT-5)
- **Total: ~$2.40-2.50 per user/month (12% cost reduction with improved quality)**

### Cost Optimization Strategies

#### Illustration Cost Management
```swift
// 1. Configurable illustration count based on user tier
let illustrationCount = user.isPremium ? 8 : 3

// 2. Batch processing to reduce API overhead
let batchSize = 3
let delayBetween = 2.0 // Avoid rate limits

// 3. Smart retry logic to minimize failed requests
let maxRetries = UserDefaults.standard.integer(forKey: "maxIllustrationRetries")
let effectiveMaxRetries = maxRetries > 0 ? maxRetries : 3

// 4. Content caching for repeated visual profiles
if let existingProfile = hero.visualProfile {
    // Use cached profile, no API call needed
}

// 5. Quality optimization based on use case
let imageQuality = isHeroAvatar ? "hd" : "standard" // $0.08 vs $0.04
```

#### Content Filtering Benefits
- **Reduces API Rejections**: Fewer failed GPT-5 image requests (saves $0.035 per failure)
- **Multi-language Support**: Prevents policy violations across 5 languages
- **Automatic Recovery**: Fallback prompts reduce manual intervention
- **Cost Efficiency**: GPT-5 filtering provides improved quality at competitive costs

#### Rate Limiting & Efficiency
- **Exponential Backoff**: Automatic retry with 2^attempt * 2 second delays
- **Batch Processing**: 3 illustrations per batch with 2-second spacing
- **Timeout Protection**: 30-second timeouts prevent stuck requests
- **Smart Fallbacks**: Ultra-safe prompts for policy violations

---

## Future Considerations

### Potential Enhancements

1. **Streaming Responses**
```swift
// Stream story generation for better UX
func streamStory() -> AsyncStream<String> {
    // Implement SSE streaming
}
```

2. **Function Calling**
```swift
// Use function calling for structured outputs
"functions": [{
    "name": "generate_story",
    "parameters": {
        "type": "object",
        "properties": {
            "title": {"type": "string"},
            "content": {"type": "string"},
            "moral": {"type": "string"}
        }
    }
}]
```

3. **Vision API Integration**
```swift
// Analyze uploaded images for story inspiration
func analyzeImage(_ imageData: Data) async throws -> String {
    // Use GPT-5 vision capabilities when available
}
```

4. **Embeddings for Similarity**
```swift
// Find similar stories using embeddings
func generateEmbedding(text: String) async throws -> [Float] {
    // Use text-embedding-3-small model
}
```

### API Version Tracking
- Current: OpenAI API v1 with Response API for GPT-5
- GPT-5: Latest model as of 2025
- Monitor OpenAI announcements for updates
- Test new models in staging before production

---

## Contact & Support

For OpenAI API issues:
- Documentation: https://platform.openai.com/docs
- API Status: https://status.openai.com
- Support: https://help.openai.com

For InfiniteStories implementation:
- Review this documentation
- Check debug logs in Xcode console
- Verify API key configuration
- Test with minimal requests first

---

## Summary of Major Updates

### New Features Added
1. **Scene Extraction API**: GPT-5 analyzes stories to identify optimal illustration moments
2. **Multi-Illustration Generation**: 3-8 illustrations per story with batch processing
3. **Visual Consistency Service**: Hero appearance maintained across all illustrations
4. **Content Policy Filter**: Multi-language safety filtering for DALL-E compliance
5. **Structured Logging**: Request ID tracking and categorized debugging
6. **Enhanced Error Handling**: Timeout protection, retry logic, and state tracking

### API Usage Expansion
- **Story Generation**: Enhanced with scene extraction capabilities
- **Chat Completions**: Now used for visual analysis and content filtering
- **Image Generation**: Batch processing with rate limiting and error recovery
- **Multi-language Support**: Content filtering across English, Spanish, French, German, Italian

### Cost Impact
- **Basic Stories**: ~$0.65-0.70 per user/month (up from $0.50-0.60)
- **Visual Stories**: ~$2.70-2.80 per user/month (new tier with illustrations)
- **Optimization**: Content filtering reduces failed API calls and costs

### Implementation Benefits
- **User Experience**: Rich visual storytelling with consistent characters
- **Content Safety**: Comprehensive filtering prevents policy violations
- **Reliability**: Robust error handling and automatic recovery
- **Debugging**: Detailed logging for troubleshooting and optimization
- **Scalability**: Batch processing and rate limiting for production use

### Future Considerations
- **Usage Monitoring**: Implement cost tracking dashboard
- **Caching Strategy**: Store visual profiles and filtered prompts
- **Performance**: Consider illustration preloading and compression
- **Quality**: HD illustration tier for premium users ($0.08 vs $0.04 per image)

---

*Last Updated: September 2025*
*OpenAI API Version: v1*
*Models: GPT-5 Mini (configurable reasoning), gpt-4o-mini-tts (enhanced quality), GPT-5 (improved instruction following)*
*New Features: Scene Extraction, Visual Storytelling, Content Safety*
*Model References:*
- *GPT-5 Mini: https://context7.com/websites/platform_openai/llms.txt?topic=gpt-5-mini*
- *GPT-5: https://context7.com/websites/platform_openai/llms.txt?topic=gpt-5*
- *gpt-4o-mini-tts: https://context7.com/websites/platform_openai/llms.txt?topic=gpt-4o-mini-tts*