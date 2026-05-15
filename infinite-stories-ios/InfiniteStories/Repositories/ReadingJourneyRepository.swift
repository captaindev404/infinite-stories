//
//  ReadingJourneyRepository.swift
//  InfiniteStories
//
//  Reading Journey analytics data access - API-only (no local persistence)
//  Provides access to reading statistics, activity charts, hero analytics,
//  milestones, and insights from the backend API.
//

import Foundation

// MARK: - Reading Journey Repository Protocol

protocol ReadingJourneyRepositoryProtocol {
    /// Fetches the analytics summary (total stories, listening time, streaks, favorites)
    func fetchSummary(forceRefresh: Bool) async throws -> AnalyticsSummary

    /// Fetches daily activity data (listening minutes per day) for a given time range
    func fetchActivity(range: TimeRange, forceRefresh: Bool) async throws -> ListeningActivityResponse

    /// Fetches per-hero analytics (story count, listening time, most active flag)
    func fetchHeroAnalytics(forceRefresh: Bool) async throws -> HeroAnalyticsResponse

    /// Fetches milestones with unlock status and progress
    func fetchMilestones(forceRefresh: Bool) async throws -> MilestonesResponse

    /// Fetches reading insights (average story length, preferred listening time, etc.)
    func fetchInsights(forceRefresh: Bool) async throws -> InsightsResponse

    /// Reports a listening session to the backend
    func reportSession(_ request: ListeningSessionRequest) async throws -> ListeningSession

    /// Invalidates all cached data (call after reporting a session)
    func invalidateCache()
}

// MARK: - Reading Journey Repository Implementation

@MainActor
class ReadingJourneyRepository: ReadingJourneyRepositoryProtocol {
    private let apiClient: APIClient

    /// Cache TTL in seconds (5 minutes)
    private static let cacheTTL: TimeInterval = 300

    /// Cached data with timestamps
    private var summaryCache: CachedData<AnalyticsSummary>?
    private var activityCache: [TimeRange: CachedData<ListeningActivityResponse>] = [:]
    private var heroAnalyticsCache: CachedData<HeroAnalyticsResponse>?
    private var milestonesCache: CachedData<MilestonesResponse>?
    private var insightsCache: CachedData<InsightsResponse>?

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Fetch Summary

    func fetchSummary(forceRefresh: Bool = false) async throws -> AnalyticsSummary {
        // Check network first
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        // Return cached data if valid and not force refreshing
        if !forceRefresh, let cached = summaryCache, cached.isValid {
            Logger.api.debug("Returning cached analytics summary")
            return cached.data
        }

        Logger.api.info("Fetching analytics summary from backend (refresh: \(forceRefresh))")

        let wrapper: APIResponse<AnalyticsSummary> = try await apiClient.request(.getAnalyticsSummary(refresh: forceRefresh))

        guard let data = wrapper.data else {
            throw APIError.unknown(NSError(
                domain: "ReadingJourneyRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in summary response"]
            ))
        }

        // Cache the result
        summaryCache = CachedData(data: data, ttl: Self.cacheTTL)
        Logger.api.success("Fetched analytics summary: \(data.totalStoriesListened) stories, \(data.currentStreak) day streak")

