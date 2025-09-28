//
//  ReadingJourneyView.swift
//  InfiniteStories
//
//  Comprehensive reading statistics and journey tracking view
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Main Reading Journey View
struct ReadingJourneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Story.createdAt, order: .reverse) private var stories: [Story]
    @Query private var heroes: [Hero]

    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedHero: Hero?
    @State private var showingShareSheet = false

    // Computed statistics
    private var totalStories: Int {
        stories.count
    }

    private var totalListeningTime: TimeInterval {
        stories.reduce(0) { $0 + ($1.estimatedDuration * Double($1.playCount)) }
    }

    private var totalPlayCount: Int {
        stories.reduce(0) { $0 + $1.playCount }
    }

    private var favoriteStories: [Story] {
        stories.filter { $0.isFavorite }
    }

    private var currentStreak: Int {
        calculateReadingStreak()
    }

    private var averageStoryLength: TimeInterval {
        guard !stories.isEmpty else { return 0 }
        let totalDuration = stories.reduce(0) { $0 + $1.estimatedDuration }
        return totalDuration / Double(stories.count)
    }

    private var mostActiveHero: Hero? {
        heroes.max { $0.stories.count < $1.stories.count }
    }

    private var listeningDataPoints: [ListeningDataPoint] {
        generateListeningData()
    }

    private var heroStoryDistribution: [HeroStoryData] {
        heroes.compactMap { hero in
            let storyCount = hero.stories.count
            guard storyCount > 0 else { return nil }
            return HeroStoryData(hero: hero, storyCount: storyCount)
        }.sorted { $0.storyCount > $1.storyCount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // Header Stats Cards
                    HeaderStatsSection(
                        totalStories: totalStories,
                        totalListeningTime: totalListeningTime,
                        currentStreak: currentStreak,
                        favoriteCount: favoriteStories.count
                    )

                    // Listening Activity Chart
                    ListeningActivityChart(
                        dataPoints: listeningDataPoints,
                        selectedTimeRange: $selectedTimeRange
                    )

                    // Hero Performance Section
                    if !heroStoryDistribution.isEmpty {
                        HeroPerformanceSection(
                            heroData: heroStoryDistribution,
                            mostActiveHero: mostActiveHero
                        )
                    }

                    // Milestones & Achievements
                    MilestonesSection(
                        totalStories: totalStories,
                        totalListeningTime: totalListeningTime,
                        currentStreak: currentStreak
                    )

                    // Recent Activity Timeline
                    RecentActivitySection(stories: Array(stories.prefix(10)))

                    // Favorite Stories Collection
                    if !favoriteStories.isEmpty {
                        FavoriteStoriesSection(favorites: favoriteStories)
                    }

                    // Reading Insights
                    ReadingInsightsSection(
                        stories: stories,
                        averageStoryLength: averageStoryLength,
                        totalPlayCount: totalPlayCount
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .background(backgroundGradient)
            .navigationTitle("Reading Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(MagicalColors.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(MagicalColors.primary)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            JourneyShareSheet(items: [generateShareText()])
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color.black.opacity(0.95), Color.purple.opacity(0.1)] :
                [Color.purple.opacity(0.05), Color.white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func calculateReadingStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()

        for _ in 0..<365 {
            let dayStories = stories.filter {
                calendar.isDate($0.createdAt, inSameDayAs: currentDate)
            }

            if !dayStories.isEmpty {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if streak > 0 {
                // Break in streak
                break
            } else {
                // Haven't found the start of the streak yet
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            }
        }

        return streak
    }

    private func generateListeningData() -> [ListeningDataPoint] {
        let calendar = Calendar.current
        var dataPoints: [ListeningDataPoint] = []

        let daysToShow = selectedTimeRange.days
        for dayOffset in 0..<daysToShow {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            let dayStories = stories.filter {
                calendar.isDate($0.createdAt, inSameDayAs: date)
            }

            let totalMinutes = dayStories.reduce(0) { $0 + ($1.estimatedDuration / 60) }
            dataPoints.append(ListeningDataPoint(date: date, minutes: totalMinutes))
        }

        return dataPoints.reversed()
    }

    private func generateShareText() -> String {
        """
        My Infinite Stories Reading Journey

        Total Stories: \(totalStories)
        Listening Time: \(formatDuration(totalListeningTime))
        Current Streak: \(currentStreak) days
        Favorite Stories: \(favoriteStories.count)

        Most Active Hero: \(mostActiveHero?.name ?? "None yet")

        Created with Infinite Stories - Where magical adventures come to life!
        """
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Header Stats Section
struct HeaderStatsSection: View {
    let totalStories: Int
    let totalListeningTime: TimeInterval
    let currentStreak: Int
    let favoriteCount: Int

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            JourneyStatCard(
                icon: "book.closed.fill",
                title: "Total Stories",
                value: "\(totalStories)",
                color: .blue,
                isLarge: false
            )

            JourneyStatCard(
                icon: "clock.fill",
                title: "Listening Time",
                value: formatDuration(totalListeningTime),
                color: .green,
                isLarge: false
            )

            JourneyStatCard(
                icon: "flame.fill",
                title: "Current Streak",
                value: "\(currentStreak) days",
                color: .orange,
                isLarge: false
            )

            JourneyStatCard(
                icon: "heart.fill",
                title: "Favorites",
                value: "\(favoriteCount)",
                color: .red,
                isLarge: false
            )
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
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

// MARK: - Listening Activity Chart
struct ListeningActivityChart: View {
    let dataPoints: [ListeningDataPoint]
    @Binding var selectedTimeRange: TimeRange
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Listening Activity")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }

            if !dataPoints.isEmpty {
                Chart(dataPoints) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Minutes", point.minutes)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [MagicalColors.primary, MagicalColors.accent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
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
                        Text("No listening data yet")
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

// MARK: - Hero Performance Section
struct HeroPerformanceSection: View {
    let heroData: [HeroStoryData]
    let mostActiveHero: Hero?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Hero Performance")
                .font(.title3)
                .fontWeight(.bold)

            if let topHero = mostActiveHero {
                HStack {
                    // Use HeroAvatarImageView for consistent avatar display
                    HeroAvatarImageView(hero: topHero, size: 50)

                    VStack(alignment: .leading) {
                        Text("Most Active Hero")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(topHero.name)
                            .font(.headline)
                            .foregroundColor(MagicalColors.primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(topHero.stories.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Stories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(MagicalColors.primary.opacity(0.1))
                )
            }

            // Hero distribution chart
            ForEach(heroData) { data in
                HeroStoryBar(heroData: data, maxCount: heroData.first?.storyCount ?? 1)
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

// MARK: - Hero Story Bar
struct HeroStoryBar: View {
    let heroData: HeroStoryData
    let maxCount: Int

    private var barWidth: CGFloat {
        let ratio = CGFloat(heroData.storyCount) / CGFloat(maxCount)
        return max(ratio, 0.1) // Minimum 10% width for visibility
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(heroData.hero.name)
                .font(.subheadline)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 30)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [MagicalColors.primary, MagicalColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * barWidth, height: 30)
                }
            }
            .frame(height: 30)

            Text("\(heroData.storyCount)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Milestones Section
struct MilestonesSection: View {
    let totalStories: Int
    let totalListeningTime: TimeInterval
    let currentStreak: Int

    @Environment(\.colorScheme) private var colorScheme

    private var unlockedMilestones: [Milestone] {
        Milestone.allMilestones.filter { $0.isUnlocked(stories: totalStories, time: totalListeningTime, streak: currentStreak) }
    }

    private var nextMilestone: Milestone? {
        Milestone.allMilestones.first { !$0.isUnlocked(stories: totalStories, time: totalListeningTime, streak: currentStreak) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Milestones")
                .font(.title3)
                .fontWeight(.bold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(unlockedMilestones) { milestone in
                        MilestoneCard(milestone: milestone, isUnlocked: true)
                    }

                    if let next = nextMilestone {
                        MilestoneCard(milestone: next, isUnlocked: false)
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

// MARK: - Milestone Card
struct MilestoneCard: View {
    let milestone: Milestone
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? milestone.color : Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)

                Image(systemName: milestone.icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }

            Text(milestone.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    let stories: [Story]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent Activity")
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
                .fill(MagicalColors.primary.opacity(0.2))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if let hero = story.hero {
                        Text(hero.name)
                            .font(.caption)
                            .foregroundColor(MagicalColors.primary)
                    }

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(RelativeDateFormatter.shared.string(from: story.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if story.playCount > 0 {
                        Text("•")
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
                Text("Favorite Stories")
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
            NavigationStack {
                AudioPlayerView(
                    story: story,
                    allStories: favorites,
                    storyIndex: favorites.firstIndex(where: { $0.id == story.id }) ?? 0
                )
            }
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
                    .fill(MagicalColors.primary.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "book.fill")
                            .foregroundColor(MagicalColors.primary)
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

// MARK: - Reading Insights Section
struct ReadingInsightsSection: View {
    let stories: [Story]
    let averageStoryLength: TimeInterval
    let totalPlayCount: Int

    @Environment(\.colorScheme) private var colorScheme

    private var mostListenedStory: Story? {
        stories.max { $0.playCount < $1.playCount }
    }

    private var averageListensPerStory: Double {
        guard !stories.isEmpty else { return 0 }
        return Double(totalPlayCount) / Double(stories.count)
    }

    private var preferredListeningTime: String {
        let calendar = Calendar.current
        let hours = stories.compactMap { calendar.component(.hour, from: $0.createdAt) }

        guard !hours.isEmpty else { return "No pattern yet" }

        let hourCounts = Dictionary(grouping: hours, by: { $0 })
        let mostCommonHour = hourCounts.max { $0.value.count < $1.value.count }?.key ?? 0

        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = calendar.date(from: DateComponents(hour: mostCommonHour)) ?? Date()

        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Reading Insights")
                .font(.title3)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                InsightRow(
                    icon: "clock",
                    label: "Average Story Length",
                    value: formatDuration(averageStoryLength)
                )

                InsightRow(
                    icon: "play.circle",
                    label: "Average Listens per Story",
                    value: String(format: "%.1f", averageListensPerStory)
                )

                InsightRow(
                    icon: "moon.stars",
                    label: "Preferred Listening Time",
                    value: preferredListeningTime
                )

                if let topStory = mostListenedStory, topStory.playCount > 0 {
                    InsightRow(
                        icon: "star.fill",
                        label: "Most Listened Story",
                        value: "\(topStory.title) (\(topStory.playCount) plays)"
                    )
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
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
                .foregroundColor(MagicalColors.primary)
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
enum TimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

struct ListeningDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
}

struct HeroStoryData: Identifiable {
    let id = UUID()
    let hero: Hero
    let storyCount: Int
}

struct Milestone: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let requirement: MilestoneRequirement

    enum MilestoneRequirement {
        case stories(Int)
        case listeningTime(TimeInterval)
        case streak(Int)
    }

    func isUnlocked(stories: Int, time: TimeInterval, streak: Int) -> Bool {
        switch requirement {
        case .stories(let required):
            return stories >= required
        case .listeningTime(let required):
            return time >= required
        case .streak(let required):
            return streak >= required
        }
    }

    static let allMilestones: [Milestone] = [
        Milestone(title: "First Story", icon: "book.closed", color: .blue, requirement: .stories(1)),
        Milestone(title: "Story Explorer", icon: "map", color: .green, requirement: .stories(5)),
        Milestone(title: "Story Master", icon: "crown", color: .purple, requirement: .stories(10)),
        Milestone(title: "Epic Reader", icon: "sparkles", color: .orange, requirement: .stories(25)),
        Milestone(title: "Legendary", icon: "star.fill", color: .yellow, requirement: .stories(50)),
        Milestone(title: "First Hour", icon: "clock", color: .blue, requirement: .listeningTime(3600)),
        Milestone(title: "Five Hours", icon: "headphones", color: .green, requirement: .listeningTime(18000)),
        Milestone(title: "Week Streak", icon: "flame", color: .orange, requirement: .streak(7)),
        Milestone(title: "Month Streak", icon: "calendar", color: .red, requirement: .streak(30))
    ]
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
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
            return "\(daysAgo) days ago"
        } else {
            return formatter.string(from: date)
        }
    }
}

// Note: Using the existing HeroAvatarImageView from Components folder

// MARK: - Preview
#Preview {
    ReadingJourneyView()
        .modelContainer(for: [Hero.self, Story.self], inMemory: true)
}