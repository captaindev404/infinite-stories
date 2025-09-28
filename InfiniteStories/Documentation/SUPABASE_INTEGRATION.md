# Supabase iOS Integration Guide for InfiniteStories

## Overview

This document provides comprehensive iOS patterns and integration guidelines for using the official Supabase Swift library in the InfiniteStories app.

## Implementation Status ✅

The `SupabaseClient.swift` file has been fully implemented with:

### 1. **Database Operations** ✅
- Hero CRUD operations with proper async/await patterns
- Story CRUD operations with SwiftData integration
- Proper error handling and type safety
- Support for both local development and production

### 2. **Edge Functions** ✅
- Story generation via `story-generation` function
- Audio synthesis via `audio-synthesis` function
- Avatar generation via `avatar-generation` function
- Scene illustrations via `scene-illustration` function

### 3. **Real-time Subscriptions** ✅
- Hero changes monitoring
- Story changes monitoring
- NotificationCenter integration for UI updates
- Automatic cleanup on sign-out

### 4. **Authentication** ✅
- Anonymous authentication support
- Session management
- Auth state observers
- Local development mode with service role key

## iOS Integration Patterns

### 1. Database Operations

#### Upserting Heroes
```swift
func upsertHero(_ hero: Hero) async throws {
    let userId = try await ensureAuthentication()

    var heroData: [String: AnyEncodable] = [
        "id": AnyEncodable(hero.id.uuidString),
        "user_id": AnyEncodable(userId.uuidString),
        "name": AnyEncodable(hero.name),
        // ... other fields
    ]

    let response = try await client.database
        .from("heroes")
        .upsert(heroData, onConflict: "id")
        .execute()

    hero.markAsSynced()
}
```

#### Fetching Data
```swift
func fetchHeroes() async throws -> [HeroData] {
    let userId = try await ensureAuthentication()

    let response = try await client.database
        .from("heroes")
        .select()
        .eq("user_id", value: userId.uuidString)
        .eq("is_active", value: true)
        .order("created_at", ascending: false)
        .execute()

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode([HeroData].self, from: response.data)
}
```

### 2. Edge Function Calls

#### Story Generation
```swift
func generateStory(heroId: String, event: [String: Any], targetDuration: Int, language: String) async throws -> StoryGenerationResult {
    let requestBody: [String: AnyEncodable] = [
        "hero_id": AnyEncodable(heroId),
        "event": AnyEncodable(event),
        "target_duration": AnyEncodable(targetDuration),
        "language": AnyEncodable(language)
    ]

    let response = try await client.functions
        .invoke(
            "story-generation",
            options: FunctionInvokeOptions(
                body: requestBody,
                headers: ["Content-Type": "application/json"]
            )
        )

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(StoryGenerationResult.self, from: response.data!)
}
```

### 3. Real-time Subscriptions

#### Setting Up Subscriptions
```swift
func setupRealtimeSubscriptions() async {
    guard let userId = currentUserId else { return }

    heroesSubscription = client.realtimeV2
        .channel("heroes-changes")
        .onPostgresChange(
            .all,
            schema: "public",
            table: "heroes",
            filter: "user_id=eq.\(userId.uuidString)"
        ) { change in
            self.handleHeroChange(change)
        }
        .subscribe()
}
```

#### Handling Changes
```swift
private func handleHeroChange(_ change: PostgresChangePayload) {
    switch change.type {
    case .insert:
        NotificationCenter.default.post(
            name: NSNotification.Name("HeroesDataChanged"),
            object: nil,
            userInfo: ["change": "insert", "data": change.record]
        )
    case .update:
        // Handle update
    case .delete:
        // Handle delete
    default:
        break
    }
}
```

### 4. SwiftData Integration

#### Syncing SwiftData Models
```swift
extension Hero {
    func markAsSynced() {
        lastSyncedAt = Date()
        needsSync = false
    }

    func toDatabaseDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "primary_trait": primaryTrait.rawValue,
            // ... other fields
        ]
    }
}
```

## Error Handling

### Custom Error Types
```swift
enum SupabaseError: Error, LocalizedError {
    case apiError(String)
    case networkError(Error)
    case decodingError(Error)
    case authenticationError(String)
    case notFound
    case conflictError(String)
}
```

### Error Handling Pattern
```swift
do {
    let result = try await supabaseService.generateStory(...)
    // Handle success
} catch let error as SupabaseError {
    switch error {
    case .apiError(let message):
        // Show user-friendly message
    case .networkError:
        // Handle network issues
    default:
        // Generic error handling
    }
} catch {
    // Unexpected error
}
```

## Authentication Flow

### Local Development
```swift
private let isLocalDevelopment = true

func ensureAuthentication() async throws -> UUID {
    if isLocalDevelopment {
        // Use fixed dev user ID
        return UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    }
    // Production auth flow
}
```

### Production Authentication
```swift
// Anonymous sign-in
let response = try await client.auth.signInAnonymously()

// Email/password sign-in (future)
let response = try await client.auth.signIn(
    email: email,
    password: password
)
```

## UI Integration

