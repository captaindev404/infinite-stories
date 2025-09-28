# 🔌 InfiniteStories API Documentation

## Overview

This document provides comprehensive API documentation for the InfiniteStories iOS application, including service protocols, data models, and integration guidelines.

## Table of Contents

1. [AI Service](#ai-service)
2. [Audio Service](#audio-service)
3. [Data Models](#data-models)
4. [View Models](#view-models)
5. [Storage Services](#storage-services)
6. [Error Handling](#error-handling)
7. [OpenAI Integration](#openai-integration)

---

## AI Service

### Protocol: `AIServiceProtocol`

```swift
protocol AIServiceProtocol {
    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse
    func generateSpeech(text: String, voice: String) async throws -> Data
}
```

### Class: `OpenAIService`

Implementation of AI service using OpenAI's API.

#### Initialization

```swift
let aiService = OpenAIService(apiKey: "your-api-key-here")
```

#### Methods

##### `generateStory(request:)`

Generates a personalized story based on hero and event parameters.

**Parameters:**
- `request: StoryGenerationRequest` - Contains hero details and story parameters

**Returns:**
- `StoryGenerationResponse` - Generated story with title and content

**Example:**

```swift
let request = StoryGenerationRequest(
    hero: hero,
    event: .bedtime,
    targetDuration: 420 // 7 minutes
)

do {
    let response = try await aiService.generateStory(request: request)
    print("Generated story: \(response.title)")
} catch {
    print("Generation failed: \(error)")
}
```

##### `generateSpeech(text:voice:)`

Converts text to speech using OpenAI's TTS API.

**Parameters:**
- `text: String` - Text to convert to speech
- `voice: String` - Voice identifier (nova, fable, alloy, echo, onyx, shimmer)

**Returns:**
- `Data` - MP3 audio data

**Example:**

```swift
let audioData = try await aiService.generateSpeech(
    text: story.content,
    voice: "nova"
)
```

### Configuration

#### API Endpoints

```swift
private let chatURL = "https://api.openai.com/v1/chat/completions"
private let ttsURL = "https://api.openai.com/v1/audio/speech"
```

#### Model Configuration

```swift
// Story Generation
"model": "gpt-4o"
"max_tokens": 2000
"temperature": 0.8

// Text-to-Speech
"model": "tts-1-hd"
"response_format": "mp3"
```

---

## Audio Service

### Protocol: `AudioServiceProtocol`

```swift
protocol AudioServiceProtocol {
    func generateAudioFile(from text: String, fileName: String, voice: String) async throws -> URL
    func playAudio(from url: URL) throws
    func playTextToSpeechDirectly(text: String)
    func pauseAudio()
    func resumeAudio()
    func seek(to time: TimeInterval)
    func setAIService(_ service: AIServiceProtocol)
    func stopAudio()
    func setPlaybackSpeed(_ speed: Float)
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var isUsingSpeechSynthesis: Bool { get }
}
```

### Class: `AudioService`

Manages audio playback and generation.

#### Key Properties

```swift
@Published var isPlaying: Bool
@Published var currentTime: TimeInterval
@Published var duration: TimeInterval
var isUsingSpeechSynthesis: Bool
```

#### Methods

##### `generateAudioFile(from:fileName:voice:)`

Creates an audio file from text using OpenAI TTS or local synthesis.

**Parameters:**
- `text: String` - Story content
- `fileName: String` - Desired file name (without extension)
- `voice: String` - Voice selection for TTS

**Returns:**
- `URL` - Location of generated audio file

**Throws:**
- `AudioServiceError.fileCreationFailed` - If file cannot be created

##### `playAudio(from:)`

Plays audio from a URL (MP3 or text file).

**Parameters:**
- `url: URL` - Audio file location

**Throws:**
- `AudioServiceError.playbackFailed` - If playback cannot start

##### `seek(to:)`

Seeks to specific time in audio (MP3 only).

**Parameters:**
- `time: TimeInterval` - Target position in seconds

**Note:** Seeking is not supported for TTS playback.

---

## Data Models

### Hero Model

```swift
@Model
final class Hero {
    var id: UUID
    var name: String
    var primaryTrait: CharacterTrait
    var secondaryTrait: CharacterTrait
    var appearance: String
    var specialAbility: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade)
    var stories: [Story] = []
}
```

#### Character Traits

```swift
enum CharacterTrait: String, CaseIterable, Codable {
    case brave = "Brave"
    case kind = "Kind"
    case funny = "Funny"
    case clever = "Clever"
    case magical = "Magical"
    case musical = "Musical"
    case athletic = "Athletic"
    case artistic = "Artistic"
    case scientific = "Scientific"
    case nature_loving = "Nature-Loving"
}
```

### Story Model

```swift
@Model
final class Story {
    var id: UUID
    var title: String
    var content: String
    var event: StoryEvent
    var createdAt: Date
    var playCount: Int
    var isFavorite: Bool
    var estimatedDuration: TimeInterval
    var audioFileName: String?
    var hero: Hero?
}
```

#### Story Events

```swift
enum StoryEvent: String, CaseIterable, Codable {
    case bedtime = "Bedtime"
    case adventure = "Adventure"
    case holiday = "Holiday"
    case learning = "Learning"
    
    var icon: String {
        switch self {
        case .bedtime: return "moon.stars"
        case .adventure: return "map"
        case .holiday: return "gift"
        case .learning: return "book"
        }
    }
    
    var promptSeed: String {
        switch self {
        case .bedtime:
            return "Create a calming, gentle story perfect for bedtime..."
        case .adventure:
            return "Create an exciting adventure story with challenges..."
        case .holiday:
            return "Create a festive story celebrating special occasions..."
        case .learning:
            return "Create an educational story that teaches valuable lessons..."
        }
    }
}
```

### Request/Response Models

#### StoryGenerationRequest

```swift
struct StoryGenerationRequest {
    let hero: Hero
    let event: StoryEvent
    let targetDuration: TimeInterval // in seconds (300-600)
}
```

#### StoryGenerationResponse

```swift
struct StoryGenerationResponse {
    let title: String
    let content: String
    let estimatedDuration: TimeInterval
}
```

---

## View Models

### StoryViewModel

Main view model coordinating story generation and playback.

```swift
@MainActor
class StoryViewModel: ObservableObject {
    @Published var isGeneratingStory: Bool
    @Published var isGeneratingAudio: Bool
    @Published var generationError: String?
    @Published var selectedEvent: StoryEvent
    @Published var isPlaying: Bool
    @Published var isPaused: Bool
    @Published var currentTime: TimeInterval
    @Published var duration: TimeInterval
    @Published var playbackSpeed: Float
}
```

#### Key Methods

##### `generateStory(for:event:)`

```swift
func generateStory(for hero: Hero, event: StoryEvent) async {
    isGeneratingStory = true
    defer { isGeneratingStory = false }
    
    do {
        let request = StoryGenerationRequest(hero: hero, event: event, targetDuration: 420)
        let response = try await aiService.generateStory(request: request)
        
        let story = Story(
            title: response.title,
            content: response.content,
            event: event,
            hero: hero
        )
        
        modelContext?.insert(story)
        try modelContext?.save()
        
        await generateAudioForStory(story)
    } catch {
        generationError = handleAIError(error)
    }
}
```

##### `playStory(_:)`

```swift
func playStory(_ story: Story) {
    guard let audioFileName = story.audioFileName else {
        Task {
            await generateAudioForStory(story)
        }
        return
    }
    
    playAudioFile(fileName: audioFileName)
    story.incrementPlayCount()
    try? modelContext?.save()
}
```

---

## Storage Services

### KeychainHelper

Secure storage for sensitive data like API keys.

```swift
class KeychainHelper {
    static let shared = KeychainHelper()
    
    func saveString(_ string: String, for key: String) -> Bool
    func loadString(key: String) -> String?
    func delete(key: String) -> Bool
}
```

#### Usage Example

```swift
// Save API key
let success = KeychainHelper.shared.saveString(apiKey, for: "openai.apikey")

// Load API key
if let apiKey = KeychainHelper.shared.loadString(key: "openai.apikey") {
    // Use API key
}

// Delete API key
KeychainHelper.shared.delete(key: "openai.apikey")
```

### AppSettings

User preferences and configuration.

```swift
class AppSettings: ObservableObject {
    @Published var openAIAPIKey: String
    @Published var preferredVoice: String
    @Published var defaultStoryLength: Int
    
    var hasValidAPIKey: Bool {
        !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

#### Available Voices

```swift
static let availableVoices: [(id: String, name: String, description: String)] = [
    ("alloy", "Alloy", "Clear and versatile"),
    ("echo", "Echo", "Warm and engaging"),
    ("fable", "Fable", "Perfect for storytelling"),
    ("onyx", "Onyx", "Deep and authoritative"),
    ("nova", "Nova", "Bright and cheerful (great for children)"),
    ("shimmer", "Shimmer", "Soft and gentle")
]
```

---

## Error Handling

### AIServiceError

```swift
enum AIServiceError: Error {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case rateLimitExceeded
}
```

### AudioServiceError

```swift
enum AudioServiceError: Error {
    case speechUnavailable
    case fileCreationFailed
    case playbackFailed
}
```

### Error Handling Example

```swift
private func handleAIError(_ error: Error) -> String {
    if let aiError = error as? AIServiceError {
        switch aiError {
        case .invalidAPIKey:
            return "Please configure your OpenAI API key in settings"
        case .networkError:
            return "Network error. Please check your internet connection"
        case .invalidResponse:
            return "Received invalid response from AI service"
        case .apiError(let message):
            return "API Error: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        }
    } else {
        return "An unexpected error occurred: \(error.localizedDescription)"
    }
}
```

---

## OpenAI Integration

### Authentication

Add API key to request headers:

```swift
urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
```

### Request Format

#### Chat Completion (Story Generation)

```json
{
    "model": "gpt-4o",
    "messages": [
        {
            "role": "system",
            "content": "You are a skilled children's storyteller..."
        },
        {
            "role": "user",
            "content": "Create a 7-minute bedtime story..."
        }
    ],
    "max_tokens": 2000,
    "temperature": 0.8
}
```

#### Text-to-Speech

```json
{
    "model": "tts-1-hd",
    "input": "Story text here...",
    "voice": "nova",
    "response_format": "mp3"
}
```

### Response Handling

#### Chat Completion Response

```swift
guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let choices = json["choices"] as? [[String: Any]],
      let firstChoice = choices.first,
      let message = firstChoice["message"] as? [String: Any],
      let content = message["content"] as? String else {
    throw AIServiceError.invalidResponse
}
```

#### TTS Response

The TTS endpoint returns raw MP3 data:

```swift
let (data, response) = try await URLSession.shared.data(for: urlRequest)
guard let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200 else {
    throw AIServiceError.invalidResponse
}
return data // MP3 audio data
```

### Rate Limiting

Handle rate limits gracefully:

```swift
if httpResponse.statusCode == 429 {
    throw AIServiceError.rateLimitExceeded
}
```

### Best Practices

1. **Always validate API responses** before processing
2. **Implement retry logic** for transient failures
3. **Cache generated content** to minimize API calls
4. **Use appropriate models** for each task
5. **Monitor token usage** to control costs
6. **Implement fallback mechanisms** for API failures

---

## Testing

### Mock Services

Create mock implementations for testing:

```swift
class MockAIService: AIServiceProtocol {
    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse {
        return StoryGenerationResponse(
            title: "Test Story",
            content: "Once upon a time...",
            estimatedDuration: 300
        )
    }
    
    func generateSpeech(text: String, voice: String) async throws -> Data {
        return Data() // Return mock MP3 data
    }
}
```

### Unit Test Example

```swift
func testStoryGeneration() async throws {
    let mockService = MockAIService()
    let viewModel = StoryViewModel(aiService: mockService)
    
    let hero = Hero(name: "Test", primaryTrait: .brave, secondaryTrait: .kind)
    await viewModel.generateStory(for: hero, event: .bedtime)
    
    XCTAssertFalse(viewModel.isGeneratingStory)
    XCTAssertNil(viewModel.generationError)
}
```

---

## Performance Considerations

### Caching Strategy

```swift
// Cache audio files locally
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let audioURL = documentsPath.appendingPathComponent("\(fileName).mp3")
```

### Async/Await Best Practices

```swift
// Use Task groups for parallel operations
await withTaskGroup(of: Void.self) { group in
    group.addTask { await self.generateStory() }
    group.addTask { await self.generateAudio() }
}
```

### Memory Management

```swift
// Clean up audio resources
deinit {
    audioPlayer?.stop()
    audioPlayer = nil
}
```

---

## Migration Guide

### Version 1.0 to 1.1

```swift
// Old API
func generateStory(hero: Hero) async -> Story?

// New API
func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse
```

### Data Model Changes

```swift
// Added in v1.1
var estimatedDuration: TimeInterval
var audioFileName: String?
```

---

## Appendix

### API Rate Limits

| Endpoint | Limit | Window |
|----------|-------|--------|
| Chat Completion | 10,000 tokens/min | 1 minute |
| TTS | 3 requests/min | 1 minute |

### Token Estimation

- Average story: 500-800 tokens
- System prompt: 100 tokens
- Response: 600-1000 tokens
- Total per story: ~1500-2000 tokens

### Cost Estimation

| Service | Cost | Unit |
|---------|------|------|
| GPT-4 | $0.03 | per 1K tokens |
| TTS HD | $0.03 | per 1K characters |

Average cost per story: $0.05-0.10

---

*Last updated: September 2025*
*API Version: 1.0.0*