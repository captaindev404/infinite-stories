//
//  AuthMigrationHelper.swift
//  InfiniteStories
//
//  Helper to facilitate migration from Supabase Auth to Firebase Auth
//  Provides compatibility layer during transition period
//

import Foundation
import FirebaseAuth
import Combine

// MARK: - Auth Migration Helper

@MainActor
final class AuthMigrationHelper: ObservableObject {
    static let shared = AuthMigrationHelper()

    private lazy var firebaseAuth = FirebaseAuthService.shared
    private let supabaseService = SupabaseService.shared

    // Migration settings stored in UserDefaults
    private let migrationKey = "auth_migration_status"
    private let migrationDateKey = "auth_migration_date"
    private let useFirebaseKey = "use_firebase_auth"

    private init() {}

    // MARK: - Migration Status

    enum MigrationStatus: String {
        case notStarted = "not_started"
        case inProgress = "in_progress"
        case completed = "completed"
        case rolledBack = "rolled_back"
    }

    var currentStatus: MigrationStatus {
        get {
            guard let statusString = UserDefaults.standard.string(forKey: migrationKey) else {
                return .notStarted
            }
            return MigrationStatus(rawValue: statusString) ?? .notStarted
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: migrationKey)
            UserDefaults.standard.set(Date(), forKey: migrationDateKey)
        }
    }

    var useFirebaseAuth: Bool {
        get {
            // Default to true for new installations
            return UserDefaults.standard.object(forKey: useFirebaseKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useFirebaseKey)
        }
    }

    // MARK: - Migration Methods

    /// Start the migration process
    func startMigration() {
        currentStatus = .inProgress
        useFirebaseAuth = true

        print("🔄 Auth Migration: Started migration from Supabase to Firebase")
        print("📊 Status: \(currentStatus.rawValue)")
        print("🔥 Using Firebase Auth: \(useFirebaseAuth)")
    }

    /// Complete the migration
    func completeMigration() {
        currentStatus = .completed
        useFirebaseAuth = true

        print("✅ Auth Migration: Completed successfully")
        print("🔥 Firebase Auth is now the primary authentication service")
    }

    /// Rollback to Supabase if needed
    func rollbackMigration() {
        currentStatus = .rolledBack
        useFirebaseAuth = false

        print("⏪ Auth Migration: Rolled back to Supabase Auth")
    }

    // MARK: - Compatibility Layer

    /// Get current user ID from active auth service
    @MainActor
    func getCurrentUserId() -> String? {
        if useFirebaseAuth {
            return firebaseAuth.currentUserId
        } else {
            // For Supabase, we use the hardcoded dev user ID for now
            return "00000000-0000-0000-0000-000000000001"
        }
    }

    /// Check if user is authenticated
    @MainActor
    func isAuthenticated() -> Bool {
        if useFirebaseAuth {
            return firebaseAuth.isAuthenticated
        } else {
            // For local Supabase development, always return true
            return true
        }
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        if useFirebaseAuth {
            _ = try await firebaseAuth.signIn(email: email, password: password)
        } else {
            // Supabase sign in would go here
            // For now, we're using hardcoded dev user
            print("⚠️ Using Supabase dev mode - no actual authentication")
        }
    }

    /// Sign up with email and password
    func signUp(email: String, password: String, displayName: String? = nil) async throws {
        if useFirebaseAuth {
            _ = try await firebaseAuth.signUp(email: email, password: password, displayName: displayName)
        } else {
            // Supabase sign up would go here
            print("⚠️ Using Supabase dev mode - no actual sign up")
        }
    }

    /// Sign out
    @MainActor
    func signOut() throws {
        if useFirebaseAuth {
            try firebaseAuth.signOut()
        } else {
            // Supabase sign out would go here
            print("⚠️ Using Supabase dev mode - no actual sign out")
        }
    }

    /// Sign in anonymously for development/testing
    func signInAnonymously() async throws {
        if useFirebaseAuth {
            _ = try await firebaseAuth.signInAnonymously()
            print("✅ Signed in anonymously with Firebase")
        } else {
            print("⚠️ Anonymous sign in not available in Supabase mode")
        }
    }

    // MARK: - User Migration

    /// Migrate existing user session from Supabase to Firebase
    /// This would be called when a user signs in during the migration period
    func migrateUserSession(email: String, password: String) async throws {
        print("🔄 Attempting to migrate user session for: \(email)")

        // Step 1: Try to sign in with Firebase
        do {
            _ = try await firebaseAuth.signIn(email: email, password: password)
            print("✅ User already exists in Firebase")
        } catch {
            // Step 2: If user doesn't exist, create them in Firebase
            print("📝 Creating new Firebase account for existing user")
            _ = try await firebaseAuth.signUp(email: email, password: password)
            print("✅ User migrated to Firebase successfully")
        }

        // Step 3: Mark migration as in progress or complete
        if currentStatus == .notStarted {
            startMigration()
        }
    }

    // MARK: - Development Helpers

    /// Create a test user for development
    func createTestUser() async throws {
        guard useFirebaseAuth else {
            print("⚠️ Test user creation only available with Firebase Auth")
            return
        }

        let testEmail = "test@infinitestories.app"
        let testPassword = "TestPassword123!"

        do {
            _ = try await firebaseAuth.signUp(
                email: testEmail,
                password: testPassword,
                displayName: "Test User"
            )
            print("✅ Test user created: \(testEmail)")
        } catch {
            // Try signing in if user already exists
            _ = try await firebaseAuth.signIn(email: testEmail, password: testPassword)
            print("✅ Test user signed in: \(testEmail)")
        }
    }

    /// Auto-authenticate for development
    func autoAuthenticateForDevelopment() async {
        #if DEBUG
        guard useFirebaseAuth else {
            print("📱 Using Supabase with hardcoded dev user")
            return
        }

        // Try anonymous sign in for development
        do {
            try await signInAnonymously()
            print("✅ Auto-authenticated anonymously for development")
        } catch {
            print("⚠️ Failed to auto-authenticate: \(error)")
        }
        #endif
    }

    // MARK: - Migration Analytics

    func logMigrationEvent(_ event: String, parameters: [String: Any]? = nil) {
        print("📊 Migration Event: \(event)")
        if let parameters = parameters {
            print("   Parameters: \(parameters)")
        }

        // Here you could send analytics to track migration progress
    }

    /// Get migration statistics
    @MainActor
    func getMigrationStats() -> [String: Any] {
        let migrationDate = UserDefaults.standard.object(forKey: migrationDateKey) as? Date

        return [
            "status": currentStatus.rawValue,
            "use_firebase": useFirebaseAuth,
            "migration_date": migrationDate?.description ?? "Not started",
            "firebase_user": firebaseAuth.currentUserId ?? "None",
            "is_authenticated": isAuthenticated()
        ]
    }

    /// Print current migration status for debugging
    @MainActor
    func printMigrationStatus() {
        print("═══════════════════════════════════════")
        print("🔄 AUTH MIGRATION STATUS")
        print("═══════════════════════════════════════")
        let stats = getMigrationStats()
        for (key, value) in stats {
            print("▸ \(key): \(value)")
        }
        print("═══════════════════════════════════════")
    }
}

// MARK: - Migration Error Types

enum AuthMigrationError: LocalizedError {
    case migrationInProgress
    case migrationFailed(String)
    case incompatibleAuthState
    case userDataMigrationFailed

    var errorDescription: String? {
        switch self {
        case .migrationInProgress:
            return "Authentication migration is currently in progress"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .incompatibleAuthState:
            return "Current authentication state is incompatible with migration"
        case .userDataMigrationFailed:
            return "Failed to migrate user data to new authentication system"
        }
    }
}