### Observing Data Changes
```swift
class HeroListView: View {
    @State private var heroes: [Hero] = []

    var body: some View {
        List(heroes) { hero in
            HeroRow(hero: hero)
        }
        .onAppear {
            setupNotifications()
            Task {
                await loadHeroes()
            }
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HeroesDataChanged"),
            object: nil,
            queue: .main
        ) { notification in
            Task {
                await loadHeroes()
            }
        }
    }
}
```

## Best Practices

### 1. Async/Await Pattern
Always use async/await for Supabase operations:
```swift
Task {
    do {
        let heroes = try await supabaseService.fetchHeroes()
        // Update UI
    } catch {
        // Handle error
    }
}
```

### 2. Type Safety
Use Codable structs for data transfer:
```swift
struct HeroData: Codable {
    let id: UUID
    let name: String
    // Use CodingKeys for snake_case conversion
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case primaryTrait = "primary_trait"
    }
}
```

### 3. Offline-First
Maintain local SwiftData storage:
```swift
// Save locally first
modelContext.insert(hero)
try modelContext.save()

// Then sync to Supabase
Task {
    try? await supabaseService.upsertHero(hero)
}
```

### 4. Error Recovery
Implement retry logic for network failures:
```swift
func syncWithRetry() async throws {
    var retryCount = 0
    let maxRetries = 3

    while retryCount < maxRetries {
        do {
            try await performSync()
            return
        } catch {
            retryCount += 1
            if retryCount < maxRetries {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
            }
        }
    }
    throw SupabaseError.apiError("Sync failed after \(maxRetries) attempts")
}
```

## Configuration

### Development Setup
```swift
// Local Supabase instance
let supabaseURL = URL(string: "http://127.0.0.1:54321")!
let supabaseKey = "your-anon-key-here"
```

### Production Setup
```swift
// Production Supabase instance
let supabaseURL = URL(string: "https://your-project.supabase.co")!
let supabaseKey = KeychainHelper.shared.getSupabaseKey() ?? ""
```

## Testing

### Connection Test
```swift
func testConnection() async throws -> Bool {
    let _: [HeroData] = try await client
        .from("heroes")
        .select("id")
        .limit(1)
        .execute()
        .value
    return true
}
```

### Mock Service for Testing
```swift
protocol SupabaseServiceProtocol {
    func fetchHeroes() async throws -> [HeroData]
    func upsertHero(_ hero: Hero) async throws
}

class MockSupabaseService: SupabaseServiceProtocol {
    func fetchHeroes() async throws -> [HeroData] {
        // Return test data
    }
}
```

## Migration from Direct OpenAI

### Before (Direct OpenAI)
```swift
let response = try await openAI.createCompletion(...)
```

### After (Supabase Edge Functions)
```swift
let response = try await supabaseService.generateStory(...)
```

## Common Issues and Solutions

### Issue 1: Authentication Errors
**Solution**: Ensure proper auth flow and check session validity
```swift
if !supabaseService.isAuthenticated() {
    try await supabaseService.signInAnonymously()
}
```

### Issue 2: Real-time Not Working
**Solution**: Check subscription setup and filters
```swift
// Ensure user ID is correct in filter
filter: "user_id=eq.\(userId.uuidString)"
```

### Issue 3: Data Not Syncing
**Solution**: Check needsSync flag and network connectivity
```swift
if hero.needsSync && NetworkService.shared.isConnected {
    try await supabaseService.upsertHero(hero)
}
```

## Performance Optimization

### Batch Operations
```swift
func syncAllHeroes(_ heroes: [Hero]) async throws {
    await withThrowingTaskGroup(of: Void.self) { group in
        for hero in heroes where hero.needsSync {
            group.addTask {
                try await self.upsertHero(hero)
            }
        }
    }
}
```

### Caching Strategy
```swift
class CachedSupabaseService {
    private var heroCache: [UUID: HeroData] = [:]
    private var cacheExpiry: Date?

    func fetchHeroes() async throws -> [HeroData] {
        if let expiry = cacheExpiry, expiry > Date(), !heroCache.isEmpty {
            return Array(heroCache.values)
        }

        let heroes = try await supabaseService.fetchHeroes()
        updateCache(heroes)
        return heroes
    }
}
```

## Security Considerations

1. **Never hardcode API keys** - Use Keychain storage
2. **Validate all inputs** before sending to Supabase
3. **Use Row Level Security (RLS)** policies in Supabase
4. **Implement proper authentication** before production
5. **Sanitize user-generated content** before storage

## Next Steps

1. Implement proper user authentication (email/password, SSO)
2. Add conflict resolution for offline edits
3. Implement background sync for iOS
4. Add analytics tracking for sync operations
5. Implement data compression for large stories
6. Add rate limiting protection
7. Implement proper data migration strategy

## Resources

- [Supabase Swift SDK Documentation](https://github.com/supabase/supabase-swift)
- [Supabase Edge Functions Guide](https://supabase.com/docs/guides/functions)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [iOS Background Tasks](https://developer.apple.com/documentation/backgroundtasks)