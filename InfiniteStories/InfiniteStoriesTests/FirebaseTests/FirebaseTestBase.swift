//
//  FirebaseTestBase.swift
//  InfiniteStoriesTests
//
//  Base test class providing common Firebase testing functionality
//

import XCTest
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
@testable import InfiniteStories

/// Base class for all Firebase service tests
class FirebaseTestBase: XCTestCase {

    // MARK: - Properties

    var testApp: FirebaseApp!
    var testAuth: Auth!
    var testFirestore: Firestore!
    var testStorage: Storage!

    /// Test user credentials
    struct TestUser {
        static let email = "test@infinite-stories.com"
        static let password = "TestPassword123!"
        static let displayName = "Test User"
        static let uid = "test-user-123"
    }

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Configure Firebase test environment
        try FirebaseTestConfiguration.shared.configureForTesting()
        testApp = try FirebaseTestConfiguration.shared.getTestApp()

        // Get service instances
        testAuth = Auth.auth(app: testApp)
        testFirestore = Firestore.firestore(app: testApp)
        testStorage = Storage.storage(app: testApp)

        // Ensure clean state
        Task {
            try await FirebaseTestConfiguration.shared.reset()
        }
    }

    override func tearDownWithError() throws {
        // Clean up test data
        Task {
            try await FirebaseTestConfiguration.shared.reset()
        }

        // Reset properties
        testApp = nil
        testAuth = nil
        testFirestore = nil
        testStorage = nil

        try super.tearDownWithError()
    }

    // MARK: - Helper Methods

    /// Create a test user in Firebase Auth
    @discardableResult
    func createTestUser(
        email: String = TestUser.email,
        password: String = TestUser.password,
        displayName: String? = TestUser.displayName
    ) async throws -> User {
        let result = try await testAuth.createUser(withEmail: email, password: password)

        if let displayName = displayName {
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        }

        return result.user
    }

    /// Sign in test user
    @discardableResult
    func signInTestUser(
        email: String = TestUser.email,
        password: String = TestUser.password
    ) async throws -> User {
        let result = try await testAuth.signIn(withEmail: email, password: password)
        return result.user
    }

    /// Sign out current user
    func signOutTestUser() throws {
        try testAuth.signOut()
    }

    /// Create test document in Firestore
    @discardableResult
    func createTestDocument(
        collection: String,
        documentId: String? = nil,
        data: [String: Any]
    ) async throws -> DocumentReference {
        let collectionRef = testFirestore.collection(collection)

        let docRef: DocumentReference
        if let documentId = documentId {
            docRef = collectionRef.document(documentId)
        } else {
            docRef = collectionRef.document()
        }

        try await docRef.setData(data)
        return docRef
    }

    /// Upload test data to Storage
    @discardableResult
    func uploadTestData(
        path: String,
        data: Data,
        metadata: StorageMetadata? = nil
    ) async throws -> StorageReference {
        let storageRef = testStorage.reference().child(path)
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        return storageRef
    }

    /// Wait for async operation with timeout
    func waitForAsync(
        timeout: TimeInterval = 10,
        operation: @escaping () async throws -> Void
    ) {
        let expectation = self.expectation(description: "Async operation")

        Task {
            do {
                try await operation()
                expectation.fulfill()
            } catch {
                XCTFail("Async operation failed: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout)
    }

    /// Assert Firebase error code
    func assertFirebaseError(
        _ error: Error?,
        hasCode expectedCode: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let nsError = error as NSError? else {
            XCTFail("Expected Firebase error with code \(expectedCode), got nil", file: file, line: line)
            return
        }

        XCTAssertEqual(
            nsError.code,
            expectedCode,
            "Expected error code \(expectedCode), got \(nsError.code)",
            file: file,
            line: line
        )
    }

    /// Create test Hero data
    func createTestHeroData(name: String = "Test Hero") -> [String: Any] {
        return [
            "id": UUID().uuidString,
            "name": name,
            "createdAt": Timestamp(date: Date()),
            "modifiedAt": Timestamp(date: Date()),
            "personalityTraits": ["brave", "kind"],
            "physicalDescription": "A brave young hero",
            "specialAbilities": "Super strength",
            "backstory": "Born in a magical land",
            "favoriteThings": "Adventure and helping others",
            "age": 8,
            "voiceType": "energetic",
            "avatarPrompt": "A young brave hero",
            "avatarURL": "test-avatar.jpg",
            "hasAvatar": true
        ]
    }

    /// Create test Story data
    func createTestStoryData(
        title: String = "Test Story",
        heroId: String? = nil
    ) -> [String: Any] {
        return [
            "id": UUID().uuidString,
            "title": title,
            "content": "Once upon a time...",
            "createdAt": Timestamp(date: Date()),
            "heroId": heroId ?? UUID().uuidString,
            "eventType": "bedtime",
            "duration": 300,
            "language": "en",
            "audioURL": "test-audio.mp3",
            "hasAudio": true,
            "isFavorite": false,
            "illustrationCount": 3,
            "hasIllustrations": true
        ]
    }

    /// Create test Custom Event data
    func createTestCustomEventData(
        title: String = "Test Event",
        userId: String? = nil
    ) -> [String: Any] {
        return [
            "id": UUID().uuidString,
            "userId": userId ?? TestUser.uid,
            "title": title,
            "description": "A test custom event",
            "promptSeed": "Test prompt seed",
            "category": "adventure",
            "tone": "exciting",
            "ageRange": "5-7",
            "keywords": ["test", "event"],
            "createdAt": Timestamp(date: Date()),
            "lastUsed": Timestamp(date: Date()),
            "usageCount": 1,
            "isFavorite": false,
            "pictogram": "🎯"
        ]
    }
}

// MARK: - Test Protocols

/// Protocol for testable Firebase services
protocol FirebaseTestable {
    /// Reset service to clean state for testing
    func resetForTesting() async throws

    /// Inject test dependencies
    func injectTestDependencies(app: FirebaseApp) throws
}

/// Protocol for services that can be mocked
protocol MockableFirebaseService {
    associatedtype MockType

    /// Create mock instance for testing
    static func createMock() -> MockType
}

// MARK: - XCTest Extensions

extension XCTestCase {
    /// Assert async operation succeeds
    func assertAsyncNoThrow<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail("\(message()): \(error)", file: file, line: line)
        }
    }

    /// Assert async operation throws specific error
    func assertAsyncThrows<T, E: Error & Equatable>(
        _ expression: @autoclosure () async throws -> T,
        expectedError: E,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error \(expectedError) but no error was thrown", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expectedError, message(), file: file, line: line)
        } catch {
            XCTFail("Expected error \(expectedError) but got \(error)", file: file, line: line)
        }
    }
}