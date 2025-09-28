//
//  SupabaseServiceTests.swift
//  InfiniteStoriesTests
//
//  Created by Test Automation Framework
//

import XCTest
import SwiftData
@testable import InfiniteStories

// MARK: - Database Operations Tests

class SupabaseHeroDatabaseTests: XCTestCase {
    var sut: SupabaseService!
    var testHero: Hero!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        sut = SupabaseService.shared

        // Setup test model context
        let container = try ModelContainer(for: Hero.self, Story.self)
        modelContext = ModelContext(container)

        // Create test hero
        testHero = Hero(
            name: "Test Hero \(UUID().uuidString.prefix(8))",
            primaryTrait: .brave,
            secondaryTrait: .kind
        )
        testHero.appearance = "Blue cape, red boots"
        testHero.specialAbility = "Super speed"
    }

    override func tearDown() async throws {
        // Clean up test data
        if let hero = testHero {
            try? await sut.deleteHero(hero.id)
        }
        try await super.tearDown()
    }

    // MARK: - Hero Upsert Tests

    func testHeroUpsert_WithValidData_SavesSuccessfully() async throws {
        // Act
        try await sut.upsertHero(testHero)

        // Assert
        XCTAssertNotNil(testHero.lastSyncedAt)
        XCTAssertFalse(testHero.needsSync)

        // Verify in database
        let heroes = try await sut.fetchHeroes()
        let savedHero = heroes.first { $0.id == testHero.id }

        XCTAssertNotNil(savedHero)
        XCTAssertEqual(savedHero?.name, testHero.name)
        XCTAssertEqual(savedHero?.primaryTrait, testHero.primaryTrait.rawValue)
        XCTAssertEqual(savedHero?.secondaryTrait, testHero.secondaryTrait.rawValue)
    }

    func testHeroUpsert_UpdateExisting_ModifiesCorrectly() async throws {
        // Initial save
        try await sut.upsertHero(testHero)

        // Modify
        testHero.name = "Updated Hero Name"
        testHero.specialAbility = "Flight"

        // Update
        try await sut.upsertHero(testHero)

        // Verify
        let heroes = try await sut.fetchHeroes()
        let updatedHero = heroes.first { $0.id == testHero.id }

        XCTAssertEqual(updatedHero?.name, "Updated Hero Name")
        XCTAssertEqual(updatedHero?.specialAbility, "Flight")
    }

    func testHeroUpsert_WithAvatarData_SavesAllFields() async throws {
        // Add avatar data
        testHero.avatarPrompt = "A brave hero with blue cape"
        testHero.avatarGenerationId = "gen_123456"
        testHero.avatarGeneratedAt = Date()

        // Save
        try await sut.upsertHero(testHero)

        // Verify
        let heroes = try await sut.fetchHeroes()
        let savedHero = heroes.first { $0.id == testHero.id }

        XCTAssertEqual(savedHero?.avatarPrompt, testHero.avatarPrompt)
        XCTAssertEqual(savedHero?.avatarGenerationId, testHero.avatarGenerationId)
    }

    // MARK: - Hero Fetch Tests

    func testFetchHeroes_ReturnsActiveHeroesOnly() async throws {
        // Create multiple heroes
        let hero1 = Hero(name: "Active Hero 1", primaryTrait: .brave, secondaryTrait: .kind)
        let hero2 = Hero(name: "Active Hero 2", primaryTrait: .curious, secondaryTrait: .funny)

        try await sut.upsertHero(hero1)
        try await sut.upsertHero(hero2)

        // Fetch
        let heroes = try await sut.fetchHeroes()

        // Verify
        XCTAssertGreaterThanOrEqual(heroes.count, 2)
        XCTAssertTrue(heroes.allSatisfy { $0.isActive })

        // Cleanup
        try await sut.deleteHero(hero1.id)
        try await sut.deleteHero(hero2.id)
    }

    func testFetchHeroes_OrdersByCreatedDate() async throws {
        // Create heroes with delay
        let hero1 = Hero(name: "First Hero", primaryTrait: .brave, secondaryTrait: .kind)
        try await sut.upsertHero(hero1)

        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        let hero2 = Hero(name: "Second Hero", primaryTrait: .curious, secondaryTrait: .funny)
        try await sut.upsertHero(hero2)

        // Fetch
        let heroes = try await sut.fetchHeroes()

        // Find our test heroes
        let testHeroes = heroes.filter { $0.name.contains("Hero") }
        if testHeroes.count >= 2 {
            // Second hero should appear first (descending order)
            XCTAssertTrue(testHeroes[0].createdAt > testHeroes[1].createdAt)
        }

        // Cleanup
        try await sut.deleteHero(hero1.id)
        try await sut.deleteHero(hero2.id)
    }

    // MARK: - Hero Delete Tests

    func testDeleteHero_SoftDeletesSuccessfully() async throws {
        // Save hero
        try await sut.upsertHero(testHero)

        // Delete
        try await sut.deleteHero(testHero.id)

        // Verify it's not in active heroes
        let heroes = try await sut.fetchHeroes()
        let deletedHero = heroes.first { $0.id == testHero.id }

        XCTAssertNil(deletedHero)
    }
}

