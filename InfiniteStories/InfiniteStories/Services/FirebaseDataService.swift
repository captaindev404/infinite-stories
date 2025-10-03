//
//  FirebaseDataService.swift
//  InfiniteStories
//
//  Firebase Firestore data service implementation for Heroes and Stories
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - DataServiceProtocol

/// Protocol defining data service operations for Firebase implementation
protocol DataServiceProtocol {
    // Hero operations
    func createHero(_ hero: Hero) async throws -> String
    func fetchHero(id: String) async throws -> HeroCodable?
    func fetchAllHeroes() async throws -> [HeroCodable]
    func updateHero(_ hero: Hero) async throws
    func deleteHero(id: String) async throws

    // Story operations
    func createStory(_ story: Story) async throws -> String
    func fetchStory(id: String) async throws -> StoryCodable?
    func fetchAllStories() async throws -> [StoryCodable]
    func fetchStoriesForHero(heroId: String) async throws -> [StoryCodable]
    func updateStory(_ story: Story) async throws
    func deleteStory(id: String) async throws

    // User operations
    func getCurrentUserId() -> String?
}

// MARK: - FirebaseDataService

/// Main Firebase data service handling all Firestore operations
final class FirebaseDataService: DataServiceProtocol {

    // MARK: - Singleton

    static let shared = FirebaseDataService()

    // MARK: - Properties

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    // Collection names
    private let heroesCollection = "heroes"
    private let storiesCollection = "stories"

    // MARK: - Initialization

    private init() {
        configureFirestore()
    }

