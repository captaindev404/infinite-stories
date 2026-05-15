//
//  ImprovedContentView.swift
//  InfiniteStories
//
//  Production-ready home screen with native iOS design
//

import SwiftUI
import SwiftData

// MARK: - Home Content View (for Tab Bar navigation)
/// This view is used within the Home tab and removes redundant navigation elements
/// that are now handled by the tab bar (Settings, Journey).
struct HomeContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeSettings: ThemeSettings

    // API-only state management
    @State private var heroes: [Hero] = []
    @State private var stories: [Story] = []
    @State private var isLoading = false
    @State private var loadError: Error?

    // Repositories
    private let heroRepository = HeroRepository()
    private let storyRepository = StoryRepository()

    @State private var showingHeroCreation = false
    @State private var showingStoryGeneration = false
    @State private var selectedStory: Story?
    @State private var selectedHeroForStory: Hero?
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingCustomEventManagement = false

    // Computed properties for stats
    private var currentStreak: Int {
        calculateReadingStreak()
    }

    private var recentStories: [Story] {
        let sorted = stories.sorted(by: { $0.createdAt > $1.createdAt })
        return Array(sorted.prefix(6))
    }

    var body: some View {
        ZStack {
            // System Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Loading/Error/Content states
            if isLoading && heroes.isEmpty {
                ProgressView(String(localized: "home.loading"))
                    .scaleEffect(1.2)
            } else if let error = loadError {
                ErrorView(error: error, retryAction: {
                    Task { await loadData() }
                })
            } else {
                homeMainContent
            }
        }
        .navigationTitle(String(localized: "app.brand.name"))
        .navigationBarTitleDisplayMode(.large)
        .glassNavigation()
        .task {
            await loadData()
        }
    }

    private var homeMainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Section
                HeroSectionView(
                    heroes: heroes,
                    showingHeroCreation: $showingHeroCreation,
                    selectedHeroForStory: $selectedHeroForStory,
                    showingStoryGeneration: $showingStoryGeneration
                )

                // Recent Stories Section
                homeRecentStoriesSection

                // Empty State
                if heroes.isEmpty {
                    EmptyStateView(showingHeroCreation: $showingHeroCreation)
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .refreshable {
            await loadData()
        }
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom) {
                FloatingCustomEventButton(
                    showingCustomEventManagement: $showingCustomEventManagement
                )
                Spacer()
                FloatingCreateStoryButton(
                    hasHeroes: !heroes.isEmpty,
                    showingStoryGeneration: $showingStoryGeneration,
                    showingHeroCreation: $showingHeroCreation
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showingHeroCreation, onDismiss: {
            Task {
                await loadData()
            }
        }) {
            HeroCreationView(heroToEdit: nil)
                .glassSheet()
        }
        .sheet(isPresented: $showingStoryGeneration, onDismiss: {
            Task {
                await loadData()
            }
        }) {
            Group {
                if heroes.count > 1 {
                    HeroSelectionForStoryView(selectedHero: $selectedHeroForStory, showingStoryGeneration: $showingStoryGeneration)
                } else if let hero = selectedHeroForStory ?? heroes.first {
                    StoryGenerationView(hero: hero)
                }
            }
            .glassSheet()
        }
        .sheet(item: $selectedStory) { story in
            let storyIndex = stories.firstIndex(where: { $0.id == story.id }) ?? 0
            AudioPlayerView(
                story: story,
                allStories: stories,
                storyIndex: storyIndex
            )
            .onDisappear {
                handleStoryPlayed(story)
            }
            .glassSheet()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "An unexpected error occurred")
        }
        .sheet(isPresented: $showingCustomEventManagement) {
            CustomEventManagementView()
                .glassSheet()
        }
    }

    private var homeRecentStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Only show section if we have stories
            if !stories.isEmpty {
                // BUG-A24: Header + "Voir tout" affordance so users can
                // discover the full list in the Library tab.
                HStack(alignment: .firstTextBaseline) {
                    Text("home.recentAdventures")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        NotificationCenter.default.post(
                            name: .switchToTab,
                            object: AppTab.library.rawValue
                        )
                    } label: {
                        Text(String(localized: "home.recentAdventures.seeAll", defaultValue: "See all"))
                            .font(.subheadline.weight(.medium))
                    }
                    .accessibilityHint(String(
                        localized: "home.recentAdventures.seeAll.a11y",
                        defaultValue: "Switches to the Library tab"
                    ))
                }

                // Story Cards
                VStack(spacing: 12) {
                    ForEach(Array(stories.sorted(by: { $0.createdAt > $1.createdAt }).prefix(6)), id: \.id) { story in
                        StoryCard(
                            story: story,
                            onTap: { selectedStory = story },
                            variant: .compact
                        )
                    }
                }
            }
            // Empty state is handled in homeMainContent, not here
        }
        .padding(.top, 25)
    }


    private func calculateReadingStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()

        for _ in 0..<30 {
            let dayStories = stories.filter {
                calendar.isDate($0.createdAt, inSameDayAs: currentDate)
            }

            if !dayStories.isEmpty {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }

        return streak
    }

    @MainActor
    private func loadData() async {
        guard NetworkMonitor.shared.isConnected else {
            loadError = APIError.networkUnavailable
            return
        }
        isLoading = true
        loadError = nil

        do {
            let fetchedHeroes = try await heroRepository.fetchHeroes()
            heroes = fetchedHeroes

            let fetchedStories = try await storyRepository.fetchStories(
                heroId: nil,
                limit: 50,
                offset: 0,
                heroes: fetchedHeroes
            )

            stories = fetchedStories
            Logger.ui.success("Loaded \(heroes.count) heroes and \(stories.count) stories")
        } catch {
            loadError = error
            Logger.ui.error("Failed to load data: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func handleStoryPlayed(_ story: Story) {
        // Play count update would need backend API support
    }
}

// MARK: - Main Improved Content View (Legacy - kept for backwards compatibility)
struct ImprovedContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeSettings: ThemeSettings

    // API-only state management
    @State private var heroes: [Hero] = []
    @State private var stories: [Story] = []
    @State private var isLoading = false
    @State private var loadError: Error?

    // Repositories
    private let heroRepository = HeroRepository()
    private let storyRepository = StoryRepository()

    @State private var showingHeroCreation = false
    @State private var showingStoryGeneration = false
    @State private var showingSettings = false
    @State private var selectedStory: Story?
    @State private var selectedHeroForStory: Hero?
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingFullJourney = false
    @State private var showingCustomEventManagement = false

    // Computed properties for stats
    private var totalStoriesRead: Int {
        stories.reduce(0) { $0 + $1.playCount }
    }

    private var currentStreak: Int {
        calculateReadingStreak()
    }

    private var recentStories: [Story] {
        let sorted = stories.sorted(by: { $0.createdAt > $1.createdAt })
        return Array(sorted.prefix(6))
    }

    private var favoriteStories: [Story] {
        stories.filter { $0.isFavorite }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // System Background
                Color(.systemBackground)
                    .ignoresSafeArea()

                // Loading/Error/Content states
                if isLoading && heroes.isEmpty {
                    ProgressView(String(localized: "home.loading"))
                        .scaleEffect(1.2)
                } else if let error = loadError {
                    ErrorView(error: error, retryAction: {
                        Task { await loadData() }
                    })
                } else {
                    mainContent
                }
            }
            .navigationTitle(String(localized: "home.title"))
            .navigationBarTitleDisplayMode(.large)
            .glassNavigation()
            .task {
                await loadData()
            }
        }
    }

    private var recentStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Only show section if we have stories
            if !stories.isEmpty {
                // Header
                HStack {
                    Text("home.recentAdventures")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                // Story Cards
                VStack(spacing: 12) {
                    ForEach(Array(stories.sorted(by: { $0.createdAt > $1.createdAt }).prefix(6)), id: \.id) { story in
                        StoryCard(
                            story: story,
                            onTap: { selectedStory = story },
                            variant: .compact
                        )
                    }
                }
            }
            // Empty state is handled in mainContent, not here
        }
        .padding(.top, 25)
    }


    private var mainContent: some View {
        ZStack {
            // Main Content
            ScrollView {
                VStack(spacing: 20) {
                    // Hero Section
                    HeroSectionView(
                        heroes: heroes,
                        showingHeroCreation: $showingHeroCreation,
                        selectedHeroForStory: $selectedHeroForStory,
                        showingStoryGeneration: $showingStoryGeneration
                    )

                    // Recent Stories Section
                    recentStoriesSection

                    // Empty State
                    if heroes.isEmpty {
                        EmptyStateView(showingHeroCreation: $showingHeroCreation)
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .refreshable {
                await loadData()
            }

            // Floating Create Story Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingCreateStoryButton(
                        hasHeroes: !heroes.isEmpty,
                        showingStoryGeneration: $showingStoryGeneration,
                        showingHeroCreation: $showingHeroCreation
                    )
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
            }

            // Floating Custom Event Management Button
            VStack {
                Spacer()
                HStack {
                    FloatingCustomEventButton(
                        showingCustomEventManagement: $showingCustomEventManagement
                    )
                    .padding(.leading, 20)
                    .padding(.bottom, 30)
                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AppLogoView()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        if !stories.isEmpty {
                            Button(action: {
                                showingFullJourney = true
                            }) {
                                ReadingJourneyTopButton(
                                    totalStories: stories.count,
                                    streak: currentStreak
                                )
                            }
                            .accessibilityLabel(String(localized: "home.readingJourney.accessibility"))
                            .accessibilityHint(String(localized: "home.readingJourney.hint"))
                        }

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.primary)
                                .font(.system(size: 20))
                        }
                        .accessibilityLabel(String(localized: "home.settings.accessibility"))
                        .accessibilityHint(String(localized: "home.settings.hint"))
                    }
                }
            }
            .sheet(isPresented: $showingHeroCreation, onDismiss: {
                Task {
                    await loadData()
                }
            }) {
                HeroCreationView(heroToEdit: nil)
                    .glassSheet()
            }
            .sheet(isPresented: $showingStoryGeneration, onDismiss: {
                Task {
                    await loadData()
                }
            }) {
                Group {
                    if heroes.count > 1 {
                        HeroSelectionForStoryView(selectedHero: $selectedHeroForStory, showingStoryGeneration: $showingStoryGeneration)
                    } else if let hero = selectedHeroForStory ?? heroes.first {
                        StoryGenerationView(hero: hero)
                    }
                }
                .glassSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(themeSettings)
                    .glassSheet()
            }
            .sheet(item: $selectedStory) { story in
                let storyIndex = stories.firstIndex(where: { $0.id == story.id }) ?? 0
                AudioPlayerView(
                    story: story,
                    allStories: stories,
                    storyIndex: storyIndex
                )
                .onDisappear {
                    handleStoryPlayed(story)
                }
                .glassSheet()
            }
            .alert(String(localized: "home.error.title"), isPresented: $showingError) {
                Button(String(localized: "home.error.ok")) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? String(localized: "home.error.unexpected"))
            }
            .fullScreenCover(isPresented: $showingFullJourney) {
                ReadingJourneyView()
                    .glassSheet()
            }
            .sheet(isPresented: $showingCustomEventManagement) {
                CustomEventManagementView()
                    .glassSheet()
            }
    }

    private func calculateReadingStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()

        for _ in 0..<30 {
            let dayStories = stories.filter {
                calendar.isDate($0.createdAt, inSameDayAs: currentDate)
            }

            if !dayStories.isEmpty {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }

        return streak
    }

    @MainActor
    private func loadData() async {
        guard NetworkMonitor.shared.isConnected else {
            loadError = APIError.networkUnavailable
            return
        }
        isLoading = true
        loadError = nil

        do {
            let fetchedHeroes = try await heroRepository.fetchHeroes()
            heroes = fetchedHeroes

            let fetchedStories = try await storyRepository.fetchStories(
                heroId: nil,
                limit: 50,
                offset: 0,
                heroes: fetchedHeroes
            )

            stories = fetchedStories
            Logger.ui.success("Loaded \(heroes.count) heroes and \(stories.count) stories")
        } catch {
            loadError = error
            Logger.ui.error("Failed to load data: \(error.localizedDescription)")
        }

        isLoading = false
    }

    @MainActor
    private func refreshData() async {
        isRefreshing = true
        await loadData()
        isRefreshing = false
    }

    private func handleStoryPlayed(_ story: Story) {
        // Play count update would need backend API support
    }

    private func toggleFavorite(_ story: Story) {
        Task {
            do {
                guard let backendId = story.backendId else {
                    Logger.ui.error("Story has no backend ID")
                    return
                }
                let newFavoriteState = !story.isFavorite
                _ = try await storyRepository.updateStory(id: backendId, title: nil, content: nil, isFavorite: newFavoriteState)

                if let index = stories.firstIndex(where: { $0.id == story.id }) {
                    stories[index].isFavorite = newFavoriteState
                }

                Logger.ui.success("Updated favorite status")
            } catch {
                Logger.ui.error("Failed to update favorite: \(error.localizedDescription)")
            }
        }
    }

    private func deleteStory(_ story: Story) {
        Task {
            do {
                guard let backendId = story.backendId else {
                    Logger.ui.error("Story has no backend ID")
                    return
                }
                try await storyRepository.deleteStory(id: backendId)

                withAnimation {
                    stories.removeAll { $0.id == story.id }
                }

                Logger.ui.success("Deleted story: \(story.title)")
            } catch {
                Logger.ui.error("Failed to delete story: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Hero Section View
struct HeroSectionView: View {
    let heroes: [Hero]
    @Binding var showingHeroCreation: Bool
    @Binding var selectedHeroForStory: Hero?
    @Binding var showingStoryGeneration: Bool

    var body: some View {
        VStack(spacing: 15) {
            // Heroes Title Bar
            HStack {
                Text("home.yourHeroes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                if !heroes.isEmpty {
                    NavigationLink(destination: HeroListView()) {
                        Text("home.manageHeroes")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(minHeight: 44)
                            .liquidGlassCapsule(variant: .clear)
                    }
                    .accessibilityLabel(String(localized: "home.manageHeroes.accessibility"))
                    .accessibilityHint(String(localized: "home.manageHeroes.hint"))
                }
            }

            // Heroes Avatar Row
            if !heroes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(heroes) { hero in
                                // BUG-02: Hero avatar is now a NavigationLink
                                // so tapping it routes to the hero's detail
                                // (visual profile) screen instead of being
                                // an inert AXStaticText element.
                                NavigationLink {
                                    HeroVisualProfileView(hero: hero)
                                } label: {
                                    VStack(spacing: 4) {
                                        HeroAvatarImageView(hero: hero, size: 40)

                                        Text(hero.name)
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .frame(minWidth: 60, maxWidth: 80)
                                    }
                                    .frame(minWidth: 60, minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(hero.name)
                                .accessibilityHint(String(localized: "home.hero.open.hint", defaultValue: "Opens \(hero.name)'s profile"))
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 5)
            }
        }
    }
}


// MARK: - Floating Create Story Button
struct FloatingCreateStoryButton: View {
    let hasHeroes: Bool
    @Binding var showingStoryGeneration: Bool
    @Binding var showingHeroCreation: Bool
    @State private var showNoHeroAlert = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            if hasHeroes {
                showingStoryGeneration = true
            } else {
                showNoHeroAlert = true
            }
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
        .buttonStyle(.glassFloating(size: 56, tintColor: .orange))
        .accessibilityLabel(String(localized: "home.createStory.accessibility"))
        .accessibilityHint(String(localized: "home.createStory.hint"))
        .alert(String(localized: "home.createHeroFirst.title"), isPresented: $showNoHeroAlert) {
            Button(String(localized: "home.createHeroFirst.action"), role: .none) {
                showingHeroCreation = true
            }
            Button(String(localized: "home.createHeroFirst.cancel"), role: .cancel) {}
        } message: {
            Text("home.createHeroFirst.message")
        }
    }
}

// MARK: - Floating Custom Event Button
struct FloatingCustomEventButton: View {
    @Binding var showingCustomEventManagement: Bool

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            showingCustomEventManagement = true
        }) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
        .buttonStyle(.glassFloating(size: 48, tintColor: .accentColor))
        .accessibilityLabel(String(localized: "home.customEvents.accessibility"))
        .accessibilityHint(String(localized: "home.customEvents.hint"))
    }
}

// MARK: - Reading Journey Top Button
struct ReadingJourneyTopButton: View {
    let totalStories: Int
    let streak: Int

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("home.journey")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(String(localized: "home.journey.streak", defaultValue: "\(streak)d"))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .liquidGlassCapsule()
    }
}


