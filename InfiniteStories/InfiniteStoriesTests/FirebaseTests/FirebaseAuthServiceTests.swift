//
//  FirebaseAuthServiceTests.swift
//  InfiniteStoriesTests
//
//  Comprehensive tests for FirebaseAuthService
//

import XCTest
import FirebaseAuth
@testable import InfiniteStories

@MainActor
final class FirebaseAuthServiceTests: FirebaseTestBase {

    // MARK: - Properties

    var authService: FirebaseAuthService!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Note: FirebaseAuthService is a singleton, so we need to work with that
        // In production code, we might want to refactor to allow dependency injection
        authService = FirebaseAuthService.shared
    }

    override func tearDownWithError() throws {
        authService = nil
        try super.tearDownWithError()
    }

    // MARK: - Sign Up Tests

    func testSignUpWithValidCredentials() async throws {
        // Given
        let email = "newuser@test.com"
        let password = "ValidPassword123!"
        let displayName = "New User"

        // When
        let user = try await authService.signUp(
            email: email,
            password: password,
            displayName: displayName
        )

        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user.email, email)
        XCTAssertTrue(authService.isAuthenticated)
        XCTAssertEqual(authService.currentUser?.uid, user.uid)
    }

    func testSignUpWithInvalidEmail() async {
        // Given
        let email = "invalid-email"
        let password = "ValidPassword123!"

        // When/Then
        do {
            _ = try await authService.signUp(email: email, password: password)
            XCTFail("Expected sign up to fail with invalid email")
        } catch {
            XCTAssertTrue(error is FirebaseAuthError)
            XCTAssertNotNil(authService.authError)
        }
    }

    func testSignUpWithWeakPassword() async {
        // Given
        let email = "user@test.com"
        let password = "weak"

        // When/Then
        do {
            _ = try await authService.signUp(email: email, password: password)
            XCTFail("Expected sign up to fail with weak password")
        } catch {
            XCTAssertTrue(error is FirebaseAuthError)
            XCTAssertNotNil(authService.authError)
        }
    }

    func testSignUpWithExistingEmail() async throws {
        // Given
        let email = "existing@test.com"
        let password = "ValidPassword123!"

        // Create first user
        _ = try await createTestUser(email: email, password: password)

        // When/Then - Try to create again
        do {
            _ = try await authService.signUp(email: email, password: password)
            XCTFail("Expected sign up to fail with existing email")
        } catch {
            XCTAssertTrue(error is FirebaseAuthError)
            XCTAssertNotNil(authService.authError)
        }
    }

    // MARK: - Sign In Tests

    func testSignInWithValidCredentials() async throws {
        // Given
        let email = "signin@test.com"
        let password = "ValidPassword123!"
        _ = try await createTestUser(email: email, password: password)

        // When
        let user = try await authService.signIn(email: email, password: password)

        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user.email, email)
        XCTAssertTrue(authService.isAuthenticated)
        XCTAssertFalse(authService.isLoading)
    }

    func testSignInWithWrongPassword() async throws {
        // Given
        let email = "wrongpass@test.com"
        let password = "CorrectPassword123!"
        _ = try await createTestUser(email: email, password: password)

        // When/Then
        do {
            _ = try await authService.signIn(email: email, password: "WrongPassword123!")
            XCTFail("Expected sign in to fail with wrong password")
        } catch {
            XCTAssertTrue(error is FirebaseAuthError)
            XCTAssertNotNil(authService.authError)
        }
    }

    func testSignInWithNonExistentUser() async {
        // Given
        let email = "nonexistent@test.com"
        let password = "Password123!"

        // When/Then
        do {
            _ = try await authService.signIn(email: email, password: password)
            XCTFail("Expected sign in to fail with non-existent user")
        } catch {
            XCTAssertTrue(error is FirebaseAuthError)
            XCTAssertNotNil(authService.authError)
        }
    }

    func testSignInAnonymously() async throws {
        // When
        let user = try await authService.signInAnonymously()

        // Then
        XCTAssertNotNil(user)
        XCTAssertTrue(user.isAnonymous)
        XCTAssertTrue(authService.isAuthenticated)
        XCTAssertNil(user.email)
    }

    // MARK: - Sign Out Tests

    func testSignOut() async throws {
        // Given - Sign in first
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )
        XCTAssertTrue(authService.isAuthenticated)

        // When
        try authService.signOut()

        // Then
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
    }

    // MARK: - Password Reset Tests

    func testSendPasswordReset() async throws {
        // Given
        let email = "reset@test.com"
        let password = "OldPassword123!"
        _ = try await createTestUser(email: email, password: password)

        // When
        try await authService.sendPasswordReset(email: email)

        // Then
        XCTAssertFalse(authService.isLoading)
        XCTAssertNil(authService.authError)
    }

    func testSendPasswordResetToNonExistentEmail() async {
        // Given
        let email = "nonexistent@test.com"

        // When/Then - Firebase Auth may not throw error for this
        // It's a security feature to not reveal if email exists
        do {
            try await authService.sendPasswordReset(email: email)
            // This might succeed without error
        } catch {
            // Or it might fail depending on configuration
            XCTAssertTrue(error is FirebaseAuthError)
        }
    }

    // MARK: - Update Methods Tests

    func testUpdatePassword() async throws {
        // Given - Create and sign in user
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // When
        let newPassword = "NewPassword123!"
        try await authService.updatePassword(newPassword: newPassword)

        // Then - Try to sign in with new password
        try authService.signOut()
        let user = try await authService.signIn(
            email: TestUser.email,
            password: newPassword
        )
        XCTAssertNotNil(user)
    }

    func testUpdatePasswordWhenNotLoggedIn() async {
        // Given - No user logged in
        XCTAssertNil(authService.currentUser)

        // When/Then
        do {
            try await authService.updatePassword(newPassword: "NewPassword123!")
            XCTFail("Expected update to fail when not logged in")
        } catch FirebaseAuthError.noUserLoggedIn {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Token Tests

    func testGetIDToken() async throws {
        // Given - Sign in user
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // When
        let token = try await authService.getIDToken()

        // Then
        XCTAssertFalse(token.isEmpty)
        XCTAssertTrue(token.count > 100) // JWT tokens are typically long
    }

    func testGetIDTokenWhenNotLoggedIn() async {
        // Given - No user logged in
        XCTAssertNil(authService.currentUser)

        // When/Then
        do {
            _ = try await authService.getIDToken()
            XCTFail("Expected token fetch to fail when not logged in")
        } catch FirebaseAuthError.noUserLoggedIn {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Email Verification Tests

    func testCheckEmailVerification() async throws {
        // Given - Create and sign in user
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // When
        let isVerified = try await authService.checkEmailVerification()

        // Then
        XCTAssertFalse(isVerified) // New users start unverified
    }

    func testResendEmailVerification() async throws {
        // Given - Create and sign in user
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // When
        try await authService.resendEmailVerification()

        // Then - No error thrown
        XCTAssertTrue(true)
    }

    // MARK: - Compatibility Methods Tests

    func testCurrentUserId() async throws {
        // Given - No user initially
        XCTAssertNil(authService.currentUserId)

        // When - Sign in
        _ = try await createTestUser()
        let user = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // Then
        XCTAssertEqual(authService.currentUserId, user.uid)
    }

    func testIsLoggedIn() async throws {
        // Given - No user initially
        XCTAssertFalse(authService.isLoggedIn)

        // When - Sign in
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // Then
        XCTAssertTrue(authService.isLoggedIn)

        // When - Sign out
        try authService.signOut()

        // Then
        XCTAssertFalse(authService.isLoggedIn)
    }

    func testUserEmail() async throws {
        // Given - No user initially
        XCTAssertNil(authService.userEmail)

        // When - Sign in
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // Then
        XCTAssertEqual(authService.userEmail, TestUser.email)
    }

    func testCheckAuthentication() async throws {
        // Given - Sign in user
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // When
        let isAuthenticated = await authService.checkAuthentication()

        // Then
        XCTAssertTrue(isAuthenticated)
    }

    // MARK: - Delete Account Tests

    func testDeleteAccount() async throws {
        // Given - Create and sign in user
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )
        XCTAssertNotNil(authService.currentUser)

        // When
        try await authService.deleteAccount()

        // Then
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
    }

    // MARK: - Reauthentication Tests

    func testReauthenticate() async throws {
        // Given - Create and sign in user
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // When
        try await authService.reauthenticate(
            email: TestUser.email,
            password: TestUser.password
        )

        // Then - No error thrown
        XCTAssertTrue(true)
    }

    func testReauthenticateWithWrongPassword() async throws {
        // Given - Create and sign in user
        _ = try await createTestUser()
        _ = try await authService.signIn(
            email: TestUser.email,
            password: TestUser.password
        )

        // When/Then
        do {
            try await authService.reauthenticate(
                email: TestUser.email,
                password: "WrongPassword123!"
            )
            XCTFail("Expected reauthentication to fail")
        } catch {
            XCTAssertTrue(error is FirebaseAuthError)
        }
    }
}