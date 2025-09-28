# 👩‍💻 InfiniteStories Developer Guide

## Overview

This comprehensive guide provides everything developers need to work on the InfiniteStories iOS application - a SwiftUI 6.0 app with SwiftData persistence, Supabase backend integration, and advanced AI features for personalized children's storytelling.

### Latest Updates (December 2024)
- **SwiftUI 6.0** - Latest declarative UI with enhanced animations
- **SwiftData Integration** - Modern persistence layer with CloudKit sync
- **Supabase Backend** - Scalable edge functions for AI operations
- **Visual Storytelling** - AI-generated illustrations synchronized with audio
- **Content Safety** - Multi-layer filtering for child-appropriate content

## Table of Contents

1. [Development Environment](#development-environment)
2. [Architecture Overview](#architecture-overview)
3. [Core Components](#core-components)
4. [API Integration](#api-integration)
5. [State Management](#state-management)
6. [Data Persistence](#data-persistence)
7. [Audio System](#audio-system)
8. [UI Development](#ui-development)
9. [Testing Strategy](#testing-strategy)
10. [Performance Optimization](#performance-optimization)
11. [Debugging Guide](#debugging-guide)
12. [Release Process](#release-process)

---

## Development Environment

### Required Tools

```bash
# Check Xcode version
xcodebuild -version
# Should be: Xcode 16.0 or later

# Check Swift version
swift --version
# Should be: Swift 6.0 or later

# Install SwiftLint (optional but recommended)
brew install swiftlint

# Install xcbeautify for prettier build output
brew install xcbeautify

# Install Supabase CLI (for backend development)
brew install supabase/tap/supabase

# Verify installations
supabase --version  # Should be 1.100+
node --version      # Should be 18+ for backend
```

### Project Setup

```bash
# Clone repository
git clone https://github.com/yourusername/infinite-stories.git
cd infinite-stories/InfiniteStories

# Open in Xcode
open InfiniteStories.xcodeproj

# Or use command line
xcodebuild -list -project InfiniteStories.xcodeproj
```

### Development Workflow

1. **Feature Branch Strategy**
   ```bash
   git checkout -b feature/your-feature-name
   # Make changes
   git add .
   git commit -m "feat: add new feature"
   git push origin feature/your-feature-name
   ```

2. **Commit Message Convention**
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation
   - `style:` Code style changes
   - `refactor:` Code refactoring
   - `test:` Test additions/changes
   - `chore:` Maintenance tasks

---

## Architecture Overview

### SwiftUI 6.0 + SwiftData Architecture

The app uses modern Apple frameworks with a clean MVVM architecture:

```swift
// SwiftData Model with relationships
@Model
final class Hero {
    var id: UUID = UUID()
    var name: String
    var primaryTrait: CharacterTrait
    var visualProfile: HeroVisualProfile?  // For consistency

    @Relationship(deleteRule: .cascade)
    var stories: [Story] = []

    var avatarGenerationId: String?  // DALL-E generation ID
}

// SwiftUI 6.0 View with new features
struct ImprovedContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var heroes: [Hero]
    @StateObject private var viewModel = StoryViewModel()

    var body: some View {
        // Enhanced UI with animations
    }
}

// ViewModel with Supabase integration
@MainActor
class StoryViewModel: ObservableObject {
    private let supabaseService: SupabaseService
    private let aiService: AIService  // Fallback

    @Published var isGeneratingStory = false
    @Published var illustrationProgress: Double = 0
}
```

### Dependency Injection

Services are injected through environment or initializers:

```swift
// Service Protocol
protocol AIServiceProtocol {
    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse
}

// Concrete Implementation
class OpenAIService: AIServiceProtocol { ... }

// Injection in ViewModel
class StoryViewModel: ObservableObject {
    private let aiService: AIServiceProtocol
    
    init(aiService: AIServiceProtocol = OpenAIService()) {
        self.aiService = aiService
    }
}
```

### Modern Architecture Stack

```
┌───────────────────────────────────────────────┐
│        UI Layer (SwiftUI 6.0 Views)         │
│    • ImprovedContentView (FAB, animations)  │
│    • ReadingJourneyView (Charts framework)  │
│    • IllustrationCarouselView (Ken Burns)   │
├───────────────────────────────────────────────┤
│      ViewModels (Business Logic Layer)      │
│    • StoryViewModel (queue management)       │
│    • AudioNavigationDelegate                │
├───────────────────────────────────────────────┤
│          Service Layer (Dual Mode)          │
│    • SupabaseService (primary backend)      │
│    • AIService (fallback to OpenAI)         │
│    • AudioService (lock screen integration) │
│    • ContentPolicyFilter (safety)           │
├───────────────────────────────────────────────┤
│        Data Layer (SwiftData + Cloud)       │
│    • @Model persistence                     │
│    • CloudKit sync                          │
│    • Keychain for secrets                   │
├───────────────────────────────────────────────┤
│         Backend (Supabase Edge Functions)   │
│    • Story generation endpoint              │
│    • Audio synthesis endpoint               │
│    • Image generation endpoints             │
└───────────────────────────────────────────────┘
```

---

## Core Components

### Models

#### Hero Model

```swift
@Model
final class Hero {
    var id: UUID = UUID()
    var name: String
    var primaryTrait: CharacterTrait
    var secondaryTrait: CharacterTrait
    var appearance: String
    var specialAbility: String
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .cascade)
    var stories: [Story] = []
    
    init(name: String, primaryTrait: CharacterTrait, secondaryTrait: CharacterTrait, 
         appearance: String = "", specialAbility: String = "") {
        self.name = name
        self.primaryTrait = primaryTrait
        self.secondaryTrait = secondaryTrait
        self.appearance = appearance
        self.specialAbility = specialAbility
    }
}
```

#### Story Model

```swift
@Model
final class Story {
    var id: UUID = UUID()
    var title: String
    var content: String
    var event: StoryEvent
    var createdAt: Date = Date()
    var playCount: Int = 0
    var isFavorite: Bool = false
    var estimatedDuration: TimeInterval = 0
    var audioFileName: String?
    
    var hero: Hero?
    
    func incrementPlayCount() {
        playCount += 1
    }
}
```

### ViewModels

#### StoryViewModel

Primary ViewModel handling story generation and playback:

```swift
@MainActor
class StoryViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var isGeneratingStory = false
    @Published var isGeneratingAudio = false
    @Published var generationError: String?
    
    // Service dependencies
    private let aiService: AIServiceProtocol
    private let audioService: AudioServiceProtocol
    
    // Core functionality
    func generateStory(for hero: Hero, event: StoryEvent) async { ... }
    func playStory(_ story: Story) { ... }
    func pauseAudio() { ... }
    func resumeAudio() { ... }
}
```

---

## API Integration

### Supabase Backend Integration (Primary)

#### Service Configuration

```swift
class SupabaseService {
    private let supabase: SupabaseClient

    init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "")!,
            supabaseKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        )
    }

    // Story generation with backend
    func generateStory(hero: Hero, event: StoryEvent) async throws -> StoryResponse {
        let token = try await getAuthToken()

        let response = try await supabase.functions.invoke(
            "story-generation",
            options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(token)"],
                body: StoryGenerationRequest(
                    heroId: hero.id,
                    event: event,
                    targetDuration: 300,
                    language: "en"
                )
            )
        )

        return try response.decode(as: StoryResponse.self)
    }
}
```

### OpenAI Service Implementation (Fallback)

#### Request Structure

```swift
struct OpenAIRequest: Codable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let temperature: Double
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}
```

#### Making API Calls

```swift
func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse {
    // 1. Prepare request
    let systemPrompt = createSystemPrompt(for: request.hero)
    let userPrompt = createUserPrompt(for: request.event)
    
    // 2. Create URL request
    var urlRequest = URLRequest(url: URL(string: chatURL)!)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // 3. Make request
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    // 4. Parse response
    let json = try JSONDecoder().decode(OpenAIResponse.self, from: data)
    
    // 5. Extract story
    return parseStoryFromResponse(json)
}
```

#### Error Handling

```swift
enum APIError: LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case networkError(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your settings."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        }
    }
}
```

---

## State Management

### SwiftUI 6.0 State Management

#### Observable Macro (New in Swift 6)

```swift
@Observable
class StoryViewModel {
    var stories: [Story] = []
    var isLoading = false
    var illustrationProgress: Double = 0

    func loadStories() async {
        isLoading = true
        defer { isLoading = false }

        // Load from SwiftData
        stories = await fetchStoriesFromDatabase()
    }
}

// In View
struct StoryListView: View {
    @State private var viewModel = StoryViewModel()

    var body: some View {
        List(viewModel.stories) { story in
            StoryCard(story: story)
        }
        .task {
            await viewModel.loadStories()
        }
    }
}
```

### Using @Published Properties (Legacy)

```swift
class StoryViewModel: ObservableObject {
    @Published var stories: [Story] = []
    @Published var isLoading = false
    
    func loadStories() {
        isLoading = true
        // Load stories
        isLoading = false
    }
}
```

### SwiftData Integration with CloudKit

```swift
// App configuration with CloudKit sync
@main
struct InfiniteStoriesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Hero.self,
            Story.self,
            StoryIllustration.self,
            HeroVisualProfile.self,
            CustomStoryEvent.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // Enable CloudKit sync
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// Using in Views
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Hero.createdAt, order: .reverse)
    private var heroes: [Hero]

    @Query(filter: #Predicate<Story> { story in
        story.isFavorite == true
    }) private var favoriteStories: [Story]

    var body: some View {
        // UI implementation
    }
}
```

### Combine Publishers

```swift
class AudioService: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var timerSubscription: AnyCancellable?
    
    func startPlayback() {
        timerSubscription = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.updateCurrentTime()
            }
    }
}
```

---

## Data Persistence

### SwiftData Configuration

```swift
@main
struct InfiniteStoriesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Hero.self,
            Story.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
```

### SwiftData CRUD Operations with Relationships

```swift
// Create with relationships
let hero = Hero(
    name: "Luna",
    primaryTrait: .brave,
    secondaryTrait: .kind
)

// Create visual profile for consistency
let visualProfile = HeroVisualProfile(
    hairColor: "brown",
    hairStyle: "curly",
    eyeColor: "green",
    skinTone: "warm",
    clothingStyle: "adventurer outfit"
)
hero.visualProfile = visualProfile

modelContext.insert(hero)
try modelContext.save()

// Read with complex queries
@Query(filter: #Predicate<Story> { story in
    story.createdAt > Date.now.addingTimeInterval(-604800) &&
    story.playCount > 0
}, sort: \Story.playCount, order: .reverse)
private var recentlyPlayedStories: [Story]

// Update with automatic audio regeneration
story.content = updatedContent  // Triggers didSet observer
// Audio regeneration happens automatically
try modelContext.save()

// Delete with cascade
modelContext.delete(hero)  // Deletes all related stories
try modelContext.save()

// Batch operations
let batchDelete = Delete<Story>(
    predicate: #Predicate { story in
        story.createdAt < Date.now.addingTimeInterval(-2592000)  // 30 days
    }
)
try modelContext.execute(batchDelete)
```

### Migration Strategy

```swift
// Future migration example
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Hero.self, Story.self, UserSettings.self]
    }
}
```

---

## Audio System

### Enhanced Audio Pipeline with Lock Screen Integration

```
Text → Supabase/OpenAI TTS → MP3 Data → File System → AVAudioPlayer
  │                                                          │
  │                                                          ↓
  │                                              MPNowPlayingInfoCenter
  │                                              MPRemoteCommandCenter
  ↓ (fallback)
AVSpeechSynthesizer → Direct Playback
```

### Implementation Details with Media Controls

```swift
class AudioService: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var speechSynthesizer = AVSpeechSynthesizer()
    weak var navigationDelegate: AudioNavigationDelegate?

    // Lock screen integration
    private func setupNowPlaying(story: Story) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: story.title,
            MPMediaItemPropertyArtist: "InfiniteStories",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: audioPlayer?.currentTime ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: audioPlayer?.rate ?? 1.0,
            MPMediaItemPropertyPlaybackDuration: audioPlayer?.duration ?? 0
        ]

        // Add artwork if available
        if let illustration = story.illustrations?.first,
           let image = UIImage(contentsOfFile: illustration.imagePath) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: image.size
            ) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // Remote command handling
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            self.resumeAudio()
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            self.pauseAudio()
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { _ in
            self.skip(seconds: 15)
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { _ in
            self.navigationDelegate?.playPreviousStory()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            self.navigationDelegate?.playNextStory()
            return .success
        }
    }
    
    private func saveAudioData(_ data: Data, fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                    in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("\(fileName).mp3")
        try data.write(to: audioURL)
        return audioURL
    }
}
```

### Audio Session Configuration

```swift
func configureAudioSession() {
    do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        print("Failed to configure audio session: \(error)")
    }
}
```

---

## UI Development

### Custom Components

#### Creating Reusable Views

```swift
struct StoryCard: View {
    let story: Story
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card content
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(radius: isPressed ? 2 : 8)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}
```

#### View Modifiers

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 8)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

### Animation Guidelines

```swift
// Spring animations for interactive elements
.animation(.spring(response: 0.3, dampingFraction: 0.7))

// Ease in/out for transitions
.animation(.easeInOut(duration: 0.3))

// Continuous animations for ambient effects
.animation(.linear(duration: 20).repeatForever(autoreverses: false))
```

### Responsive Design

```swift
struct AdaptiveView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .compact {
            // iPhone layout
            VStack { content }
        } else {
            // iPad layout
            HStack { content }
        }
    }
}
```

---

## Testing Strategy

### Unit Tests with Modern Swift Testing

```swift
import Testing
@testable import InfiniteStories

// Using Swift Testing framework (new in Swift 6)
@Suite("Story Generation Tests")
struct StoryGenerationTests {
    @Test("Hero creation with visual profile")
    func testHeroCreation() async throws {
        let hero = Hero(
            name: "Luna",
            primaryTrait: .brave,
            secondaryTrait: .kind
        )

        let visualProfile = HeroVisualProfile(
            hairColor: "brown",
            hairStyle: "curly",
            eyeColor: "green"
        )
        hero.visualProfile = visualProfile

        #expect(hero.name == "Luna")
        #expect(hero.primaryTrait == .brave)
        #expect(hero.visualProfile?.hairColor == "brown")
    }

    @Test("Supabase backend integration")
    func testSupabaseStoryGeneration() async throws {
        let supabase = SupabaseService()
        let hero = Hero(name: "Test", primaryTrait: .brave, secondaryTrait: .kind)

        let story = try await supabase.generateStory(
            hero: hero,
            event: .magicalForestAdventure
        )

        #expect(!story.title.isEmpty)
        #expect(story.scenes.count > 0)
        #expect(story.estimatedDuration > 0)
    }
    
    func testStoryGeneration() async throws {
        let mockService = MockAIService()
        let viewModel = StoryViewModel(aiService: mockService)
        
        let hero = Hero(name: "Test", primaryTrait: .brave, secondaryTrait: .kind)
        await viewModel.generateStory(for: hero, event: .bedtime)
        
        XCTAssertFalse(viewModel.isGeneratingStory)
        XCTAssertNil(viewModel.generationError)
    }
}
```

### UI Tests

```swift
import XCTest

class InfiniteStoriesUITests: XCTestCase {
    func testHeroCreationFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Tap create hero button
        app.buttons["Create Your First Hero"].tap()
        
        // Fill in hero details
        app.textFields["Hero name"].tap()
        app.textFields["Hero name"].typeText("Luna")
        
        // Select traits
        app.pickers["Primary trait"].tap()
        app.pickerWheels.element.adjust(toPickerWheelValue: "Brave")
        
        // Save hero
        app.buttons["Save Hero"].tap()
        
        // Verify hero was created
        XCTAssertTrue(app.staticTexts["Luna"].exists)
    }
}
```

### Integration Tests

```swift
func testEndToEndStoryGeneration() async throws {
    // Create hero
    let hero = Hero(name: "Test", primaryTrait: .brave, secondaryTrait: .kind)
    
    // Generate story
    let aiService = OpenAIService(apiKey: testAPIKey)
    let request = StoryGenerationRequest(hero: hero, event: .bedtime, targetDuration: 300)
    let response = try await aiService.generateStory(request: request)
    
    // Verify response
    XCTAssertFalse(response.title.isEmpty)
    XCTAssertFalse(response.content.isEmpty)
    XCTAssertGreaterThan(response.estimatedDuration, 0)
}
```

---

## Performance Optimization

### SwiftUI 6.0 Performance Enhancements

#### View Performance

```swift
// Use @State for view-local state
struct StoryCard: View {
    let story: Story
    @State private var isPressed = false  // View-local state

    var body: some View {
        VStack {
            // Content
        }
        .animation(.spring(), value: isPressed)  // Explicit animation
        .task {  // Structured concurrency
            await loadThumbnail()
        }
    }
}

// Use task modifier for async work
struct StoryLibraryView: View {
    @Query private var stories: [Story]

    var body: some View {
        ScrollView {
            LazyVStack {  // Lazy loading
                ForEach(stories) { story in
                    StoryCard(story: story)
                        .task { @MainActor in
                            // Load additional data if needed
                        }
                }
            }
        }
    }
}
```

### Memory Management with ARC and Swift 6

```swift
// Weak references to prevent retain cycles
class AudioService: NSObject, ObservableObject {
    weak var delegate: AudioServiceDelegate?
}

// Cleanup in deinit
deinit {
    audioPlayer?.stop()
    audioPlayer = nil
    speechSynthesizer.stopSpeaking(at: .immediate)
}
```

### Lazy Loading with SwiftData Pagination

```swift
struct StoryLibraryView: View {
    @Query(sort: \Story.createdAt, order: .reverse)
    private var allStories: [Story]

    @State private var visibleRange = 0..<20

    var visibleStories: [Story] {
        Array(allStories.prefix(visibleRange.upperBound))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(visibleStories) { story in
                    StoryCard(story: story)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }

                if visibleRange.upperBound < allStories.count {
                    ProgressView()
                        .onAppear {
                            withAnimation {
                                visibleRange = 0..<min(
                                    visibleRange.upperBound + 20,
                                    allStories.count
                                )
                            }
                        }
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)  // iOS 16+
    }
}
```

### Image Optimization

```swift
// Async image loading
AsyncImage(url: imageURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fit)
} placeholder: {
    ProgressView()
}
.frame(width: 60, height: 60)
```

### Caching Strategy

```swift
class CacheManager {
    private let cache = NSCache<NSString, NSData>()
    
    func cacheAudio(data: Data, for key: String) {
        cache.setObject(data as NSData, forKey: key as NSString)
    }
    
    func getCachedAudio(for key: String) -> Data? {
        return cache.object(forKey: key as NSString) as Data?
    }
}
```

---

## Debugging Guide

### Structured Logging with Logger (iOS 14+)

```swift
import OSLog

class Logger {
    private let subsystem = "com.infinitestories.app"

    // Category-specific loggers
    static let story = Logger(category: "story")
    static let audio = Logger(category: "audio")
    static let avatar = Logger(category: "avatar")
    static let illustration = Logger(category: "illustration")
    static let api = Logger(category: "api")
    static let ui = Logger(category: "ui")

    private let logger: os.Logger

    init(category: String) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String, metadata: [String: Any]? = nil) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String, metadata: [String: Any]? = nil) {
        logger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String, error: Error? = nil) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String, error: Error) {
        logger.error("\(message, privacy: .public) - Error: \(error.localizedDescription, privacy: .public)")
    }
}

// Usage
Logger.story.info("Generating story for hero", metadata: ["heroId": hero.id])
Logger.api.error("API call failed", error: apiError)
```

### Enable Debug Logging (Legacy)

```swift
// In AppConfiguration.swift
struct AppConfiguration {
    static let debugMode = true
    static let verboseLogging = true
}

// Usage in code
if AppConfiguration.debugMode {
    print("🔍 Debug: \(message)")
}
```

### Console Output

```swift
// Structured logging
func log(_ message: String, type: LogType = .info) {
    let emoji = type.emoji
    let timestamp = DateFormatter.localizedString(from: Date(), 
                                                 dateStyle: .none, 
                                                 timeStyle: .medium)
    print("\(emoji) [\(timestamp)] \(message)")
}

enum LogType {
    case info, warning, error, success
    
    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .success: return "✅"
        }
    }
}
```

### Memory Debugging

```swift
// Use Instruments for memory profiling
// Product → Profile → Leaks

// Add memory warnings
func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    print("⚠️ Memory warning received")
    // Clear caches
    imageCache.removeAllObjects()
    audioCache.removeAllObjects()
}
```

### Network Debugging

```swift
// Enable URLSession logging
let configuration = URLSessionConfiguration.default
configuration.waitsForConnectivity = true
configuration.timeoutIntervalForRequest = 30

// Log requests
extension URLRequest {
    func log() {
        print("🌐 Request: \(self.httpMethod ?? "") \(self.url?.absoluteString ?? "")")
        if let headers = self.allHTTPHeaderFields {
            print("   Headers: \(headers)")
        }
    }
}
```

---

## Release Process

### Pre-Release Checklist

```markdown
- [ ] Update version number in Info.plist
- [ ] Update build number
- [ ] Run all tests
- [ ] Test on multiple devices
- [ ] Review console logs for sensitive data
- [ ] Update screenshots if UI changed
- [ ] Update App Store description
- [ ] Create release notes
- [ ] Archive and validate
```

### Build Configuration

```swift
// Release configuration
#if DEBUG
    let apiEndpoint = "https://api-dev.openai.com"
    let debugMode = true
#else
    let apiEndpoint = "https://api.openai.com"
    let debugMode = false
#endif
```

### Archive and Upload

```bash
# Archive for App Store
xcodebuild archive \
    -project InfiniteStories.xcodeproj \
    -scheme InfiniteStories \
    -configuration Release \
    -archivePath ./build/InfiniteStories.xcarchive

# Export IPA
xcodebuild -exportArchive \
    -archivePath ./build/InfiniteStories.xcarchive \
    -exportPath ./build \
    -exportOptionsPlist ExportOptions.plist

# Upload to App Store Connect
xcrun altool --upload-app \
    --type ios \
    --file ./build/InfiniteStories.ipa \
    --username "your@email.com" \
    --password "@keychain:AC_PASSWORD"
```

### TestFlight Distribution

1. Upload build to App Store Connect
2. Add build notes
3. Select test groups
4. Submit for review (if external)
5. Monitor crash reports and feedback

### App Store Submission

1. Prepare marketing materials
2. Set pricing and availability
3. Configure in-app purchases (if any)
4. Submit for review
5. Monitor review status
6. Respond to reviewer feedback promptly

---

## Best Practices

### Swift 6.0 Best Practices

#### Structured Concurrency

```swift
// Use async/await throughout
class StoryViewModel: ObservableObject {
    @MainActor
    func generateCompleteStory(hero: Hero, event: StoryEvent) async throws {
        // Use task groups for parallel operations
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Generate story content
            group.addTask {
                let story = try await self.generateStory(hero: hero, event: event)
                await MainActor.run {
                    self.currentStory = story
                }
            }

            // Pre-warm illustration cache
            group.addTask {
                try await self.preloadIllustrationCache()
            }

            try await group.waitForAll()
        }
    }
}
```

#### Actor Isolation

```swift
// Use actors for thread-safe services
actor CacheManager {
    private var cache: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        cache[key]
    }

    func set(_ key: String, value: Data) {
        cache[key] = value
    }

    func clear() {
        cache.removeAll()
    }
}
```

### Code Style

```swift
// MARK: - Properties
private let aiService: AIServiceProtocol

// MARK: - Lifecycle
init(aiService: AIServiceProtocol = OpenAIService()) {
    self.aiService = aiService
}

// MARK: - Public Methods
func generateStory() async { }

// MARK: - Private Methods
private func handleError(_ error: Error) { }
```

### Documentation

```swift
/// Generates a personalized story for the given hero
/// - Parameters:
///   - hero: The hero character for the story
///   - event: The type of story event (bedtime, adventure, etc.)
/// - Returns: A generated story with title and content
/// - Throws: `AIServiceError` if generation fails
func generateStory(for hero: Hero, event: StoryEvent) async throws -> Story {
    // Implementation
}
```

### Error Handling

```swift
do {
    let story = try await generateStory()
    // Handle success
} catch let error as AIServiceError {
    // Handle specific AI errors
    handleAIError(error)
} catch {
    // Handle general errors
    handleGeneralError(error)
}
```

### Security

```swift
// Never hardcode sensitive data
// Bad ❌
let apiKey = "sk-1234567890"

// Good ✅
let apiKey = KeychainHelper.shared.loadString(key: "openai.apikey") ?? ""

// Validate user input
guard !userInput.isEmpty,
      userInput.count <= 1000 else {
    throw ValidationError.invalidInput
}
```

---

## Troubleshooting

### Common Development Issues

| Issue | Solution |
|-------|----------|
| **"No such module" error** | Clean build folder (Shift+Cmd+K) |
| **SwiftData crashes** | Delete app and reinstall |
| **Audio not playing in simulator** | Test on real device |
| **API calls failing** | Check API key and network |
| **Memory issues** | Profile with Instruments |

### Debugging Tips

1. **Use breakpoints liberally**
   - Symbolic breakpoints for specific methods
   - Exception breakpoints for crashes
   - Conditional breakpoints for specific cases

2. **LLDB commands**
   ```lldb
   po variable  // Print object
   p variable   // Print value
   bt          // Backtrace
   ```

3. **View debugging**
   - Debug View Hierarchy (Debug → View Debugging)
   - Environment overrides for testing

---

## Resources

### Documentation

- [Swift 6 Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/)
- [SwiftUI 6.0 Reference](https://developer.apple.com/documentation/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Supabase iOS SDK](https://supabase.com/docs/reference/swift/introduction)
- [OpenAI API Docs](https://platform.openai.com/docs)
- [Charts Framework](https://developer.apple.com/documentation/charts)

### Tools

- [SwiftLint](https://github.com/realm/SwiftLint) - Code style enforcement
- [Swift Testing](https://developer.apple.com/documentation/testing) - Modern testing framework (Swift 6)
- [XCTest](https://developer.apple.com/documentation/xctest) - Legacy testing framework
- [Instruments](https://help.apple.com/instruments) - Performance profiling
- [Supabase CLI](https://supabase.com/docs/reference/cli/introduction) - Backend management
- [Reality Composer Pro](https://developer.apple.com/augmented-reality/tools/) - Future AR features

### Community

- [Swift Forums](https://forums.swift.org)
- [iOS Dev Slack](https://ios-developers.io)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/swiftui)

## Integration with Backend

### Supabase Edge Functions

```typescript
// Edge function structure
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { hero_id, event, language } = await req.json()

  // Generate story with GPT-4o
  const story = await generateStory(hero_id, event, language)

  // Extract scenes for illustrations
  const scenes = await extractScenes(story.content)

  // Generate illustrations in parallel
  const illustrations = await Promise.all(
    scenes.map(scene => generateIllustration(scene))
  )

  return new Response(
    JSON.stringify({ story, scenes, illustrations }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})
```

### iOS Integration Layer

```swift
class BackendService {
    enum Mode {
        case supabase  // Primary
        case direct    // Fallback to OpenAI
    }

    private var mode: Mode = .supabase
    private let supabase: SupabaseService
    private let openai: AIService

    func generateStory(hero: Hero, event: StoryEvent) async throws -> Story {
        switch mode {
        case .supabase:
            do {
                return try await supabase.generateStory(hero: hero, event: event)
            } catch {
                // Fallback to direct OpenAI
                mode = .direct
                return try await openai.generateStory(hero: hero, event: event)
            }
        case .direct:
            return try await openai.generateStory(hero: hero, event: event)
        }
    }
}
```

## Deployment and CI/CD

### GitHub Actions Workflow

```yaml
name: iOS Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-14  # macOS Sonoma

    steps:
    - uses: actions/checkout@v4

    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_16.0.app

    - name: Build iOS App
      run: |
        cd InfiniteStories
        xcodebuild -project InfiniteStories.xcodeproj \
                   -scheme InfiniteStories \
                   -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
                   -configuration Debug \
                   build

    - name: Run Tests
      run: |
        cd InfiniteStories
        xcodebuild test -project InfiniteStories.xcodeproj \
                       -scheme InfiniteStories \
                       -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

    - name: Deploy Supabase Functions
      if: github.ref == 'refs/heads/main'
      run: |
        cd infinite-stories-backend
        npx supabase functions deploy --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
```

### TestFlight Distribution

```bash
# Build for TestFlight
xcodebuild archive \
    -project InfiniteStories.xcodeproj \
    -scheme InfiniteStories \
    -configuration Release \
    -archivePath build/InfiniteStories.xcarchive

# Export for TestFlight
xcodebuild -exportArchive \
    -archivePath build/InfiniteStories.xcarchive \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath build/

# Upload to App Store Connect
xcrun altool --upload-app \
    --type ios \
    --file build/InfiniteStories.ipa \
    --apiKey $API_KEY \
    --apiIssuer $API_ISSUER
```

---

*Last updated: December 2024*
*Developer Guide Version: 2.0.0*