// MARK: - Recent Stories View
struct RecentStoriesView: View {
    let stories: [Story]
    @Binding var selectedStory: Story?

    private let headerFont = Font.system(size: 18, weight: .bold, design: .rounded)
    private let linkFont = Font.system(size: 14, weight: .medium, design: .rounded)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("home.recentAdventures")
                        .font(headerFont)
                        .foregroundColor(.primary)

                    if stories.count > 3 {
                        Text(String(localized: "home.recentAdventures.count", defaultValue: "\(stories.count) new"))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.2))
                            )
                            .foregroundColor(.accentColor)
                    }
                }

                Spacer()

                NavigationLink(destination: ImprovedStoryLibraryView()) {
                    HStack(spacing: 4) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 14))
                        Text("home.library")
                            .font(linkFont)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .liquidGlassCapsule(variant: .tinted(.accentColor))
                }
            }

            VStack(spacing: 10) {
                ForEach(stories) { story in
                    MiniStoryCard(story: story) {
                        selectedStory = story
                    }
                }
            }
        }
    }
}

// MARK: - Mini Story Card (Enhanced Accessibility)
struct MiniStoryCard: View {
    let story: Story
    let onTap: () -> Void
    @State private var isPressed = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    private var titleFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .title3 : AccessibleTypography.cardTitle
    }

    private var contentFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .body : AccessibleTypography.cardBody
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        }) {
            ZStack {
                AccessibleCardStyle.cardBackground(for: colorScheme)

                HStack(spacing: AccessibleSizes.cardSpacing) {
                    if let hero = story.hero {
                        HeroAvatarImageView(hero: hero, size: AccessibleSizes.iconContainerSize)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: AccessibleSizes.iconContainerSize,
                                       height: AccessibleSizes.iconContainerSize)

                            Image(systemName: "book.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(story.title)
                                .font(titleFont)
                                .foregroundColor(AccessibleColors.primaryText)
                                .lineLimit(1)

                            if story.isFavorite {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .accessibilityLabel(String(localized: "home.favorite"))
                            }
                        }

                        Text(story.shortContent)
                            .font(contentFont)
                            .foregroundColor(AccessibleColors.secondaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .multilineTextAlignment(.leading)

                        HStack {
                            if let hero = story.hero {
                                Text(hero.name)
                                    .font(AccessibleTypography.metadata)
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.medium)
                            }

                            if story.hasAudio {
                                Label("\(Int(story.estimatedDuration / 60))m",
                                      systemImage: "speaker.wave.2.fill")
                                    .font(AccessibleTypography.metadata)
                                    .foregroundColor(.orange)
                            }

                            Spacer()

                            Text(story.formattedDate)
                                .font(AccessibleTypography.metadata)
                                .foregroundColor(AccessibleColors.secondaryText)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AccessibleColors.secondaryText)
                }
                .padding(AccessibleSizes.cardPadding)
            }
            .frame(minHeight: AccessibleSizes.miniCardMinHeight)
        }
        .buttonStyle(AccessibleCardButtonStyle())
        .scaleEffect(isPressed ? 0.95 : (isFocused ? 1.02 : 1.0))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 3)
        )
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .focusable()
        .focused($isFocused)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(reduceMotion ? nil : .spring()) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityLabelProvider.storyCardLabel(for: story))
        .accessibilityHint(AccessibilityLabelProvider.storyCardHint(for: story))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(story.isFavorite ? String(localized: "home.favorite") : "")
        .accessibilityActions {
            if story.isFavorite {
                Button(String(localized: "home.removeFavorite")) {
                    // Toggle favorite action
                }
            } else {
                Button(String(localized: "home.addFavorite")) {
                    // Toggle favorite action
                }
            }

            Button(String(localized: "home.shareStory")) {
                // Share action
            }
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @Binding var showingHeroCreation: Bool

    private let titleFont = Font.system(size: 24, weight: .bold, design: .rounded)
    private let bodyFont = Font.system(size: 16, weight: .light, design: .rounded)
    private let buttonFont = Font.system(size: 18, weight: .bold, design: .rounded)

    var body: some View {
        VStack(spacing: 25) {
            // Static Illustration
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 12) {
                Text("home.emptyState.title")
                    .font(titleFont)
                    .foregroundColor(.primary)

                Text("home.emptyState.message")
                    .font(bodyFont)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                showingHeroCreation = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title3)
                    Text("home.emptyState.button")
                        .font(buttonFont)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(Color.accentColor)
                .cornerRadius(25)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "home.emptyState.button.accessibility"))
            .accessibilityHint(String(localized: "home.emptyState.button.hint"))
        }
    }
}

