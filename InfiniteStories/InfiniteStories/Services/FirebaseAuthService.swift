//
//  FirebaseAuthService.swift
//  InfiniteStories
//
//  Firebase Authentication service to replace Supabase Auth
//  Provides user authentication and session management
//

import Foundation
import FirebaseAuth
import FirebaseCore
import Combine

// MARK: - Firebase Auth Service

@MainActor
final class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()

    // MARK: - Published Properties
    @Published var currentUser: User? = nil
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var authError: String? = nil

    // MARK: - Private Properties
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Management

    /// Set up listener for authentication state changes
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil

                if let user = user {
                    print("🔐 Firebase Auth: User authenticated - \(user.uid)")
                    print("📧 Email: \(user.email ?? "No email")")

                    // Refresh token if needed
                    do {
                        let token = try await user.getIDTokenResult(forcingRefresh: false)
                        print("🎟️ Token expiration: \(token.expirationDate)")
                    } catch {
                        print("⚠️ Failed to get ID token: \(error)")
                    }
                } else {
                    print("🔓 Firebase Auth: User not authenticated")
                }
            }
        }
    }

    // MARK: - Authentication Methods

    /// Sign up with email and password
    func signUp(email: String, password: String, displayName: String? = nil) async throws -> User {
        isLoading = true
        authError = nil

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Update display name if provided
            if let displayName = displayName {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }

            // Send email verification
            try await result.user.sendEmailVerification()

            print("✅ Firebase Auth: User created successfully - \(result.user.uid)")
            isLoading = false
            return result.user
        } catch let error as NSError {
            isLoading = false
            let errorMessage = handleAuthError(error)
            authError = errorMessage
            throw FirebaseAuthError.signUpFailed(errorMessage)
        }
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> User {
        isLoading = true
        authError = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Firebase Auth: User signed in - \(result.user.uid)")
            isLoading = false
            return result.user
        } catch let error as NSError {
            isLoading = false
            let errorMessage = handleAuthError(error)
            authError = errorMessage
            throw FirebaseAuthError.signInFailed(errorMessage)
        }
    }

    /// Sign in anonymously for testing or guest access
    func signInAnonymously() async throws -> User {
        isLoading = true
        authError = nil

        do {
            let result = try await Auth.auth().signInAnonymously()
            print("✅ Firebase Auth: Anonymous user signed in - \(result.user.uid)")
            isLoading = false
            return result.user
        } catch let error as NSError {
            isLoading = false
            let errorMessage = handleAuthError(error)
            authError = errorMessage
            throw FirebaseAuthError.signInFailed(errorMessage)
        }
    }

    /// Sign out the current user
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            print("✅ Firebase Auth: User signed out")
            authError = nil
        } catch let error as NSError {
            let errorMessage = handleAuthError(error)
            authError = errorMessage
            throw FirebaseAuthError.signOutFailed(errorMessage)
        }
    }

    /// Send password reset email
    func sendPasswordReset(email: String) async throws {
        isLoading = true
        authError = nil

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("✅ Firebase Auth: Password reset email sent to \(email)")
            isLoading = false
        } catch let error as NSError {
            isLoading = false
            let errorMessage = handleAuthError(error)
            authError = errorMessage
            throw FirebaseAuthError.passwordResetFailed(errorMessage)
        }
    }

    /// Update user email
    func updateEmail(newEmail: String) async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.noUserLoggedIn
        }

        isLoading = true
        authError = nil

        do {
            // For security, may require recent login
            try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
            print("✅ Firebase Auth: Email update verification sent to \(newEmail)")
            isLoading = false
        } catch let error as NSError {
            isLoading = false
            let errorMessage = handleAuthError(error)
            authError = errorMessage
            throw FirebaseAuthError.updateFailed(errorMessage)
        }
    }

    /// Update user password
    func updatePassword(newPassword: String) async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.noUserLoggedIn
        }

        isLoading = true
        authError = nil

        do {
            try await user.updatePassword(to: newPassword)
            print("✅ Firebase Auth: Password updated successfully")
            isLoading = false
        } catch let error as NSError {
            isLoading = false
            let errorMessage = handleAuthError(error)
            authError = errorMessage
            throw FirebaseAuthError.updateFailed(errorMessage)
        }
    }

    /// Delete user account
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.noUserLoggedIn
        }

        isLoading = true
        authError = nil

        do {
            try await user.delete()
            print("✅ Firebase Auth: User account deleted")
            isLoading = false
        } catch let error as NSError {
            isLoading = false
            let errorMessage = handleAuthError(error)
            authError = errorMessage
            throw FirebaseAuthError.deleteFailed(errorMessage)
        }
    }

    /// Re-authenticate user (required for sensitive operations)
    func reauthenticate(email: String, password: String) async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.noUserLoggedIn
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        do {
            try await user.reauthenticate(with: credential)
            print("✅ Firebase Auth: User re-authenticated")
        } catch let error as NSError {
            let errorMessage = handleAuthError(error)
            throw FirebaseAuthError.reauthenticationFailed(errorMessage)
        }
    }

    /// Get current user's ID token for API calls
    func getIDToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = currentUser else {
            throw FirebaseAuthError.noUserLoggedIn
        }

        do {
            let token = try await user.getIDTokenResult(forcingRefresh: forceRefresh)
            return token.token
        } catch {
            throw FirebaseAuthError.tokenFetchFailed(error.localizedDescription)
        }
    }

    /// Check if user's email is verified
    func checkEmailVerification() async throws -> Bool {
        guard let user = currentUser else {
            throw FirebaseAuthError.noUserLoggedIn
        }

        // Reload user to get latest verification status
        try await user.reload()
        return user.isEmailVerified
    }

    /// Resend email verification
    func resendEmailVerification() async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.noUserLoggedIn
        }

        try await user.sendEmailVerification()
        print("✅ Firebase Auth: Verification email resent")
    }

    // MARK: - Error Handling

    private func handleAuthError(_ error: NSError) -> String {
        let errorCode = AuthErrorCode(rawValue: error.code)

        switch errorCode {
        case .invalidEmail:
            return "Invalid email address format"
        case .emailAlreadyInUse:
            return "This email is already registered"
        case .weakPassword:
            return "Password must be at least 6 characters"
        case .wrongPassword:
            return "Incorrect password"
        case .userNotFound:
            return "No account found with this email"
        case .userDisabled:
            return "This account has been disabled"
        case .tooManyRequests:
            return "Too many attempts. Please try again later"
        case .networkError:
            return "Network error. Please check your connection"
        case .requiresRecentLogin:
            return "This operation requires recent authentication. Please sign in again"
        case .invalidCredential:
            return "Invalid credentials provided"
        case .credentialAlreadyInUse:
            return "This credential is already associated with another account"
        default:
            return error.localizedDescription
        }
    }

    // MARK: - Compatibility Methods (Supabase Migration)

    /// Get current user ID (compatible with Supabase usage)
    var currentUserId: String? {
        return currentUser?.uid
    }

    /// Check if user is logged in (compatible with Supabase usage)
    var isLoggedIn: Bool {
        return currentUser != nil
    }

    /// Get user email (compatible with Supabase usage)
    var userEmail: String? {
        return currentUser?.email
    }

    /// Compatibility wrapper for async authentication check
    func checkAuthentication() async -> Bool {
        // Give Firebase a moment to restore session
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return currentUser != nil
    }
}

