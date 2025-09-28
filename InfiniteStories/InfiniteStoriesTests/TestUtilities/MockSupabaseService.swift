//
//  MockSupabaseService.swift
//  InfiniteStoriesTests
//
//  Mock implementation for offline testing
//

import Foundation
@testable import InfiniteStories

// MARK: - Mock Supabase Service

class MockSupabaseService: ObservableObject {
    // Mock data storage as dictionaries
    private var heroesData: [UUID: [String: Any]] = [:]
    private var storiesData: [UUID: [String: Any]] = [:]

    // Configuration
    var shouldFail = false
    var networkDelay: TimeInterval = 0.1
    var errorToThrow: SupabaseError = .networkError(NSError(domain: "Mock", code: -1))

    // Tracking
    var callCount: [String: Int] = [:]
    var lastCalledMethod: String?

    // Response configurations
    var mockResponses: [String: Any] = [:]
    var responseSequence: [Any] = []
    private var responseIndex = 0

    // MARK: - Helper Methods

    private func trackCall(_ method: String) {
        lastCalledMethod = method
        callCount[method, default: 0] += 1
    }

    private func simulateNetwork() async throws {
        try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))

        if shouldFail {
            throw errorToThrow
        }
    }

    private func getNextResponse<T>() -> T? {
        guard responseIndex < responseSequence.count else { return nil }
        let response = responseSequence[responseIndex]
        responseIndex += 1
        return response as? T
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        trackCall("testConnection")
        try await simulateNetwork()
        return !shouldFail
    }

    // MARK: - Hero Operations

    func saveHero(_ hero: Hero) async throws {
        trackCall("saveHero")
        try await simulateNetwork()

        let heroData: [String: Any] = [
            "id": hero.id.uuidString,
            "user_id": "00000000-0000-0000-0000-000000000001",
            "name": hero.name,
            "primary_trait": hero.primaryTrait.rawValue,
            "secondary_trait": hero.secondaryTrait.rawValue,
            "appearance": hero.appearance,
            "special_ability": hero.specialAbility,
            "created_at": ISO8601DateFormatter().string(from: hero.createdAt),
            "updated_at": ISO8601DateFormatter().string(from: hero.updatedAt),
            "is_active": hero.isActive,
            "avatar_prompt": hero.avatarPrompt as Any,
            "avatar_generation_id": hero.avatarGenerationId as Any
        ]

        heroesData[hero.id] = heroData
        hero.markAsSynced()
    }

    func fetchHeroes(limit: Int = 100) async throws -> [[String: Any]] {
        trackCall("fetchHeroes")
        try await simulateNetwork()

        if let mockHeroes = mockResponses["heroes"] as? [[String: Any]] {
            return mockHeroes
        }

        return Array(heroesData.values)
            .filter { ($0["is_active"] as? Bool) ?? true }
            .sorted { hero1, hero2 in
                let date1 = ISO8601DateFormatter().date(from: hero1["created_at"] as? String ?? "") ?? Date.distantPast
                let date2 = ISO8601DateFormatter().date(from: hero2["created_at"] as? String ?? "") ?? Date.distantPast
                return date1 > date2
            }
            .prefix(limit)
            .map { $0 }
    }

    func deleteHero(_ heroId: UUID) async throws {
        trackCall("deleteHero")
        try await simulateNetwork()

        if var heroData = heroesData[heroId] {
            heroData["is_active"] = false
            heroData["updated_at"] = ISO8601DateFormatter().string(from: Date())
            heroesData[heroId] = heroData
        }
    }

    // MARK: - Story Operations

    func saveStory(_ story: Story) async throws {
        trackCall("saveStory")
        try await simulateNetwork()

        var storyData: [String: Any] = [
            "id": story.id.uuidString,
            "user_id": "00000000-0000-0000-0000-000000000001",
            "title": story.title,
            "content": story.content,
            "created_at": ISO8601DateFormatter().string(from: story.createdAt),
            "is_favorite": story.isFavorite,
            "play_count": story.playCount,
            "estimated_duration": "\(Int(story.estimatedDuration)) seconds",
            "word_count": story.content.split(separator: " ").count
        ]

        if let heroId = story.hero?.id {
            storyData["hero_id"] = heroId.uuidString
        }

        if let builtInEvent = story.builtInEvent {
            storyData["event_type"] = "built_in"
            storyData["event_data"] = ["event": builtInEvent.rawValue]
        } else if let customEvent = story.customEvent {
            storyData["event_type"] = "custom"
            storyData["custom_event_id"] = customEvent.id.uuidString
        }

        storiesData[story.id] = storyData
        story.markAsSynced()
    }

    func fetchStories(limit: Int = 50) async throws -> [[String: Any]] {
        trackCall("fetchStories")
        try await simulateNetwork()

        if let mockStories = mockResponses["stories"] as? [[String: Any]] {
            return mockStories
        }

        return Array(storiesData.values)
            .sorted { story1, story2 in
                let date1 = ISO8601DateFormatter().date(from: story1["created_at"] as? String ?? "") ?? Date.distantPast
                let date2 = ISO8601DateFormatter().date(from: story2["created_at"] as? String ?? "") ?? Date.distantPast
                return date1 > date2
            }
            .prefix(limit)
            .map { $0 }
    }

    func fetchStoriesForHero(_ heroId: UUID, limit: Int = 20) async throws -> [[String: Any]] {
        trackCall("fetchStoriesForHero")
        try await simulateNetwork()

        return Array(storiesData.values)
            .filter { ($0["hero_id"] as? String) == heroId.uuidString }
            .sorted { story1, story2 in
                let date1 = ISO8601DateFormatter().date(from: story1["created_at"] as? String ?? "") ?? Date.distantPast
                let date2 = ISO8601DateFormatter().date(from: story2["created_at"] as? String ?? "") ?? Date.distantPast
                return date1 > date2
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Edge Functions (Mocked)

    func generateStory(
        heroId: String,
        event: [String: Any],
        targetDuration: Int,
        language: String
    ) async throws -> [String: Any] {
        trackCall("generateStory")
        try await simulateNetwork()

        if let mockResponse = mockResponses["generateStory"] as? [String: Any] {
            return mockResponse
        }

        return [
            "story_id": UUID().uuidString,
            "title": "Mock Story Title",
            "content": "Once upon a time in a mock testing world...",
            "estimated_duration": targetDuration,
            "word_count": 250,
            "language": language,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
    }

    func synthesizeAudio(
        text: String,
        voice: String,
        language: String,
        storyId: String? = nil
    ) async throws -> [String: Any] {
        trackCall("synthesizeAudio")
        try await simulateNetwork()

        if let mockResponse = mockResponses["synthesizeAudio"] as? [String: Any] {
            return mockResponse
        }

        return [
            "audio_url": "mock://test-audio.mp3",
            "duration": 180.0,
            "voice": voice,
            "language": language
        ]
    }

    func generateAvatar(
        heroId: String,
        prompt: String,
        style: String = "watercolor",
        quality: String = "high",
        size: String = "1024x1024"
    ) async throws -> [String: Any] {
        trackCall("generateAvatar")
        try await simulateNetwork()

        if let mockResponse = mockResponses["generateAvatar"] as? [String: Any] {
            return mockResponse
        }

        return [
            "avatar_url": "mock://test-avatar.png",
            "generation_id": UUID().uuidString,
            "style": style,
            "quality": quality,
            "size": size
        ]
    }

    func generateSceneIllustrations(
        storyId: String,
        heroId: String,
        scenes: [[String: Any]],
        heroVisualProfile: [String: Any]? = nil,
        processAsync: Bool = false
    ) async throws -> [String: Any] {
        trackCall("generateSceneIllustrations")
        try await simulateNetwork()

        if let mockResponse = mockResponses["generateSceneIllustrations"] as? [String: Any] {
            return mockResponse
        }

        return [
            "illustrations": scenes.map { scene in
                [
                    "scene_id": scene["id"] as? String ?? UUID().uuidString,
                    "image_url": "mock://scene-\(scene["id"] as? String ?? "unknown").png",
                    "timestamp": scene["timestamp"] as? Double ?? 0.0,
                    "prompt": scene["prompt"] as? String ?? ""
                ]
            },
            "status": processAsync ? "processing" : "completed"
        ]
    }

    // MARK: - Realtime (Mocked)

    func setupRealtimeSubscriptions() async {
        trackCall("setupRealtimeSubscriptions")
        // Mock implementation - no-op
    }

    func cleanupSubscriptions() async {
        trackCall("cleanupSubscriptions")
        // Mock implementation - no-op
    }

    // MARK: - Helper Functions

    func upsertHero(_ hero: Hero) async throws {
        try await saveHero(hero)
    }

    func upsertStory(_ story: Story) async throws {
        try await saveStory(story)
    }

    // MARK: - Test Helpers

    func reset() {
        heroesData.removeAll()
        storiesData.removeAll()
        callCount.removeAll()
        lastCalledMethod = nil
        mockResponses.removeAll()
        responseSequence.removeAll()
        responseIndex = 0
        shouldFail = false
    }

    func seedMockData() {
        // Add some default mock hero data
        let heroId = UUID()
        let heroData: [String: Any] = [
            "id": heroId.uuidString,
            "user_id": "00000000-0000-0000-0000-000000000001",
            "name": "Test Hero 1",
            "primary_trait": "brave",
            "secondary_trait": "kind",
            "appearance": "A brave knight with shining armor",
            "special_ability": "Super strength",
            "avatar_prompt": "A brave knight",
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date()),
            "is_active": true
        ]

        heroesData[heroId] = heroData

        // Add some default mock story data
        let storyId = UUID()
        let storyData: [String: Any] = [
            "id": storyId.uuidString,
            "user_id": "00000000-0000-0000-0000-000000000001",
            "hero_id": heroId.uuidString,
            "title": "Test Story 1",
            "content": "This is a test story content",
            "event_type": "bedtime",
            "estimated_duration": 60,
            "word_count": 100,
            "language": "en",
            "generated_voice": "alloy",
            "has_illustrations": false,
            "illustration_count": 0,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date()),
            "is_favorite": false
        ]

        storiesData[storyId] = storyData
    }
}