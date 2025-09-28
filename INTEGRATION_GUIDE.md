# InfiniteStories Integration Guide

## Overview

This guide provides comprehensive documentation for integrating the InfiniteStories iOS application with the Supabase backend infrastructure. It covers authentication flows, API communication patterns, error handling strategies, and best practices for maintaining a robust connection between the client and server.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Authentication Integration](#authentication-integration)
3. [API Communication Patterns](#api-communication-patterns)
4. [Error Handling & Retry Mechanisms](#error-handling--retry-mechanisms)
5. [Rate Limiting & Throttling](#rate-limiting--throttling)
6. [Caching Strategies](#caching-strategies)
7. [Real-Time Updates](#real-time-updates)
8. [Migration from Direct OpenAI](#migration-from-direct-openai)
9. [Testing Integration](#testing-integration)
10. [Performance Optimization](#performance-optimization)
11. [Security Considerations](#security-considerations)
12. [Monitoring & Debugging](#monitoring--debugging)

## Architecture Overview

### Integration Stack

```
┌──────────────────────────────┐
│      iOS Application         │
│   (SwiftUI + SwiftData)      │
├──────────────────────────────┤
│    Integration Layer         │
│  (SupabaseClient Service)    │
├──────────────────────────────┤
│     Network Layer            │
│   (URLSession + Async)       │
└──────────────────────────────┘
              ↕
         [HTTPS/WSS]
              ↕
┌──────────────────────────────┐
│    Supabase API Gateway      │
├──────────────────────────────┤
│     Edge Functions           │
│   (TypeScript + Deno)        │
├──────────────────────────────┤
│  Database & Storage          │
│  (PostgreSQL + S3)           │
└──────────────────────────────┘
```

### Communication Flow

1. **Request Initiation**: User action triggers API call
2. **Authentication**: JWT token attached to request
3. **Network Transport**: HTTPS request with retry logic
4. **Edge Processing**: Request validation and processing
5. **Response Handling**: Parse and transform response
6. **Local Update**: Update SwiftData and UI

## Authentication Integration

### Initial Setup

#### 1. Configure Supabase Client

```swift
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://your-project-ref.supabase.co")!,
            supabaseKey: "your-anon-key"
        )
    }
}
```

#### 2. Authentication Flow

```swift
class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let supabase = SupabaseManager.shared.client

    // Anonymous Authentication (for initial use)
    func signInAnonymously() async throws {
        let response = try await supabase.auth.signInAnonymously()
        self.currentUser = response.user
        self.isAuthenticated = true

        // Store session in Keychain
        try await storeSession(response.session)
    }

    // Email Authentication (for full features)
    func signUp(email: String, password: String) async throws {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: [
                "app_version": Bundle.main.appVersion,
                "platform": "iOS"
            ]
        )

        self.currentUser = response.user
        self.isAuthenticated = true
    }

    // Session Management
    func restoreSession() async throws {
        if let session = try await retrieveStoredSession() {
            try await supabase.auth.setSession(session)
            self.currentUser = session.user
            self.isAuthenticated = true
        }
    }

    // Token Refresh
    func refreshToken() async throws {
        let session = try await supabase.auth.refreshSession()
        try await storeSession(session)
    }
}
```

#### 3. Keychain Storage

```swift
import Security

class KeychainService {
    static func store(session: Session) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(session)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "supabase_session",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary) // Remove existing
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }
}
```

### JWT Token Management

```swift
class TokenManager {
    private var currentToken: String?
    private var tokenExpiry: Date?

    func getValidToken() async throws -> String {
        // Check if token exists and is valid
        if let token = currentToken,
           let expiry = tokenExpiry,
           expiry > Date().addingTimeInterval(60) {
            return token
        }

        // Refresh token
        let session = try await SupabaseManager.shared.client.auth.session
        self.currentToken = session.accessToken
        self.tokenExpiry = Date(timeIntervalSince1970: session.expiresAt)

        return session.accessToken
    }
}
```

## API Communication Patterns

### Service Layer Architecture

#### 1. Protocol Definition

```swift
protocol BackendServiceProtocol {
    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse
    func synthesizeAudio(request: AudioSynthesisRequest) async throws -> AudioSynthesisResponse
    func generateAvatar(request: AvatarGenerationRequest) async throws -> AvatarGenerationResponse
    func generateSceneIllustrations(request: SceneIllustrationRequest) async throws -> SceneIllustrationResponse
}
```

#### 2. Implementation

```swift
class SupabaseBackendService: BackendServiceProtocol {
    private let baseURL: URL
    private let tokenManager: TokenManager
    private let session: URLSession

    init() {
        self.baseURL = URL(string: "https://your-project-ref.supabase.co/functions/v1")!
        self.tokenManager = TokenManager()

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }

    // Generic request handler
    private func makeRequest<Request: Encodable, Response: Decodable>(
        endpoint: String,
        method: HTTPMethod = .post,
        body: Request,
        responseType: Response.Type
    ) async throws -> Response {
        // Build URL
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add headers
        let token = try await tokenManager.getValidToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")

        // Encode body
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        // Make request with retry logic
        let (data, response) = try await performRequestWithRetry(request)

        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntegrationError.invalidResponse
        }

        // Check status code
        try handleStatusCode(httpResponse.statusCode, data: data)

        // Decode response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Response.self, from: data)
    }

    // Retry logic with exponential backoff
    private func performRequestWithRetry(
        _ request: URLRequest,
        maxRetries: Int = 3
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await session.data(for: request)
            } catch {
                lastError = error

                // Check if error is retryable
                if !isRetryableError(error) {
                    throw error
                }

                // Exponential backoff
                let delay = pow(2.0, Double(attempt)) * 0.5
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? IntegrationError.maxRetriesExceeded
    }
}
```

### Request/Response Models

#### Story Generation

```swift
// Request
struct StoryGenerationRequest: Codable {
    let heroId: UUID
    let event: StoryEvent
    let targetDuration: Int
    let language: String = "en"

    enum StoryEvent: Codable {
        case builtIn(String)
        case custom(UUID)

        private enum CodingKeys: String, CodingKey {
            case type, data
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .builtIn(let eventName):
                try container.encode("built_in", forKey: .type)
                try container.encode(["event": eventName], forKey: .data)
            case .custom(let eventId):
                try container.encode("custom", forKey: .type)
                try container.encode(["custom_event_id": eventId.uuidString], forKey: .data)
            }
        }
    }
}

// Response
struct StoryGenerationResponse: Codable {
    let success: Bool
    let data: StoryData
    let meta: ResponseMeta

    struct StoryData: Codable {
        let storyId: UUID
        let title: String
        let content: String
        let estimatedDuration: Int
        let wordCount: Int
        let scenes: [Scene]

        struct Scene: Codable {
            let sceneNumber: Int
            let textSegment: String
            let illustrationPrompt: String
            let timestampSeconds: Double
            let emotion: String
            let importance: String
        }
    }

    struct ResponseMeta: Codable {
        let requestId: String
        let processingTime: Int
        let cached: Bool
    }
}
```

#### Audio Synthesis

```swift
struct AudioSynthesisRequest: Codable {
    let storyId: UUID
    let text: String
    let voice: Voice
    let language: String = "en"

    enum Voice: String, Codable {
        case coral = "coral"
        case nova = "nova"
        case fable = "fable"
        case alloy = "alloy"
        case echo = "echo"
        case onyx = "onyx"
        case shimmer = "shimmer"
    }
}

struct AudioSynthesisResponse: Codable {
    let success: Bool
    let data: AudioData

    struct AudioData: Codable {
        let audioUrl: URL
        let durationSeconds: Double
        let fileSizeBytes: Int64
        let voiceUsed: String
    }
}
```

## Error Handling & Retry Mechanisms

### Error Types

```swift
enum IntegrationError: LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval)
    case contentPolicyViolation(message: String)
    case networkError(underlying: Error)
    case serverError(code: String, message: String)
    case invalidResponse
    case maxRetriesExceeded
    case timeout

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required. Please sign in."
        case .rateLimited(let retryAfter):
            return "Too many requests. Try again in \(Int(retryAfter)) seconds."
        case .contentPolicyViolation(let message):
            return "Content safety issue: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(_, let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .maxRetriesExceeded:
            return "Request failed after multiple attempts"
        case .timeout:
            return "Request timed out"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .timeout:
            return true
        default:
            return false
        }
    }
}
```

### Error Response Handling

```swift
struct ErrorResponse: Codable {
    let error: ErrorDetail
    let requestId: String?
    let timestamp: Date?

    struct ErrorDetail: Codable {
        let code: String
        let message: String
        let details: [String: AnyCodable]?
        let retryAfter: Int?
    }
}

func handleStatusCode(_ statusCode: Int, data: Data) throws {
    switch statusCode {
    case 200...299:
        return // Success

    case 401:
        throw IntegrationError.unauthorized

    case 429:
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
           let retryAfter = errorResponse.error.retryAfter {
            throw IntegrationError.rateLimited(retryAfter: TimeInterval(retryAfter))
        }
        throw IntegrationError.rateLimited(retryAfter: 60)

    case 400:
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            if errorResponse.error.code == "CONTENT_POLICY_VIOLATION" {
                throw IntegrationError.contentPolicyViolation(message: errorResponse.error.message)
            }
        }
        throw IntegrationError.serverError(code: "400", message: "Bad request")

    case 500...599:
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw IntegrationError.serverError(
                code: errorResponse.error.code,
                message: errorResponse.error.message
            )
        }
        throw IntegrationError.serverError(code: "\(statusCode)", message: "Server error")

    default:
        throw IntegrationError.invalidResponse
    }
}
```

### Retry Strategy

```swift
class RetryManager {
    struct RetryPolicy {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double
        let jitter: Bool

        static let `default` = RetryPolicy(
            maxAttempts: 3,
            initialDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0,
            jitter: true
        )

        static let aggressive = RetryPolicy(
            maxAttempts: 5,
            initialDelay: 0.5,
            maxDelay: 60.0,
            multiplier: 1.5,
            jitter: true
        )
    }

    func calculateDelay(
        attempt: Int,
        policy: RetryPolicy
    ) -> TimeInterval {
        let exponentialDelay = policy.initialDelay * pow(policy.multiplier, Double(attempt))
        let boundedDelay = min(exponentialDelay, policy.maxDelay)

        if policy.jitter {
            // Add random jitter (±25%)
            let jitter = Double.random(in: 0.75...1.25)
            return boundedDelay * jitter
        }

        return boundedDelay
    }

    func shouldRetry(
        error: Error,
        attempt: Int,
        policy: RetryPolicy
    ) -> Bool {
        guard attempt < policy.maxAttempts else { return false }

        if let integrationError = error as? IntegrationError {
            return integrationError.isRetryable
        }

        // Check for network errors
        if (error as NSError).domain == NSURLErrorDomain {
            let retryableCodes = [
                NSURLErrorTimedOut,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet
            ]
            return retryableCodes.contains((error as NSError).code)
        }

        return false
    }
}
```

## Rate Limiting & Throttling

### Client-Side Rate Limiting

```swift
class RateLimiter {
    private var buckets: [String: TokenBucket] = [:]
    private let queue = DispatchQueue(label: "rate.limiter", attributes: .concurrent)

    class TokenBucket {
        let capacity: Int
        let refillRate: TimeInterval
        private var tokens: Int
        private var lastRefill: Date

        init(capacity: Int, refillRate: TimeInterval) {
            self.capacity = capacity
            self.refillRate = refillRate
            self.tokens = capacity
            self.lastRefill = Date()
        }

        func consume() -> Bool {
            refill()

            if tokens > 0 {
                tokens -= 1
                return true
            }
            return false
        }

        private func refill() {
            let now = Date()
            let elapsed = now.timeIntervalSince(lastRefill)
            let tokensToAdd = Int(elapsed / refillRate)

            if tokensToAdd > 0 {
                tokens = min(capacity, tokens + tokensToAdd)
                lastRefill = now
            }
        }

        var timeUntilNextToken: TimeInterval {
            if tokens > 0 { return 0 }

            let elapsed = Date().timeIntervalSince(lastRefill)
            let remaining = refillRate - elapsed.truncatingRemainder(dividingBy: refillRate)
            return remaining
        }
    }

    func configureLimit(for endpoint: String, capacity: Int, refillRate: TimeInterval) {
        queue.async(flags: .barrier) {
            self.buckets[endpoint] = TokenBucket(capacity: capacity, refillRate: refillRate)
        }
    }

    func checkLimit(for endpoint: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let bucket = self.buckets[endpoint] else {
                    continuation.resume()
                    return
                }

                if bucket.consume() {
                    continuation.resume()
                } else {
                    let waitTime = bucket.timeUntilNextToken
                    continuation.resume(throwing: IntegrationError.rateLimited(retryAfter: waitTime))
                }
            }
        }
    }
}
```

### Rate Limit Configuration

```swift
extension RateLimiter {
    static func configureDefaultLimits() -> RateLimiter {
        let limiter = RateLimiter()

        // Configure per-endpoint limits (requests per hour)
        limiter.configureLimit(for: "story-generation", capacity: 10, refillRate: 360)
        limiter.configureLimit(for: "audio-synthesis", capacity: 15, refillRate: 240)
        limiter.configureLimit(for: "avatar-generation", capacity: 8, refillRate: 450)
        limiter.configureLimit(for: "scene-illustration", capacity: 25, refillRate: 144)

        return limiter
    }
}
```

## Caching Strategies

### Multi-Layer Cache Implementation

```swift
class CacheManager {
    // Memory cache for quick access
    private let memoryCache = NSCache<NSString, AnyObject>()

    // Disk cache for persistence
    private let diskCacheURL: URL

    // Database cache using SwiftData
    @MainActor
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Configure disk cache directory
        let documentsPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.diskCacheURL = documentsPath.appendingPathComponent("InfiniteStoriesCache")

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    // Cache key generation
    func cacheKey(for request: any Hashable) -> String {
        let data = try? JSONEncoder().encode(request)
        let hash = data?.base64EncodedString() ?? ""
        return hash
    }

    // Store in cache
    func store<T: Codable>(_ object: T, for key: String, ttl: TimeInterval = 3600) async {
        // Memory cache
        memoryCache.setObject(object as AnyObject, forKey: key as NSString)

        // Disk cache
        let fileURL = diskCacheURL.appendingPathComponent("\(key).cache")
        let cacheEntry = CacheEntry(data: object, expiry: Date().addingTimeInterval(ttl))

        if let data = try? JSONEncoder().encode(cacheEntry) {
            try? data.write(to: fileURL)
        }

        // Database cache for important data
        await MainActor.run {
            let dbCache = CacheRecord(key: key, data: data, expiry: cacheEntry.expiry)
            modelContext.insert(dbCache)
            try? modelContext.save()
        }
    }

    // Retrieve from cache
    func retrieve<T: Codable>(_ type: T.Type, for key: String) async -> T? {
        // Check memory cache first
        if let cached = memoryCache.object(forKey: key as NSString) as? T {
            return cached
        }

        // Check disk cache
        let fileURL = diskCacheURL.appendingPathComponent("\(key).cache")
        if let data = try? Data(contentsOf: fileURL),
           let entry = try? JSONDecoder().decode(CacheEntry<T>.self, from: data),
           entry.expiry > Date() {

            // Restore to memory cache
            memoryCache.setObject(entry.data as AnyObject, forKey: key as NSString)
            return entry.data
        }

        // Check database cache
        return await MainActor.run {
            let predicate = #Predicate<CacheRecord> { record in
                record.key == key && record.expiry > Date()
            }

            let descriptor = FetchDescriptor<CacheRecord>(predicate: predicate)
            if let record = try? modelContext.fetch(descriptor).first,
               let object = try? JSONDecoder().decode(T.self, from: record.data) {

                // Restore to faster caches
                memoryCache.setObject(object as AnyObject, forKey: key as NSString)
                return object
            }

            return nil
        }
    }

    // Clear expired entries
    func cleanupExpiredEntries() async {
        // Clean disk cache
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil) {
            for file in files {
                if let data = try? Data(contentsOf: file),
                   let entry = try? JSONDecoder().decode(CacheEntryMetadata.self, from: data),
                   entry.expiry < Date() {
                    try? fileManager.removeItem(at: file)
                }
            }
        }

        // Clean database cache
        await MainActor.run {
            let predicate = #Predicate<CacheRecord> { record in
                record.expiry < Date()
            }

            try? modelContext.delete(model: CacheRecord.self, where: predicate)
            try? modelContext.save()
        }
    }
}
```

### Cache Strategy by Content Type

```swift
extension CacheManager {
    enum CacheStrategy {
        case shortTerm    // 1 hour
        case mediumTerm   // 24 hours
        case longTerm     // 7 days
        case permanent    // No expiry

        var ttl: TimeInterval {
            switch self {
            case .shortTerm: return 3600
            case .mediumTerm: return 86400
            case .longTerm: return 604800
            case .permanent: return .infinity
            }
        }
    }

    func cacheStory(_ story: Story, strategy: CacheStrategy = .mediumTerm) async {
        let key = "story_\(story.id)"
        await store(story, for: key, ttl: strategy.ttl)
    }

    func cacheAudioURL(_ url: URL, for storyId: UUID, strategy: CacheStrategy = .longTerm) async {
        let key = "audio_\(storyId)"
        await store(url.absoluteString, for: key, ttl: strategy.ttl)
    }

    func cacheIllustrations(_ urls: [URL], for storyId: UUID, strategy: CacheStrategy = .longTerm) async {
        let key = "illustrations_\(storyId)"
        let urlStrings = urls.map { $0.absoluteString }
        await store(urlStrings, for: key, ttl: strategy.ttl)
    }
}
```

## Real-Time Updates

### WebSocket Integration

```swift
class RealtimeManager {
    private let supabase = SupabaseManager.shared.client
    private var channels: [String: RealtimeChannel] = [:]

    // Subscribe to story updates
    func subscribeToStoryUpdates(userId: String, handler: @escaping (Story) -> Void) {
        let channel = supabase.channel("story-updates-\(userId)")
            .on("postgres_changes", filter: ChannelFilter(
                event: "INSERT",
                schema: "public",
                table: "stories",
                filter: "user_id=eq.\(userId)"
            )) { payload in
                if let story = self.parseStory(from: payload) {
                    handler(story)
                }
            }
            .subscribe()

        channels["story-updates-\(userId)"] = channel
    }

    // Subscribe to illustration progress
    func subscribeToIllustrationProgress(
        storyId: String,
        handler: @escaping (IllustrationProgress) -> Void
    ) {
        let channel = supabase.channel("illustration-\(storyId)")
            .on("postgres_changes", filter: ChannelFilter(
                event: "UPDATE",
                schema: "public",
                table: "story_illustrations",
                filter: "story_id=eq.\(storyId)"
            )) { payload in
                if let progress = self.parseProgress(from: payload) {
                    handler(progress)
                }
            }
            .subscribe()

        channels["illustration-\(storyId)"] = channel
    }

    // Subscribe to custom events
    func subscribeToPresence(
        roomId: String,
        handler: @escaping ([String: Any]) -> Void
    ) {
        let channel = supabase.channel("presence-\(roomId)")
            .on("presence", filter: ChannelFilter(event: "sync")) { payload in
                handler(payload)
            }
            .subscribe { status in
                if status == .subscribed {
                    channel.track(["user_id": userId])
                }
            }

        channels["presence-\(roomId)"] = channel
    }

    // Cleanup subscriptions
    func unsubscribe(from channelName: String) {
        if let channel = channels[channelName] {
            channel.unsubscribe()
            channels.removeValue(forKey: channelName)
        }
    }

    func unsubscribeAll() {
        channels.values.forEach { $0.unsubscribe() }
        channels.removeAll()
    }
}
```

### Progress Tracking

```swift
class ProgressTracker: ObservableObject {
    @Published var storyGenerationProgress: Double = 0
    @Published var audioGenerationProgress: Double = 0
    @Published var illustrationProgress: [Int: Double] = [:]
    @Published var currentStatus: String = ""

    private let realtimeManager = RealtimeManager()

    func trackStoryGeneration(for requestId: String) {
        // Subscribe to progress updates
        realtimeManager.subscribeToCustomChannel("progress-\(requestId)") { update in
            DispatchQueue.main.async {
                if let progress = update["progress"] as? Double {
                    self.storyGenerationProgress = progress
                }
                if let status = update["status"] as? String {
                    self.currentStatus = status
                }
            }
        }
    }

    func trackIllustrationGeneration(for storyId: String, sceneCount: Int) {
        realtimeManager.subscribeToIllustrationProgress(storyId: storyId) { progress in
            DispatchQueue.main.async {
                self.illustrationProgress[progress.sceneNumber] = progress.percentage

                // Calculate overall progress
                let totalProgress = self.illustrationProgress.values.reduce(0, +) / Double(sceneCount)
                self.currentStatus = "Generating illustrations: \(Int(totalProgress * 100))%"
            }
        }
    }
}
```

## Migration from Direct OpenAI

### Migration Strategy

#### Phase 1: Dual Mode Support

```swift
class AIServiceManager {
    enum Mode {
        case direct     // Direct OpenAI API
        case supabase   // Supabase backend
    }

    private var mode: Mode
    private let directService: DirectOpenAIService
    private let supabaseService: SupabaseBackendService

    init(mode: Mode = .supabase) {
        self.mode = mode
        self.directService = DirectOpenAIService()
        self.supabaseService = SupabaseBackendService()
    }

    func generateStory(request: StoryRequest) async throws -> Story {
        switch mode {
        case .direct:
            return try await directService.generateStory(request: request)
        case .supabase:
            return try await supabaseService.generateStory(request: request)
        }
    }

    // Feature flag for gradual rollout
    func shouldUseSupabase(for feature: Feature) -> Bool {
        let rolloutPercentage = RemoteConfig.shared.getValue(for: "supabase_rollout_\(feature)")
        let userHash = currentUserId.hash
        return (userHash % 100) < rolloutPercentage
    }
}
```

#### Phase 2: Data Migration

```swift
class DataMigrationService {
    func migrateLocalDataToSupabase() async throws {
        // Migrate heroes
        let localHeroes = try await fetchLocalHeroes()
        for hero in localHeroes {
            try await supabaseService.createHero(hero)
        }

        // Migrate stories
        let localStories = try await fetchLocalStories()
        for story in localStories {
            try await supabaseService.createStory(story)

            // Upload audio files if they exist
            if let audioURL = story.localAudioURL {
                let uploadedURL = try await uploadAudioFile(audioURL)
                try await supabaseService.updateStoryAudioURL(story.id, url: uploadedURL)
            }
        }

        // Migrate custom events
        let localEvents = try await fetchLocalCustomEvents()
        for event in localEvents {
            try await supabaseService.createCustomEvent(event)
        }
    }
}
```

## Testing Integration

### Integration Test Suite

```swift
import XCTest
@testable import InfiniteStories

class IntegrationTests: XCTestCase {
    var service: SupabaseBackendService!

    override func setUp() async throws {
        // Use test environment
        service = SupabaseBackendService(
            baseURL: "https://test-project.supabase.co",
            apiKey: "test-api-key"
        )
    }

    func testStoryGeneration() async throws {
        // Create test hero
        let hero = TestDataFactory.createHero()

        // Generate story
        let request = StoryGenerationRequest(
            heroId: hero.id,
            event: .builtIn("magical_forest_adventure"),
            targetDuration: 300
        )

        let response = try await service.generateStory(request: request)

        // Assertions
        XCTAssertNotNil(response.data.storyId)
        XCTAssertFalse(response.data.title.isEmpty)
        XCTAssertFalse(response.data.content.isEmpty)
        XCTAssertGreaterThan(response.data.scenes.count, 0)
    }

    func testRateLimiting() async throws {
        // Make requests up to limit
        for _ in 0..<10 {
            _ = try await service.generateStory(request: testRequest)
        }

        // Next request should fail
        do {
            _ = try await service.generateStory(request: testRequest)
            XCTFail("Should have thrown rate limit error")
        } catch IntegrationError.rateLimited {
            // Expected
        }
    }

    func testErrorHandling() async throws {
        // Test with invalid hero ID
        let request = StoryGenerationRequest(
            heroId: UUID(),
            event: .builtIn("test"),
            targetDuration: 300
        )

        do {
            _ = try await service.generateStory(request: request)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
```

### Mock Service for Testing

```swift
class MockBackendService: BackendServiceProtocol {
    var shouldFail = false
    var delay: TimeInterval = 0

    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw IntegrationError.serverError(code: "TEST", message: "Test error")
        }

        return StoryGenerationResponse(
            success: true,
            data: .init(
                storyId: UUID(),
                title: "Test Story",
                content: "Once upon a time...",
                estimatedDuration: 300,
                wordCount: 500,
                scenes: []
            ),
            meta: .init(
                requestId: UUID().uuidString,
                processingTime: 1000,
                cached: false
            )
        )
    }
}
```

## Performance Optimization

### Request Optimization

```swift
class RequestOptimizer {
    // Batch requests when possible
    func batchIllustrationRequests(scenes: [Scene]) async throws -> [Illustration] {
        // Group scenes into batches
        let batchSize = 5
        let batches = scenes.chunked(into: batchSize)

        // Process batches in parallel
        return try await withThrowingTaskGroup(of: [Illustration].self) { group in
            for batch in batches {
                group.addTask {
                    try await self.generateIllustrations(for: batch)
                }
            }

            var allIllustrations: [Illustration] = []
            for try await illustrations in group {
                allIllustrations.append(contentsOf: illustrations)
            }
            return allIllustrations
        }
    }

    // Preload next likely requests
    func preloadNextStory(currentEvent: StoryEvent) async {
        let nextLikelyEvents = predictNextEvents(from: currentEvent)

        for event in nextLikelyEvents {
            Task {
                let request = StoryGenerationRequest(
                    heroId: currentHeroId,
                    event: event,
                    targetDuration: 300
                )

                let cacheKey = CacheManager.shared.cacheKey(for: request)

                // Check if already cached
                if await CacheManager.shared.retrieve(StoryGenerationResponse.self, for: cacheKey) == nil {
                    // Generate and cache
                    if let response = try? await service.generateStory(request: request) {
                        await CacheManager.shared.store(response, for: cacheKey)
                    }
                }
            }
        }
    }
}
```

### Network Optimization

```swift
extension URLSession {
    // Configure optimal session
    static var optimized: URLSession {
        let configuration = URLSessionConfiguration.default

        // Connection settings
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true

        // Caching
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,  // 50 MB
            diskCapacity: 200 * 1024 * 1024     // 200 MB
        )

        // Performance
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.multipathServiceType = .handover

        // Security
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv13

        return URLSession(configuration: configuration)
    }
}
```

## Security Considerations

### API Key Management

```swift
class SecurityManager {
    // Never hardcode keys
    private var apiKeys: [String: String] = [:]

    func storeAPIKey(_ key: String, for service: String) throws {
        // Store in Keychain
        let data = key.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "api_key_\(service)",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw SecurityError.keychainError(status)
        }
    }

    func retrieveAPIKey(for service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "api_key_\(service)",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw SecurityError.keyNotFound
        }

        return key
    }
}
```

### Certificate Pinning

```swift
class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedCertificates: [SecCertificate]

    init(certificates: [SecCertificate]) {
        self.pinnedCertificates = certificates
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Evaluate server trust
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        guard isValid else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check certificate pinning
        for pinnedCert in pinnedCertificates {
            for index in 0..<SecTrustGetCertificateCount(serverTrust) {
                if let serverCert = SecTrustGetCertificateAtIndex(serverTrust, index) {
                    if SecCertificateEqual(pinnedCert, serverCert) {
                        let credential = URLCredential(trust: serverTrust)
                        completionHandler(.useCredential, credential)
                        return
                    }
                }
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
```

## Monitoring & Debugging

### Request Logging

```swift
class NetworkLogger {
    enum LogLevel {
        case verbose, info, warning, error
    }

    static func log(request: URLRequest, level: LogLevel = .info) {
        #if DEBUG
        print("🌐 REQUEST [\(Date())]")
        print("  URL: \(request.url?.absoluteString ?? "nil")")
        print("  Method: \(request.httpMethod ?? "nil")")

        if level == .verbose {
            print("  Headers: \(request.allHTTPHeaderFields ?? [:])")

            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) {
                print("  Body: \(json)")
            }
        }
        #endif
    }

    static func log(response: URLResponse?, data: Data?, error: Error?, level: LogLevel = .info) {
        #if DEBUG
        if let error = error {
            print("❌ ERROR: \(error.localizedDescription)")
            return
        }

        if let httpResponse = response as? HTTPURLResponse {
            let emoji = httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 ? "✅" : "⚠️"
            print("\(emoji) RESPONSE [\(Date())]")
            print("  Status: \(httpResponse.statusCode)")

            if level == .verbose {
                print("  Headers: \(httpResponse.allHeaderFields)")

                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    print("  Body: \(json)")
                }
            }
        }
        #endif
    }
}
```

### Performance Monitoring

```swift
class PerformanceMonitor {
    private var metrics: [String: [TimeInterval]] = [:]

    func startTimer(for operation: String) -> UUID {
        let id = UUID()
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "timer_\(id)")
        return id
    }

    func endTimer(id: UUID, operation: String) {
        guard let startTime = UserDefaults.standard.object(forKey: "timer_\(id)") as? TimeInterval else {
            return
        }

        let duration = Date().timeIntervalSince1970 - startTime

        if metrics[operation] == nil {
            metrics[operation] = []
        }
        metrics[operation]?.append(duration)

        UserDefaults.standard.removeObject(forKey: "timer_\(id)")

        // Log if slow
        if duration > 3.0 {
            print("⚠️ Slow operation: \(operation) took \(duration)s")
        }
    }

    func getAverageTime(for operation: String) -> TimeInterval? {
        guard let times = metrics[operation], !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }

    func generateReport() -> PerformanceReport {
        var report = PerformanceReport()

        for (operation, times) in metrics {
            report.operations.append(OperationMetrics(
                name: operation,
                count: times.count,
                average: times.reduce(0, +) / Double(times.count),
                min: times.min() ?? 0,
                max: times.max() ?? 0
            ))
        }

        return report
    }
}
```

## Conclusion

This integration guide provides comprehensive patterns and best practices for connecting the InfiniteStories iOS application with the Supabase backend. Key takeaways:

1. **Authentication**: Use JWT tokens with automatic refresh
2. **Error Handling**: Implement retry logic with exponential backoff
3. **Rate Limiting**: Client-side throttling to prevent API abuse
4. **Caching**: Multi-layer caching for optimal performance
5. **Real-Time**: WebSocket subscriptions for live updates
6. **Security**: Keychain storage and certificate pinning
7. **Monitoring**: Comprehensive logging and performance tracking

Following these patterns ensures a robust, performant, and secure integration between the iOS client and the Supabase backend infrastructure.

---

*Document Version: 1.0.0*
*Last Updated: September 2025*
*Next Review: Q4 2025*