        return data
    }

    // MARK: - Fetch Activity

    func fetchActivity(range: TimeRange, forceRefresh: Bool = false) async throws -> ListeningActivityResponse {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        // Return cached data if valid and not force refreshing
        if !forceRefresh, let cached = activityCache[range], cached.isValid {
            Logger.api.debug("Returning cached activity data for \(range.rawValue)")
            return cached.data
        }

        Logger.api.info("Fetching listening activity for \(range.rawValue)")

        let wrapper: APIResponse<ListeningActivityResponse> = try await apiClient.request(.getListeningActivity(range: range))

        guard let data = wrapper.data else {
            throw APIError.unknown(NSError(
                domain: "ReadingJourneyRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in activity response"]
            ))
        }

        // Cache the result
        activityCache[range] = CachedData(data: data, ttl: Self.cacheTTL)
        Logger.api.success("Fetched \(data.activity.count) activity data points")

        return data
    }

    // MARK: - Fetch Hero Analytics

    func fetchHeroAnalytics(forceRefresh: Bool = false) async throws -> HeroAnalyticsResponse {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        // Return cached data if valid and not force refreshing
        if !forceRefresh, let cached = heroAnalyticsCache, cached.isValid {
            Logger.api.debug("Returning cached hero analytics")
            return cached.data
        }

        Logger.api.info("Fetching hero analytics")

        let wrapper: APIResponse<HeroAnalyticsResponse> = try await apiClient.request(.getHeroAnalytics)

        guard let data = wrapper.data else {
            throw APIError.unknown(NSError(
                domain: "ReadingJourneyRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in hero analytics response"]
            ))
        }

        // Cache the result
        heroAnalyticsCache = CachedData(data: data, ttl: Self.cacheTTL)
        Logger.api.success("Fetched analytics for \(data.heroes.count) heroes")

        return data
    }

    // MARK: - Fetch Milestones

    func fetchMilestones(forceRefresh: Bool = false) async throws -> MilestonesResponse {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        // Return cached data if valid and not force refreshing
        if !forceRefresh, let cached = milestonesCache, cached.isValid {
            Logger.api.debug("Returning cached milestones")
            return cached.data
        }

        Logger.api.info("Fetching milestones")

        let wrapper: APIResponse<MilestonesResponse> = try await apiClient.request(.getMilestones)

        guard let data = wrapper.data else {
            throw APIError.unknown(NSError(
                domain: "ReadingJourneyRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in milestones response"]
            ))
        }

        // Cache the result
        milestonesCache = CachedData(data: data, ttl: Self.cacheTTL)
        Logger.api.success("Fetched \(data.milestones.count) milestones (\(data.summary.unlockedCount) unlocked)")

        return data
    }

    // MARK: - Fetch Insights

    func fetchInsights(forceRefresh: Bool = false) async throws -> InsightsResponse {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        // Return cached data if valid and not force refreshing
        if !forceRefresh, let cached = insightsCache, cached.isValid {
            Logger.api.debug("Returning cached insights")
            return cached.data
        }

        Logger.api.info("Fetching reading insights")

        let wrapper: APIResponse<InsightsResponse> = try await apiClient.request(.getInsights)

        guard let data = wrapper.data else {
            throw APIError.unknown(NSError(
                domain: "ReadingJourneyRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in insights response"]
            ))
        }

        // Cache the result
        insightsCache = CachedData(data: data, ttl: Self.cacheTTL)
        Logger.api.success("Fetched reading insights")

        return data
    }

    // MARK: - Report Session

    func reportSession(_ request: ListeningSessionRequest) async throws -> ListeningSession {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Reporting listening session for story \(request.storyId)")

        let wrapper: APIResponse<ListeningSession> = try await apiClient.request(.reportListeningSession(data: request))

        guard let data = wrapper.data else {
            throw APIError.unknown(NSError(
                domain: "ReadingJourneyRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in session response"]
            ))
        }

        // Invalidate cache since analytics may have changed
        invalidateCache()

        Logger.api.success("Reported listening session (duration: \(data.duration ?? 0)s, completed: \(data.completed))")

        return data
    }

    // MARK: - Cache Management

    func invalidateCache() {
        summaryCache = nil
        activityCache.removeAll()
        heroAnalyticsCache = nil
        milestonesCache = nil
        insightsCache = nil
        Logger.api.debug("Invalidated all reading journey cache")
    }
}

// MARK: - Cache Helper

/// A simple in-memory cache wrapper with TTL support
private struct CachedData<T> {
    let data: T
    let cachedAt: Date
    let ttl: TimeInterval

    init(data: T, ttl: TimeInterval) {
        self.data = data
        self.cachedAt = Date()
        self.ttl = ttl
    }

    var isValid: Bool {
        Date().timeIntervalSince(cachedAt) < ttl
    }
}

// MARK: - Response DTOs

/// Analytics summary response from GET /api/v1/analytics/summary
struct AnalyticsSummary: Decodable {
    let totalStoriesListened: Int
    let totalListeningTimeMinutes: Int
    let currentStreak: Int
    let longestStreak: Int
    let favoriteStoriesCount: Int
    let lastListeningDate: String? // ISO8601 date string (YYYY-MM-DD)

    // Computed properties for UI
    var totalListeningTimeHours: Double {
        Double(totalListeningTimeMinutes) / 60.0
    }

