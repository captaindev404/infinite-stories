//
//  FirebaseTestConfiguration.swift
//  InfiniteStoriesTests
//
//  Firebase test configuration and base setup for all Firebase tests
//

import XCTest
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// Base configuration for Firebase testing with emulator support
class FirebaseTestConfiguration {

    static let shared = FirebaseTestConfiguration()

    // MARK: - Emulator Configuration

    struct EmulatorConfig {
        static let authHost = "127.0.0.1"
        static let authPort = 9099
        static let firestoreHost = "127.0.0.1"
        static let firestorePort = 8080
        static let storageHost = "127.0.0.1"
        static let storagePort = 9199
    }

    // MARK: - Properties

    private(set) var isConfigured = false
    private var testApp: FirebaseApp?

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration Methods

    /// Configure Firebase for testing with emulators
    func configureForTesting() throws {
        guard !isConfigured else { return }

        // Configure Firebase app for testing
        let options = FirebaseOptions()
        options.projectID = "infinite-stories-test"
        options.apiKey = "test-api-key"
        options.appID = "1:test:ios:test"
        options.storageBucket = "infinite-stories-test.appspot.com"

        // Create test app instance
        FirebaseApp.configure(name: "testApp", options: options)
        testApp = FirebaseApp.app(name: "testApp")

        guard let app = testApp else {
            throw FirebaseTestError.configurationFailed("Failed to create test Firebase app")
        }

        // Configure Auth emulator
        let auth = Auth.auth(app: app)
        auth.useEmulator(withHost: EmulatorConfig.authHost, port: EmulatorConfig.authPort)

        // Configure Firestore emulator
        let firestore = Firestore.firestore(app: app)
        let settings = firestore.settings
        settings.host = "\(EmulatorConfig.firestoreHost):\(EmulatorConfig.firestorePort)"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        firestore.settings = settings

        // Configure Storage emulator
        let storage = Storage.storage(app: app)
        storage.useEmulator(withHost: EmulatorConfig.storageHost, port: EmulatorConfig.storagePort)

        isConfigured = true
        print("✅ Firebase Test Environment configured with emulators")
    }

    /// Reset Firebase test environment
    func reset() async throws {
        guard let app = testApp else { return }

        // Clear Auth
        let auth = Auth.auth(app: app)
        if auth.currentUser != nil {
            try? auth.signOut()
        }

        // Clear Firestore (if needed)
        let firestore = Firestore.firestore(app: app)
        try await clearFirestore(firestore)

        // Note: Storage clearing would be done via emulator REST API if needed
    }

    /// Get test app instance
    func getTestApp() throws -> FirebaseApp {
        guard let app = testApp else {
            throw FirebaseTestError.notConfigured
        }
        return app
    }

    // MARK: - Helper Methods

    private func clearFirestore(_ firestore: Firestore) async throws {
        // This would typically be done via emulator REST API
        // For now, we'll clear known collections
        let collections = ["heroes", "stories", "users", "events"]

        for collectionName in collections {
            let collection = firestore.collection(collectionName)
            let snapshot = try await collection.getDocuments()

            let batch = firestore.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }

            if !snapshot.documents.isEmpty {
                try await batch.commit()
            }
        }
    }

    /// Teardown test configuration
    func teardown() async {
        if let app = testApp {
            await app.delete()
            testApp = nil
        }
        isConfigured = false
    }
}

// MARK: - Test Errors

enum FirebaseTestError: LocalizedError {
    case notConfigured
    case configurationFailed(String)
    case emulatorNotRunning

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase test environment not configured"
        case .configurationFailed(let message):
            return "Firebase test configuration failed: \(message)"
        case .emulatorNotRunning:
            return "Firebase emulators are not running. Run 'firebase emulators:start' first."
        }
    }
}