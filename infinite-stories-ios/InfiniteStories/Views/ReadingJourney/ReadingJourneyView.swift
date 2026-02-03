//
//  ReadingJourneyView.swift
//  InfiniteStories
//
//  Comprehensive reading statistics and journey tracking view - API-only
//

import SwiftUI
import Charts

// MARK: - Reading Journey Tab Content (for Tab Bar navigation)
/// This view is used within the Journey tab and removes redundant dismiss button
/// since navigation is now handled by the tab bar.
struct ReadingJourneyTabContent: View {
    @Environment(\.colorScheme) private var colorScheme

    // API-only state management
    @State private var summary: AnalyticsSummary?
    @State private var activityData: ListeningActivityResponse?
    @State private var heroAnalytics: HeroAnalyticsResponse?
    @State private var milestones: MilestonesResponse?
    @State private var insights: InsightsResponse?
    @State private var recentStories: [Story] = []
    @State private var favoriteStories: [Story] = []

    // Loading and error states
    @State private var isLoading = false
    @State private var error: Error?

    // UI state
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingShareSheet = false

    // Repositories
    private let journeyRepository = ReadingJourneyRepository()
    private let storyRepository = StoryRepository()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && summary == nil {
                    LoadingView()
                } else if let error = error, summary == nil {
                    ErrorView(error: error, retryAction: {
                        Task { await loadAllData(forceRefresh: true) }
                    })
                } else {
                    contentView
                }
            }
            .background(backgroundGradient)
            .navigationTitle(String(localized: "journey.title"))
            .navigationBarTitleDisplayMode(.large)
            .glassNavigation()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            Task { await loadAllData(forceRefresh: true) }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(isLoading)

                        Button(action: { showingShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            JourneyShareSheet(items: [generateShareText()])
        }
        .task {
            await loadAllData(forceRefresh: false)
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            Task {
                await loadActivityData(range: newRange, forceRefresh: true)
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header Stats Cards
                HeaderStatsSection(summary: summary)

                // Listening Activity Chart
                ListeningActivityChartAPI(
                    activityData: activityData,
                    selectedTimeRange: $selectedTimeRange,
                    isLoading: isLoading
                )

                // Hero Performance Section
                if let heroAnalytics = heroAnalytics, !heroAnalytics.heroes.isEmpty {
                    HeroPerformanceSectionAPI(heroAnalytics: heroAnalytics)
                }

                // Milestones & Achievements
                if let milestones = milestones {
                    MilestonesSectionAPI(milestones: milestones)
                }

                // Recent Activity Timeline
                if !recentStories.isEmpty {
                    RecentActivitySection(stories: recentStories)
                }


                // Reading Insights
                if let insights = insights {
                    ReadingInsightsSectionAPI(insights: insights.insights)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .refreshable {
            await loadAllData(forceRefresh: true)
        }
    }

    private var backgroundGradient: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
    }

    // MARK: - Data Loading

    private func loadAllData(forceRefresh: Bool) async {
        guard NetworkMonitor.shared.isConnected else {
            error = APIError.networkUnavailable
            return
        }

        isLoading = true
        error = nil

        // Load all data concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadSummary(forceRefresh: forceRefresh) }
            group.addTask { await loadActivityData(range: selectedTimeRange, forceRefresh: forceRefresh) }
            group.addTask { await loadHeroAnalytics(forceRefresh: forceRefresh) }
            group.addTask { await loadMilestones(forceRefresh: forceRefresh) }
            group.addTask { await loadInsights(forceRefresh: forceRefresh) }
            group.addTask { await loadRecentStories() }
            group.addTask { await loadFavoriteStories() }
        }

        isLoading = false
    }

    private func loadSummary(forceRefresh: Bool) async {
        do {
            summary = try await journeyRepository.fetchSummary(forceRefresh: forceRefresh)
            Logger.ui.success("Loaded analytics summary")
        } catch {
            if self.error == nil {
                self.error = error
            }
            Logger.ui.error("Failed to load summary: \(error.localizedDescription)")
        }
    }

    private func loadActivityData(range: TimeRange, forceRefresh: Bool) async {
        do {
            activityData = try await journeyRepository.fetchActivity(range: range, forceRefresh: forceRefresh)
            Logger.ui.success("Loaded activity data for \(range.rawValue)")
        } catch {
            Logger.ui.error("Failed to load activity: \(error.localizedDescription)")
        }
    }

    private func loadHeroAnalytics(forceRefresh: Bool) async {
        do {
            heroAnalytics = try await journeyRepository.fetchHeroAnalytics(forceRefresh: forceRefresh)
            Logger.ui.success("Loaded hero analytics")
        } catch {
            Logger.ui.error("Failed to load hero analytics: \(error.localizedDescription)")
        }
    }

    private func loadMilestones(forceRefresh: Bool) async {
        do {
            milestones = try await journeyRepository.fetchMilestones(forceRefresh: forceRefresh)
            Logger.ui.success("Loaded milestones")
        } catch {
            Logger.ui.error("Failed to load milestones: \(error.localizedDescription)")
        }
    }

    private func loadInsights(forceRefresh: Bool) async {
        do {
            insights = try await journeyRepository.fetchInsights(forceRefresh: forceRefresh)
            Logger.ui.success("Loaded insights")
        } catch {
            Logger.ui.error("Failed to load insights: \(error.localizedDescription)")
        }
    }

    private func loadRecentStories() async {
        do {
            let stories = try await storyRepository.fetchStories(heroId: nil, limit: 10, offset: 0)
            recentStories = stories
            Logger.ui.success("Loaded \(stories.count) recent stories")
        } catch {
            Logger.ui.error("Failed to load recent stories: \(error.localizedDescription)")
        }
    }

    private func loadFavoriteStories() async {
        do {
            // Fetch stories and filter favorites client-side
            // TODO: Add backend endpoint for favorite stories when available
            let stories = try await storyRepository.fetchStories(heroId: nil, limit: 50, offset: 0)
            favoriteStories = stories.filter { $0.isFavorite }
            Logger.ui.success("Loaded \(favoriteStories.count) favorite stories")
        } catch {
            Logger.ui.error("Failed to load favorite stories: \(error.localizedDescription)")
        }
    }

    private func generateShareText() -> String {
        let totalStories = summary?.totalStoriesListened ?? 0
        let listeningTime = summary?.formattedListeningTime ?? "0m"
        let streak = summary?.currentStreak ?? 0
        let favorites = summary?.favoriteStoriesCount ?? 0
        let mostActiveHero = heroAnalytics?.mostActiveHero?.heroName ?? String(localized: "journey.share.noneYet")

        return String(localized: "journey.share.text", defaultValue: """
        My Infinite Stories Reading Journey

        Total Stories: \(totalStories)
        Listening Time: \(listeningTime)
        Current Streak: \(streak) days
        Favorite Stories: \(favorites)

        Most Active Hero: \(mostActiveHero)

        Created with Infinite Stories - Where magical adventures come to life!
        """)
    }
}

