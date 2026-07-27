//
//  AppSettings.swift
//  InfiniteStories
//
//  Created by Captain Dev on 22/12/2025.
//
//  Extracted from StoryViewModel as part of ViewModel architecture refactoring.
//  User preferences for AI service configuration (voice, language, story length).
//

import Foundation
import SwiftUI

/// User preferences for AI story generation
@Observable
final class AppSettings {

    // MARK: - Stored Properties

    /// Preferred voice for TTS audio generation
    var preferredVoice: String {
        didSet {
            UserDefaults.standard.set(preferredVoice, forKey: "preferredVoice")
        }
    }

    /// Default story length (in approximate minutes)
    var defaultStoryLength: Int {
        didSet {
            UserDefaults.standard.set(defaultStoryLength, forKey: "defaultStoryLength")
        }
    }

    /// Preferred language for story generation
    var preferredLanguage: String {
        didSet {
            UserDefaults.standard.set(preferredLanguage, forKey: "preferredLanguage")
        }
    }

    // MARK: - Initialization

    init() {
        // Load settings from UserDefaults
        self.preferredVoice = UserDefaults.standard.string(forKey: "preferredVoice") ?? "coral"
        self.defaultStoryLength = UserDefaults.standard.integer(forKey: "defaultStoryLength") == 0 ? 7 : UserDefaults.standard.integer(forKey: "defaultStoryLength")

        // Load language setting with system language as default
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let defaultLanguage = Self.languageCodeToSupported(systemLanguage)
        let storedLanguage = UserDefaults.standard.string(forKey: "preferredLanguage")

        // Migrate users with non-released language preferences (e.g., Spanish, German, Italian)
        // to English. This handles existing users who had selected languages that are
        // now hidden in v1.0. Translations are preserved for future releases.
        if let stored = storedLanguage, !Self.releasedLanguageNames.contains(stored) {
            self.preferredLanguage = "English"
            UserDefaults.standard.set("English", forKey: "preferredLanguage")
        } else {
            self.preferredLanguage = storedLanguage ?? defaultLanguage
        }
    }

    // MARK: - Static Voice Definitions

    /// Available OpenAI voices for TTS (optimized for children's bedtime stories)
    static let availableVoices: [(id: String, name: String, description: String)] = [
        ("coral", "Coral", "Warm and nurturing - ideal for bedtime"),
        ("nova", "Nova", "Friendly and cheerful - captivating for young listeners"),
        ("fable", "Fable", "Wise and comforting - like a loving grandparent"),
        ("alloy", "Alloy", "Clear and pleasant - perfect for educational stories"),
        ("echo", "Echo", "Soft and dreamy - creates magical atmosphere"),
        ("onyx", "Onyx", "Deep and reassuring - protective parent voice"),
        ("shimmer", "Shimmer", "Bright and melodic - sparkles with imagination")
    ]

    // MARK: - Static Language Definitions

    /// Available languages for story generation.
    /// The app ships English and French only — the bundle carries no other
    /// localizations, so nothing else may be offered here.
    static let availableLanguages: [(id: String, name: String, nativeName: String)] = [
        ("English", "English", "English"),
        ("French", "French", "Francais")
    ]

    // MARK: - Released Languages (v1.0)

    /// Language codes enabled for the current release.
    static let releasedLanguageCodes: Set<String> = ["en", "fr"]

    /// Language names enabled for the current release.
    static let releasedLanguageNames: Set<String> = ["English", "French"]

    /// Filtered list of languages available for the current release.
    static var releasedLanguages: [(id: String, name: String, nativeName: String)] {
        availableLanguages.filter { releasedLanguageNames.contains($0.name) }
    }

    // MARK: - Helper Methods

    /// Map system language code to a released language. Anything the app does
    /// not ship a localization for falls back to English.
    static func languageCodeToSupported(_ code: String) -> String {
        switch code {
        case "fr": return "French"
        default: return "English"
        }
    }

    /// Get the display name for the current voice
    var currentVoiceName: String {
        Self.availableVoices.first { $0.id == preferredVoice }?.name ?? preferredVoice
    }

    /// Get the display name for the current language
    var currentLanguageName: String {
        Self.availableLanguages.first { $0.id == preferredLanguage }?.name ?? preferredLanguage
    }

    /// BUG-15: Localized description for a given voice id. Used instead of
    /// the English `description` field stored in `availableVoices` so French
    /// users don't see "Warm and nurturing - ideal for bedtime" in a FR UI.
    static func localizedVoiceDescription(for voiceId: String) -> String {
        switch voiceId {
        case "coral":   return String(localized: "settings.voice.coral.description")
        case "nova":    return String(localized: "settings.voice.nova.description")
        case "fable":   return String(localized: "settings.voice.fable.description")
        case "alloy":   return String(localized: "settings.voice.alloy.description")
        case "echo":    return String(localized: "settings.voice.echo.description")
        case "onyx":    return String(localized: "settings.voice.onyx.description")
        case "shimmer": return String(localized: "settings.voice.shimmer.description")
        default:
            return availableVoices.first { $0.id == voiceId }?.description ?? ""
        }
    }

    /// BUG-15: Localized display name for a story-generation language. The
    /// stored preference (`English`, `French`, ...) is kept as the stable
    /// backend key, but the picker renders this localized variant so French
    /// users see "Anglais"/"Français" rather than the English names.
    static func localizedLanguageName(for languageId: String) -> String {
        switch languageId {
        case "English": return String(localized: "settings.language.english")
        case "French":  return String(localized: "settings.language.french")
        default:
            return availableLanguages.first { $0.id == languageId }?.name ?? languageId
        }
    }

    /// Reset all settings to defaults
    func resetToDefaults() {
        preferredVoice = "coral"
        defaultStoryLength = 7
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        preferredLanguage = Self.languageCodeToSupported(systemLanguage)
    }
}
