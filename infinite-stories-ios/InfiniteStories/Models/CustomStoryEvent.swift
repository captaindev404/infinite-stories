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
        case .daily: return String(localized: "customEvent.category.daily")
        case .adventure: return String(localized: "customEvent.category.adventure")
        case .emotional: return String(localized: "customEvent.category.emotional")
        case .learning: return String(localized: "customEvent.category.learning")
        case .celebration: return String(localized: "customEvent.category.celebration")
        case .challenge: return String(localized: "customEvent.category.challenge")
        case .imagination: return String(localized: "customEvent.category.imagination")
        case .custom: return String(localized: "customEvent.category.custom")
        case .general: return String(localized: "customEvent.category.general")
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

    var displayName: String {
        switch self {
        case .calming: return "Calming"
        case .exciting: return "Exciting"
        case .educational: return "Educational"
        case .funny: return "Funny"
        case .inspiring: return "Inspiring"
        case .mysterious: return "Mysterious"
        case .balanced: return "Balanced"
        case .cheerful: return "Cheerful"
        }
    }

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
        if usageCount == 0 {
            return "Never used"
        } else if usageCount == 1 {
            return "Used once"
        } else {
            return "Used \(usageCount) times"
        }
    }

    var timeSinceCreation: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var keywordsDisplay: String {
        if keywords.isEmpty {
            return "No keywords"
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