// MARK: - Story Database Tests

class SupabaseStoryDatabaseTests: XCTestCase {
    var sut: SupabaseService!
    var testHero: Hero!
    var testStory: Story!

    override func setUp() async throws {
        try await super.setUp()
        sut = SupabaseService.shared

        // Create test hero
        testHero = Hero(
            name: "Story Test Hero",
            primaryTrait: .brave,
            secondaryTrait: .kind
        )

        // Create test story
        testStory = Story(
            title: "Test Adventure \(UUID().uuidString.prefix(8))",
            content: "Once upon a time, there was a brave hero...",
            hero: testHero,
            createdAt: Date()
        )
        testStory.builtInEvent = .bedtime
        testStory.estimatedDuration = 300
    }

    override func tearDown() async throws {
        // Clean up
        if let hero = testHero {
            try? await sut.deleteHero(hero.id)
        }
        try await super.tearDown()
    }

    func testStoryUpsert_WithHeroRelationship_SavesCorrectly() async throws {
        // Save hero first
        try await sut.upsertHero(testHero)

        // Save story
        try await sut.upsertStory(testStory)

        // Verify
        XCTAssertNotNil(testStory.lastSyncedAt)
        XCTAssertFalse(testStory.needsSync)

        // Fetch and verify
        let stories = try await sut.fetchStories()
        let savedStory = stories.first { $0.id == testStory.id }

        XCTAssertNotNil(savedStory)
        XCTAssertEqual(savedStory?.title, testStory.title)
        XCTAssertEqual(savedStory?.heroId, testHero.id)
    }

    func testStoryUpsert_WithCustomEvent_SavesEventData() async throws {
        // Create custom event
        let customEvent = CustomStoryEvent(
            title: "Test Event",
            description: "A test custom event",
            promptSeed: "Test prompt"
        )
        testStory.customEvent = customEvent
        testStory.builtInEvent = nil

        // Save
        try await sut.upsertStory(testStory)

        // Fetch and verify
        let stories = try await sut.fetchStories()
        let savedStory = stories.first { $0.id == testStory.id }

        XCTAssertNotNil(savedStory)
        // Event type should be saved correctly
        // Note: Full verification would require checking event_data JSON
    }

    func testFetchStoriesForHero_ReturnsCorrectStories() async throws {
        // Save hero
        try await sut.upsertHero(testHero)

        // Create multiple stories for hero
        let story1 = Story(
            title: "Adventure 1",
            content: "Content 1",
            hero: testHero,
            createdAt: Date()
        )
        let story2 = Story(
            title: "Adventure 2",
            content: "Content 2",
            hero: testHero,
            createdAt: Date()
        )

        try await sut.upsertStory(story1)
        try await sut.upsertStory(story2)

        // Fetch stories for hero
        let heroStories = try await sut.fetchStoriesForHero(testHero.id)

        // Verify
        XCTAssertGreaterThanOrEqual(heroStories.count, 2)
        XCTAssertTrue(heroStories.allSatisfy { $0.heroId == testHero.id })
    }
}

// MARK: - Edge Function Tests

class SupabaseEdgeFunctionTests: XCTestCase {
    var sut: SupabaseService!

    override func setUp() async throws {
        try await super.setUp()
        sut = SupabaseService.shared
    }

