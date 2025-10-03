//
//  FirebaseAuthView.swift
//  InfiniteStories
//
//  Authentication view for Firebase Auth
//  Provides sign in, sign up, and anonymous access options
//

import SwiftUI
import FirebaseAuth

struct FirebaseAuthView: View {
    @StateObject private var authService = FirebaseAuthService.shared
    @StateObject private var migrationHelper = AuthMigrationHelper.shared

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var showingPasswordReset = false
    @State private var resetEmail = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Authentication"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    authHeader

                    // Auth Form
                    authForm

                    // Action Buttons
                    actionButtons

                    // Alternative Options
                    alternativeOptions

                    // Development Options
                    #if DEBUG
                    developmentOptions
                    #endif
                }
                .padding()
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingPasswordReset) {
            passwordResetView
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }

    // MARK: - View Components

    private var authHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Welcome to Infinite Stories")
                .font(.title2)
                .fontWeight(.semibold)

            Text(isSignUp ? "Create your account to start your journey" : "Sign in to continue your stories")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private var authForm: some View {
        VStack(spacing: 16) {
            // Display Name (Sign Up only)
            if isSignUp {
                TextField("Display Name (optional)", text: $displayName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
            }

            // Email Field
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            // Password Field
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            // Confirm Password (Sign Up only)
            if isSignUp {
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                    Label("Passwords do not match", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary Action Button
            Button(action: performAuth) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authService.isLoading || !isFormValid)

            // Toggle Sign In/Sign Up
            Button(action: { isSignUp.toggle() }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }

            // Forgot Password
            if !isSignUp {
                Button(action: { showingPasswordReset = true }) {
                    Text("Forgot Password?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var alternativeOptions: some View {
        VStack(spacing: 16) {
            Divider()

            Text("OR")
                .font(.caption)
                .foregroundColor(.secondary)

            // Anonymous Sign In
            Button(action: signInAnonymously) {
                Label("Continue as Guest", systemImage: "person.fill.questionmark")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
            }

            Text("Guest accounts have limited features")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }

    #if DEBUG
    private var developmentOptions: some View {
        VStack(spacing: 12) {
            Divider()

            Text("Development Options")
                .font(.headline)
                .foregroundColor(.secondary)

            Button(action: createTestAccount) {
                Label("Create Test Account", systemImage: "hammer.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
            }

            Button(action: { migrationHelper.printMigrationStatus() }) {
                Label("Show Migration Status", systemImage: "info.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(.vertical)
    }
    #endif

    private var passwordResetView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .padding()

                Text("Reset Password")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Email", text: $resetEmail)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                Button(action: sendPasswordReset) {
                    Text("Send Reset Email")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(resetEmail.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Password Reset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingPasswordReset = false
                        resetEmail = ""
                    }
                }
            }
        }
    }

    // MARK: - Helper Properties

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty &&
                   password == confirmPassword && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    // MARK: - Actions

    private func performAuth() {
        Task {
            do {
                if isSignUp {
                    _ = try await authService.signUp(
                        email: email,
                        password: password,
                        displayName: displayName.isEmpty ? nil : displayName
                    )
                    showAlert(
                        title: "Account Created",
                        message: "Please check your email to verify your account."
                    )
                } else {
                    _ = try await authService.signIn(email: email, password: password)
                }
            } catch {
                showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }

    private func signInAnonymously() {
        Task {
            do {
                _ = try await authService.signInAnonymously()
            } catch {
                showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }

    private func sendPasswordReset() {
        Task {
            do {
                try await authService.sendPasswordReset(email: resetEmail)
                showingPasswordReset = false
                showAlert(
                    title: "Email Sent",
                    message: "Password reset instructions have been sent to \(resetEmail)"
                )
                resetEmail = ""
            } catch {
                showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }

    #if DEBUG
    private func createTestAccount() {
        Task {
            do {
                try await migrationHelper.createTestUser()
                showAlert(
                    title: "Test Account",
                    message: "Test account created or signed in successfully"
                )
            } catch {
                showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }
    #endif

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Preview

struct FirebaseAuthView_Previews: PreviewProvider {
    static var previews: some View {
        FirebaseAuthView()
    }
}