// MARK: - Main Reading Journey View (Legacy - for sheet/fullScreenCover presentation)
struct ReadingJourneyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // API-only state management
    @State private var summary: AnalyticsSummary?
    @State private var activityData: ListeningActivityResponse?
    @State private var heroAnalytics: HeroAnalyticsResponse?
    @State private var milestones: MilestonesResponse?
    @State private var insights: InsightsResponse?
    @State private var recentStories: [Story] = []
    @State private var favoriteStories: [Story] = []

    // Loading and error states
    @State private var isLoading = false
    @State private var error: Error?

    // UI state
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingShareSheet = false

    // Repositories
    private let journeyRepository = ReadingJourneyRepository()
    private let storyRepository = StoryRepository()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && summary == nil {
                    LoadingView()
                } else if let error = error, summary == nil {
                    ErrorView(error: error, retryAction: {
                        Task { await loadAllData(forceRefresh: true) }
                    })
                } else {
                    contentView
                }
            }
            .background(backgroundGradient)
            .navigationTitle("Reading Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            Task { await loadAllData(forceRefresh: true) }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(isLoading)

                        Button(action: { showingShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "journey.done")) {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            JourneyShareSheet(items: [generateShareText()])
        }
        .task {
            await loadAllData(forceRefresh: false)
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            Task {
                await loadActivityData(range: newRange, forceRefresh: true)
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header Stats Cards
                HeaderStatsSection(summary: summary)

                // Listening Activity Chart
                ListeningActivityChartAPI(
                    activityData: activityData,
                    selectedTimeRange: $selectedTimeRange,
                    isLoading: isLoading
                )

                // Hero Performance Section
                if let heroAnalytics = heroAnalytics, !heroAnalytics.heroes.isEmpty {
                    HeroPerformanceSectionAPI(heroAnalytics: heroAnalytics)
                }

                // Milestones & Achievements
                if let milestones = milestones {
                    MilestonesSectionAPI(milestones: milestones)
                }

                // Recent Activity Timeline
                if !recentStories.isEmpty {
                    RecentActivitySection(stories: recentStories)
                }


                // Reading Insights
                if let insights = insights {
                    ReadingInsightsSectionAPI(insights: insights.insights)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .refreshable {
            await loadAllData(forceRefresh: true)
        }
    }

    private var backgroundGradient: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
    }

    // MARK: - Data Loading

    private func loadAllData(forceRefresh: Bool) async {
        guard NetworkMonitor.shared.isConnected else {
            error = APIError.networkUnavailable
            return
        }

        isLoading = true
        error = nil

        // Load all data concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadSummary(forceRefresh: forceRefresh) }
            group.addTask { await loadActivityData(range: selectedTimeRange, forceRefresh: forceRefresh) }
            group.addTask { await loadHeroAnalytics(forceRefresh: forceRefresh) }
            group.addTask { await loadMilestones(forceRefresh: forceRefresh) }
            group.addTask { await loadInsights(forceRefresh: forceRefresh) }
            group.addTask { await loadRecentStories() }
            group.addTask { await loadFavoriteStories() }
        }

        isLoading = false
    }

    private func loadSummary(forceRefresh: Bool) async {
        do {
            summary = try await journeyRepository.fetchSummary(forceRefresh: forceRefresh)
            Logger.ui.success("Loaded analytics summary")
        } catch {
            if self.error == nil {
                self.error = error
            }
            Logger.ui.error("Failed to load summary: \(error.localizedDescription)")
        }
    }

    private func loadActivityData(range: TimeRange, forceRefresh: Bool) async {
        do {
            activityData = try await journeyRepository.fetchActivity(range: range, forceRefresh: forceRefresh)
            Logger.ui.success("Loaded activity data for \(range.rawValue)")
        } catch {
            Logger.ui.error("Failed to load activity: \(error.localizedDescription)")
        }
    }

    private func loadHeroAnalytics(forceRefresh: Bool) async {
        do {
            heroAnalytics = try await journeyRepository.fetchHeroAnalytics(forceRefresh: forceRefresh)
            Logger.ui.success("Loaded hero analytics")
        } catch {
            Logger.ui.error("Failed to load hero analytics: \(error.localizedDescription)")
        }
    }

    private func loadMilestones(forceRefresh: Bool) async {
        do {
            milestones = try await journeyRepository.fetchMilestones(forceRefresh: forceRefresh)
            Logger.ui.success("Loaded milestones")
        } catch {
            Logger.ui.error("Failed to load milestones: \(error.localizedDescription)")
        }
    }

    private func loadInsights(forceRefresh: Bool) async {
        do {
            insights = try await journeyRepository.fetchInsights(forceRefresh: forceRefresh)
            Logger.ui.success("Loaded insights")
        } catch {
            Logger.ui.error("Failed to load insights: \(error.localizedDescription)")
        }
    }

    private func loadRecentStories() async {
        do {
            let stories = try await storyRepository.fetchStories(heroId: nil, limit: 10, offset: 0)
            recentStories = stories
            Logger.ui.success("Loaded \(stories.count) recent stories")
        } catch {
            Logger.ui.error("Failed to load recent stories: \(error.localizedDescription)")
        }
    }

    private func loadFavoriteStories() async {
        do {
            // Fetch stories and filter favorites client-side
            // TODO: Add backend endpoint for favorite stories when available
            let stories = try await storyRepository.fetchStories(heroId: nil, limit: 50, offset: 0)
            favoriteStories = stories.filter { $0.isFavorite }
            Logger.ui.success("Loaded \(favoriteStories.count) favorite stories")
        } catch {
            Logger.ui.error("Failed to load favorite stories: \(error.localizedDescription)")
        }
    }

    private func generateShareText() -> String {
        let totalStories = summary?.totalStoriesListened ?? 0
        let listeningTime = summary?.formattedListeningTime ?? "0m"
        let streak = summary?.currentStreak ?? 0
        let favorites = summary?.favoriteStoriesCount ?? 0
        let mostActiveHero = heroAnalytics?.mostActiveHero?.heroName ?? String(localized: "journey.share.noneYet")

        return String(localized: "journey.share.text", defaultValue: """
        My Infinite Stories Reading Journey

        Total Stories: \(totalStories)
        Listening Time: \(listeningTime)
        Current Streak: \(streak) days
        Favorite Stories: \(favorites)

        Most Active Hero: \(mostActiveHero)

        Created with Infinite Stories - Where magical adventures come to life!
        """)
    }
}

