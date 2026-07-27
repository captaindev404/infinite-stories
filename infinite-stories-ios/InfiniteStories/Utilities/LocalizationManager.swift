//
//  LocalizationManager.swift
//  InfiniteStories
//
//  Manages UI language override independent of device language.
//  Allows users to match UI language with story language preference.
//

import Foundation
import SwiftUI

/// Manages language override for UI localization
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    /// UserDefaults key for language override
    private static let languageOverrideKey = "uiLanguageOverride"

    /// Available UI languages matching story languages
    enum UILanguage: String, CaseIterable, Identifiable {
        case system = "system"
        case english = "en"
        case french = "fr"

        var id: String { rawValue }

        /// Display name for the language picker (shown in the language itself)
        var displayName: String {
            switch self {
            case .system: return String(localized: "settings.language.systemDefault")
            case .english: return "English"
            case .french: return "Français"
            }
        }

        /// Native name for accessibility
        var nativeName: String {
            switch self {
            case .system: return "System"
            case .english: return "English"
            case .french: return "Français"
            }
        }
    }

    // MARK: - Released UI Languages (v1.0)

    /// UI languages enabled for the current release.
    static let releasedUILanguages: [UILanguage] = [.system, .english, .french]

    /// Current language override setting
    @Published var currentLanguage: UILanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.languageOverrideKey)
            applyLanguageOverride()
        }
    }

    /// Whether a restart is needed after language change
    @Published var needsRestart: Bool = false

    private init() {
        let savedValue = UserDefaults.standard.string(forKey: Self.languageOverrideKey) ?? UILanguage.system.rawValue
        let loadedLanguage = UILanguage(rawValue: savedValue) ?? .system

        // Migrate users with non-released UI language preferences (e.g., Spanish, German, Italian)
        // to System. This handles existing users who had selected languages that are
        // now hidden in v1.0. Translations are preserved for future releases.
        if !Self.releasedUILanguages.contains(loadedLanguage) {
            self.currentLanguage = .system
            UserDefaults.standard.set(UILanguage.system.rawValue, forKey: Self.languageOverrideKey)
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        } else {
            self.currentLanguage = loadedLanguage
        }
    }

    /// Apply language override at app launch
    /// Call this from InfiniteStoriesApp.init() before views load
    func applyLanguageOverrideAtLaunch() {
        guard currentLanguage != .system else { return }

        // Override Apple languages for the entire app
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    /// Apply language change (requires app restart to take effect)
    private func applyLanguageOverride() {
        if currentLanguage == .system {
            // Remove override to use system language
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()

        // Mark that restart is needed for changes to take effect
        needsRestart = true
    }

    /// Reset restart flag (call after showing restart prompt)
    func acknowledgeRestartNeeded() {
        needsRestart = false
    }
}

// MARK: - SwiftUI Environment Support

private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}
