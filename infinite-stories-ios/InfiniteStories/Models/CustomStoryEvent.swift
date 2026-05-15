//
//  CustomStoryEvent.swift
//  InfiniteStories
//
//  Created on 2025-09-14.
//

import Foundation

// MARK: - Supporting Enums

enum EventCategory: String, Codable, CaseIterable {
    case daily = "daily"
    case adventure = "adventure"
    case emotional = "emotional"
    case learning = "learning"
    case celebration = "celebration"
    case challenge = "challenge"
    case imagination = "imagination"
    case custom = "custom"
    case general = "general"

    // BUG-15: FR users were seeing the English category labels ("Daily Life",
    // "Learning", etc.) in the category filter pills. The display name now
    // goes through Localizable.xcstrings so each locale renders its own term.
    var displayName: String {
        switch self {
        case .daily: return String(localized: "customEvent.category.daily", comment: "Event category label: Daily Life")
        case .adventure: return String(localized: "customEvent.category.adventure", comment: "Event category label: Adventure")
        case .emotional: return String(localized: "customEvent.category.emotional", comment: "Event category label: Emotional Growth")
        case .learning: return String(localized: "customEvent.category.learning", comment: "Event category label: Learning")
        case .celebration: return String(localized: "customEvent.category.celebration", comment: "Event category label: Celebration")
        case .challenge: return String(localized: "customEvent.category.challenge", comment: "Event category label: Challenge")
        case .imagination: return String(localized: "customEvent.category.imagination", comment: "Event category label: Imagination")
        case .custom: return String(localized: "customEvent.category.custom", comment: "Event category label: Custom")
        case .general: return String(localized: "customEvent.category.general", comment: "Event category label: General")
        }
    }

    var icon: String {
        switch self {
        case .daily: return "calendar"
        case .adventure: return "map"
        case .emotional: return "heart"
        case .learning: return "graduationcap"
        case .celebration: return "party.popper"
        case .challenge: return "trophy"
        case .imagination: return "sparkles"
        case .custom: return "star"
        case .general: return "book"
        }
    }

    var defaultColor: String {
        switch self {
        case .daily: return "#007AFF"
        case .adventure: return "#34C759"
        case .emotional: return "#FF3B30"
        case .learning: return "#5856D6"
        case .celebration: return "#FF9500"
        case .challenge: return "#AF52DE"
        case .imagination: return "#FF2D55"
        case .custom: return "#00C7BE"
        case .general: return "#8E8E93"
        }
    }
}

/// ⚠️ **Wire-format contract — DO NOT EDIT rawValue strings.**
///
/// The rawValues `"2-4 years"`, `"4-6 years"`, `"6-10 years"`, `"All Ages"`
/// are persisted to the backend `ageRange` field on `CustomStoryEvent` and
/// decoded from backend responses. Changing any of them silently corrupts
/// every existing user's custom-event records on the next sync.
///
/// For UI display, call `localizedName` (routes through xcstrings).
/// For API / analytics / logs, call `apiIdentifier` (an alias for rawValue).
///
/// A structural fix that separates display from wire format is tracked under
/// task #89 and requires a coordinated backend release.
enum AgeRange: String, Codable, CaseIterable {
    case toddler = "2-4 years"
    case preschool = "4-6 years"
    case elementary = "6-10 years"
    case all = "All Ages"

    var minAge: Int {
        switch self {
        case .toddler: return 2
        case .preschool: return 4
        case .elementary: return 6
        case .all: return 2
        }
    }

    var maxAge: Int {
        switch self {
        case .toddler: return 4
        case .preschool: return 6
        case .elementary: return 10
        case .all: return 10
        }
    }

    // BUG-L10N-08: the rawValue doubles as an API identifier (e.g. "All Ages")
    // and was being rendered verbatim in the FR custom-event detail badge.
    // Use localizedName for any UI display so French users see "Tous âges"
    // instead of the English rawValue. The rawValue/wire-format contract is
    // pinned by the `AgeRangeWireFormatTests` suite — see task #89 for the
    // planned structural split that decouples display from wire format.
    var localizedName: String {
        switch self {
        case .toddler: return String(localized: "customEvent.ageRange.toddler", comment: "Custom event age-range badge: toddler 2-4 years")
        case .preschool: return String(localized: "customEvent.ageRange.preschool", comment: "Custom event age-range badge: preschool 4-6 years")
        case .elementary: return String(localized: "customEvent.ageRange.elementary", comment: "Custom event age-range badge: elementary 6-10 years")
        case .all: return String(localized: "customEvent.ageRange.all", comment: "Custom event age-range badge: all ages")
        }
    }

