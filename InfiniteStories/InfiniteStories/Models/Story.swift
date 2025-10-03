//
//  Story.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation
import SwiftData

// MARK: - Helper Types for Firestore Compatibility

/// Codable wrapper for Story to enable Firestore sync
struct StoryCodable: Codable {
    let id: String
    let userId: String
    let heroId: String?
    let title: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let isFavorite: Bool
    let playCount: Int
    let estimatedDuration: Int  // Store as Int for Firestore
    let wordCount: Int
    let eventType: String  // Always provided, defaults to "built_in"
    let eventData: [String: Any]  // Always provided, defaults to empty object
    let customEventId: String?

    // Firestore-specific metadata
    let lastModified: Date
    let version: Int
    let syncStatus: String?
    let audioGenerated: Bool
    let illustrationsCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case heroId = "hero_id"
        case title
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isFavorite = "is_favorite"
        case playCount = "play_count"
        case estimatedDuration = "estimated_duration"
        case wordCount = "word_count"
        case eventType = "event_type"
        case eventData = "event_data"
        case customEventId = "custom_event_id"
        case lastModified = "last_modified"
        case version
        case syncStatus = "sync_status"
        case audioGenerated = "audio_generated"
        case illustrationsCount = "illustrations_count"
    }

    init(from story: Story, userId: UUID) {
        self.id = story.id.uuidString
        self.userId = userId.uuidString
        self.heroId = story.hero?.id.uuidString
        self.title = story.title
        self.content = story.content
        self.createdAt = story.createdAt
        self.updatedAt = story.lastModified
        self.isFavorite = story.isFavorite
        self.playCount = story.playCount
        self.estimatedDuration = Int(story.estimatedDuration)
        self.wordCount = story.content.split(separator: " ").count

        if let builtInEvent = story.builtInEvent {
            self.eventType = "built_in"
            self.eventData = ["event": builtInEvent.rawValue]
            self.customEventId = nil
        } else if let customEvent = story.customEvent {
            self.eventType = "custom"
            // Provide empty object instead of nil for custom events
            self.eventData = [:]
            self.customEventId = customEvent.id.uuidString
        } else {
            // Default to built_in with empty data if no event is specified
            self.eventType = "built_in"
            self.eventData = [:]
            self.customEventId = nil
        }

        // Firestore metadata
        self.lastModified = story.lastModified
        self.version = 1 // Increment for optimistic concurrency control
        self.syncStatus = story.needsSync ? "pending" : "synced"
        self.audioGenerated = story.audioFileName != nil
        self.illustrationsCount = story.illustrations.count
    }

    // Custom encoding for eventData
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(heroId, forKey: .heroId)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(playCount, forKey: .playCount)
        try container.encode(estimatedDuration, forKey: .estimatedDuration)
        try container.encode(wordCount, forKey: .wordCount)
        try container.encode(eventType, forKey: .eventType)  // Always encode
        try container.encodeIfPresent(customEventId, forKey: .customEventId)

        // Firestore metadata
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(syncStatus, forKey: .syncStatus)
        try container.encode(audioGenerated, forKey: .audioGenerated)
        try container.encode(illustrationsCount, forKey: .illustrationsCount)

        // Always encode eventData as JSON (never nil)
        let jsonData = try JSONSerialization.data(withJSONObject: eventData)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
        try container.encode(AnyJSON(jsonObject as? Encodable), forKey: .eventData)
    }

    // Custom decoding for eventData
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        heroId = try container.decodeIfPresent(String.self, forKey: .heroId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        playCount = try container.decode(Int.self, forKey: .playCount)
        estimatedDuration = try container.decode(Int.self, forKey: .estimatedDuration)
        wordCount = try container.decode(Int.self, forKey: .wordCount)
        // Default to "built_in" if eventType is missing
        eventType = try container.decodeIfPresent(String.self, forKey: .eventType) ?? "built_in"
        customEventId = try container.decodeIfPresent(String.self, forKey: .customEventId)

        // Firestore metadata
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        syncStatus = try container.decodeIfPresent(String.self, forKey: .syncStatus)
        audioGenerated = try container.decodeIfPresent(Bool.self, forKey: .audioGenerated) ?? false
        illustrationsCount = try container.decodeIfPresent(Int.self, forKey: .illustrationsCount) ?? 0

        // Decode eventData from AnyJSON, default to empty object if nil
        if let anyJSON = try container.decodeIfPresent(AnyJSON.self, forKey: .eventData) {
            eventData = anyJSON.value as? [String: Any] ?? [:]
        } else {
            eventData = [:]
        }
    }

    /// Convert Firestore data back to Story model
    func toStory() -> Story {
        let story = Story(
            title: title,
            content: content
        )

        // Set ID and timestamps
        if let uuid = UUID(uuidString: id) {
            story.id = uuid
        }
        story.createdAt = createdAt
        story.lastModified = updatedAt
        story.isFavorite = isFavorite
        story.playCount = playCount
        story.estimatedDuration = TimeInterval(estimatedDuration)

        // Set sync status
        story.lastSyncedAt = lastModified
        story.needsSync = syncStatus == "pending"

        return story
    }
}

