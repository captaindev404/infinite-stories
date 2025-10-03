//
//  FirebaseConfig.swift
//  InfiniteStories
//
//  Created by Migration Agent on 02/10/2025.
//

import Foundation
import FirebaseCore
// Additional Firebase modules will be imported as they are added to the project
// import FirebaseAuth
// import FirebaseFirestore
// import FirebaseStorage
// import FirebaseFunctions

/// FirebaseConfig manages Firebase services initialization and configuration
class FirebaseConfig {
    static let shared = FirebaseConfig()

    // MARK: - Properties

    /// Check if Firebase is configured
    var isConfigured: Bool {
        return FirebaseApp.app() != nil
    }

    /// Current Firebase project ID
    var projectID: String? {
        return FirebaseApp.app()?.options.projectID
    }

    /// Current Firebase app name
    var appName: String? {
        return FirebaseApp.app()?.name
    }

    /// Current Firebase options
    var options: FirebaseOptions? {
        return FirebaseApp.app()?.options
    }

    // MARK: - Initialization

    private init() {
        // Private init to enforce singleton
    }

    // MARK: - Configuration Methods

    /// Configure Firebase services for the app
    /// This is called automatically in InfiniteStoriesApp.init()
    static func configure() {
        guard FirebaseApp.app() == nil else {
            print("⚠️ Firebase already configured")
            return
        }

        FirebaseApp.configure()

        print("✅ Firebase configured successfully")
        print("📱 Project ID: \(shared.projectID ?? "Unknown")")
        print("📱 App Name: \(shared.appName ?? "Unknown")")

        // Log additional configuration details
        if let options = shared.options {
            print("📱 Bundle ID: \(options.bundleID ?? "Unknown")")
            print("📱 API Key: \(String(options.apiKey?.prefix(10) ?? "").appending("..."))")
            print("📱 Storage Bucket: \(options.storageBucket ?? "Unknown")")
        }
    }

    // MARK: - Future Integration Points

    /*
     The following methods will be implemented as Firebase modules are added to the project:

     1. Authentication (FirebaseAuth):
        - Sign in/out methods
        - User management
        - Auth state listeners

     2. Database (FirebaseFirestore):
        - Document CRUD operations
        - Collection queries
        - Real-time listeners

     3. Storage (FirebaseStorage):
        - File uploads/downloads
        - Storage references
        - Metadata management

     4. Cloud Functions (FirebaseFunctions):
        - Function invocation
        - Response handling
        - Error management

     5. Analytics (FirebaseAnalytics):
        - Event logging
        - User properties
        - Screen tracking

     These will be progressively enabled as the migration from Supabase proceeds.
     */

    // MARK: - Error Types

    enum FirebaseConfigError: Error, LocalizedError {
        case notConfigured
        case moduleNotAvailable
        case unknownError(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Firebase is not configured. Call FirebaseConfig.configure() first."
            case .moduleNotAvailable:
                return "The requested Firebase module is not available in the project."
            case .unknownError(let message):
                return "Firebase error: \(message)"
            }
        }
    }
}

// MARK: - Convenience Extensions

extension FirebaseConfig {
    /// Check if Firebase has been properly initialized
    func verifyConfiguration() -> Bool {
        guard isConfigured else {
            print("❌ Firebase is not configured")
            return false
        }

        guard let projectID = projectID, !projectID.isEmpty else {
            print("❌ Firebase project ID is missing")
            return false
        }

        print("✅ Firebase configuration verified")
        print("📱 Project: \(projectID)")
        return true
    }

    /// Get Firebase configuration summary
    func getConfigurationSummary() -> String {
        guard isConfigured else {
            return "Firebase not configured"
        }

        var summary = "Firebase Configuration:\n"
        summary += "- Project ID: \(projectID ?? "Unknown")\n"
        summary += "- App Name: \(appName ?? "Unknown")\n"

        if let options = options {
            summary += "- Bundle ID: \(options.bundleID ?? "Unknown")\n"
            summary += "- Storage Bucket: \(options.storageBucket ?? "Unknown")\n"
        }

        return summary
    }
}