    /// English rawValue used for API payloads, analytics, and logs.
    /// Do NOT use this for user-facing display — call `localizedName` instead.
    /// The rawValue is also the wire-format identifier persisted to the backend;
    /// see the enum-level doc and task #89 for the planned structural split.
    var apiIdentifier: String { rawValue }
}

enum StoryTone: String, Codable, CaseIterable {
    case calming = "calming"
    case exciting = "exciting"
    case educational = "educational"
    case funny = "funny"
    case inspiring = "inspiring"
    case mysterious = "mysterious"
    case balanced = "balanced"
    case cheerful = "cheerful"

    // BUG-L10N-08 / #87: Prior to this change `displayName` returned the English
    // rawValue. It was aliased to `localizedName` during the l10n sweep, which
    // silently broke the "displayName is English" contract and risked FR strings
    // leaking into logs, analytics, and API payloads. The alias is removed: UI
    // call sites must use `localizedName` explicitly, non-UI sites must use
    // `apiIdentifier` (English rawValue, locale-independent).
    var localizedName: String {
        switch self {
        case .calming: return String(localized: "customEvent.tone.calming", comment: "Custom event mood badge: calming")
        case .exciting: return String(localized: "customEvent.tone.exciting", comment: "Custom event mood badge: exciting")
        case .educational: return String(localized: "customEvent.tone.educational", comment: "Custom event mood badge: educational")
        case .funny: return String(localized: "customEvent.tone.funny", comment: "Custom event mood badge: funny")
        case .inspiring: return String(localized: "customEvent.tone.inspiring", comment: "Custom event mood badge: inspiring")
        case .mysterious: return String(localized: "customEvent.tone.mysterious", comment: "Custom event mood badge: mysterious")
        case .balanced: return String(localized: "customEvent.tone.balanced", comment: "Custom event mood badge: balanced")
        case .cheerful: return String(localized: "customEvent.tone.cheerful", comment: "Custom event mood badge: cheerful")
        }
    }

    /// English, locale-independent identifier used for API payloads, analytics
    /// events, and logs. Do NOT show this to users — use `localizedName`.
    var apiIdentifier: String { rawValue }

    var description: String {
        switch self {
        case .calming: return "Peaceful and soothing, perfect for bedtime"
        case .exciting: return "Action-packed and thrilling adventures"
        case .educational: return "Learn something new while having fun"
        case .funny: return "Filled with humor and giggles"
        case .inspiring: return "Uplifting and motivational"
        case .mysterious: return "Intriguing puzzles and discoveries"
        case .balanced: return "A mix of everything"
        case .cheerful: return "Bright and happy adventures"
        }
    }
}

// MARK: - CustomStoryEvent Model (API-based, not persisted locally)

struct CustomStoryEvent: Codable, Identifiable, Hashable {
    let id: String  // Server-assigned cuid
    var title: String
    var description: String
    var promptSeed: String
    var category: String
    var ageRange: String?
    var tone: String
    var keywords: [String]
    var usageCount: Int
    var isFavorite: Bool
    var aiEnhanced: Bool
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    var eventCategory: EventCategory {
        EventCategory(rawValue: category) ?? .general
    }

    var storyTone: StoryTone {
        StoryTone(rawValue: tone) ?? .cheerful
    }

    var eventAgeRange: AgeRange? {
        guard let ageRange = ageRange else { return nil }
        return AgeRange(rawValue: ageRange)
    }

    var iconName: String {
        eventCategory.icon
    }

    var colorHex: String {
        eventCategory.defaultColor
    }

    var formattedUsageCount: String {
        // BUG-A08: localized usage-count labels so French users no longer see
        // "Never used" / "Used 5 times" in the event card footer.
        if usageCount == 0 {
            return String(localized: "customEvent.usage.never",
                          comment: "Usage label for a custom event that has never been used.")
        } else if usageCount == 1 {
            return String(localized: "customEvent.usage.once",
                          comment: "Usage label when a custom event has been used exactly once.")
        } else {
            return String(
                format: String(localized: "customEvent.usage.times",
                               comment: "Usage label for custom events used multiple times; %d is the count."),
                usageCount
            )
        }
    }

