//
//  ReadingJourneyRepositoryTests.swift
//  InfiniteStoriesTests
//
//  Unit tests for ReadingJourneyRepository DTOs and computed properties
//

import Testing
import Foundation
@testable import InfiniteStories

// MARK: - Test Data Helpers

/// Helper to create AnalyticsSummary from JSON
func createMockSummary(
    totalStoriesListened: Int = 10,
    totalListeningTimeMinutes: Int = 120,
    currentStreak: Int = 5,
    longestStreak: Int = 10,
    favoriteStoriesCount: Int = 3,
    lastListeningDate: String? = "2024-12-15"
) -> AnalyticsSummary {
    let json = """
    {
        "totalStoriesListened": \(totalStoriesListened),
        "totalListeningTimeMinutes": \(totalListeningTimeMinutes),
        "currentStreak": \(currentStreak),
        "longestStreak": \(longestStreak),
        "favoriteStoriesCount": \(favoriteStoriesCount),
        "lastListeningDate": \(lastListeningDate.map { "\"\($0)\"" } ?? "null")
    }
    """
    return try! JSONDecoder().decode(AnalyticsSummary.self, from: json.data(using: .utf8)!)
}

/// Helper to create ListeningActivityResponse from JSON
func createMockActivity(
    range: String = "week",
    activityPoints: [(date: String, minutes: Int)] = [("2024-12-15", 30)]
) -> ListeningActivityResponse {
    let activityJson = activityPoints.isEmpty ? "[]" : "[" + activityPoints.map { "{\"date\": \"\($0.date)\", \"minutes\": \($0.minutes)}" }.joined(separator: ", ") + "]"
    let json = """
    {
        "range": "\(range)",
        "timezone": "America/New_York",
        "startDate": "2024-12-09",
        "endDate": "2024-12-15",
        "activity": \(activityJson)
    }
    """
    return try! JSONDecoder().decode(ListeningActivityResponse.self, from: json.data(using: .utf8)!)
}

/// Helper to create HeroAnalyticsResponse from JSON
func createMockHeroAnalytics(heroCount: Int = 2) -> HeroAnalyticsResponse {
    var heroesJson = "["
    for i in 0..<heroCount {
        if i > 0 { heroesJson += "," }
        heroesJson += """
        {
            "heroId": "hero-\(i)",
            "heroName": "Hero \(i)",
            "avatarUrl": null,
            "storiesCount": \(i * 5 + 1),
            "totalListeningMinutes": \(i * 30 + 10),
            "isMostActive": \(i == 0)
        }
        """
    }
    heroesJson += "]"

    let json = """
    {
        "heroes": \(heroesJson)
    }
    """
    return try! JSONDecoder().decode(HeroAnalyticsResponse.self, from: json.data(using: .utf8)!)
}

/// Helper to create MilestonesResponse from JSON
func createMockMilestones(unlockedCount: Int = 3, totalCount: Int = 10) -> MilestonesResponse {
    let json = """
    {
        "milestones": [
            {
                "id": "FIRST_STORY",
                "category": "stories",
                "title": "First Story",
                "description": "Listen to your first story",
                "emoji": "1",
                "unlocked": true,
                "unlockedAt": "2024-12-01T10:00:00Z",
                "progress": null,
                "target": null,
                "percentage": null
            },
            {
                "id": "STORIES_5",
                "category": "stories",
                "title": "Story Explorer",
                "description": "Listen to 5 stories",
                "emoji": "5",
                "unlocked": false,
                "unlockedAt": null,
                "progress": 3,
                "target": 5,
                "percentage": 60
            }
        ],
        "summary": {
            "totalMilestones": \(totalCount),
            "unlockedCount": \(unlockedCount),
            "newlyUnlocked": null
        }
    }
    """
    return try! JSONDecoder().decode(MilestonesResponse.self, from: json.data(using: .utf8)!)
}

/// Helper to create InsightsResponse from JSON
func createMockInsights(
    preferredHour: Int? = 20,
    preferredPeriod: String? = "evening"
) -> InsightsResponse {
    let json = """
    {
        "insights": {
            "averageStoryLengthMinutes": 5.5,
            "averageListensPerStory": 2.3,
            "preferredListeningHour": \(preferredHour.map { String($0) } ?? "null"),
            "preferredListeningPeriod": \(preferredPeriod.map { "\"\($0)\"" } ?? "null"),
            "mostListenedStory": {
                "storyId": "story-123",
                "title": "The Brave Adventure",
                "playCount": 15
            },
            "totalUniqueStoriesListened": 25
        }
    }
    """
    return try! JSONDecoder().decode(InsightsResponse.self, from: json.data(using: .utf8)!)
}