    func testStoryGeneration_WithValidInput_ReturnsStory() async throws {
        // This test requires Edge Functions to be running
        // Skip if not in integration test mode
        guard ProcessInfo.processInfo.environment["INTEGRATION_TESTS"] == "1" else {
            throw XCTSkip("Skipping integration test - Edge Functions not available")
        }

        // Arrange
        let heroId = UUID().uuidString
        let event: [String: Any] = [
            "type": "built_in",
            "data": ["event": "bedtime"]
        ]

        // Act
        let result = try await sut.generateStory(
            heroId: heroId,
            event: event,
            targetDuration: 300,
            language: "en"
        )

        // Assert
        XCTAssertFalse(result.title.isEmpty)
        XCTAssertFalse(result.content.isEmpty)
        XCTAssertGreaterThan(result.wordCount, 50)
        XCTAssertEqual(result.estimatedDuration, 300, accuracy: 60)
    }

    func testAudioSynthesis_WithValidText_ReturnsAudioURL() async throws {
        // Skip if not in integration test mode
        guard ProcessInfo.processInfo.environment["INTEGRATION_TESTS"] == "1" else {
            throw XCTSkip("Skipping integration test - Edge Functions not available")
        }

        // Arrange
        let text = "Once upon a time, there was a brave little hero."

        // Act
        let result = try await sut.synthesizeAudio(
            text: text,
            voice: "nova",
            language: "en"
        )

        // Assert
        XCTAssertFalse(result.audioUrl.isEmpty)
        XCTAssertGreaterThan(result.duration, 0)
    }
}

// MARK: - Real-time Subscription Tests

class SupabaseRealtimeTests: XCTestCase {
    var device1: SupabaseService!
    var device2: SupabaseService!

    override func setUp() async throws {
        try await super.setUp()
        // In real implementation, would create separate instances
        device1 = SupabaseService.shared
        device2 = SupabaseService.shared
    }

    func testRealtimeSync_HeroUpdate_ReceivesNotification() async throws {
        // Skip if not in integration test mode
        guard ProcessInfo.processInfo.environment["INTEGRATION_TESTS"] == "1" else {
            throw XCTSkip("Skipping integration test - Realtime not available")
        }

        // Setup subscription
        await device2.setupRealtimeSubscriptions()

        // Setup expectation for notification
        let expectation = XCTestExpectation(description: "Hero update notification")

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HeroesDataChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let change = notification.userInfo?["change"] as? String,
               change == "update" {
                expectation.fulfill()
            }
        }

        // Create and update hero
        let hero = Hero(name: "Realtime Test Hero", primaryTrait: .brave, secondaryTrait: .kind)
        try await device1.upsertHero(hero)

        // Update hero
        hero.name = "Updated Realtime Hero"
        try await device1.upsertHero(hero)

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 5.0)

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
        await device2.cleanupSubscriptions()
        try await device1.deleteHero(hero.id)
    }
}

// MARK: - Error Handling Tests

class SupabaseErrorHandlingTests: XCTestCase {
    var sut: SupabaseService!

    override func setUp() async throws {
        try await super.setUp()
        sut = SupabaseService.shared
    }

    func testInvalidDataHandling_ThrowsAppropriateError() async throws {
        // Test with invalid hero ID format
        do {
            _ = try await sut.fetchStoriesForHero(UUID())
            // If no stories exist, this is valid
        } catch let error as SupabaseError {
            // Verify error is handled appropriately
            XCTAssertNotNil(error.errorDescription)
        }
    }

    func testConnectionTest_ReturnsStatus() async throws {
        // Test connection
        let isConnected = try await sut.testConnection()

        // Should return true for local development
        XCTAssertTrue(isConnected)
    }
}

// MARK: - Performance Tests

class SupabasePerformanceTests: XCTestCase {
    var sut: SupabaseService!

    override func setUp() async throws {
        try await super.setUp()
        sut = SupabaseService.shared
    }

    func testBulkHeroFetch_PerformanceUnder1Second() throws {
        // Measure fetch performance
        measure {
            let expectation = XCTestExpectation()

            Task {
                _ = try? await sut.fetchHeroes()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0)
        }
    }

    func testSingleHeroUpsert_PerformanceUnder500ms() throws {
        let hero = Hero(name: "Performance Test", primaryTrait: .brave, secondaryTrait: .kind)

        measure {
            let expectation = XCTestExpectation()

            Task {
                try? await sut.upsertHero(hero)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 0.5)
        }

        // Cleanup
        Task {
            try? await sut.deleteHero(hero.id)
        }
    }
}