@Model
final class Story {
    var id: UUID = UUID() // Single UUID for both local and remote
    var title: String {
        didSet {
            // Only mark for regeneration if we already have an audio file
            // This prevents triggering on initial creation
            if audioFileName != nil {
                audioNeedsRegeneration = true
                lastModified = Date()
            }
            // Mark as needing sync
            markAsModified()
        }
    }

    var content: String {
        didSet {
            // Only mark for regeneration if we already have an audio file
            // This prevents triggering on initial creation
            if audioFileName != nil {
                audioNeedsRegeneration = true
                lastModified = Date()
            }
            // Mark as needing sync
            markAsModified()
        }
    }
    
    // Support both built-in and custom events
    var builtInEvent: StoryEvent?
    @Relationship var customEvent: CustomStoryEvent?
    
    var createdAt: Date
    var audioFileName: String?
    var isGenerated: Bool
    var isFavorite: Bool
    var playCount: Int
    var estimatedDuration: TimeInterval
    var audioNeedsRegeneration: Bool
    var lastModified: Date

    // Simple sync properties
    var lastSyncedAt: Date? // When last synced to Supabase
    var needsSync: Bool = true // Whether changes need to be synced

    @Relationship(inverse: \Hero.stories) var hero: Hero?

    // Illustrations for visual storytelling
    @Relationship(deleteRule: .cascade) var illustrations: [StoryIllustration] = []