// MARK: - App Logo View
struct AppLogoView: View {
    private let logoFont = Font.system(size: 20, weight: .bold, design: .rounded)

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.pages.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
                // BUG-26: logo glyph is decorative — the adjacent
                // `home.logo` text already carries the meaningful label.
                // iOS was auto-reading `Book Pages Fill` / `Relever`.
                .accessibilityHidden(true)

            Text("home.logo")
                .font(logoFont)
                .foregroundColor(.primary)
        }
    }
}


// MARK: - Preview
#Preview("Empty State") {
    ImprovedContentView()
        .modelContainer(for: Hero.self, inMemory: true)
}

#Preview("With Stories") {
    struct PreviewWrapper: View {
        @State private var heroes: [Hero] = []
        @State private var stories: [Story] = []

        var body: some View {
            ImprovedContentView_Preview(
                heroes: heroes,
                stories: stories
            )
            .onAppear {
                let hero1 = Hero(
                    name: "Luna",
                    primaryTrait: .brave,
                    secondaryTrait: .magical,
                    appearance: "sparkly blue eyes and silver hair",
                    specialAbility: "create beautiful dreams",
                    backendId: "hero-1"
                )
                hero1.avatarImagePath = "https://via.placeholder.com/150"

                let hero2 = Hero(
                    name: "Max",
                    primaryTrait: .curious,
                    secondaryTrait: .kind,
                    appearance: "curly red hair and freckles",
                    specialAbility: "talk to animals",
                    backendId: "hero-2"
                )
                hero2.avatarImagePath = "https://via.placeholder.com/150"

                heroes = [hero1, hero2]

                let story1 = Story(
                    title: "Luna's Magical Dream Adventure",
                    content: "Once upon a time, Luna discovered she could enter other people's dreams...",
                    event: .bedtime,
                    hero: hero1
                )
                story1.backendId = "story-1"
                story1.createdAt = Date()
                story1.isFavorite = true

                let story2 = Story(
                    title: "Max and the Talking Forest",
                    content: "Max ventured into the enchanted forest where every animal had a story to tell...",
                    event: .weekend,
                    hero: hero2
                )
                story2.backendId = "story-2"
                story2.createdAt = Date().addingTimeInterval(-3600)

                let story3 = Story(
                    title: "The Birthday Surprise",
                    content: "It was Luna's special day, and the whole magical kingdom was preparing...",
                    event: .birthday,
                    hero: hero1
                )
                story3.backendId = "story-3"
                story3.createdAt = Date().addingTimeInterval(-7200)
                story3.playCount = 2

                stories = [story1, story2, story3]

                let illustration1 = StoryIllustration(
                    timestamp: 0,
                    imagePrompt: "Luna floating in a starry dream world",
                    displayOrder: 0,
                    textSegment: "Luna discovered she could enter dreams"
                )
                illustration1.imagePath = "https://via.placeholder.com/300"
                illustration1.isGenerated = true
                story1.illustrations = [illustration1]
            }
        }
    }

    return PreviewWrapper()
        .modelContainer(for: Hero.self, inMemory: true)
}