// MARK: - Firebase Auth Errors

enum FirebaseAuthError: LocalizedError {
    case signUpFailed(String)
    case signInFailed(String)
    case signOutFailed(String)
    case passwordResetFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case reauthenticationFailed(String)
    case tokenFetchFailed(String)
    case noUserLoggedIn
    case emailNotVerified

    var errorDescription: String? {
        switch self {
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .passwordResetFailed(let message):
            return "Password reset failed: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        case .deleteFailed(let message):
            return "Account deletion failed: \(message)"
        case .reauthenticationFailed(let message):
            return "Re-authentication failed: \(message)"
        case .tokenFetchFailed(let message):
            return "Failed to get authentication token: \(message)"
        case .noUserLoggedIn:
            return "No user is currently logged in"
        case .emailNotVerified:
            return "Please verify your email address"
        }
    }
}

// MARK: - Firebase Auth Configuration

extension FirebaseAuthService {
    /// Initialize Firebase if not already done
    static func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured successfully")

            // Enable auth state persistence
            Auth.auth().useAppLanguage()

            // Set up any additional Firebase Auth settings
            configureAuthSettings()
        }
    }

    private static func configureAuthSettings() {
        // Enable offline persistence for Firestore (if using)
        // This helps with auth token caching

        // Additional configuration can be added here
    }
}

// MARK: - User Extension for Convenience

extension User {
    /// Get display name or email prefix as fallback
    var displayNameOrEmail: String {
        if let displayName = displayName, !displayName.isEmpty {
            return displayName
        }
        if let email = email {
            return email.split(separator: "@").first.map(String.init) ?? "User"
        }
        return "User"
    }

    /// Check if user is anonymous
    var isAnonymousUser: Bool {
        return isAnonymous
    }
}