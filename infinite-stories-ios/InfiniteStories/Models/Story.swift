//
//  Story.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation
import SwiftData

@Model
final class Story: Identifiable {
    var id: UUID = UUID() // Local ID for SwiftData (not persisted in API-only architecture)
    var backendId: String? // Backend ID from API (cuid string)
    var title: String {
        didSet {
            // Only mark for regeneration if we already have an audio file
            // This prevents triggering on initial creation
            if audioFileName != nil {
                audioNeedsRegeneration = true
                lastModified = Date()
            }
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
        }
    }
    
    // Support both built-in and custom events
    var builtInEvent: StoryEvent?
    var customEventId: String?  // Backend ID for custom event (CustomStoryEvent is API-only)
    @Transient var customEvent: CustomStoryEvent?  // Not persisted, loaded separately
    
    var createdAt: Date
    var audioFileName: String?
    var isGenerated: Bool
    var isFavorite: Bool
    var playCount: Int
    var estimatedDuration: TimeInterval
    var audioNeedsRegeneration: Bool
    var lastModified: Date
    
    @Relationship(inverse: \Hero.stories) var hero: Hero?

    // Illustrations for visual storytelling
    @Relationship(deleteRule: .cascade) var illustrations: [StoryIllustration] = []

    // Initializer for built-in events
    init(title: String, content: String, event: StoryEvent, hero: Hero, backendId: String? = nil) {
        self.id = UUID()
        self.backendId = backendId
        self.title = title
        self.content = content
        self.builtInEvent = event
        self.customEventId = nil
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
    }

    // Initializer for custom events
    init(title: String, content: String, customEvent: CustomStoryEvent, hero: Hero, backendId: String? = nil) {
        self.id = UUID()
        self.backendId = backendId
        self.title = title
        self.content = content
        self.builtInEvent = nil
        self.customEventId = customEvent.id
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
        // Note: Usage count for custom events is tracked by the backend API
    }
    
    // Computed properties for event access
    var eventTitle: String {
        if let builtIn = builtInEvent {
            // BUG-A16: return localized name so the chip reads "Aventure au
            // coucher" in French instead of the raw English enum value.
            return builtIn.localizedName
        } else if let custom = customEvent {
            // L10N-83: detect placeholder custom events by empty title only.
            // The repository sets `title = ""` for placeholders built from a
            // StoryResponse that only carries `customEventId` (the real event
            // is loaded separately). Never control-flow on a translatable
            // display string ("Custom Event") — that breaks the instant the
            // backend localizes titles or a real user names an event that.
            let trimmed = custom.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return String(
                    localized: "story.card.event.custom",
                    comment: "Default fallback label for a placeholder custom event in the story repository / story card badge."
                )
            }
            return custom.title
        }
        // NOTE: catalog state is `new` — EN fallback kept until the key is
        // translated. See Task #86 report.
        return String(localized: "story.card.event.unknown",
                      defaultValue: "Unknown Event",
                      comment: "Default value for the title of an event that is not defined in the built-in list.")
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
        return customEventId != nil || customEvent != nil
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Whitespace-separated word count computed from `content`. Matches the
    /// previous `AudioPlayerView.wordCount` helper — kept as a computed
    /// property so formatting helpers (and tests — see Task #88) can access
    /// it without duplicating the splitting rule.
    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    // MARK: - Localized display labels
    //
    // L10N-07 / Task #84: These were previously private View helpers in
    // `AudioPlayerView.swift`. They're pure `Story -> String` transformations
    // with no SwiftUI coupling, so they belong on the model where they can be
    // unit-tested (Task #88) and shared across layouts (`ViewThatFits`
    // branches + the alternate compact layout) without duplication.

    /// Localized "Played X time(s)" label using the `audio.player.playCount`
    /// catalog key with a plural variation so each locale renders
    /// singular/plural correctly (French "Lu X fois", English "Played X
    /// time(s)", etc.). BUG-A14/A29 / L10N-07.
    var localizedPlayCountLabel: String {
        String.localizedStringWithFormat(
            NSLocalizedString("audio.player.playCount", comment: "Audio player play count"),
            playCount
        )
    }

    /// Localized "X word(s)" label, plural-aware per locale. Uses the
    /// whitespace-split `wordCount` computed from `content`. L10N-07.
    var localizedWordCountLabel: String {
        String.localizedStringWithFormat(
            NSLocalizedString("audio.player.wordCount", comment: "Audio player word count"),
            wordCount
        )
    }

    /// Localized "Created %@" label prefixing the already-locale-formatted
    /// `formattedDate`. The date string is produced by `Story.formattedDate`
    /// (locale-aware `DateFormatter`). L10N-07.
    var localizedCreatedAtLabel: String {
        String(
            format: NSLocalizedString("audio.player.createdAt", comment: "Audio player created-at label"),
            formattedDate
        )
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
}
