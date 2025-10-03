//
//  FirebaseDataServiceTests.swift
//  InfiniteStoriesTests
//
//  Comprehensive tests for Firestore data operations
//

import XCTest
import FirebaseFirestore
@testable import InfiniteStories

final class FirebaseDataServiceTests: FirebaseTestBase {

    // MARK: - Properties

    var dataService: FirebaseDataServiceMock!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Initialize data service with test Firestore instance
        dataService = FirebaseDataServiceMock(firestore: testFirestore)
    }

    override func tearDownWithError() throws {
        dataService = nil
        try super.tearDownWithError()
    }

    // MARK: - Hero Tests

    func testCreateHero() async throws {
        // Given
        let heroData = createTestHeroData(name: "Super Kid")

        // When
        let docRef = try await dataService.createHero(data: heroData)

        // Then
        XCTAssertNotNil(docRef)
        let snapshot = try await docRef.getDocument()
        XCTAssertTrue(snapshot.exists)
        XCTAssertEqual(snapshot.data()?["name"] as? String, "Super Kid")
    }

    func testGetHero() async throws {
        // Given - Create a hero first
        let heroData = createTestHeroData(name: "Test Hero")
        let docRef = try await createTestDocument(
            collection: "heroes",
            documentId: "test-hero-123",
            data: heroData
        )

        // When
        let retrievedData = try await dataService.getHero(id: "test-hero-123")

        // Then
        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData?["name"] as? String, "Test Hero")
    }

    func testGetNonExistentHero() async throws {
        // When
        let retrievedData = try await dataService.getHero(id: "non-existent-id")

        // Then
        XCTAssertNil(retrievedData)
    }

    func testUpdateHero() async throws {
        // Given - Create a hero first
        let heroData = createTestHeroData(name: "Original Name")
        let docRef = try await createTestDocument(
            collection: "heroes",
            documentId: "update-test-hero",
            data: heroData
        )

        // When
        let updates = ["name": "Updated Name", "age": 10]
        try await dataService.updateHero(id: "update-test-hero", data: updates)

        // Then
        let snapshot = try await docRef.getDocument()
        XCTAssertEqual(snapshot.data()?["name"] as? String, "Updated Name")
        XCTAssertEqual(snapshot.data()?["age"] as? Int, 10)
    }

    func testDeleteHero() async throws {
        // Given - Create a hero first
        let heroData = createTestHeroData(name: "To Delete")
        _ = try await createTestDocument(
            collection: "heroes",
            documentId: "delete-test-hero",
            data: heroData
        )

        // When
        try await dataService.deleteHero(id: "delete-test-hero")

        // Then
        let snapshot = try await testFirestore
            .collection("heroes")
            .document("delete-test-hero")
            .getDocument()
        XCTAssertFalse(snapshot.exists)
    }

    func testGetAllHeroes() async throws {
        // Given - Create multiple heroes
        let hero1 = createTestHeroData(name: "Hero 1")
        let hero2 = createTestHeroData(name: "Hero 2")
        let hero3 = createTestHeroData(name: "Hero 3")

        _ = try await createTestDocument(collection: "heroes", data: hero1)
        _ = try await createTestDocument(collection: "heroes", data: hero2)
        _ = try await createTestDocument(collection: "heroes", data: hero3)

        // When
        let heroes = try await dataService.getAllHeroes()

        // Then
        XCTAssertGreaterThanOrEqual(heroes.count, 3)
        let heroNames = heroes.compactMap { $0["name"] as? String }
        XCTAssertTrue(heroNames.contains("Hero 1"))
        XCTAssertTrue(heroNames.contains("Hero 2"))
        XCTAssertTrue(heroNames.contains("Hero 3"))
    }

    // MARK: - Story Tests

    func testCreateStory() async throws {
        // Given
        let storyData = createTestStoryData(title: "Amazing Adventure")

        // When
        let docRef = try await dataService.createStory(data: storyData)

        // Then
        XCTAssertNotNil(docRef)
        let snapshot = try await docRef.getDocument()
        XCTAssertTrue(snapshot.exists)
        XCTAssertEqual(snapshot.data()?["title"] as? String, "Amazing Adventure")
    }

    func testGetStory() async throws {
        // Given - Create a story first
        let storyData = createTestStoryData(title: "Test Story")
        _ = try await createTestDocument(
            collection: "stories",
            documentId: "test-story-123",
            data: storyData
        )

        // When
        let retrievedData = try await dataService.getStory(id: "test-story-123")

        // Then
        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData?["title"] as? String, "Test Story")
    }

    func testUpdateStory() async throws {
        // Given - Create a story first
        let storyData = createTestStoryData(title: "Original Title")
        let docRef = try await createTestDocument(
            collection: "stories",
            documentId: "update-test-story",
            data: storyData
        )

        // When
        let updates = [
            "title": "Updated Title",
            "isFavorite": true
        ]
        try await dataService.updateStory(id: "update-test-story", data: updates)

        // Then
        let snapshot = try await docRef.getDocument()
        XCTAssertEqual(snapshot.data()?["title"] as? String, "Updated Title")
        XCTAssertEqual(snapshot.data()?["isFavorite"] as? Bool, true)
    }

    func testDeleteStory() async throws {
        // Given - Create a story first
        let storyData = createTestStoryData(title: "To Delete")
        _ = try await createTestDocument(
            collection: "stories",
            documentId: "delete-test-story",
            data: storyData
        )

        // When
        try await dataService.deleteStory(id: "delete-test-story")

        // Then
        let snapshot = try await testFirestore
            .collection("stories")
            .document("delete-test-story")
            .getDocument()
        XCTAssertFalse(snapshot.exists)
    }

    func testGetStoriesForHero() async throws {
        // Given - Create stories for specific hero
        let heroId = "hero-123"
        let story1 = createTestStoryData(title: "Story 1", heroId: heroId)
        let story2 = createTestStoryData(title: "Story 2", heroId: heroId)
        let story3 = createTestStoryData(title: "Story 3", heroId: "other-hero")

        _ = try await createTestDocument(collection: "stories", data: story1)
        _ = try await createTestDocument(collection: "stories", data: story2)
        _ = try await createTestDocument(collection: "stories", data: story3)

        // When
        let stories = try await dataService.getStoriesForHero(heroId: heroId)

        // Then
        XCTAssertEqual(stories.count, 2)
        let storyTitles = stories.compactMap { $0["title"] as? String }
        XCTAssertTrue(storyTitles.contains("Story 1"))
        XCTAssertTrue(storyTitles.contains("Story 2"))
        XCTAssertFalse(storyTitles.contains("Story 3"))
    }

    // MARK: - Custom Event Tests

    func testCreateCustomEvent() async throws {
        // Given
        let userId = "user-123"
        let eventData = createTestCustomEventData(title: "Birthday Party", userId: userId)

        // When
        let docRef = try await dataService.createCustomEvent(userId: userId, data: eventData)

        // Then
        XCTAssertNotNil(docRef)
        let snapshot = try await docRef.getDocument()
        XCTAssertTrue(snapshot.exists)
        XCTAssertEqual(snapshot.data()?["title"] as? String, "Birthday Party")
    }

    func testGetCustomEvent() async throws {
        // Given - Create an event first
        let userId = "user-123"
        let eventData = createTestCustomEventData(title: "Test Event", userId: userId)
        _ = try await createTestDocument(
            collection: "users/\(userId)/customEvents",
            documentId: "test-event-123",
            data: eventData
        )

        // When
        let retrievedData = try await dataService.getCustomEvent(
            userId: userId,
            eventId: "test-event-123"
        )

        // Then
        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData?["title"] as? String, "Test Event")
    }

    func testGetCustomEventsForUser() async throws {
        // Given - Create events for user
        let userId = "user-123"
        let event1 = createTestCustomEventData(title: "Event 1", userId: userId)
        let event2 = createTestCustomEventData(title: "Event 2", userId: userId)

        _ = try await createTestDocument(
            collection: "users/\(userId)/customEvents",
            data: event1
        )
        _ = try await createTestDocument(
            collection: "users/\(userId)/customEvents",
            data: event2
        )

        // When
        let events = try await dataService.getCustomEvents(userId: userId)

        // Then
        XCTAssertEqual(events.count, 2)
        let eventTitles = events.compactMap { $0["title"] as? String }
        XCTAssertTrue(eventTitles.contains("Event 1"))
        XCTAssertTrue(eventTitles.contains("Event 2"))
    }

    // MARK: - Batch Operations Tests

    func testBatchWrite() async throws {
        // Given
        let batch = testFirestore.batch()

        let hero1Ref = testFirestore.collection("heroes").document("batch-hero-1")
        let hero2Ref = testFirestore.collection("heroes").document("batch-hero-2")
        let storyRef = testFirestore.collection("stories").document("batch-story-1")

        batch.setData(createTestHeroData(name: "Batch Hero 1"), forDocument: hero1Ref)
        batch.setData(createTestHeroData(name: "Batch Hero 2"), forDocument: hero2Ref)
        batch.setData(createTestStoryData(title: "Batch Story"), forDocument: storyRef)

        // When
        try await batch.commit()

        // Then
        let hero1 = try await hero1Ref.getDocument()
        let hero2 = try await hero2Ref.getDocument()
        let story = try await storyRef.getDocument()

        XCTAssertTrue(hero1.exists)
        XCTAssertTrue(hero2.exists)
        XCTAssertTrue(story.exists)
    }

    // MARK: - Query Tests

    func testQueryWithFilter() async throws {
        // Given - Create heroes with different ages
        var youngHero = createTestHeroData(name: "Young Hero")
        youngHero["age"] = 5

        var teenHero = createTestHeroData(name: "Teen Hero")
        teenHero["age"] = 13

        var adultHero = createTestHeroData(name: "Adult Hero")
        adultHero["age"] = 25

        _ = try await createTestDocument(collection: "heroes", data: youngHero)
        _ = try await createTestDocument(collection: "heroes", data: teenHero)
        _ = try await createTestDocument(collection: "heroes", data: adultHero)

        // When - Query for heroes age 10 or younger
        let query = testFirestore.collection("heroes").whereField("age", isLessThanOrEqualTo: 10)
        let snapshot = try await query.getDocuments()

        // Then
        XCTAssertEqual(snapshot.documents.count, 1)
        XCTAssertEqual(snapshot.documents.first?.data()["name"] as? String, "Young Hero")
    }

    func testQueryWithOrdering() async throws {
        // Given - Create stories with different dates
        let cal = Calendar.current
        let now = Date()

        var story1 = createTestStoryData(title: "Oldest Story")
        story1["createdAt"] = Timestamp(date: cal.date(byAdding: .day, value: -3, to: now)!)

        var story2 = createTestStoryData(title: "Middle Story")
        story2["createdAt"] = Timestamp(date: cal.date(byAdding: .day, value: -1, to: now)!)

        var story3 = createTestStoryData(title: "Newest Story")
        story3["createdAt"] = Timestamp(date: now)

        _ = try await createTestDocument(collection: "stories", data: story1)
        _ = try await createTestDocument(collection: "stories", data: story2)
        _ = try await createTestDocument(collection: "stories", data: story3)

        // When - Query ordered by creation date descending
        let query = testFirestore.collection("stories")
            .order(by: "createdAt", descending: true)
            .limit(to: 2)
        let snapshot = try await query.getDocuments()

        // Then
        XCTAssertEqual(snapshot.documents.count, 2)
        XCTAssertEqual(snapshot.documents.first?.data()["title"] as? String, "Newest Story")
        XCTAssertEqual(snapshot.documents.last?.data()["title"] as? String, "Middle Story")
    }

    // MARK: - Transaction Tests

    func testTransaction() async throws {
        // Given - Create initial hero
        let heroRef = testFirestore.collection("heroes").document("trans-hero")
        let initialData = createTestHeroData(name: "Transaction Hero")
        try await heroRef.setData(initialData)

        // When - Run transaction to increment a counter
        try await testFirestore.runTransaction { transaction, errorPointer in
            let heroDoc: DocumentSnapshot
            do {
                heroDoc = try transaction.getDocument(heroRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard heroDoc.exists else {
                errorPointer?.pointee = NSError(
                    domain: "FirebaseDataServiceTests",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Hero doesn't exist"]
                )
                return nil
            }

            let currentCount = heroDoc.data()?["storyCount"] as? Int ?? 0
            transaction.updateData(["storyCount": currentCount + 1], forDocument: heroRef)
            return nil
        }

        // Then
        let updatedDoc = try await heroRef.getDocument()
        XCTAssertEqual(updatedDoc.data()?["storyCount"] as? Int, 1)
    }
}

// MARK: - FirebaseDataServiceMock Implementation

/// Mock/Test implementation of Firebase Data Service
class FirebaseDataServiceMock {
    private let firestore: Firestore

    init(firestore: Firestore) {
        self.firestore = firestore
    }

    // MARK: - Hero Methods

    func createHero(data: [String: Any]) async throws -> DocumentReference {
        let docRef = firestore.collection("heroes").document()
        try await docRef.setData(data)
        return docRef
    }

    func getHero(id: String) async throws -> [String: Any]? {
        let snapshot = try await firestore.collection("heroes").document(id).getDocument()
        return snapshot.exists ? snapshot.data() : nil
    }

    func updateHero(id: String, data: [String: Any]) async throws {
        try await firestore.collection("heroes").document(id).updateData(data)
    }

    func deleteHero(id: String) async throws {
        try await firestore.collection("heroes").document(id).delete()
    }

    func getAllHeroes() async throws -> [[String: Any]] {
        let snapshot = try await firestore.collection("heroes").getDocuments()
        return snapshot.documents.map { $0.data() }
    }

    // MARK: - Story Methods

    func createStory(data: [String: Any]) async throws -> DocumentReference {
        let docRef = firestore.collection("stories").document()
        try await docRef.setData(data)
        return docRef
    }

    func getStory(id: String) async throws -> [String: Any]? {
        let snapshot = try await firestore.collection("stories").document(id).getDocument()
        return snapshot.exists ? snapshot.data() : nil
    }

    func updateStory(id: String, data: [String: Any]) async throws {
        try await firestore.collection("stories").document(id).updateData(data)
    }

    func deleteStory(id: String) async throws {
        try await firestore.collection("stories").document(id).delete()
    }

    func getStoriesForHero(heroId: String) async throws -> [[String: Any]] {
        let snapshot = try await firestore.collection("stories")
            .whereField("heroId", isEqualTo: heroId)
            .getDocuments()
        return snapshot.documents.map { $0.data() }
    }

    // MARK: - Custom Event Methods

    func createCustomEvent(userId: String, data: [String: Any]) async throws -> DocumentReference {
        let docRef = firestore.collection("users").document(userId)
            .collection("customEvents").document()
        try await docRef.setData(data)
        return docRef
    }

    func getCustomEvent(userId: String, eventId: String) async throws -> [String: Any]? {
        let snapshot = try await firestore.collection("users").document(userId)
            .collection("customEvents").document(eventId).getDocument()
        return snapshot.exists ? snapshot.data() : nil
    }

    func getCustomEvents(userId: String) async throws -> [[String: Any]] {
        let snapshot = try await firestore.collection("users").document(userId)
            .collection("customEvents").getDocuments()
        return snapshot.documents.map { $0.data() }
    }
}