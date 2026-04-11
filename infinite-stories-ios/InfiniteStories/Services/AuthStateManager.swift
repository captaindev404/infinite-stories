//
//  AuthStateManager.swift
//  InfiniteStories
//
//  Global authentication state management
//

import SwiftUI
import Combine

@MainActor
class AuthStateManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var sessionToken: String?
    @Published var userId: String?
    @Published var hasEverAuthenticated = false // Track if user has ever signed in
    /// True when the backend rejected us with 401 while we previously thought we were
    /// authenticated. Used by the app root to unmount `MainTabView` and present the
    /// authentication screen full-screen (BUG-28).
    @Published var sessionExpired = false
    /// Tab the user was on before the session expired, so we can restore it on the
    /// next successful sign-in (BUG-28).
    @Published var pendingRestoreTab: AppTab?

    private let keychainHelper = KeychainHelper.shared

    init() {
        checkAuthenticationStatus()
    }

    private func checkAuthenticationStatus() {
        // Check if user has ever authenticated (even if session expired)
        if let _ = keychainHelper.load(forKey: "hasEverAuthenticated") as? Bool {
            self.hasEverAuthenticated = true
        }

        // Check if we have a valid session token
        if let token = keychainHelper.load(forKey: "sessionToken") as? String,
           let userId = keychainHelper.load(forKey: "userId") as? String,
           !token.isEmpty {
            self.sessionToken = token
            self.userId = userId
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
        }
    }

    func signIn(token: String, userId: String) {
        keychainHelper.save(token, forKey: "sessionToken")
        keychainHelper.save(userId, forKey: "userId")
        keychainHelper.save(true, forKey: "hasEverAuthenticated") // Mark as authenticated before
        self.sessionToken = token
        self.userId = userId
        self.isAuthenticated = true
        self.hasEverAuthenticated = true
        self.sessionExpired = false
    }

    /// Sign the user out explicitly (e.g. via Settings). Clears keychain, in-memory
    /// state, and ALL HTTP session state (cookies + URLCache auth) so the next
    /// sign-in starts from a clean slate (BUG-35).
    func signOut() {
        performSessionTeardown()
        self.sessionExpired = false
        self.pendingRestoreTab = nil
    }

    /// Called by the API client when a 401 is received. Clears session state and
    /// flips `sessionExpired` so the root view unmounts `MainTabView` (BUG-28).
    /// Preserves the currently-selected tab so we can restore it on reconnect.
    func handleSessionExpired(restoreTab: AppTab? = nil) {
        // Only record a restore tab the first time (don't overwrite with nil on
        // subsequent 401s from background retries).
        if self.pendingRestoreTab == nil, let restoreTab {
            self.pendingRestoreTab = restoreTab
        }
        performSessionTeardown()
        self.sessionExpired = true
    }

    /// Shared teardown: keychain, in-memory token, HTTP cookies, URL cache auth.
    /// (BUG-35 — sign-out must wipe better-auth cookies so the next "Login Test
    /// User" doesn't replay a stale/invalidated session cookie from
    /// `HTTPCookieStorage.shared` which `URLSession.shared` uses by default.)
    private func performSessionTeardown() {
        keychainHelper.delete(forKey: "sessionToken")
        keychainHelper.delete(forKey: "userId")
        self.sessionToken = nil
        self.userId = nil
        self.isAuthenticated = false

        // 1. Nuke every cookie in the shared storage (better-auth session,
        //    CSRF token, anything else). `.distantPast` is the documented way
        //    to clear all cookies regardless of expiration.
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)

        // 2. If the shared URLSession (used by AuthenticationViewModel and
        //    APIClient) carries its own configuration cookie storage, clear it
        //    too. In practice this is the same as HTTPCookieStorage.shared but
        //    we defend against custom configurations.
        if let sharedCookies = URLSession.shared.configuration.httpCookieStorage?.cookies {
            for cookie in sharedCookies {
                URLSession.shared.configuration.httpCookieStorage?.deleteCookie(cookie)
            }
        }

        // 3. Drop any cached authenticated responses so we don't serve stale
        //    data back to the next user.
        URLCache.shared.removeAllCachedResponses()
    }

    func getAuthorizationHeader() -> String? {
        guard let token = sessionToken else { return nil }
        return "Bearer \(token)"
    }
}

// MARK: - Global Singleton for Backend API Calls
extension AuthStateManager {
    static let shared = AuthStateManager()
}