// Preview version of ImprovedContentView with injected data
struct ImprovedContentView_Preview: View {
    @State var heroes: [Hero]
    @State var stories: [Story]
    @State private var isLoading = false
    @State private var loadError: Error?

    @Environment(\.colorScheme) private var colorScheme
    @State private var showingHeroCreation = false
    @State private var showingStoryGeneration = false
    @State private var showingSettings = false
    @State private var selectedStory: Story?
    @State private var selectedHeroForStory: Hero?
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingFullJourney = false
    @State private var showingCustomEventManagement = false

    private var totalStoriesRead: Int { stories.reduce(0) { $0 + $1.playCount } }
    private var currentStreak: Int { 3 }

    private var recentStories: [Story] {
        Array(stories.sorted(by: { $0.createdAt > $1.createdAt }).prefix(6))
    }

    private var favoriteStories: [Story] {
        stories.filter { $0.isFavorite }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ZStack {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 0) {
                                HeroSectionView(
                                    heroes: heroes,
                                    showingHeroCreation: $showingHeroCreation,
                                    selectedHeroForStory: $selectedHeroForStory,
                                    showingStoryGeneration: $showingStoryGeneration
                                )
                                .padding(.top, 20)

                                // Recent Stories
                                VStack {
                                    if !recentStories.isEmpty {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Text("Recent Adventures")
                                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }

                                            LazyVStack(spacing: 12) {
                                                ForEach(recentStories) { story in
                                                    StoryCard(
                                                        story: story,
                                                        onTap: { selectedStory = story },
                                                        variant: .compact
                                                    )
                                                }
                                            }
                                        }
                                        .padding(.top, 25)
                                    } else {
                                        Text("home.noRecentStories")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding()
                                    }
                                }

                                if heroes.isEmpty {
                                    EmptyStateView(showingHeroCreation: $showingHeroCreation)
                                        .padding(.top, 40)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                    }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FloatingCreateStoryButton(
                                hasHeroes: !heroes.isEmpty,
                                showingStoryGeneration: $showingStoryGeneration,
                                showingHeroCreation: $showingHeroCreation
                            )
                            .padding(.trailing, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "app.brand.name"))
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