// MARK: - Loading View
private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("journey.loading")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Header Stats Section (Updated for API)
struct HeaderStatsSection: View {
    let summary: AnalyticsSummary?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            JourneyStatCard(
                icon: "book.closed.fill",
                title: String(localized: "journey.totalStories"),
                value: "\(summary?.totalStoriesListened ?? 0)",
                color: .blue,
                isLarge: false
            )

            JourneyStatCard(
                icon: "clock.fill",
                title: String(localized: "journey.listeningTime"),
                value: summary?.formattedListeningTime ?? "0m",
                color: .green,
                isLarge: false
            )

            JourneyStatCard(
                icon: "flame.fill",
                title: String(localized: "journey.currentStreak"),
                value: String(localized: "journey.currentStreak.value", defaultValue: "\(summary?.currentStreak ?? 0) days"),
                color: .orange,
                isLarge: false
            )

            JourneyStatCard(
                icon: "heart.fill",
                title: String(localized: "journey.favorites"),
                value: "\(summary?.favoriteStoriesCount ?? 0)",
                color: .red,
                isLarge: false
            )
        }
    }
}

// MARK: - Journey Stat Card
struct JourneyStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let isLarge: Bool

    @State private var isAnimated = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(isLarge ? .title : .title2)
                    .foregroundColor(color)
                    .scaleEffect(isAnimated ? 1.1 : 1.0)

                if isLarge {
                    Spacer()
                }
            }

            VStack(alignment: isLarge ? .leading : .center, spacing: 4) {
                Text(value)
                    .font(isLarge ? .title : .title3)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isLarge {
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: isLarge ? 120 : 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(colorScheme == .dark ? 0.2 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.1)) {
                isAnimated = true
            }
        }
    }
}

