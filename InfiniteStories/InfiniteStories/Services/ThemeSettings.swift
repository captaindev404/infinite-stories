//
//  ThemeSettings.swift
//  InfiniteStories
//
//  Theme settings manager for dark mode support
//

import SwiftUI
import Combine

class ThemeSettings: ObservableObject {
    static let shared = ThemeSettings()
    
    init() {}
    
    // MARK: - Theme Settings
    @AppStorage("themePreference") var themePreferenceString: String = AppConfiguration.defaultThemePreference {
        didSet {
            objectWillChange.send()
        }
    }
    
    var themePreference: ThemePreference {
        get {
            switch themePreferenceString {
            case "light":
                return .light
            case "dark":
                return .dark
            default:
                return .system
            }
        }
        set {
            themePreferenceString = newValue.rawValue
        }
    }
    
    // Theme Preference Enum
    enum ThemePreference: String, CaseIterable {
        case system = "system"
        case light = "light"
        case dark = "dark"
        
        var colorScheme: ColorScheme? {
            switch self {
            case .system:
                return nil
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }
        
        var icon: String {
            switch self {
            case .system:
                return "circle.lefthalf.filled"
            case .light:
                return "sun.max.fill"
            case .dark:
                return "moon.fill"
            }
        }
    }
}