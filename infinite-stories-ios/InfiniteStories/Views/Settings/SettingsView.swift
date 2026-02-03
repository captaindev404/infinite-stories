//
//  SettingsView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData

// MARK: - Settings Tab Content (for Tab Bar navigation)
/// This view is used within the Settings tab and removes redundant Done button
/// since navigation is now handled by the tab bar.
struct SettingsTabContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var settings = AppSettings()
    @EnvironmentObject private var themeSettings: ThemeSettings
    @EnvironmentObject private var authState: AuthStateManager
    @StateObject private var localizationManager = LocalizationManager.shared

    @State private var showingEraseConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingDeleteAccountFinalConfirmation = false
    @State private var showingDeleteAccountError = false
    @State private var isDeletingAccount = false
    @State private var showingAuthView = false
    @State private var showingRestartAlert = false
    @State private var debugTestUserEmail = "test@example.com"
    @State private var debugTestUserPassword = "password123"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "gear.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title2)

                        VStack(alignment: .leading) {
                            Text("settings.header.title")
                                .font(.headline)
                            Text("settings.header.subtitle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Theme Settings Section
                Section {
                    HStack {
                        Label("settings.appearance", systemImage: "moon.circle.fill")
                            .foregroundColor(.purple)

                        Spacer()

                        Picker("", selection: $themeSettings.themePreferenceString) {
                            ForEach(["system", "light", "dark"], id: \.self) { theme in
                                HStack {
                                    Image(systemName: settingsThemeIcon(for: theme))
                                    Text(LocalizedStringKey("settings.theme.\(theme)"))
                                }
                                .tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.purple)
                    }

                    // Visual indicator showing current theme
                    HStack {
                        Text("settings.currentMode")
                        Spacer()
                        Text(colorScheme == .dark ? String(localized: "settings.theme.dark") : String(localized: "settings.theme.light"))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("settings.theme")
                } footer: {
                    Text("settings.theme.footer")
                        .font(.caption)
                }

                // UI Language Section
                Section {
                    HStack {
                        Label("settings.uiLanguage", systemImage: "globe")
                            .foregroundColor(.purple)

                        Spacer()

                        Picker("", selection: $localizationManager.currentLanguage) {
                            ForEach(LocalizationManager.releasedUILanguages) { language in
                                Text(language.displayName)
                                    .tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.purple)
                    }
                } header: {
                    Text("settings.uiLanguage")
                } footer: {
                    Text("settings.uiLanguage.footer")
                        .font(.caption)
                }
                .onChange(of: localizationManager.currentLanguage) { _, _ in
                    showingRestartAlert = localizationManager.needsRestart
                }

                Section {
                    HStack {
                        Picker(String(localized: "settings.storyLength"), selection: $settings.defaultStoryLength) {
                            Text("settings.storyLength.5").tag(5)
                            Text("settings.storyLength.7").tag(7)
                            Text("settings.storyLength.10").tag(10)
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Picker(String(localized: "settings.voice"), selection: $settings.preferredVoice) {
                                ForEach(AppSettings.availableVoices, id: \.id) { voice in
                                    Text(voice.name).tag(voice.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        if let selectedVoice = AppSettings.availableVoices.first(where: { $0.id == settings.preferredVoice }) {
                            Text(selectedVoice.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Picker(String(localized: "settings.language"), selection: $settings.preferredLanguage) {
                                ForEach(AppSettings.releasedLanguages, id: \.id) { language in
                                    HStack {
                                        Text(language.name)
                                        Text(language.nativeName)
                                            .foregroundColor(.secondary)
                                    }
                                    .tag(language.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Text("settings.storyLanguage.footer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("settings.storyPreferences")
                } footer: {
                    Text("settings.storyPreferences.footer")
                        .font(.caption)
                }

                if AppConfiguration.enableStoryIllustrations {
                    Section {
                        Toggle(String(localized: "settings.autoGenerateIllustrations"), isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "autoGenerateIllustrations") },
                            set: { UserDefaults.standard.set($0, forKey: "autoGenerateIllustrations") }
                        ))

                        Toggle(String(localized: "settings.continueOnFailures"), isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "allowIllustrationFailures") },
                            set: { UserDefaults.standard.set($0, forKey: "allowIllustrationFailures") }
                        ))

                        Toggle(String(localized: "settings.showErrorDetails"), isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "showIllustrationErrors") },
                            set: { UserDefaults.standard.set($0, forKey: "showIllustrationErrors") }
                        ))

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("settings.maxRetryAttempts")
                                Spacer()
                                Picker(String(localized: "settings.maxRetryAttempts"), selection: Binding(
                                    get: {
                                        let value = UserDefaults.standard.integer(forKey: "maxIllustrationRetries")
                                        return value > 0 ? value : 3
                                    },
                                    set: { UserDefaults.standard.set($0, forKey: "maxIllustrationRetries") }
                                )) {
                                    Text("1").tag(1)
                                    Text("2").tag(2)
                                    Text("3").tag(3)
                                    Text("5").tag(5)
                                }
                                .pickerStyle(.menu)
                            }

                            Text("settings.maxRetryAttempts.footer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("settings.maxIllustrationsPerStory")
                            Spacer()
                            Picker(String(localized: "settings.maxIllustrationsPerStory"), selection: Binding(
                                get: {
                                    let value = UserDefaults.standard.integer(forKey: "maxIllustrationsPerStory")
                                    return value > 0 ? value : 6
                                },
                                set: { UserDefaults.standard.set($0, forKey: "maxIllustrationsPerStory") }
                            )) {
                                Text("5").tag(5)
                                Text("6").tag(6)
                                Text("7").tag(7)
                                Text("8").tag(8)
                            }
                            .pickerStyle(.menu)
                        }
                    } header: {
                        Text("settings.illustrations")
                    } footer: {
                        Text("settings.illustrations.footer")
                            .font(.caption)
                    }
                }

                #if DEBUG
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Auth Status: \(authState.isAuthenticated ? "✓ Signed In" : "✗ Not Signed In")")
                            .font(.caption)
                            .foregroundColor(authState.isAuthenticated ? .green : .orange)

                        if let userId = authState.userId {
                            Text("User ID: \(userId)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button(action: {
                        print("Debug sign-in not implemented - use auth flow instead")
                    }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                            Text("Sign In as Test User")
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(authState.isAuthenticated)

                    Button(action: {
                        print("Debug sign-up not implemented - use auth flow instead")
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus.fill")
                            Text("Create Random Test User")
                        }
                        .foregroundColor(.purple)
                    }

                    if authState.isAuthenticated {
                        Button(action: {
                            authState.signOut()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text("Debug Controls")
                } footer: {
                    Text("Debug-only controls for testing authentication. Test user: \(debugTestUserEmail)")
                        .font(.caption)
                }
                #endif

                Section {
                    Button(action: { showingEraseConfirmation = true }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("settings.eraseAllData")
                        }
                        .foregroundColor(.red)
                    }

                    Button(action: { showingDeleteAccountConfirmation = true }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.minus")
                            Text("settings.deleteAccount")
                            if isDeletingAccount {
                                Spacer()
                                ProgressView()
                            }
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(isDeletingAccount)
                } header: {
                    Text("settings.advanced")
                } footer: {
                    Text("settings.eraseAllData.footer")
                        .font(.caption)
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("settings.about.title")
                            .font(.headline)

                        Text("settings.about.description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("settings.version")
                            Spacer()
                            Text("1.0.1")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    Link(destination: URL(string: "https://www.infinitestories.app/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("settings.privacyPolicy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "settings.privacyPolicy"))

                    Link(destination: URL(string: "https://www.infinitestories.app/terms")!) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("settings.termsOfService")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "settings.termsOfService"))
                } header: {
                    Text("settings.appInfo")
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .glassNavigation()
            .confirmationDialog("settings.eraseAllData.confirm.title", isPresented: $showingEraseConfirmation, titleVisibility: .visible) {
                Button("settings.eraseAllData.confirm.button", role: .destructive) {
                    settingsEraseAllData()
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text("settings.eraseAllData.confirm.message")
            }
            .alert("settings.deleteAccount.confirm.title", isPresented: $showingDeleteAccountConfirmation) {
                Button("settings.deleteAccount.confirm.button", role: .destructive) {
                    showingDeleteAccountFinalConfirmation = true
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text("settings.deleteAccount.confirm.message")
            }
            .alert("settings.deleteAccount.final.title", isPresented: $showingDeleteAccountFinalConfirmation) {
                Button("settings.deleteAccount.final.button", role: .destructive) {
                    performAccountDeletion()
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text("settings.deleteAccount.final.message")
            }
            .alert("settings.deleteAccount.error.title", isPresented: $showingDeleteAccountError) {
                Button("common.retry") {
                    performAccountDeletion()
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text("settings.deleteAccount.error.message")
            }
            .alert("settings.restartRequired.title", isPresented: $showingRestartAlert) {
                Button("common.ok") {
                    localizationManager.acknowledgeRestartNeeded()
                }
            } message: {
                Text("settings.restartRequired.message")
            }
        }
    }

    private func performAccountDeletion() {
        isDeletingAccount = true
        Task {
            do {
                try await APIClient.shared.requestVoid(.deleteAccount)
                settingsEraseAllData()
            } catch {
                isDeletingAccount = false
                showingDeleteAccountError = true
            }
        }
    }

    private func settingsEraseAllData() {
        do {
            // 1. Delete local SwiftData models (only StoryIllustration remains in SwiftData)
            // Note: Hero, Story, and CustomStoryEvent are API-only - data is managed on the server
            try modelContext.delete(model: StoryIllustration.self)

            // Save the deletion
            try modelContext.save()

            // 2. Delete all file directories
            let fileManager = FileManager.default
            if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                // Delete AudioStories directory
                let audioPath = documentsPath.appendingPathComponent("AudioStories")
                if fileManager.fileExists(atPath: audioPath.path) {
                    try? fileManager.removeItem(at: audioPath)
                }

                // Delete Avatars directory
                let avatarsPath = documentsPath.appendingPathComponent("Avatars")
                if fileManager.fileExists(atPath: avatarsPath.path) {
                    try? fileManager.removeItem(at: avatarsPath)
                }

                // Delete StoryIllustrations directory
                let illustrationsPath = documentsPath.appendingPathComponent("StoryIllustrations")
                if fileManager.fileExists(atPath: illustrationsPath.path) {
                    try? fileManager.removeItem(at: illustrationsPath)
                }

                // Clean up any loose MP3 files in root documents
                let contents = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                for file in contents {
                    if file.pathExtension == "mp3" {
                        try? fileManager.removeItem(at: file)
                    }
                }
            }

            // 3. Clear all Keychain data (auth tokens, session data)
            let keychainHelper = KeychainHelper()
            keychainHelper.clearAll()

            // 4. Reset UserDefaults to default values
            UserDefaults.standard.removeObject(forKey: "autoGenerateIllustrations")
            UserDefaults.standard.removeObject(forKey: "allowIllustrationFailures")
            UserDefaults.standard.removeObject(forKey: "showIllustrationErrors")
            UserDefaults.standard.removeObject(forKey: "maxIllustrationRetries")
            UserDefaults.standard.removeObject(forKey: "maxIllustrationsPerStory")

            // 5. Reset theme to system default
            themeSettings.themePreferenceString = "system"

            // 6. Sign out user
            authState.signOut()

        } catch {
            print("Failed to erase all data: \(error)")
        }
    }

    private func settingsThemeIcon(for theme: String) -> String {
        switch theme {
        case "system":
            return "circle.lefthalf.filled"
        case "light":
            return "sun.max.fill"
        case "dark":
            return "moon.fill"
        default:
            return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Main Settings View (Legacy - for sheet presentation)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var settings = AppSettings()
    @EnvironmentObject private var themeSettings: ThemeSettings
    @EnvironmentObject private var authState: AuthStateManager

    @State private var showingEraseConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingDeleteAccountFinalConfirmation = false
    @State private var showingDeleteAccountError = false
    @State private var isDeletingAccount = false
    @State private var showingAuthView = false
    @State private var debugTestUserEmail = "test@example.com"
    @State private var debugTestUserPassword = "password123"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "gear.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title2)

                        VStack(alignment: .leading) {
                            Text("settings.header.title")
                                .font(.headline)
                            Text("settings.header.subtitle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Theme Settings Section
                Section {
                    HStack {
                        Label("settings.appearance", systemImage: "moon.circle.fill")
                            .foregroundColor(.purple)

                        Spacer()

                        Picker("", selection: $themeSettings.themePreferenceString) {
                            ForEach(["system", "light", "dark"], id: \.self) { theme in
                                HStack {
                                    Image(systemName: themeIcon(for: theme))
                                    Text(LocalizedStringKey("settings.theme.\(theme)"))
                                }
                                .tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.purple)
                    }

                    // Visual indicator showing current theme
                    HStack {
                        Text("settings.currentMode")
                        Spacer()
                        Text(colorScheme == .dark ? String(localized: "settings.theme.dark") : String(localized: "settings.theme.light"))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("settings.theme")
                } footer: {
                    Text("settings.theme.footer")
                        .font(.caption)
                }
                    Section {
                        HStack {
                            Picker(String(localized: "settings.storyLength"), selection: $settings.defaultStoryLength) {
                                Text("settings.storyLength.5").tag(5)
                                Text("settings.storyLength.7").tag(7)
                                Text("settings.storyLength.10").tag(10)
                            }
                            .pickerStyle(.menu)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Picker(String(localized: "settings.voice"), selection: $settings.preferredVoice) {
                                    ForEach(AppSettings.availableVoices, id: \.id) { voice in
                                        Text(voice.name).tag(voice.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            if let selectedVoice = AppSettings.availableVoices.first(where: { $0.id == settings.preferredVoice }) {
                                Text(selectedVoice.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Picker(String(localized: "settings.language"), selection: $settings.preferredLanguage) {
                                    ForEach(AppSettings.releasedLanguages, id: \.id) { language in
                                        HStack {
                                            Text(language.name)
                                            Text(language.nativeName)
                                                .foregroundColor(.secondary)
                                        }
                                        .tag(language.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            Text("settings.storyLanguage.footer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("settings.storyPreferences")
                    } footer: {
                        Text("settings.storyPreferences.footer")
                            .font(.caption)
                    }

                    Section {
                        Toggle(String(localized: "settings.autoGenerateIllustrations"), isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "autoGenerateIllustrations") },
                            set: { UserDefaults.standard.set($0, forKey: "autoGenerateIllustrations") }
                        ))

                        Toggle(String(localized: "settings.continueOnFailures"), isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "allowIllustrationFailures") },
                            set: { UserDefaults.standard.set($0, forKey: "allowIllustrationFailures") }
                        ))

                        Toggle(String(localized: "settings.showErrorDetails"), isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "showIllustrationErrors") },
                            set: { UserDefaults.standard.set($0, forKey: "showIllustrationErrors") }
                        ))

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("settings.maxRetryAttempts")
                                Spacer()
                                Picker(String(localized: "settings.maxRetryAttempts"), selection: Binding(
                                    get: {
                                        let value = UserDefaults.standard.integer(forKey: "maxIllustrationRetries")
                                        return value > 0 ? value : 3
                                    },
                                    set: { UserDefaults.standard.set($0, forKey: "maxIllustrationRetries") }
                                )) {
                                    Text("1").tag(1)
                                    Text("2").tag(2)
                                    Text("3").tag(3)
                                    Text("5").tag(5)
                                }
                                .pickerStyle(.menu)
                            }

                            Text("settings.maxRetryAttempts.footer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("settings.maxIllustrationsPerStory")
                            Spacer()
                            Picker(String(localized: "settings.maxIllustrationsPerStory"), selection: Binding(
                                get: {
                                    let value = UserDefaults.standard.integer(forKey: "maxIllustrationsPerStory")
                                    return value > 0 ? value : 6
                                },
                                set: { UserDefaults.standard.set($0, forKey: "maxIllustrationsPerStory") }
                            )) {
                                Text("5").tag(5)
                                Text("6").tag(6)
                                Text("7").tag(7)
                                Text("8").tag(8)
                            }
                            .pickerStyle(.menu)
                        }
                    } header: {
                        Text("settings.illustrations")
                    } footer: {
                        Text("settings.illustrations.footer")
                            .font(.caption)
                    }

                #if DEBUG
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Auth Status: \(authState.isAuthenticated ? "✓ Signed In" : "✗ Not Signed In")")
                            .font(.caption)
                            .foregroundColor(authState.isAuthenticated ? .green : .orange)

                        if let userId = authState.userId {
                            Text("User ID: \(userId)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button(action: {
                        // Debug sign-in would need to call backend API endpoint first
                        // Then call authState.signIn(token:userId:) with the response
                        print("Debug sign-in not implemented - use auth flow instead")
                    }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                            Text("Sign In as Test User")
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(authState.isAuthenticated)

                    Button(action: {
                        // Debug sign-up would need to call backend API endpoint first
                        // Then call authState.signIn(token:userId:) with the response
                        print("Debug sign-up not implemented - use auth flow instead")
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus.fill")
                            Text("Create Random Test User")
                        }
                        .foregroundColor(.purple)
                    }

                    if authState.isAuthenticated {
                        Button(action: {
                            authState.signOut()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text("Debug Controls")
                } footer: {
                    Text("Debug-only controls for testing authentication. Test user: \(debugTestUserEmail)")
                        .font(.caption)
                }
                #endif

                Section {
                    Button(action: { showingEraseConfirmation = true }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("settings.eraseAllData")
                        }
                        .foregroundColor(.red)
                    }

                    Button(action: { showingDeleteAccountConfirmation = true }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.minus")
                            Text("settings.deleteAccount")
                            if isDeletingAccount {
                                Spacer()
                                ProgressView()
                            }
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(isDeletingAccount)
                } header: {
                    Text("settings.advanced")
                } footer: {
                    Text("settings.eraseAllData.footer")
                        .font(.caption)
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("settings.about.title")
                            .font(.headline)

                        Text("settings.about.description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("settings.version")
                            Spacer()
                            Text("1.0.1")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    Link(destination: URL(string: "https://www.infinitestories.app/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("settings.privacyPolicy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "settings.privacyPolicy"))

                    Link(destination: URL(string: "https://www.infinitestories.app/terms")!) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("settings.termsOfService")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "settings.termsOfService"))
                } header: {
                    Text("settings.appInfo")
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .glassNavigation()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("settings.eraseAllData.confirm.title", isPresented: $showingEraseConfirmation, titleVisibility: .visible) {
                Button("settings.eraseAllData.confirm.button", role: .destructive) {
                    eraseAllData()
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text("settings.eraseAllData.confirm.message")
            }
            .alert("settings.deleteAccount.confirm.title", isPresented: $showingDeleteAccountConfirmation) {
                Button("settings.deleteAccount.confirm.button", role: .destructive) {
                    showingDeleteAccountFinalConfirmation = true
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text("settings.deleteAccount.confirm.message")
            }
            .alert("settings.deleteAccount.final.title", isPresented: $showingDeleteAccountFinalConfirmation) {
                Button("settings.deleteAccount.final.button", role: .destructive) {
                    performAccountDeletion()
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text("settings.deleteAccount.final.message")
            }
            .alert("settings.deleteAccount.error.title", isPresented: $showingDeleteAccountError) {
                Button("common.retry") {
                    performAccountDeletion()
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text("settings.deleteAccount.error.message")
            }
        }
    }

    private func performAccountDeletion() {
        isDeletingAccount = true
        Task {
            do {
                try await APIClient.shared.requestVoid(.deleteAccount)
                eraseAllData()
            } catch {
                isDeletingAccount = false
                showingDeleteAccountError = true
            }
        }
    }

    private func eraseAllData() {
        do {
            // 1. Delete local SwiftData models (only StoryIllustration remains in SwiftData)
            // Note: Hero, Story, and CustomStoryEvent are API-only - data is managed on the server
            try modelContext.delete(model: StoryIllustration.self)

            // Save the deletion
            try modelContext.save()

            // 2. Delete all file directories
            let fileManager = FileManager.default
            if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                // Delete AudioStories directory
                let audioPath = documentsPath.appendingPathComponent("AudioStories")
                if fileManager.fileExists(atPath: audioPath.path) {
                    try? fileManager.removeItem(at: audioPath)
                }

                // Delete Avatars directory
                let avatarsPath = documentsPath.appendingPathComponent("Avatars")
                if fileManager.fileExists(atPath: avatarsPath.path) {
                    try? fileManager.removeItem(at: avatarsPath)
                }

                // Delete StoryIllustrations directory
                let illustrationsPath = documentsPath.appendingPathComponent("StoryIllustrations")
                if fileManager.fileExists(atPath: illustrationsPath.path) {
                    try? fileManager.removeItem(at: illustrationsPath)
                }

                // Clean up any loose MP3 files in root documents
                let contents = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                for file in contents {
                    if file.pathExtension == "mp3" {
                        try? fileManager.removeItem(at: file)
                    }
                }
            }

            // 3. Clear all Keychain data (auth tokens, session data)
            let keychainHelper = KeychainHelper()
            keychainHelper.clearAll()

            // 4. Reset UserDefaults to default values
            UserDefaults.standard.removeObject(forKey: "autoGenerateIllustrations")
            UserDefaults.standard.removeObject(forKey: "allowIllustrationFailures")
            UserDefaults.standard.removeObject(forKey: "showIllustrationErrors")
            UserDefaults.standard.removeObject(forKey: "maxIllustrationRetries")
            UserDefaults.standard.removeObject(forKey: "maxIllustrationsPerStory")

            // 5. Reset theme to system default
            themeSettings.themePreferenceString = "system"

            // 6. Sign out user
            authState.signOut()

            // 7. Dismiss settings and show auth view
            dismiss()

            // Small delay to allow settings to dismiss before showing auth
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingAuthView = true
            }

        } catch {
            print("Failed to erase all data: \(error)")
        }
    }
    
    private func themeIcon(for theme: String) -> String {
        switch theme {
        case "system":
            return "circle.lefthalf.filled"
        case "light":
            return "sun.max.fill"
        case "dark":
            return "moon.fill"
        default:
            return "circle.lefthalf.filled"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeSettings.shared)
}