    var timeSinceCreation: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var keywordsDisplay: String {
        if keywords.isEmpty {
            // NOTE: catalog state is `new` — EN fallback kept until the key
            // is translated. See Task #86 report.
            return String(localized: "customEvent.keywords.none",
                          defaultValue: "No keywords",
                          comment: "Default value for the text displayed when a custom story event has no keywords.")
        }
        return keywords.prefix(3).joined(separator: ", ") + (keywords.count > 3 ? "..." : "")
    }

    // MARK: - Initializers

    /// Create a new custom event for API submission (id will be assigned by server)
    init(
        title: String,
        description: String,
        promptSeed: String,
        category: EventCategory = .custom,
        ageRange: AgeRange? = .all,
        tone: StoryTone = .cheerful
    ) {
        self.id = "" // Will be assigned by server
        self.title = title
        self.description = description
        self.promptSeed = promptSeed
        self.category = category.rawValue
        self.ageRange = ageRange?.rawValue
        self.tone = tone.rawValue
        self.keywords = []
        self.usageCount = 0
        self.isFavorite = false
        self.aiEnhanced = false
        self.lastUsedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CustomStoryEvent, rhs: CustomStoryEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - API Response DTOs

struct CustomEventResponse: Decodable {
    let id: String
    let userId: String
    let title: String
    let description: String
    let promptSeed: String
    let category: String
    let ageRange: String?
    let tone: String
    let keywords: [String]?
    let aiEnhanced: Bool
    let usageCount: Int
    let isFavorite: Bool
    let lastUsedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    func toCustomStoryEvent() -> CustomStoryEvent {
        CustomStoryEvent(
            id: id,
            title: title,
            description: description,
            promptSeed: promptSeed,
            category: category,
            ageRange: ageRange,
            tone: tone,
            keywords: keywords ?? [],
            usageCount: usageCount,
            isFavorite: isFavorite,
            aiEnhanced: aiEnhanced,
            lastUsedAt: lastUsedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct CustomEventsListWrapper: Decodable {
    let data: CustomEventsListResponse
}

struct CustomEventsListResponse: Decodable {
    let customEvents: [CustomEventResponse]
    let pagination: Pagination?
}

// MARK: - Private Extension for Full Initializer

private extension CustomStoryEvent {
    init(
        id: String,
        title: String,
        description: String,
        promptSeed: String,
        category: String,
        ageRange: String?,
        tone: String,
        keywords: [String],
        usageCount: Int,
        isFavorite: Bool,
        aiEnhanced: Bool,
        lastUsedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.promptSeed = promptSeed
        self.category = category
        self.ageRange = ageRange
        self.tone = tone
        self.keywords = keywords
        self.usageCount = usageCount
        self.isFavorite = isFavorite
        self.aiEnhanced = aiEnhanced
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Preview Data

extension CustomStoryEvent {
    static var previewData: [CustomStoryEvent] {
        [
            CustomStoryEvent(
                id: "preview-1",
                title: "First Day at School",
                description: "A story about overcoming nervousness and making new friends on the first day of school",
                promptSeed: "an adventure about starting school, making friends, and discovering that new experiences can be exciting",
                category: "learning",
                ageRange: "4-6 years",
                tone: "inspiring",
                keywords: ["school", "friends", "courage"],
                usageCount: 5,
                isFavorite: true,
                aiEnhanced: true,
                lastUsedAt: Date(),
                createdAt: Date(),
                updatedAt: Date()
            ),
            CustomStoryEvent(
                id: "preview-2",
                title: "Lost Teddy Bear",
                description: "Finding a beloved toy that went missing during a family trip",
                promptSeed: "a heartwarming journey to reunite with a cherished teddy bear, learning about responsibility and perseverance",
                category: "emotional",
                ageRange: "2-4 years",
                tone: "calming",
                keywords: ["teddy", "adventure", "love"],
                usageCount: 2,
                isFavorite: false,
                aiEnhanced: false,
                lastUsedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            CustomStoryEvent(
                id: "preview-3",
                title: "Backyard Camping",
                description: "An exciting camping adventure right in the backyard",
                promptSeed: "a magical night under the stars in the backyard, discovering nature's wonders and family bonding",
                category: "adventure",
                ageRange: "6-10 years",
                tone: "exciting",
                keywords: ["camping", "stars", "nature"],
                usageCount: 0,
                isFavorite: false,
                aiEnhanced: false,
                lastUsedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
}