/// Helper to create ListeningSession from JSON
func createMockSession(
    id: String = "session-123",
    storyId: String = "story-456",
    duration: Int = 300,
    completed: Bool = true
) -> ListeningSession {
    let json = """
    {
        "id": "\(id)",
        "userId": "user-789",
        "storyId": "\(storyId)",
        "startedAt": "2024-12-15T19:00:00.000Z",
        "endedAt": "2024-12-15T19:05:00.000Z",
        "duration": \(duration),
        "completed": \(completed),
        "createdAt": "2024-12-15T19:05:00.000Z",
        "updatedAt": "2024-12-15T19:05:00.000Z"
    }
    """

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try! decoder.decode(ListeningSession.self, from: json.data(using: .utf8)!)
}

// MARK: - Analytics Summary Tests

@Suite("AnalyticsSummary Tests")
struct AnalyticsSummaryTests {

    @Test("formats listening time with hours and minutes")
    func formatsTimeWithHoursAndMinutes() async throws {
        let summary = createMockSummary(totalListeningTimeMinutes: 150)
        #expect(summary.formattedListeningTime == "2h 30m")
    }

    @Test("formats listening time with minutes only")
    func formatsTimeMinutesOnly() async throws {
        let shortSummary = createMockSummary(totalListeningTimeMinutes: 45)
        #expect(shortSummary.formattedListeningTime == "45m")
    }

    @Test("formats listening time with exact hours")
    func formatsTimeExactHours() async throws {
        let longSummary = createMockSummary(totalListeningTimeMinutes: 60)
        #expect(longSummary.formattedListeningTime == "1h 0m")
    }

    @Test("calculates listening time in hours")
    func calculatesHours() async throws {
        let summary = createMockSummary(totalListeningTimeMinutes: 90)
        #expect(summary.totalListeningTimeHours == 1.5)
    }

    @Test("decodes all properties correctly")
    func decodesProperties() async throws {
        let summary = createMockSummary(
            totalStoriesListened: 25,
            totalListeningTimeMinutes: 180,
            currentStreak: 7,
            longestStreak: 14,
            favoriteStoriesCount: 5
        )

        #expect(summary.totalStoriesListened == 25)
        #expect(summary.totalListeningTimeMinutes == 180)
        #expect(summary.currentStreak == 7)
        #expect(summary.longestStreak == 14)
        #expect(summary.favoriteStoriesCount == 5)
    }
}

// MARK: - Activity Tests

@Suite("ListeningActivity Tests")
struct ListeningActivityTests {

    @Test("parses date correctly")
    func parsesDate() async throws {
        let response = createMockActivity()
        #expect(response.activity.count > 0)

        let firstPoint = response.activity[0]
        #expect(firstPoint.dateValue != nil)
    }

    @Test("returns minutes as Double for charting")
    func minutesAsDouble() async throws {
        let response = createMockActivity(activityPoints: [("2024-12-15", 45)])
        let firstPoint = response.activity[0]
        #expect(firstPoint.minutesDouble == 45.0)
    }

    @Test("handles multiple activity points")
    func multipleActivityPoints() async throws {
        let response = createMockActivity(activityPoints: [
            ("2024-12-15", 30),
            ("2024-12-14", 45),
            ("2024-12-13", 60)
        ])
        #expect(response.activity.count == 3)
    }

    @Test("activity point identifiable by date")
    func activityPointIdentifiable() async throws {
        let response = createMockActivity(activityPoints: [("2024-12-15", 30)])
        let firstPoint = response.activity[0]
        #expect(firstPoint.id == "2024-12-15")
    }
}

// MARK: - Hero Analytics Tests

@Suite("HeroAnalytics Tests")
struct HeroAnalyticsTests {

    @Test("finds most active hero")
    func findsMostActive() async throws {
        let response = createMockHeroAnalytics(heroCount: 3)

        #expect(response.heroes.count == 3)
        #expect(response.mostActiveHero != nil)
        #expect(response.mostActiveHero?.isMostActive == true)
    }

    @Test("handles empty heroes")
    func handlesEmpty() async throws {
        let response = createMockHeroAnalytics(heroCount: 0)

        #expect(response.heroes.isEmpty)
        #expect(response.mostActiveHero == nil)
    }

    @Test("hero is identifiable by heroId")
    func heroIdentifiable() async throws {
        let response = createMockHeroAnalytics(heroCount: 1)
        let hero = response.heroes[0]
        #expect(hero.id == "hero-0")
    }
}

// MARK: - Milestones Tests

@Suite("Milestones Tests")
struct MilestonesTests {

    @Test("filters unlocked milestones")
    func filtersUnlocked() async throws {
        let response = createMockMilestones()

        let unlocked = response.unlockedMilestones
        #expect(unlocked.allSatisfy { $0.unlocked })
    }

    @Test("finds next milestone")
    func findsNext() async throws {
        let response = createMockMilestones()

        let next = response.nextMilestone
        #expect(next != nil)
        #expect(next?.unlocked == false)
    }

    @Test("parses unlocked date")
    func parsesUnlockedDate() async throws {
        let response = createMockMilestones()
        let unlockedMilestone = response.milestones.first { $0.unlocked }

        #expect(unlockedMilestone?.unlockedDate != nil)
    }

