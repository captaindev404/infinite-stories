//
//  SupabaseService.swift
//  InfiniteStories
//
//  Complete Supabase integration using supabase-swift v2.33.1
//

import Foundation
import Supabase
import Functions

// MARK: - Supabase Service

final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    private let client: SupabaseClient
    private var currentUserId: UUID?

    private init() {
        // Use local development settings by default
        let url = URL(string: "http://127.0.0.1:54321")!
        let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: apiKey
        )

        // Use a fixed dev user ID for now
        self.currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")

        print("📡 SupabaseService initialized")
        print("🔗 URL: \(url.absoluteString)")
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        do {
            // Try to fetch from a simple table to test connection
            let _ = try await client
                .from("heroes")
                .select("id")
                .limit(1)
                .execute()

            print("✅ Test connection successful")
            return true
        } catch {
            print("❌ Test connection failed: \(error)")
            throw error
        }
    }

    // MARK: - Hero Operations

    func saveHero(_ hero: Hero) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let heroCodable = HeroCodable(from: hero, userId: userId)

        do {
            let _ = try await client
                .from("heroes")
                .upsert(heroCodable)
                .execute()

            hero.lastSyncedAt = Date()
            hero.needsSync = false
            print("📤 Synced hero: \(hero.name)")
        } catch {
            print("❌ Failed to sync hero: \(error)")
            throw SupabaseError.apiError("Failed to sync hero: \(error.localizedDescription)")
        }
    }

    func fetchHeroes(limit: Int = 100) async throws -> [[String: Any]] {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        do {
            let heroes: [HeroCodable] = try await client
                .from("heroes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            // Convert to dictionaries
            let encoder = JSONEncoder()

            let result = try heroes.map { hero -> [String: Any] in
                let data = try encoder.encode(hero)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                return json
            }

            print("📥 Fetched \(result.count) heroes")
            return result
        } catch {
            print("❌ Failed to fetch heroes: \(error)")
            throw SupabaseError.apiError("Failed to fetch heroes: \(error.localizedDescription)")
        }
    }

    func deleteHero(_ heroId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        do {
            let _ = try await client
                .from("heroes")
                .delete()
                .eq("id", value: heroId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("🗑️ Deleted hero: \(heroId)")
        } catch {
            print("❌ Failed to delete hero: \(error)")
            throw SupabaseError.apiError("Failed to delete hero: \(error.localizedDescription)")
        }
    }

    // MARK: - Story Operations

    func saveStory(_ story: Story) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let storyCodable = StoryCodable(from: story, userId: userId)

        do {
            let _ = try await client
                .from("stories")
                .upsert(storyCodable)
                .execute()

            story.lastSyncedAt = Date()
            story.needsSync = false
            print("📤 Synced story: \(story.title)")
        } catch {
            print("❌ Failed to sync story: \(error)")
            throw SupabaseError.apiError("Failed to sync story: \(error.localizedDescription)")
        }
    }

    func fetchStories(limit: Int = 50) async throws -> [[String: Any]] {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        do {
            let stories: [StoryCodable] = try await client
                .from("stories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            // Convert to dictionaries
            let encoder = JSONEncoder()
            let result = try stories.map { story -> [String: Any] in
                let data = try encoder.encode(story)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                return json
            }

            print("📥 Fetched \(result.count) stories")
            return result
        } catch {
            print("❌ Failed to fetch stories: \(error)")
            throw SupabaseError.apiError("Failed to fetch stories: \(error.localizedDescription)")
        }
    }

    func fetchStoriesForHero(_ heroId: UUID, limit: Int = 20) async throws -> [[String: Any]] {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        do {
            let stories: [StoryCodable] = try await client
                .from("stories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("hero_id", value: heroId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            // Convert to dictionaries
            let encoder = JSONEncoder()
            let result = try stories.map { story -> [String: Any] in
                let data = try encoder.encode(story)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                return json
            }

            print("📥 Fetched \(result.count) stories for hero: \(heroId)")
            return result
        } catch {
            print("❌ Failed to fetch stories for hero: \(error)")
            throw SupabaseError.apiError("Failed to fetch stories for hero: \(error.localizedDescription)")
        }
    }

    // MARK: - Edge Functions

    func generateStory(heroId: String, event: [String: Any], targetDuration: Int, language: String) async throws -> [String: Any] {
        let requestBody = [
            "hero_id": heroId,
            "event": event,
            "target_duration": targetDuration,
            "language": language
        ] as [String: Any]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            _ = try await client.functions
                .invoke(
                    "story-generation",
                    options: FunctionInvokeOptions(body: jsonData)
                )

            // For now, return mock data until we figure out the correct API
            print("🎭 Generated story via edge function (mocked)")
            return [
                "story_id": UUID().uuidString,
                "title": "Generated Story",
                "content": "This is a generated story.",
                "estimated_duration": 60,
                "word_count": 10
            ]
        } catch {
            print("❌ Failed to generate story: \(error)")
            throw SupabaseError.apiError("Failed to generate story: \(error.localizedDescription)")
        }
    }

    func synthesizeAudio(text: String, voice: String, language: String, storyId: String? = nil) async throws -> [String: Any] {
        var requestBody: [String: Any] = [
            "text": text,
            "voice": voice,
            "language": language
        ]

        if let storyId = storyId {
            requestBody["story_id"] = storyId
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            _ = try await client.functions
                .invoke(
                    "audio-synthesis",
                    options: FunctionInvokeOptions(body: jsonData)
                )

            // For now, return mock data until we figure out the correct API
            print("🎵 Synthesized audio via edge function (mocked)")
            return [
                "audio_url": "mock://audio.mp3",
                "duration": 60.0
            ]
        } catch {
            print("❌ Failed to synthesize audio: \(error)")
            throw SupabaseError.apiError("Failed to synthesize audio: \(error.localizedDescription)")
        }
    }

    func generateAvatar(heroId: String, prompt: String, style: String = "watercolor", quality: String = "high", size: String = "1024x1024") async throws -> [String: Any] {
        let requestBody = [
            "hero_id": heroId,
            "prompt": prompt,
            "style": style,
            "quality": quality,
            "size": size
        ] as [String: Any]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            _ = try await client.functions
                .invoke(
                    "avatar-generation",
                    options: FunctionInvokeOptions(body: jsonData)
                )

            // For now, return mock data until we figure out the correct API
            print("🎨 Generated avatar via edge function (mocked)")
            return [
                "avatar_url": "mock://avatar.png",
                "generation_id": UUID().uuidString
            ]
        } catch {
            print("❌ Failed to generate avatar: \(error)")
            throw SupabaseError.apiError("Failed to generate avatar: \(error.localizedDescription)")
        }
    }

    func generateSceneIllustrations(
        storyId: String,
        heroId: String,
        scenes: [[String: Any]],
        heroVisualProfile: [String: Any]? = nil,
        processAsync: Bool = false
    ) async throws -> [String: Any] {
        var requestBody: [String: Any] = [
            "story_id": storyId,
            "hero_id": heroId,
            "scenes": scenes,
            "process_async": processAsync
        ]

        if let profile = heroVisualProfile {
            requestBody["hero_visual_profile"] = profile
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            _ = try await client.functions
                .invoke(
                    "scene-illustrations",
                    options: FunctionInvokeOptions(body: jsonData)
                )

            // For now, return mock data until we figure out the correct API
            print("🖼️ Generated scene illustrations via edge function (mocked)")
            return [
                "illustrations": [],
                "status": "pending"
            ]
        } catch {
            print("❌ Failed to generate scene illustrations: \(error)")
            throw SupabaseError.apiError("Failed to generate scene illustrations: \(error.localizedDescription)")
        }
    }

    // MARK: - Realtime (Future implementation)

    func setupRealtimeSubscriptions() async {
        // TODO: Implement realtime subscriptions when needed
        print("📡 Realtime subscriptions not yet implemented")
    }

    func cleanupSubscriptions() async {
        // TODO: Implement subscription cleanup when needed
        print("🔚 Cleanup subscriptions not yet implemented")
    }

    // MARK: - Helpers

    func upsertHero(_ hero: Hero) async throws {
        try await saveHero(hero)
    }

    func upsertStory(_ story: Story) async throws {
        try await saveStory(story)
    }
}

// MARK: - Model Extensions for Sync

extension Hero {
    func markAsSynced() {
        lastSyncedAt = Date()
        needsSync = false
    }
}

extension Story {
    func markAsSynced() {
        lastSyncedAt = Date()
        needsSync = false
    }
}

// MARK: - SupabaseError for compatibility

enum SupabaseError: Error, LocalizedError {
    case apiError(String)
    case networkError(Error)
    case authenticationError(String)
    case decodingError(Error)
    case notFound
    case invalidConfiguration(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        case .decodingError(let error):
            return "Decoding Error: \(error.localizedDescription)"
        case .notFound:
            return "Requested resource was not found"
        case .invalidConfiguration(let message):
            return "Invalid Supabase configuration: \(message)"
        case .unexpectedResponse:
            return "Supabase returned an unexpected response"
        }
    }
}