    var formattedListeningTime: String {
        let hours = totalListeningTimeMinutes / 60
        let minutes = totalListeningTimeMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Activity data point for a single day
struct ActivityDataPoint: Decodable, Identifiable {
    let date: String // ISO date format: YYYY-MM-DD
    let minutes: Int // Total listening minutes for the day

    var id: String { date }

    /// Converts the date string to a Date object
    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    /// Returns minutes as Double for charting
    var minutesDouble: Double {
        Double(minutes)
    }
}

/// Listening activity response from GET /api/v1/analytics/activity
struct ListeningActivityResponse: Decodable {
    let range: String
    let timezone: String
    let startDate: String?
    let endDate: String?
    let activity: [ActivityDataPoint]
}

/// Hero analytics data for a single hero
struct HeroAnalytics: Decodable, Identifiable {
    let heroId: String
    let heroName: String
    let avatarUrl: String?
    let storiesCount: Int
    let totalListeningMinutes: Int
    let isMostActive: Bool

    var id: String { heroId }
}

/// Hero analytics response from GET /api/v1/analytics/heroes
struct HeroAnalyticsResponse: Decodable {
    let heroes: [HeroAnalytics]

    /// Returns the most active hero, if any
    var mostActiveHero: HeroAnalytics? {
        heroes.first { $0.isMostActive }
    }
}

/// Milestone data
struct MilestoneData: Decodable, Identifiable {
    let id: String
    let category: String
    let title: String
    let description: String
    let emoji: String?
    let unlocked: Bool
    let unlockedAt: String? // ISO8601 timestamp
    let progress: Int? // Current progress value (only if not unlocked)
    let target: Int? // Target value to unlock (only if not unlocked)
    let percentage: Int? // Progress percentage 0-100 (only if not unlocked)

    /// Converts unlockedAt to Date
    var unlockedDate: Date? {
        guard let unlockedAt = unlockedAt else { return nil }
        return ISO8601DateFormatter().date(from: unlockedAt)
    }
}

/// Milestone summary
struct MilestoneSummary: Decodable {
    let totalMilestones: Int
    let unlockedCount: Int
    let newlyUnlocked: [String]? // IDs of newly unlocked milestones
}

/// Milestones response from GET /api/v1/analytics/milestones
struct MilestonesResponse: Decodable {
    let milestones: [MilestoneData]
    let summary: MilestoneSummary

    /// Returns only unlocked milestones
    var unlockedMilestones: [MilestoneData] {
        milestones.filter { $0.unlocked }
    }

    /// Returns the next milestone to unlock (lowest progress percentage)
    var nextMilestone: MilestoneData? {
        milestones.filter { !$0.unlocked }.min { ($0.percentage ?? 0) > ($1.percentage ?? 0) }
    }
}

/// Most listened story data
struct MostListenedStory: Decodable {
    let storyId: String
    let title: String
    let playCount: Int
}

/// Reading insights data
struct Insights: Decodable {
    let averageStoryLengthMinutes: Double?
    let averageListensPerStory: Double?
    let preferredListeningHour: Int? // 0-23
    let preferredListeningPeriod: String? // "morning", "afternoon", "evening", "night"
    let mostListenedStory: MostListenedStory?
    let totalUniqueStoriesListened: Int

    /// Formats the preferred listening hour for display
    /// BUG-18: Previously hardcoded `h a` which forced English AM/PM inside
    /// French UI (e.g. "Heure d'Écoute Préférée: 2 PM"). Now uses the current
    /// user locale with short time style so FR renders "14:00" / "14 h".
    var formattedPreferredTime: String {
        guard let hour = preferredListeningHour else {
            return String(localized: "journey.insights.preferredTime.noData")
        }

        var components = DateComponents()
        components.hour = hour
        components.minute = 0

        guard let date = Calendar.current.date(from: components) else {
            return "\(hour):00"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = .current
        return formatter.string(from: date)
    }

    /// Formats the preferred listening period for display
    var formattedListeningPeriod: String {
        guard let period = preferredListeningPeriod else { return "No pattern yet" }

        switch period {
        case "morning": return "Morning (6am-12pm)"
        case "afternoon": return "Afternoon (12pm-5pm)"
        case "evening": return "Evening (5pm-9pm)"
        case "night": return "Night (9pm-6am)"
        default: return period.capitalized
        }
    }
}

/// Insights response from GET /api/v1/analytics/insights
struct InsightsResponse: Decodable {
    let insights: Insights
}

/// Listening session response from POST /api/v1/analytics/sessions
struct ListeningSession: Decodable, Identifiable {
    let id: String
    let userId: String
    let storyId: String
    let startedAt: Date
    let endedAt: Date?
    let duration: Int? // seconds
    let completed: Bool
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Shared Types

/// Time range for analytics queries - used across views and API calls
/// This is the single source of truth for TimeRange in the app
enum TimeRange: String, CaseIterable, Identifiable, Hashable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"

    var id: String { rawValue }

    /// Number of days in this time range
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .all: return 365 * 10
        }
    }

    /// The API query parameter value for this time range
    var apiValue: String {
        switch self {
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        case .all: return "all"
        }
    }

    /// BUG-15: Localized label for the chart range picker. The rawValue is
    /// kept as the stable API key ("Week", etc.); views should display this
    /// localized variant instead.
    var localizedName: String {
        switch self {
        case .week: return String(localized: "journey.timeRange.week")
        case .month: return String(localized: "journey.timeRange.month")
        case .year: return String(localized: "journey.timeRange.year")
        case .all: return String(localized: "journey.timeRange.all", defaultValue: "All Time")
        }
    }
}