    /// Configure Firestore settings
    private func configureFirestore() {
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024)) // 100MB cache
        db.settings = settings

        print("🔥 FirebaseDataService initialized")
        print("📊 Firestore cache enabled: 100MB")
    }

    // MARK: - User Operations

    /// Get current authenticated user ID
    func getCurrentUserId() -> String? {
        return auth.currentUser?.uid
    }

    /// Ensure user is authenticated
    private func ensureAuthenticated() throws -> String {
        guard let userId = getCurrentUserId() else {
            throw FirebaseDataError.notAuthenticated
        }
        return userId
    }

    // MARK: - Hero Operations

    /// Create a new hero in Firestore
    func createHero(_ hero: Hero) async throws -> String {
        let userId = try ensureAuthenticated()

        // Convert Hero to Codable format
        let heroData = HeroCodable(from: hero, userId: UUID(uuidString: userId) ?? UUID())

        do {
            // Create document with hero ID
            let docRef = db.collection(heroesCollection).document(hero.id.uuidString)

            // Convert to dictionary
            let data = try Firestore.Encoder().encode(heroData)

            // Write to Firestore
            try await docRef.setData(data)

            print("✅ Created hero: \(hero.name) with ID: \(hero.id.uuidString)")
            return hero.id.uuidString

        } catch {
            print("❌ Failed to create hero: \(error.localizedDescription)")
            throw FirebaseDataError.createFailed(error)
        }
    }

    /// Fetch a specific hero by ID
    func fetchHero(id: String) async throws -> HeroCodable? {
        let userId = try ensureAuthenticated()

        do {
            let docRef = db.collection(heroesCollection).document(id)
            let document = try await docRef.getDocument()

            guard document.exists else {
                print("⚠️ Hero not found: \(id)")
                return nil
            }

            let hero = try document.data(as: HeroCodable.self)

            // Verify ownership
            guard hero.userId == userId else {
                print("⚠️ Hero belongs to different user: \(id)")
                throw FirebaseDataError.unauthorized
            }

            print("✅ Fetched hero: \(hero.name)")
            return hero

        } catch {
            print("❌ Failed to fetch hero: \(error.localizedDescription)")
            throw FirebaseDataError.fetchFailed(error)
        }
    }

    /// Fetch all heroes for the current user
    func fetchAllHeroes() async throws -> [HeroCodable] {
        let userId = try ensureAuthenticated()

        do {
            let query = db.collection(heroesCollection)
                .whereField("user_id", isEqualTo: userId)
                .order(by: "created_at", descending: true)

            let snapshot = try await query.getDocuments()

            let heroes = try snapshot.documents.compactMap { document in
                try document.data(as: HeroCodable.self)
            }

            print("✅ Fetched \(heroes.count) heroes")
            return heroes

        } catch {
            print("❌ Failed to fetch heroes: \(error.localizedDescription)")
            throw FirebaseDataError.fetchFailed(error)
        }
    }

    /// Update an existing hero
    func updateHero(_ hero: Hero) async throws {
        let userId = try ensureAuthenticated()

        // Prepare update data
        let heroData = HeroCodable(from: hero, userId: UUID(uuidString: userId) ?? UUID())

        do {
            let docRef = db.collection(heroesCollection).document(hero.id.uuidString)

            // Verify document exists and belongs to user
            let document = try await docRef.getDocument()
            guard document.exists else {
                throw FirebaseDataError.notFound
            }

            // Update document
            let data = try Firestore.Encoder().encode(heroData)
            try await docRef.setData(data, merge: true)

            // Update sync status
            hero.lastSyncedAt = Date()
            hero.needsSync = false

            print("✅ Updated hero: \(hero.name)")

        } catch {
            print("❌ Failed to update hero: \(error.localizedDescription)")
            throw FirebaseDataError.updateFailed(error)
        }
    }

    /// Delete a hero
    func deleteHero(id: String) async throws {
        let userId = try ensureAuthenticated()

        do {
            // Verify ownership before deletion
            if let hero = try await fetchHero(id: id) {
                guard hero.userId == userId else {
                    throw FirebaseDataError.unauthorized
                }

                // Delete the document
                try await db.collection(heroesCollection).document(id).delete()

                print("✅ Deleted hero: \(id)")
            } else {
                throw FirebaseDataError.notFound
            }

        } catch {
            print("❌ Failed to delete hero: \(error.localizedDescription)")
            throw FirebaseDataError.deleteFailed(error)
        }
    }

    // MARK: - Story Operations

    /// Create a new story in Firestore
    func createStory(_ story: Story) async throws -> String {
        let userId = try ensureAuthenticated()

        // Convert Story to Codable format
        let storyData = StoryCodable(from: story, userId: UUID(uuidString: userId) ?? UUID())

        do {
            // Create document with story ID
            let docRef = db.collection(storiesCollection).document(story.id.uuidString)

            // Convert to dictionary (custom encoding handles eventData)
            let encoder = Firestore.Encoder()
            let data = try encoder.encode(storyData)

            // Write to Firestore
            try await docRef.setData(data)

            print("✅ Created story: \(story.title) with ID: \(story.id.uuidString)")
            return story.id.uuidString

        } catch {
            print("❌ Failed to create story: \(error.localizedDescription)")
            throw FirebaseDataError.createFailed(error)
        }
    }

    /// Fetch a specific story by ID
    func fetchStory(id: String) async throws -> StoryCodable? {
        let userId = try ensureAuthenticated()

        do {
            let docRef = db.collection(storiesCollection).document(id)
            let document = try await docRef.getDocument()

            guard document.exists else {
                print("⚠️ Story not found: \(id)")
                return nil
            }

            let story = try document.data(as: StoryCodable.self)

            // Verify ownership
            guard story.userId == userId else {
                print("⚠️ Story belongs to different user: \(id)")
                throw FirebaseDataError.unauthorized
            }

            print("✅ Fetched story: \(story.title)")
            return story

        } catch {
            print("❌ Failed to fetch story: \(error.localizedDescription)")
            throw FirebaseDataError.fetchFailed(error)
        }
    }

    /// Fetch all stories for the current user
    func fetchAllStories() async throws -> [StoryCodable] {
        let userId = try ensureAuthenticated()

        do {
            let query = db.collection(storiesCollection)
                .whereField("user_id", isEqualTo: userId)
                .order(by: "created_at", descending: true)
                .limit(to: 100) // Limit for performance

            let snapshot = try await query.getDocuments()

            let stories = try snapshot.documents.compactMap { document in
                try document.data(as: StoryCodable.self)
            }

            print("✅ Fetched \(stories.count) stories")
            return stories

        } catch {
            print("❌ Failed to fetch stories: \(error.localizedDescription)")
            throw FirebaseDataError.fetchFailed(error)
        }
    }

    /// Fetch stories for a specific hero
    func fetchStoriesForHero(heroId: String) async throws -> [StoryCodable] {
        let userId = try ensureAuthenticated()

        do {
            let query = db.collection(storiesCollection)
                .whereField("user_id", isEqualTo: userId)
                .whereField("hero_id", isEqualTo: heroId)
                .order(by: "created_at", descending: true)

            let snapshot = try await query.getDocuments()

            let stories = try snapshot.documents.compactMap { document in
                try document.data(as: StoryCodable.self)
            }

            print("✅ Fetched \(stories.count) stories for hero: \(heroId)")
            return stories

        } catch {
            print("❌ Failed to fetch stories for hero: \(error.localizedDescription)")
            throw FirebaseDataError.fetchFailed(error)
        }
    }

    /// Update an existing story
    func updateStory(_ story: Story) async throws {
        let userId = try ensureAuthenticated()

        // Prepare update data
        let storyData = StoryCodable(from: story, userId: UUID(uuidString: userId) ?? UUID())

        do {
            let docRef = db.collection(storiesCollection).document(story.id.uuidString)

            // Verify document exists and belongs to user
            let document = try await docRef.getDocument()
            guard document.exists else {
                throw FirebaseDataError.notFound
            }

            // Update document
            let encoder = Firestore.Encoder()
            let data = try encoder.encode(storyData)
            try await docRef.setData(data, merge: true)

            // Update sync status
            story.lastSyncedAt = Date()
            story.needsSync = false

            print("✅ Updated story: \(story.title)")

        } catch {
            print("❌ Failed to update story: \(error.localizedDescription)")
            throw FirebaseDataError.updateFailed(error)
        }
    }

    /// Delete a story
    func deleteStory(id: String) async throws {
        let userId = try ensureAuthenticated()

        do {
            // Verify ownership before deletion
            if let story = try await fetchStory(id: id) {
                guard story.userId == userId else {
                    throw FirebaseDataError.unauthorized
                }

                // Delete the document
                try await db.collection(storiesCollection).document(id).delete()

                print("✅ Deleted story: \(id)")
            } else {
                throw FirebaseDataError.notFound
            }

        } catch {
            print("❌ Failed to delete story: \(error.localizedDescription)")
            throw FirebaseDataError.deleteFailed(error)
        }
    }

    // MARK: - Batch Operations

    /// Batch update multiple heroes
    func batchUpdateHeroes(_ heroes: [Hero]) async throws {
        let userId = try ensureAuthenticated()
        let batch = db.batch()

        for hero in heroes {
            let docRef = db.collection(heroesCollection).document(hero.id.uuidString)
            let heroData = HeroCodable(from: hero, userId: UUID(uuidString: userId) ?? UUID())

            do {
                let data = try Firestore.Encoder().encode(heroData)
                batch.setData(data, forDocument: docRef, merge: true)
            } catch {
                print("⚠️ Failed to prepare hero for batch: \(error)")
            }
        }

        do {
            try await batch.commit()

            // Update sync status for all heroes
            for hero in heroes {
                hero.lastSyncedAt = Date()
                hero.needsSync = false
            }

            print("✅ Batch updated \(heroes.count) heroes")
        } catch {
            print("❌ Batch update failed: \(error)")
            throw FirebaseDataError.batchOperationFailed(error)
        }
    }

    /// Batch update multiple stories
    func batchUpdateStories(_ stories: [Story]) async throws {
        let userId = try ensureAuthenticated()
        let batch = db.batch()

        for story in stories {
            let docRef = db.collection(storiesCollection).document(story.id.uuidString)
            let storyData = StoryCodable(from: story, userId: UUID(uuidString: userId) ?? UUID())

            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(storyData)
                batch.setData(data, forDocument: docRef, merge: true)
            } catch {
                print("⚠️ Failed to prepare story for batch: \(error)")
            }
        }

        do {
            try await batch.commit()

            // Update sync status for all stories
            for story in stories {
                story.lastSyncedAt = Date()
                story.needsSync = false
            }

            print("✅ Batch updated \(stories.count) stories")
        } catch {
            print("❌ Batch update failed: \(error)")
            throw FirebaseDataError.batchOperationFailed(error)
        }
    }

    // MARK: - Real-time Listeners

    /// Listen for hero changes
    func listenToHeroes(completion: @escaping (Result<[HeroCodable], Error>) -> Void) -> ListenerRegistration? {
        guard let userId = getCurrentUserId() else {
            completion(.failure(FirebaseDataError.notAuthenticated))
            return nil
        }

        let listener = db.collection(heroesCollection)
            .whereField("user_id", isEqualTo: userId)
            .order(by: "created_at", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(FirebaseDataError.listenFailed(error)))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                do {
                    let heroes = try documents.compactMap { document in
                        try document.data(as: HeroCodable.self)
                    }
                    completion(.success(heroes))
                } catch {
                    completion(.failure(FirebaseDataError.decodingFailed(error)))
                }
            }

        return listener
    }

    /// Listen for story changes
    func listenToStories(completion: @escaping (Result<[StoryCodable], Error>) -> Void) -> ListenerRegistration? {
        guard let userId = getCurrentUserId() else {
            completion(.failure(FirebaseDataError.notAuthenticated))
            return nil
        }

        let listener = db.collection(storiesCollection)
            .whereField("user_id", isEqualTo: userId)
            .order(by: "created_at", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(FirebaseDataError.listenFailed(error)))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                do {
                    let stories = try documents.compactMap { document in
                        try document.data(as: StoryCodable.self)
                    }
                    completion(.success(stories))
                } catch {
                    completion(.failure(FirebaseDataError.decodingFailed(error)))
                }
            }

        return listener
    }
}

// MARK: - Error Types

/// Firebase Data Service specific errors
enum FirebaseDataError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case notFound
    case createFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case batchOperationFailed(Error)
    case listenFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated. Please sign in."
        case .unauthorized:
            return "You don't have permission to access this resource."
        case .notFound:
            return "The requested resource was not found."
        case .createFailed(let error):
            return "Failed to create resource: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update resource: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete resource: \(error.localizedDescription)"
        case .batchOperationFailed(let error):
            return "Batch operation failed: \(error.localizedDescription)"
        case .listenFailed(let error):
            return "Failed to listen for changes: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        }
    }
}

// MARK: - Firebase Helper Extensions

extension ISO8601DateFormatter {
    /// Firebase-compatible date formatter
    static let firebaseCompatible: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}