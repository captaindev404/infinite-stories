//
//  FirebaseMockDataHelpers.swift
//  InfiniteStoriesTests
//
//  Mock data generators and helpers for Firebase testing
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
@testable import InfiniteStories

// MARK: - Mock Data Factory

/// Factory for creating consistent test data across all Firebase tests
struct FirebaseMockDataFactory {

    // MARK: - User Mock Data

    static func createMockUser(
        id: String = UUID().uuidString,
        email: String = "user@test.com",
        displayName: String = "Test User",
        isVerified: Bool = false
    ) -> MockFirebaseUser {
        return MockFirebaseUser(
            uid: id,
            email: email,
            displayName: displayName,
            isEmailVerified: isVerified,
            isAnonymous: false
        )
    }

    static func createAnonymousUser() -> MockFirebaseUser {
        return MockFirebaseUser(
            uid: UUID().uuidString,
            email: nil,
            displayName: nil,
            isEmailVerified: false,
            isAnonymous: true
        )
    }

    // MARK: - Hero Mock Data

    static func createMockHero(
        id: String = UUID().uuidString,
        name: String = "Test Hero",
        age: Int = 8,
        traits: [String] = ["brave", "kind", "curious"],
        hasAvatar: Bool = true
    ) -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "age": age,
            "personalityTraits": traits,
            "physicalDescription": "A \(traits.first ?? "brave") young hero with sparkling eyes",
            "specialAbilities": "Courage and determination",
            "backstory": "Born in the magical land of Infinite Stories",
            "favoriteThings": "Adventures, helping friends, and bedtime stories",
            "voiceType": "energetic",
            "avatarPrompt": "A young \(name) with \(traits.joined(separator: ", ")) personality",
            "avatarURL": hasAvatar ? "https://storage.test/avatars/\(id).png" : nil,
            "hasAvatar": hasAvatar,
            "createdAt": Timestamp(date: Date()),
            "modifiedAt": Timestamp(date: Date())
        ]
    }

    static func createMockHeroVisualProfile(
        heroId: String
    ) -> [String: Any] {
        return [
            "heroId": heroId,
            "hairColor": "brown",
            "hairStyle": "short and wavy",
            "eyeColor": "blue",
            "skinTone": "fair",
            "clothingStyle": "adventurer outfit with cape",
            "distinctiveFeatures": "bright smile, freckles",
            "artStyle": "whimsical children's book illustration",
            "colorPalette": ["blue", "gold", "green"],
            "canonicalPrompt": "A young hero with brown wavy hair, blue eyes, and adventurer outfit",
            "simplifiedPrompt": "Young hero, brown hair, blue eyes, cape"
        ]
    }

    // MARK: - Story Mock Data

    static func createMockStory(
        id: String = UUID().uuidString,
        title: String = "The Great Adventure",
        heroId: String? = nil,
        content: String? = nil,
        hasAudio: Bool = true,
        hasIllustrations: Bool = false,
        language: String = "en"
    ) -> [String: Any] {
        let defaultContent = """
        Once upon a time, in a land far away, there lived a brave young hero.
        Every day brought new adventures and exciting discoveries.
        Our hero loved exploring the magical forests and making new friends.
        This is the story of one particularly amazing adventure...
        """

        return [
            "id": id,
            "title": title,
            "content": content ?? defaultContent,
            "heroId": heroId ?? UUID().uuidString,
            "eventType": "bedtime",
            "duration": 180,
            "language": language,
            "audioURL": hasAudio ? "https://storage.test/audio/\(id).mp3" : nil,
            "hasAudio": hasAudio,
            "illustrationCount": hasIllustrations ? 4 : 0,
            "hasIllustrations": hasIllustrations,
            "isFavorite": false,
            "createdAt": Timestamp(date: Date()),
            "lastPlayed": nil
        ]
    }

    static func createMockStoryScenes(storyId: String) -> [[String: Any]] {
        return [
            [
                "sceneNumber": 1,
                "content": "The hero woke up to a beautiful sunny morning.",
                "timestamp": 0.0,
                "prompt": "Young hero waking up in a cozy bedroom, morning sunlight"
            ],
            [
                "sceneNumber": 2,
                "content": "They ventured into the magical forest.",
                "timestamp": 15.5,
                "prompt": "Hero walking through enchanted forest with tall trees"
            ],
            [
                "sceneNumber": 3,
                "content": "A friendly dragon appeared from behind the trees.",
                "timestamp": 30.0,
                "prompt": "Friendly green dragon meeting the hero in forest clearing"
            ],
            [
                "sceneNumber": 4,
                "content": "Together they had an amazing adventure.",
                "timestamp": 45.0,
                "prompt": "Hero and dragon flying above the clouds at sunset"
            ]
        ]
    }

    // MARK: - Custom Event Mock Data

    static func createMockCustomEvent(
        id: String = UUID().uuidString,
        userId: String,
        title: String = "First Day at Magic School",
        category: String = "adventure"
    ) -> [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "title": title,
            "description": "An exciting story about starting at a magical school",
            "promptSeed": "First day at a school for young wizards, making friends, learning spells",
            "category": category,
            "tone": "exciting",
            "ageRange": "5-7",
            "keywords": ["school", "magic", "friends", "learning"],
            "pictogram": "🏫✨",
            "usageCount": 0,
            "isFavorite": false,
            "createdAt": Timestamp(date: Date()),
            "lastUsed": nil,
            "aiEnhanced": false
        ]
    }

    // MARK: - Illustration Mock Data

    static func createMockIllustration(
        id: String = UUID().uuidString,
        storyId: String,
        sceneNumber: Int,
        timestamp: Double = 0.0
    ) -> [String: Any] {
        return [
            "id": id,
            "storyId": storyId,
            "sceneNumber": sceneNumber,
            "timestamp": timestamp,
            "prompt": "Scene \(sceneNumber) illustration prompt",
            "imageURL": "https://storage.test/illustrations/\(storyId)/scene-\(sceneNumber).png",
            "generationId": "gen-\(UUID().uuidString)",
            "status": "completed",
            "error": nil,
            "retryCount": 0,
            "createdAt": Timestamp(date: Date())
        ]
    }

    // MARK: - Audio Mock Data

    static func createMockAudioMetadata(
        storyId: String,
        duration: Double = 180.0,
        voice: String = "nova"
    ) -> [String: Any] {
        return [
            "storyId": storyId,
            "duration": duration,
            "voice": voice,
            "format": "mp3",
            "bitrate": 128,
            "sampleRate": 44100,
            "fileSize": Int(duration * 16000), // Rough estimate
            "url": "https://storage.test/audio/\(storyId).mp3",
            "createdAt": Timestamp(date: Date())
        ]
    }

    // MARK: - Batch Data Creation

    static func createMockDataSet(userId: String) -> MockDataSet {
        let heroes = (1...3).map { i in
            createMockHero(
                id: "hero-\(i)",
                name: "Hero \(i)",
                age: 6 + i
            )
        }

        let stories = heroes.flatMap { hero in
            (1...2).map { j in
                createMockStory(
                    id: "\(hero["id"] as! String)-story-\(j)",
                    title: "Adventure \(j) of \(hero["name"] as! String)",
                    heroId: hero["id"] as? String,
                    hasIllustrations: j == 1
                )
            }
        }

        let customEvents = (1...5).map { i in
            createMockCustomEvent(
                id: "event-\(i)",
                userId: userId,
                title: "Custom Event \(i)"
            )
        }

        return MockDataSet(
            userId: userId,
            heroes: heroes,
            stories: stories,
            customEvents: customEvents
        )
    }
}

