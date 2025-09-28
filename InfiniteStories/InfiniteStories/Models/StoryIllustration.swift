//
//  StoryIllustration.swift
//  InfiniteStories
//
//  Created by Captain Dev on 16/09/2025.
//

import Foundation
import SwiftData

@Model
final class StoryIllustration {
    /// Unique identifier for the illustration
    var id: UUID

    /// Timestamp in the audio playback where this illustration should appear (in seconds)
    var timestamp: Double

    /// The prompt used to generate this illustration via DALL-E
    var imagePrompt: String

    /// Path to the stored image file in Documents directory
    var imagePath: String?

    /// Display order for the carousel (0-based index)
    var displayOrder: Int

    /// Whether the image has been successfully generated
    var isGenerated: Bool

    /// Date when the illustration was created
    var createdAt: Date

    /// The text segment this illustration represents (for context)
    var textSegment: String

    /// Error tracking for failed illustrations
    var lastError: String?
    var errorType: String?
    var retryCount: Int
    var failedAt: Date?

    /// GPT-Image-1 generation IDs for multi-turn consistency
    var generationId: String? // This illustration's generation ID
    var previousGenerationId: String? // Referenced previous image generation ID

    /// Relationship to the parent story
    @Relationship(inverse: \Story.illustrations) var story: Story?

    init(
        timestamp: Double,
        imagePrompt: String,
        displayOrder: Int,
        textSegment: String,
        previousGenerationId: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.imagePrompt = imagePrompt
        self.imagePath = nil
        self.displayOrder = displayOrder
        self.isGenerated = false
        self.createdAt = Date()
        self.textSegment = textSegment
        self.lastError = nil
        self.errorType = nil
        self.retryCount = 0
        self.failedAt = nil
        self.generationId = nil
        self.previousGenerationId = previousGenerationId
    }

    /// Computed property to get the full URL for the image
    var imageURL: URL? {
        guard let imagePath = imagePath else { return nil }
        return getDocumentsDirectory()
            .appendingPathComponent("StoryIllustrations")
            .appendingPathComponent(imagePath)
    }

    /// Check if the image exists on disk
    var imageExists: Bool {
        guard let url = imageURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Update the image path after successful generation
    func setImagePath(_ filename: String) {
        self.imagePath = filename
        self.isGenerated = true
    }

    /// Helper to get documents directory
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    /// Format timestamp for display (e.g., "1:23")
    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Check if this illustration is a placeholder due to failure
    var isPlaceholder: Bool {
        return !isGenerated && lastError != nil
    }

    /// Check if retry limit has been reached
    var hasReachedRetryLimit: Bool {
        let maxRetries = UserDefaults.standard.integer(forKey: "maxIllustrationRetries")
        return retryCount >= (maxRetries > 0 ? maxRetries : 3)
    }

    /// Mark illustration as failed with error details
    func markAsFailed(error: String, type: IllustrationErrorType) {
        self.lastError = error
        self.errorType = type.rawValue
        self.failedAt = Date()
        self.retryCount += 1
    }

    /// Reset error state for retry
    func resetError() {
        self.lastError = nil
        self.errorType = nil
        self.failedAt = nil
    }

    /// Get typed error if available
    var typedError: IllustrationErrorType? {
        guard let errorType = errorType else { return nil }
        return IllustrationErrorType(rawValue: errorType)
    }
}

/// Extension to support error type in model
extension StoryIllustration {
    enum IllustrationErrorType: String {
        case network = "Network Error"
        case invalidPrompt = "Invalid Content"
        case rateLimit = "Rate Limited"
        case apiError = "Service Error"
        case timeout = "Timeout"
        case fileSystem = "Storage Error"
        case unknown = "Unknown Error"
    }
}