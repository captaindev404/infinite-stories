//
//  AuthenticationView.swift
//  InfiniteStories
//
//  Authentication screen for sign in and sign up
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var authState: AuthStateManager
    @StateObject private var viewModel = AuthenticationViewModel()
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, password, confirmPassword, name
    }

    var body: some View {
        // BUG-10: Wrap in NavigationStack with an empty inline title so iOS
        // draws a thin opaque `.bar` material above the scroll content. The
        // `Histoires Infinies` hero text lives inside the ScrollView on
        // purpose (brand), so we keep an always-visible opaque nav-bar
        // material above it to prevent the hero from bleeding into the
        // Dynamic Island / clock when the user scrolls up.
        NavigationStack {
            ZStack {
            // System background
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                // BUG-05: spacings/paddings tightened so the debug test-account
                // row sits inside the 874pt viewport on iPhone 17 Pro without
                // having to scroll to reach it.
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                            // BUG-26: decorative header icon; title+subtitle
                            // already carry the meaningful label.
                            .accessibilityHidden(true)

                        Text("auth.appTitle")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)

                        Text(isSignUp ? String(localized: "auth.createAccount.subtitle") : String(localized: "auth.signIn.subtitle"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Auth toggle
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isSignUp = false
                                clearForm()
                            }
                        }) {
                            Text("auth.signIn.button")
                                .font(.headline)
                                .foregroundColor(isSignUp ? .secondary : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSignUp ? Color.clear : Color.accentColor)
                                .cornerRadius(15)
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isSignUp = true
                                clearForm()
                            }
                        }) {
                            Text("auth.signUp.button")
                                .font(.headline)
                                .foregroundColor(isSignUp ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSignUp ? Color.accentColor : Color.clear)
                                .cornerRadius(15)
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .padding(.horizontal, 30)

                    // Form fields
                    // BUG-24/26/29/30: every field now carries an explicit
                    // accessibility label (matching the visible FR label /
                    // placeholder), the correct textContentType (so the
                    // sign-up password gets `.newPassword` instead of
                    // hijacking the user with the strong-password prompt),
                    // autocorrect disabled on identifier-like inputs, and
                    // .never capitalization on email/password.
                    VStack(spacing: 14) {
                        if isSignUp {
                            MagicalTextField(
                                icon: "person.fill",
                                placeholder: String(localized: "auth.field.fullName"),
                                text: $name,
                                isSecure: false,
                                keyboardType: .default,
                                accessibilityLabel: String(localized: "auth.field.fullName"),
                                textContentType: .name,
                                autocorrectionDisabled: false,
                                textInputAutocapitalization: .words
                            )
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .email
                            }
                        }

                        MagicalTextField(
                            icon: "envelope.fill",
                            placeholder: String(localized: "auth.field.email"),
                            text: $email,
                            isSecure: false,
                            keyboardType: .emailAddress,
                            accessibilityLabel: String(localized: "auth.field.email"),
                            textContentType: .emailAddress,
                            autocorrectionDisabled: true,
                            textInputAutocapitalization: .never
                        )
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }

                        MagicalTextField(
                            icon: "lock.fill",
                            placeholder: String(localized: "auth.field.password"),
                            text: $password,
                            isSecure: true,
                            keyboardType: .default,
                            accessibilityLabel: String(localized: "auth.field.password"),
                            textContentType: isSignUp ? .newPassword : .password,
                            autocorrectionDisabled: true,
                            textInputAutocapitalization: .never
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(isSignUp ? .next : .done)
                        .onSubmit {
                            if isSignUp {
                                focusedField = .confirmPassword
                            } else {
                                handleAuthentication()
                            }
                        }

                        if isSignUp {
                            MagicalTextField(
                                icon: "lock.rotation",
                                placeholder: String(localized: "auth.field.confirmPassword"),
                                text: $confirmPassword,
                                isSecure: true,
                                keyboardType: .default,
                                accessibilityLabel: String(localized: "auth.field.confirmPassword"),
                                textContentType: .newPassword,
                                autocorrectionDisabled: true,
                                textInputAutocapitalization: .never
                            )
                            .focused($focusedField, equals: .confirmPassword)
                            .submitLabel(.done)
                            .onSubmit {
                                handleAuthentication()
                            }
                        }
                    }
                    .padding(.horizontal, 30)

                    // Action buttons
                    VStack(spacing: 12) {
                        // Main auth button
                        Button(action: handleAuthentication) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(height: 22)
                            } else {
                                HStack {
                                    Text(isSignUp ? String(localized: "auth.createAccount.button") : String(localized: "auth.signIn.button"))
                                        .font(.headline)
                                    Image(systemName: "arrow.right.circle.fill")
                                        // BUG-26: decorative chevron inside
                                        // a text-labeled button.
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .cornerRadius(25)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        .disabled(viewModel.isLoading || !isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                        .padding(.horizontal, 30)

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("auth.or")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 30)

                        // Sign in with Apple
                        SignInWithAppleButton(
                            isSignUp ? .signUp : .signIn,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result: result)
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(25)
                        .padding(.horizontal, 30)
                        .disabled(viewModel.isLoading)

                        // Test buttons (development only)
                        // BUG-05: moved above Apple-sign-in spacing + Spacer so
                        // they land inside the visible scroll viewport on
                        // iPhone 17 Pro (874pt) without requiring the user to
                        // scroll to reach them.
                        #if DEBUG
                        debugTestAccountButtons
                            .padding(.top, 4)
                        #endif
                    }
                    .padding(.top, 10)

                    Spacer(minLength: 30)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Material.bar, for: .navigationBar)
        }
        .onAppear {
            // BUG-A09: Always default to Sign In on cold launch. Returning users
            // land on Sign In (their primary action); new users tap once to Sign Up.
            isSignUp = false
        }
        .alert(String(localized: "auth.error.title"), isPresented: $showError) {
            Button(String(localized: "common.ok"), role: .cancel) {
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }

    #if DEBUG
    /// Extracted so we can place the debug test-account row wherever we need
    /// inside the scroll container without duplicating styling (BUG-05).
    private var debugTestAccountButtons: some View {
        HStack(spacing: 12) {
            // Login with test user
            Button(action: loginWithTestUser) {
                HStack {
                    Image(systemName: "person.fill.checkmark")
                    // BUG-34: debug helpers are now localized so they don't
                    // stand out as English inside an otherwise-FR screen.
                    Text("auth.debug.loginTestUser")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .disabled(viewModel.isLoading)

            // Create new test account
            Button(action: createTestAccount) {
                HStack {
                    Image(systemName: "hammer.fill")
                    // BUG-34: localized debug button label.
                    Text("auth.debug.createTest")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 30)
    }
    #endif

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty &&
                   !password.isEmpty &&
                   !name.isEmpty &&
                   password == confirmPassword &&
                   password.count >= 8 &&
                   email.contains("@")
        } else {
            return !email.isEmpty && !password.isEmpty &&
                   email.contains("@")
        }
    }

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        name = ""
        errorMessage = ""
        focusedField = nil
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = String(localized: "auth.error.appleSignIn")
                showError = true
                return
            }

            let fullName = appleIDCredential.fullName
            let displayName = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            Task {
                do {
                    let (token, userId) = try await viewModel.signInWithApple(
                        identityToken: identityToken,
                        name: displayName.isEmpty ? nil : displayName
                    )
                    await MainActor.run {
                        authState.signIn(token: token, userId: userId)
                        let successFeedback = UINotificationFeedbackGenerator()
                        successFeedback.notificationOccurred(.success)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                        let errorFeedback = UINotificationFeedbackGenerator()
                        errorFeedback.notificationOccurred(.error)
                    }
                }
            }

        case .failure(let error):
            // User cancelled — don't show error for cancellation
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleAuthentication() {
        guard isFormValid else { return }

        // Hide keyboard
        focusedField = nil

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        Task {
            do {
                if isSignUp {
                    let (token, userId) = try await viewModel.signUp(email: email, password: password, name: name)
                    await MainActor.run {
                        authState.signIn(token: token, userId: userId)

                        // Success haptic
                        let successFeedback = UINotificationFeedbackGenerator()
                        successFeedback.notificationOccurred(.success)
                    }
                } else {
                    let (token, userId) = try await viewModel.signIn(email: email, password: password)
                    await MainActor.run {
                        authState.signIn(token: token, userId: userId)

                        // Success haptic
                        let successFeedback = UINotificationFeedbackGenerator()
                        successFeedback.notificationOccurred(.success)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true

                    // Error haptic
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }

    private func loginWithTestUser() {
        // BUG-A19: refuse to use the dev test account against a non-localhost
        // backend so an accidentally-leaked DEBUG build can't authenticate a
        // fake user against production. Localhost-only environments are the
        // contract for this helper.
        guard AppConfiguration.backendBaseURL.contains("localhost") || AppConfiguration.backendBaseURL.contains("127.0.0.1") else {
            errorMessage = "Debug test user is only permitted against localhost backends."
            showError = true
            return
        }

        // Auto-fill test credentials for login
        email = "test@example.com"
        password = "testpass123"
        isSignUp = false

        // Clear other fields
        confirmPassword = ""
        name = ""
        errorMessage = ""

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        Task {
            do {
                let (token, userId) = try await viewModel.signIn(email: "test@example.com", password: "testpass123")
                await MainActor.run {
                    authState.signIn(token: token, userId: userId)
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }

    private func createTestAccount() {
        // BUG-A19: localhost-only guard, same as loginWithTestUser.
        guard AppConfiguration.backendBaseURL.contains("localhost") || AppConfiguration.backendBaseURL.contains("127.0.0.1") else {
            errorMessage = "Debug test account creation is only permitted against localhost backends."
            showError = true
            return
        }

        // Auto-fill test credentials for sign up (same as login test user)
        email = "test@example.com"
        password = "testpass123"
        confirmPassword = "testpass123"
        name = "Test User"
        isSignUp = true

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        Task {
            do {
                let (token, userId) = try await viewModel.signUp(
                    email: "test@example.com",
                    password: "testpass123",
                    name: "Test User"
                )
                await MainActor.run {
                    authState.signIn(token: token, userId: userId)
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                }
            } catch AuthenticationError.userAlreadyExists {
                // BUG-21: backend returned 409/422 USER_ALREADY_EXISTS. Fall
                // back to a plain sign-in with the same credentials so the
                // debug button "just works" on re-runs.
                #if DEBUG
                print("ℹ️ Create Test: account already exists, falling back to sign-in")
                #endif
                do {
                    let (token, userId) = try await viewModel.signIn(
                        email: "test@example.com",
                        password: "testpass123"
                    )
                    await MainActor.run {
                        authState.signIn(token: token, userId: userId)
                        let successFeedback = UINotificationFeedbackGenerator()
                        successFeedback.notificationOccurred(.success)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                        let errorFeedback = UINotificationFeedbackGenerator()
                        errorFeedback.notificationOccurred(.error)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - View Model
@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isAuthenticated = false

    private let baseURL = AppConfiguration.backendBaseURL

    func signInWithApple(identityToken: String, name: String?) async throws -> (String, String) {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: "\(baseURL)/api/auth/sign-in/social")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        request.setValue("InfiniteStories/1.0", forHTTPHeaderField: "User-Agent")

        var idTokenObject: [String: Any] = ["token": identityToken]
        if let name = name {
            idTokenObject["name"] = name
        }
        let body: [String: Any] = [
            "provider": "apple",
            "idToken": idTokenObject,
            "callbackURL": "\(baseURL)/api/auth/callback/apple"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.networkError
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            #if DEBUG
            print("Apple sign-in failed with status \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            #endif
            throw AuthenticationError.invalidCredentials
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthenticationError.invalidResponse
        }

        // Parse token from response (same structure as email sign-in)
        var token: String?
        var userId: String?

        if let session = json["session"] as? [String: Any] {
            token = session["token"] as? String ?? session["sessionToken"] as? String ?? session["id"] as? String
        }
        if token == nil {
            token = json["token"] as? String ?? json["sessionToken"] as? String ?? json["accessToken"] as? String
        }
        if token == nil, let data = json["data"] as? [String: Any] {
            if let session = data["session"] as? [String: Any] {
                token = session["token"] as? String ?? session["sessionToken"] as? String ?? session["id"] as? String
            }
            token = token ?? data["token"] as? String
        }

        guard let token = token else {
            throw AuthenticationError.invalidResponse
        }

        if let user = json["user"] as? [String: Any] {
            userId = user["id"] as? String
        } else if let data = json["data"] as? [String: Any],
                  let user = data["user"] as? [String: Any] {
            userId = user["id"] as? String
        } else {
            userId = json["userId"] as? String ?? json["id"] as? String
        }

        guard let userId = userId else {
            throw AuthenticationError.invalidResponse
        }

        isAuthenticated = true
        return (token, userId)
    }

    func signIn(email: String, password: String) async throws -> (String, String) {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: "\(baseURL)/api/auth/sign-in/email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        request.setValue("InfiniteStories/1.0", forHTTPHeaderField: "User-Agent")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.networkError
        }

        #if DEBUG
        print("Sign in response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("Sign in response body: \(responseString)")
        }
        #endif

        if httpResponse.statusCode == 200 {
            // Parse response - better-auth can return different structures
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                #if DEBUG
                print("Failed to parse JSON")
                #endif
                throw AuthenticationError.invalidResponse
            }

            #if DEBUG
            print("Parsed JSON keys: \(json.keys)")
            if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyJson = String(data: jsonData, encoding: .utf8) {
                print("Full JSON structure:\n\(prettyJson)")
            }
            #endif

            // Try different response structures
            var token: String?
            var userId: String?

            // Structure 1: { user: {...}, session: {...} }
            if let session = json["session"] as? [String: Any] {
                #if DEBUG
                print("Found session object, keys: \(session.keys)")
                #endif
                token = session["token"] as? String ?? session["sessionToken"] as? String ?? session["id"] as? String
            }

            // Structure 2: Token might be at root level
            if token == nil {
                token = json["token"] as? String ?? json["sessionToken"] as? String ?? json["accessToken"] as? String
                #if DEBUG
                if token != nil {
                    print("Found token at root level")
                }
                #endif
            }

            // Structure 3: Check for data wrapper { data: { user, session } }
            if token == nil, let data = json["data"] as? [String: Any] {
                #if DEBUG
                print("Found data wrapper, keys: \(data.keys)")
                #endif
                if let session = data["session"] as? [String: Any] {
                    token = session["token"] as? String ?? session["sessionToken"] as? String ?? session["id"] as? String
                }
                token = token ?? data["token"] as? String
            }

            guard let token = token else {
                #if DEBUG
                print("❌ No token found in any expected location")
                #endif
                throw AuthenticationError.invalidResponse
            }

            // Get user ID - try different structures
            if let user = json["user"] as? [String: Any] {
                userId = user["id"] as? String
            } else if let data = json["data"] as? [String: Any],
                      let user = data["user"] as? [String: Any] {
                userId = user["id"] as? String
            } else {
                userId = json["userId"] as? String ?? json["id"] as? String
            }

            guard let userId = userId else {
                #if DEBUG
                print("❌ No user ID found in response")
                #endif
                throw AuthenticationError.invalidResponse
            }

            #if DEBUG
            print("✅ Sign in successful! User ID: \(userId), Token: \(token.prefix(10))...")
            #endif

            isAuthenticated = true
            return (token, userId)
        } else {
            #if DEBUG
            print("❌ Sign in failed with status \(httpResponse.statusCode)")
            #endif
            throw AuthenticationError.invalidCredentials
        }
    }

    func signUp(email: String, password: String, name: String) async throws -> (String, String) {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: "\(baseURL)/api/auth/sign-up/email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        request.setValue("InfiniteStories/1.0", forHTTPHeaderField: "User-Agent")

        let body = ["email": email, "password": password, "name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.networkError
        }

        #if DEBUG
        print("Sign up request to: \(url)")
        print("Sign up response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("Sign up response body: \(responseString)")
        }
        #endif

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            // Parse response - better-auth can return different structures
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                #if DEBUG
                print("Failed to parse JSON")
                #endif
                throw AuthenticationError.invalidResponse
            }

            #if DEBUG
            print("Parsed JSON keys: \(json.keys)")
            if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyJson = String(data: jsonData, encoding: .utf8) {
                print("Full JSON structure:\n\(prettyJson)")
            }
            #endif

            // Try different response structures
            var token: String?
            var userId: String?

            // Structure 1: { user: {...}, session: {...} }
            if let session = json["session"] as? [String: Any] {
                #if DEBUG
                print("Found session object, keys: \(session.keys)")
                #endif
                token = session["token"] as? String ?? session["sessionToken"] as? String ?? session["id"] as? String
            }

            // Structure 2: Token might be at root level
            if token == nil {
                token = json["token"] as? String ?? json["sessionToken"] as? String ?? json["accessToken"] as? String
                #if DEBUG
                if token != nil {
                    print("Found token at root level")
                }
                #endif
            }

            // Structure 3: Check for data wrapper { data: { user, session } }
            if token == nil, let data = json["data"] as? [String: Any] {
                #if DEBUG
                print("Found data wrapper, keys: \(data.keys)")
                #endif
                if let session = data["session"] as? [String: Any] {
                    token = session["token"] as? String ?? session["sessionToken"] as? String ?? session["id"] as? String
                }
                token = token ?? data["token"] as? String
            }

            guard let token = token else {
                #if DEBUG
                print("❌ No token found in any expected location")
                #endif
                throw AuthenticationError.invalidResponse
            }

            // Get user ID - try different structures
            if let user = json["user"] as? [String: Any] {
                userId = user["id"] as? String
            } else if let data = json["data"] as? [String: Any],
                      let user = data["user"] as? [String: Any] {
                userId = user["id"] as? String
            } else {
                userId = json["userId"] as? String ?? json["id"] as? String
            }

            guard let userId = userId else {
                #if DEBUG
                print("❌ No user ID found in response")
                #endif
                throw AuthenticationError.invalidResponse
            }

            #if DEBUG
            print("✅ Sign up successful! User ID: \(userId), Token: \(token.prefix(10))...")
            #endif

            isAuthenticated = true
            return (token, userId)
        } else if httpResponse.statusCode == 409 || httpResponse.statusCode == 422 {
            // Backend may return 409 (legacy) or 422 USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL
            // for an existing account. Treat both as "user already exists" so the
            // debug `Create Test` button can fall back to a plain login (BUG-21).
            #if DEBUG
            print("⚠️ User already exists (status \(httpResponse.statusCode))")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Sign up conflict body: \(responseString)")
            }
            #endif
            throw AuthenticationError.userAlreadyExists
        } else {
            #if DEBUG
            print("❌ Sign up failed with status \(httpResponse.statusCode)")
            #endif
            throw AuthenticationError.signUpFailed
        }
    }
}

enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case networkError
    case userAlreadyExists
    case signUpFailed
    case invalidResponse
    case appleSignInFailed

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return String(localized: "auth.error.invalidCredentials")
        case .networkError:
            return String(localized: "auth.error.network")
        case .userAlreadyExists:
            return String(localized: "auth.error.userExists")
        case .signUpFailed:
            return String(localized: "auth.error.signUpFailed")
        case .invalidResponse:
            return String(localized: "auth.error.serverResponse")
        case .appleSignInFailed:
            return String(localized: "auth.error.appleSignIn")
        }
    }
}

#Preview {
    AuthenticationView()
}
