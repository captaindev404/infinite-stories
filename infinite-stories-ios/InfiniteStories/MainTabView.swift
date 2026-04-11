//
//  MainTabView.swift
//  InfiniteStories
//
//  Root TabView container with 5 tabs leveraging iOS 26 Liquid Glass tab bars.
//

import SwiftUI

/// Tab identifiers for the app's main navigation
enum AppTab: Int, CaseIterable, Identifiable {
    case home = 0
    case library = 1
    case heroes = 2
    case journey = 3
    case settings = 4

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: return "tabs.home"
        case .heroes: return "tabs.heroes"
        case .library: return "tabs.library"
        case .journey: return "tabs.journey"
        case .settings: return "tabs.settings"
        }
    }

    /// String version for accessibility labels
    var titleString: String {
        switch self {
        case .home: return String(localized: "tabs.home")
        case .heroes: return String(localized: "tabs.heroes")
        case .library: return String(localized: "tabs.library")
        case .journey: return String(localized: "tabs.journey")
        case .settings: return String(localized: "tabs.settings")
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .heroes: return "person.2.fill"
        case .library: return "books.vertical.fill"
        case .journey: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @Namespace private var tabNamespace
    @EnvironmentObject private var themeSettings: ThemeSettings
    @EnvironmentObject private var authState: AuthStateManager

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeTabView()
                .tabItem {
                    Label(AppTab.home.title, systemImage: AppTab.home.icon)
                        .accessibilityLabel("\(AppTab.home.titleString) tab")
                }
                .tag(AppTab.home)

            // Library Tab
            LibraryTabView()
                .tabItem {
                    Label(AppTab.library.title, systemImage: AppTab.library.icon)
                        .accessibilityLabel("\(AppTab.library.titleString) tab")
                }
                .tag(AppTab.library)

            // Heroes Tab
            HeroesTabView()
                .tabItem {
                    Label(AppTab.heroes.title, systemImage: AppTab.heroes.icon)
                        .accessibilityLabel("\(AppTab.heroes.titleString) tab")
                }
                .tag(AppTab.heroes)

            // Journey Tab
            JourneyTabView()
                .tabItem {
                    Label(AppTab.journey.title, systemImage: AppTab.journey.icon)
                        .accessibilityLabel("\(AppTab.journey.titleString) tab")
                }
                .tag(AppTab.journey)

            // Settings Tab
            SettingsTabView()
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
                        .accessibilityLabel("\(AppTab.settings.titleString) tab")
                }
                .tag(AppTab.settings)
        }
        .glassTabBar()
        .glassTabMorphing(namespace: tabNamespace, selectedTab: selectedTab)
        .tint(.accentColor)
        .onAppear {
            // BUG-28: after a session-expired → "Se reconnecter" roundtrip we
            // want the user to land back on the tab they came from.
            if let restore = authState.pendingRestoreTab {
                selectedTab = restore
                authState.pendingRestoreTab = nil
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            // Track the last user-selected tab so we can restore it after a
            // forced sign-out (BUG-28).
            authState.pendingRestoreTab = newValue
        }
    }
}

// MARK: - Home Tab View

/// Wrapper for the Home tab content with its own NavigationStack
struct HomeTabView: View {
    var body: some View {
        NavigationStack {
            HomeContentView()
        }
    }
}

// MARK: - Heroes Tab View

/// Wrapper for the Heroes tab content with its own NavigationStack
struct HeroesTabView: View {
    var body: some View {
        NavigationStack {
            HeroListView()
                .glassNavigation()
        }
    }
}

// MARK: - Library Tab View

/// Wrapper for the Library tab content with its own NavigationStack
struct LibraryTabView: View {
    var body: some View {
        NavigationStack {
            ImprovedStoryLibraryView()
                .glassNavigation()
        }
    }
}

// MARK: - Journey Tab View

/// Wrapper for the Journey tab content with its own NavigationStack
struct JourneyTabView: View {
    var body: some View {
        ReadingJourneyTabContent()
    }
}

// MARK: - Settings Tab View

/// Wrapper for the Settings tab content with its own NavigationStack
struct SettingsTabView: View {
    @EnvironmentObject private var themeSettings: ThemeSettings
    @EnvironmentObject private var authState: AuthStateManager

    var body: some View {
        SettingsTabContent()
            .environmentObject(themeSettings)
            .environmentObject(authState)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(ThemeSettings.shared)
        .environmentObject(AuthStateManager())
}