// MARK: - Listening Activity Chart (API Version)
struct ListeningActivityChartAPI: View {
    let activityData: ListeningActivityResponse?
    @Binding var selectedTimeRange: TimeRange
    let isLoading: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var dataPoints: [ListeningDataPoint] {
        guard let activity = activityData?.activity else { return [] }
        return activity.compactMap { point in
            guard let date = point.dateValue else { return nil }
            return ListeningDataPoint(date: date, minutes: point.minutesDouble)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("journey.listeningActivity")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Picker(String(localized: "journey.timeRange"), selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }

            if isLoading && activityData == nil {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                    )
            } else if !dataPoints.isEmpty {
                Chart(dataPoints) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Minutes", point.minutes)
                    )
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedTimeRange == .week ? 1 : 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            } else {
                // Empty state
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        Text("journey.noListeningData")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        )
    }
}

// MARK: - Hero Performance Section (API Version)
struct HeroPerformanceSectionAPI: View {
    let heroAnalytics: HeroAnalyticsResponse
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("journey.heroPerformance")
                .font(.title3)
                .fontWeight(.bold)

            if let topHero = heroAnalytics.mostActiveHero {
                HStack {
                    // Avatar
                    AsyncImage(url: topHero.avatarUrl.flatMap { URL(string: $0) }) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        case .failure, .empty:
                            Circle()
                                .fill(Color.accentColor.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(String(topHero.heroName.prefix(1)))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentColor)
                                )
                        @unknown default:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("journey.mostActiveHero")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(topHero.heroName)
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(topHero.storiesCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("journey.stories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.1))
                )
            }

            // Hero distribution bars
            ForEach(heroAnalytics.heroes) { hero in
                HeroAnalyticsBar(hero: hero, maxCount: heroAnalytics.heroes.first?.storiesCount ?? 1)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        )
    }
}

// MARK: - Hero Analytics Bar
struct HeroAnalyticsBar: View {
    let hero: HeroAnalytics
    let maxCount: Int

    private var barWidth: CGFloat {
        let ratio = CGFloat(hero.storiesCount) / CGFloat(maxCount)
        return max(ratio, 0.1) // Minimum 10% width for visibility
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(hero.heroName)
                .font(.subheadline)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 30)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * barWidth, height: 30)
                }
            }
            .frame(height: 30)

            Text("\(hero.storiesCount)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Milestones Section (API Version)
struct MilestonesSectionAPI: View {
    let milestones: MilestonesResponse

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("journey.milestones")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Text("\(milestones.summary.unlockedCount)/\(milestones.summary.totalMilestones)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(milestones.unlockedMilestones) { milestone in
                        MilestoneCardAPI(milestone: milestone, isUnlocked: true)
                    }

                    if let next = milestones.nextMilestone {
                        MilestoneCardAPI(milestone: next, isUnlocked: false)
                            .opacity(0.6)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        )
    }
}

