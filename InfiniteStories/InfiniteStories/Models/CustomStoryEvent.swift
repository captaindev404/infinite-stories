//
//  CustomStoryEvent.swift
//  InfiniteStories
//
//  Created on 2025-09-14.
//

import Foundation
import SwiftData

// MARK: - Supporting Enums

enum EventCategory: String, Codable, CaseIterable {
    case daily = "Daily Life"
    case adventure = "Adventure"
    case emotional = "Emotional Growth"
    case learning = "Learning"
    case celebration = "Celebration"
    case challenge = "Challenge"
    case imagination = "Imagination"
    case custom = "Custom"
    
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
    case calming = "Calming"
    case exciting = "Exciting"
    case educational = "Educational"
    case funny = "Funny"
    case inspiring = "Inspiring"
    case mysterious = "Mysterious"
    case balanced = "Balanced"

    var description: String {
        switch self {
        case .calming: return "Peaceful and soothing, perfect for bedtime"
        case .exciting: return "Action-packed and thrilling adventures"
        case .educational: return "Learn something new while having fun"
        case .funny: return "Filled with humor and giggles"
        case .inspiring: return "Uplifting and motivational"
        case .mysterious: return "Intriguing puzzles and discoveries"
        case .balanced: return "A mix of everything"
        }
    }
}

// MARK: - Pictogram Style

enum PictogramStyle: String, Codable, CaseIterable {
    case playful = "playful"
    case minimalist = "minimalist"
    case storybook = "storybook"
    case geometric = "geometric"
    case watercolor = "watercolor"

    var displayName: String {
        switch self {
        case .playful: return "Playful"
        case .minimalist: return "Minimalist"
        case .storybook: return "Storybook"
        case .geometric: return "Geometric"
        case .watercolor: return "Watercolor"
        }
    }

    var stylePrompt: String {
        switch self {
        case .playful:
            return "playful, colorful, child-friendly icon style with rounded shapes and bright colors"
        case .minimalist:
            return "simple, clean, minimalist icon design with solid colors and clear symbolism"
        case .storybook:
            return "whimsical storybook illustration style with magical elements and soft edges"
        case .geometric:
            return "modern geometric shapes and patterns with bold colors and clean lines"
        case .watercolor:
            return "soft watercolor artistic style with gentle brushstrokes and pastel colors"
        }
    }

    var icon: String {
        switch self {
        case .playful: return "face.smiling.fill"
        case .minimalist: return "square.fill"
        case .storybook: return "book.fill"
        case .geometric: return "hexagon.fill"
        case .watercolor: return "paintbrush.fill"
        }
    }
}

// MARK: - CustomStoryEvent Model

@Model
final class CustomStoryEvent {
    var id: UUID
    var title: String
    var eventDescription: String
    var promptSeed: String
    var category: EventCategory
    var ageRange: AgeRange
    var tone: StoryTone
    var keywords: [String]
    var iconName: String
    var colorHex: String
    var createdAt: Date
    var lastUsed: Date?
    var usageCount: Int
    var isAIEnhanced: Bool
    var isFavorite: Bool

    // Pictogram properties
    var pictogramPath: String?
    var pictogramPrompt: String?
    var pictogramGeneratedAt: Date?
    var pictogramStyle: PictogramStyle?
    var pictogramFailureCount: Int
    var lastPictogramError: String?

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \Story.customEvent)
    var stories: [Story]?
    
    init(
        title: String,
        description: String,
        promptSeed: String,
        category: EventCategory = .custom,
        ageRange: AgeRange = .all,
        tone: StoryTone = .balanced
    ) {
        self.id = UUID()
        self.title = title
        self.eventDescription = description
        self.promptSeed = promptSeed
        self.category = category
        self.ageRange = ageRange
        self.tone = tone
        self.keywords = []
        self.iconName = category.icon
        self.colorHex = category.defaultColor
        self.createdAt = Date()
        self.lastUsed = nil
        self.usageCount = 0
        self.isAIEnhanced = false
        self.isFavorite = false
        self.pictogramFailureCount = 0
    }
    
    // Convenience properties
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

    // Pictogram computed properties
    var hasPictogram: Bool {
        guard let path = pictogramPath else { return false }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("EventPictograms")
            .appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: url.path)
    }

    var pictogramURL: URL? {
        guard let path = pictogramPath, hasPictogram else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("EventPictograms")
            .appendingPathComponent(path)
    }

    var needsPictogramRegeneration: Bool {
        return !hasPictogram && pictogramFailureCount > 0 && pictogramFailureCount < 3
    }

    // Methods
    func incrementUsage() {
        usageCount += 1
        lastUsed = Date()
    }
    
    func updateWithAIEnhancement(
        enhancedPrompt: String,
        keywords: [String]
    ) {
        self.promptSeed = enhancedPrompt
        self.keywords = keywords
        self.isAIEnhanced = true
    }
    
    func toggleFavorite() {
        isFavorite.toggle()
    }
}

// MARK: - Preview Data

extension CustomStoryEvent {
    static var previewData: [CustomStoryEvent] {
        [
            CustomStoryEvent(
                title: "First Day at School",
                description: "A story about overcoming nervousness and making new friends on the first day of school",
                promptSeed: "an adventure about starting school, making friends, and discovering that new experiences can be exciting",
                category: .learning,
                ageRange: .preschool,
                tone: .inspiring
            ),
            CustomStoryEvent(
                title: "Lost Teddy Bear",
                description: "Finding a beloved toy that went missing during a family trip",
                promptSeed: "a heartwarming journey to reunite with a cherished teddy bear, learning about responsibility and perseverance",
                category: .emotional,
                ageRange: .toddler,
                tone: .calming
            ),
            CustomStoryEvent(
                title: "Backyard Camping",
                description: "An exciting camping adventure right in the backyard",
                promptSeed: "a magical night under the stars in the backyard, discovering nature's wonders and family bonding",
                category: .adventure,
                ageRange: .elementary,
                tone: .exciting
            )
        ]
    }
}