// MARK: - Mock Data Models

struct MockDataSet {
    let userId: String
    let heroes: [[String: Any]]
    let stories: [[String: Any]]
    let customEvents: [[String: Any]]
}

struct MockFirebaseUser {
    let uid: String
    let email: String?
    let displayName: String?
    let isEmailVerified: Bool
    let isAnonymous: Bool

    var photoURL: URL? {
        return URL(string: "https://example.com/photos/\(uid).jpg")
    }
}

// MARK: - Test Data Validators

struct FirebaseTestDataValidator {

    static func validateHeroData(_ data: [String: Any]) -> Bool {
        let requiredFields = ["id", "name", "age", "personalityTraits", "createdAt"]
        return requiredFields.allSatisfy { data[$0] != nil }
    }

    static func validateStoryData(_ data: [String: Any]) -> Bool {
        let requiredFields = ["id", "title", "content", "heroId", "createdAt"]
        return requiredFields.allSatisfy { data[$0] != nil }
    }

    static func validateCustomEventData(_ data: [String: Any]) -> Bool {
        let requiredFields = ["id", "userId", "title", "description", "category", "createdAt"]
        return requiredFields.allSatisfy { data[$0] != nil }
    }

    static func validateTimestamp(_ data: [String: Any], field: String) -> Bool {
        return data[field] is Timestamp
    }
}