    // Initializer for built-in events
    init(title: String, content: String, event: StoryEvent, hero: Hero) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.builtInEvent = event
        self.customEvent = nil
        self.hero = hero
        self.createdAt = Date()
        self.audioFileName = nil
        self.isGenerated = true
        self.isFavorite = false
        self.playCount = 0
        self.estimatedDuration = 0
        self.audioNeedsRegeneration = false
        self.lastModified = Date()
        self.lastSyncedAt = nil
        self.needsSync = true
    }
    
    // Initializer for custom events
    init(title: String, content: String, customEvent: CustomStoryEvent, hero: Hero) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.builtInEvent = nil
        self.customEvent = customEvent
        self.hero = hero
        self.createdAt = Date()
        self.audioFileName = nil
        self.isGenerated = true
        self.isFavorite = false
        self.playCount = 0
        self.estimatedDuration = 0
        self.audioNeedsRegeneration = false
        self.lastModified = Date()
        self.lastSyncedAt = nil
        self.needsSync = true

        // Increment usage count for custom event
        customEvent.incrementUsage()
    }

    // Initializer for stories without events or with optional custom events
    init(title: String, content: String, customEvent: CustomStoryEvent? = nil, hero: Hero?) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.builtInEvent = nil
        self.customEvent = customEvent
        self.hero = hero
        self.createdAt = Date()
        self.audioFileName = nil
        self.isGenerated = true
        self.isFavorite = false
        self.playCount = 0
        self.estimatedDuration = 0
        self.audioNeedsRegeneration = false
        self.lastModified = Date()
        self.lastSyncedAt = nil
        self.needsSync = true

        // Increment usage count for custom event if provided
        if let customEvent = customEvent {
            customEvent.incrementUsage()
        }
    }

    // Simple initializer for Firestore conversions
    init(title: String, content: String) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.builtInEvent = nil
        self.customEvent = nil
        self.hero = nil
        self.createdAt = Date()
        self.audioFileName = nil
        self.isGenerated = true
        self.isFavorite = false
        self.playCount = 0
        self.estimatedDuration = 0
        self.audioNeedsRegeneration = false
        self.lastModified = Date()
        self.lastSyncedAt = nil
        self.needsSync = true
    }
    
    // Computed properties for event access
    var eventTitle: String {
        if let builtIn = builtInEvent {
            return builtIn.rawValue
        } else if let custom = customEvent {
            return custom.title
        }
        return "Unknown Event"
    }
    
    var eventPromptSeed: String {
        if let builtIn = builtInEvent {
            return builtIn.promptSeed
        } else if let custom = customEvent {
            return custom.promptSeed
        }
        return "a magical adventure"
    }
    
    var eventIcon: String {
        if let builtIn = builtInEvent {
            return builtIn.icon
        } else if let custom = customEvent {
            return custom.iconName
        }
        return "star"
    }
    
    var isCustomEvent: Bool {
        return customEvent != nil
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var shortContent: String {
        let maxLength = 100
        if content.count <= maxLength {
            return content
        }
        let truncated = String(content.prefix(maxLength))
        return truncated + "..."
    }
    
    var hasAudio: Bool {
        return audioFileName != nil && !audioNeedsRegeneration
    }
    
    func incrementPlayCount() {
        playCount += 1
    }
    
    func clearAudioRegenerationFlag() {
        audioNeedsRegeneration = false
    }

    // MARK: - Illustration Management

    /// Check if the story has any generated illustrations to display
    var hasIllustrations: Bool {
        return !illustrations.isEmpty && illustrations.contains { $0.isGenerated }
    }

    /// Check if all illustrations have been successfully generated
    var allIllustrationsGenerated: Bool {
        return !illustrations.isEmpty && illustrations.allSatisfy { $0.isGenerated }
    }

    /// Check if illustrations are currently being generated
    var illustrationsInProgress: Bool {
        return !illustrations.isEmpty && illustrations.contains { !$0.isGenerated }
    }

    /// Get sorted illustrations by display order (includes all illustrations regardless of status)
    var sortedIllustrations: [StoryIllustration] {
        return illustrations.sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Get only generated illustrations sorted by display order
    var generatedIllustrations: [StoryIllustration] {
        return illustrations.filter { $0.isGenerated }.sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Get illustration timeline data for sync with audio
    var illustrationTimeline: [(timestamp: Double, illustration: StoryIllustration)] {
        return generatedIllustrations.map { (timestamp: $0.timestamp, illustration: $0) }
    }

    /// Find the illustration that should be displayed at a given audio timestamp
    func illustrationAt(timestamp: TimeInterval) -> StoryIllustration? {
        // Find the illustration with the latest timestamp that's still before or equal to the current time
        let validIllustrations = sortedIllustrations.filter { $0.timestamp <= timestamp && $0.isGenerated }
        return validIllustrations.last
    }

    /// Get the next illustration after a given timestamp
    func nextIllustrationAfter(timestamp: TimeInterval) -> StoryIllustration? {
        return sortedIllustrations.first { $0.timestamp > timestamp && $0.isGenerated }
    }

    /// Get the number of illustrations for this story
    var recommendedIllustrationCount: Int {
        // Return the actual count of illustrations from AI-extracted scenes
        // No artificial limits - let the AI determine the appropriate number
        return illustrations.count
    }

    /// Import scenes from AI generation into story illustrations
    /// Note: StoryScene is defined in AIService.swift
    func importScenes(from scenes: [(sceneNumber: Int, textSegment: String, illustrationPrompt: String, timestamp: TimeInterval)]) {
        // Clear any existing illustrations that haven't been generated
        illustrations.removeAll { !$0.isGenerated }

        // Create new StoryIllustration objects from scenes
        for scene in scenes {
            let illustration = StoryIllustration(
                timestamp: scene.timestamp,
                imagePrompt: scene.illustrationPrompt,
                displayOrder: scene.sceneNumber - 1, // Convert to 0-based index
                textSegment: scene.textSegment
            )
            illustrations.append(illustration)
        }

        print("📚 Imported \(scenes.count) scenes as illustrations for story: \(title)")
    }

    /// Update illustration with generated image
    func updateIllustration(at index: Int, withImagePath imagePath: String) {
        guard index < illustrations.count else { return }
        illustrations[index].setImagePath(imagePath)
        print("📚 Updated illustration \(index) with image: \(imagePath)")
    }

    /// Get count of failed illustrations that can still be retried
    var retryableIllustrationCount: Int {
        illustrations.filter { $0.isPlaceholder && !$0.hasReachedRetryLimit }.count
    }

    /// Get count of successfully generated illustrations
    var successfulIllustrationCount: Int {
        illustrations.filter { $0.isGenerated }.count
    }

    /// Get count of permanently failed illustrations
    var permanentlyFailedIllustrationCount: Int {
        illustrations.filter { $0.isPlaceholder && $0.hasReachedRetryLimit }.count
    }

    /// Check if all illustrations have been generated or permanently failed
    var illustrationsComplete: Bool {
        illustrations.allSatisfy { $0.isGenerated || $0.hasReachedRetryLimit }
    }

    /// Get progress percentage for illustration generation
    var illustrationProgress: Double {
        guard !illustrations.isEmpty else { return 0 }
        let completed = illustrations.filter { $0.isGenerated || $0.hasReachedRetryLimit }.count
        return Double(completed) / Double(illustrations.count)
    }

    /// Reset failed illustrations for retry
    func resetFailedIllustrations() {
        for illustration in illustrations where illustration.isPlaceholder {
            illustration.resetError()
            illustration.retryCount = 0
        }
    }

    // MARK: - Simple Sync Methods

    /// Mark story as needing sync (call after any change)
    func markAsModified() {
        lastModified = Date()
        needsSync = true
    }

    /// Sync status for UI
    var syncStatusDescription: String {
        if let lastSync = lastSyncedAt, !needsSync {
            let formatter = RelativeDateTimeFormatter()
            return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else if needsSync {
            return "Needs sync"
        } else {
            return "Not synced"
        }
    }
}