    @Test("milestone has progress info when locked")
    func milestoneProgress() async throws {
        let response = createMockMilestones()
        let lockedMilestone = response.milestones.first { !$0.unlocked }

        #expect(lockedMilestone?.progress == 3)
        #expect(lockedMilestone?.target == 5)
        #expect(lockedMilestone?.percentage == 60)
    }
}

// MARK: - Insights Tests

@Suite("Insights Tests")
struct InsightsTests {

    @Test("formats preferred time")
    func formatsPreferredTime() async throws {
        let response = createMockInsights(preferredHour: 20)
        let insights = response.insights

        // BUG-18: `formattedPreferredTime` now uses `DateFormatter.short` with
        // the current locale, so the output varies by locale (e.g. "8:00 PM"
        // in en_US, "20:00" in fr_FR). Build the expected value dynamically
        // so the test stays locale-independent while still verifying that
        // hour 20 is rendered via the same short-time formatter.
        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let date = Calendar.current.date(from: components)!

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = .current
        let expected = formatter.string(from: date)

        #expect(insights.formattedPreferredTime == expected)
        #expect(!insights.formattedPreferredTime.isEmpty)
    }

    @Test("formats listening period")
    func formatsListeningPeriod() async throws {
        let response = createMockInsights(preferredPeriod: "evening")
        let insights = response.insights

        #expect(insights.formattedListeningPeriod.contains("Evening"))
    }

    @Test("handles nil preferred hour")
    func handlesNilHour() async throws {
        let response = createMockInsights(preferredHour: nil, preferredPeriod: nil)

        // BUG-18: The "no data" placeholder is now localized via xcstrings,
        // so compare against the resolved localized string rather than a
        // hardcoded English literal.
        let expectedNoData = String(localized: "journey.insights.preferredTime.noData")
        #expect(response.insights.formattedPreferredTime == expectedNoData)
        #expect(!response.insights.formattedPreferredTime.isEmpty)
        #expect(response.insights.formattedListeningPeriod == "No pattern yet")
    }

    @Test("formats morning period")
    func formatsMorningPeriod() async throws {
        let response = createMockInsights(preferredPeriod: "morning")
        #expect(response.insights.formattedListeningPeriod.contains("Morning"))
    }

    @Test("formats afternoon period")
    func formatsAfternoonPeriod() async throws {
        let response = createMockInsights(preferredPeriod: "afternoon")
        #expect(response.insights.formattedListeningPeriod.contains("Afternoon"))
    }

    @Test("formats night period")
    func formatsNightPeriod() async throws {
        let response = createMockInsights(preferredPeriod: "night")
        #expect(response.insights.formattedListeningPeriod.contains("Night"))
    }
}

// MARK: - TimeRange Tests

@Suite("TimeRange Tests")
struct TimeRangeTests {

    @Test("week has correct day count")
    func weekDays() async throws {
        #expect(TimeRange.week.days == 7)
    }

    @Test("month has correct day count")
    func monthDays() async throws {
        #expect(TimeRange.month.days == 30)
    }

    @Test("year has correct day count")
    func yearDays() async throws {
        #expect(TimeRange.year.days == 365)
    }

    @Test("week has correct API value")
    func weekAPIValue() async throws {
        #expect(TimeRange.week.apiValue == "week")
    }

    @Test("month has correct API value")
    func monthAPIValue() async throws {
        #expect(TimeRange.month.apiValue == "month")
    }

    @Test("year has correct API value")
    func yearAPIValue() async throws {
        #expect(TimeRange.year.apiValue == "year")
    }

    @Test("is CaseIterable with 3 cases")
    func caseIterable() async throws {
        #expect(TimeRange.allCases.count == 3)
    }

    @Test("is Hashable")
    func isHashable() async throws {
        var set = Set<TimeRange>()
        set.insert(.week)
        set.insert(.month)
        set.insert(.year)
        #expect(set.count == 3)
    }

    @Test("uses rawValue for display")
    func rawValueDisplay() async throws {
        #expect(TimeRange.week.rawValue == "Week")
        #expect(TimeRange.month.rawValue == "Month")
        #expect(TimeRange.year.rawValue == "Year")
    }
}

// MARK: - ListeningSession Tests

@Suite("ListeningSession Tests")
struct ListeningSessionTests {

    @Test("decodes all properties")
    func decodesProperties() async throws {
        let session = createMockSession(
            id: "test-session",
            storyId: "test-story",
            duration: 600,
            completed: false
        )

        #expect(session.id == "test-session")
        #expect(session.storyId == "test-story")
        #expect(session.duration == 600)
        #expect(session.completed == false)
    }

    @Test("is Identifiable")
    func isIdentifiable() async throws {
        let session = createMockSession(id: "unique-id")
        #expect(session.id == "unique-id")
    }

    @Test("has dates parsed correctly")
    func datesParseCorrectly() async throws {
        let session = createMockSession()
        #expect(session.startedAt != nil)
        #expect(session.createdAt != nil)
        #expect(session.updatedAt != nil)
    }
}