// MARK: - Milestone Card (API Version)
struct MilestoneCardAPI: View {
    let milestone: MilestoneData
    let isUnlocked: Bool

    private var color: Color {
        switch milestone.category {
        case "stories": return .blue
        case "listening": return .green
        case "streak": return .orange
        default: return .purple
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color : Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)

                if let emoji = milestone.emoji {
                    Text(emoji)
                        .font(.title2)
                } else {
                    Image(systemName: iconForCategory(milestone.category))
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }

            Text(milestone.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(width: 80)

            if !isUnlocked, let percentage = milestone.percentage {
                ProgressView(value: Double(percentage), total: 100)
                    .frame(width: 60)
            }
        }
        .padding(.vertical, 10)
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "stories": return "book.closed"
        case "listening": return "clock"
        case "streak": return "flame"
        default: return "star"
        }
    }
}

// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    let stories: [Story]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("journey.recentActivity")
                .font(.title3)
                .fontWeight(.bold)

            VStack(spacing: 10) {
                ForEach(stories) { story in
                    ActivityRow(story: story)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        )
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let story: Story

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if let hero = story.hero {
                        Text(hero.name)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }

                    Text("*")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(RelativeDateFormatter.shared.string(from: story.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if story.playCount > 0 {
                        Text("*")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("\(story.playCount)", systemImage: "play.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            if story.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Favorite Stories Section
struct FavoriteStoriesSection: View {
    let favorites: [Story]
    @State private var selectedStory: Story?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("journey.favoriteStories")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(favorites) { story in
                        FavoriteStoryCard(story: story)
                            .onTapGesture {
                                selectedStory = story
                            }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        )
        .sheet(item: $selectedStory) { story in
            AudioPlayerView(
                story: story,
                allStories: favorites,
                storyIndex: favorites.firstIndex(where: { $0.id == story.id }) ?? 0
            )
            .glassSheet()
        }
    }
}

// MARK: - Favorite Story Card
struct FavoriteStoryCard: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let hero = story.hero {
                HeroAvatarImageView(hero: hero, size: 60)
            } else {
                Circle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "book.fill")
                            .foregroundColor(.accentColor)
                    )
            }

            Text(story.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 100, alignment: .leading)

            if let hero = story.hero {
                Text(hero.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Reading Insights Section (API Version)
struct ReadingInsightsSectionAPI: View {
    let insights: Insights

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("journey.readingInsights")
                .font(.title3)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                if let avgLength = insights.averageStoryLengthMinutes {
                    InsightRow(
                        icon: "clock",
                        label: String(localized: "journey.insights.averageLength"),
                        value: String(localized: "journey.insights.averageLength.value", defaultValue: "\(Int(avgLength)) min")
                    )
                }

                if let avgListens = insights.averageListensPerStory {
                    InsightRow(
                        icon: "play.circle",
                        label: String(localized: "journey.insights.averageListens"),
                        value: String(format: "%.1f", avgListens)
                    )
                }

                InsightRow(
                    icon: "moon.stars",
                    label: String(localized: "journey.insights.preferredTime"),
                    value: insights.formattedPreferredTime
                )

                if let topStory = insights.mostListenedStory {
                    InsightRow(
                        icon: "star.fill",
                        label: String(localized: "journey.insights.mostListened"),
                        value: String(localized: "journey.insights.mostListened.value", defaultValue: "\(topStory.title) (\(topStory.playCount) plays)")
                    )
                }

                InsightRow(
                    icon: "books.vertical",
                    label: String(localized: "journey.insights.uniqueStories"),
                    value: "\(insights.totalUniqueStoriesListened)"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        )
    }
}

// MARK: - Insight Row
struct InsightRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 25)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Supporting Types
// Note: TimeRange enum is defined in ReadingJourneyRepository.swift as the single source of truth

struct ListeningDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
}

// MARK: - Journey Share Sheet
struct JourneyShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Relative Date Formatter
class RelativeDateFormatter {
    static let shared = RelativeDateFormatter()

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    func string(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return String(localized: "journey.date.today")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "journey.date.yesterday")
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
            return String(localized: "journey.date.daysAgo", defaultValue: "\(daysAgo) days ago")
        } else {
            return formatter.string(from: date)
        }
    }
}

// Note: Using the existing HeroAvatarImageView from Components folder

// MARK: - Preview
#Preview {
    ReadingJourneyView()
}