// MARK: - Test Data Comparators

extension Dictionary where Key == String, Value == Any {

    /// Compare two Firebase data dictionaries, ignoring timestamps
    func isEqualIgnoringTimestamps(to other: [String: Any]) -> Bool {
        for (key, value) in self {
            // Skip timestamp fields
            if key.contains("At") || key.contains("Date") || value is Timestamp {
                continue
            }

            // Compare other values
            if let otherValue = other[key] {
                // Handle arrays
                if let array1 = value as? [Any],
                   let array2 = otherValue as? [Any] {
                    if !array1.elementsEqual(array2, by: { "\($0)" == "\($1)" }) {
                        return false
                    }
                }
                // Handle other types
                else if "\(value)" != "\(otherValue)" {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }
}

// MARK: - Performance Test Helpers

struct FirebasePerformanceTestHelper {

    /// Generate large dataset for performance testing
    static func generateLargeDataset(
        heroCount: Int = 100,
        storiesPerHero: Int = 10
    ) -> [[String: Any]] {
        var allData: [[String: Any]] = []

        for i in 1...heroCount {
            let hero = FirebaseMockDataFactory.createMockHero(
                id: "perf-hero-\(i)",
                name: "Performance Hero \(i)"
            )
            allData.append(hero)

            for j in 1...storiesPerHero {
                let story = FirebaseMockDataFactory.createMockStory(
                    id: "perf-story-\(i)-\(j)",
                    title: "Perf Story \(j)",
                    heroId: hero["id"] as? String
                )
                allData.append(story)
            }
        }

        return allData
    }

    /// Measure time for async operation
    static func measureAsyncTime(
        operation: () async throws -> Void
    ) async throws -> TimeInterval {
        let start = Date()
        try await operation()
        return Date().timeIntervalSince(start)
    }
}

// MARK: - Mock Service Responses

struct MockFirebaseResponses {

    static func successResponse() -> [String: Any] {
        return [
            "success": true,
            "message": "Operation completed successfully",
            "timestamp": Date().timeIntervalSince1970
        ]
    }

    static func errorResponse(code: String, message: String) -> [String: Any] {
        return [
            "success": false,
            "error": [
                "code": code,
                "message": message
            ],
            "timestamp": Date().timeIntervalSince1970
        ]
    }

    static func paginatedResponse<T>(
        items: [T],
        page: Int,
        pageSize: Int,
        total: Int
    ) -> [String: Any] {
        return [
            "items": items,
            "pagination": [
                "page": page,
                "pageSize": pageSize,
                "total": total,
                "hasMore": (page * pageSize) < total
            ]
        ]
    }
}

// MARK: - Test Assertion Helpers

extension XCTestCase {

    /// Assert Firebase document exists and contains expected fields
    func assertDocument(
        _ document: DocumentSnapshot,
        hasFields fields: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(document.exists, "Document should exist", file: file, line: line)

        guard let data = document.data() else {
            XCTFail("Document data should not be nil", file: file, line: line)
            return
        }

        for field in fields {
            XCTAssertNotNil(
                data[field],
                "Document should have field '\(field)'",
                file: file,
                line: line
            )
        }
    }

    /// Assert Firebase collection has expected count
    func assertCollection(
        _ snapshot: QuerySnapshot,
        hasCount expectedCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            snapshot.documents.count,
            expectedCount,
            "Collection should have \(expectedCount) documents",
            file: file,
            line: line
        )
    }
}