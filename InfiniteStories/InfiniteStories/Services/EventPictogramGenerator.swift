//
//  EventPictogramGenerator.swift
//  InfiniteStories
//
//  Service for generating AI-powered pictograms for custom events
//

import Foundation
import UIKit
import SwiftUI
import os.log

// MARK: - Error Types

enum PictogramError: LocalizedError {
    case generationFailed(String)
    case storageFull
    case networkUnavailable
    case rateLimited(retryAfter: TimeInterval)
    case contentPolicyViolation
    case invalidImageData
    case fileSystemError(String)

    var errorDescription: String? {
        switch self {
        case .generationFailed(let reason):
            return "Failed to generate pictogram: \(reason)"
        case .storageFull:
            return "Not enough storage space for pictogram"
        case .networkUnavailable:
            return "Network connection required to generate pictogram"
        case .rateLimited(let seconds):
            return "Too many requests. Try again in \(Int(seconds)) seconds"
        case .contentPolicyViolation:
            return "Event description violates content policy"
        case .invalidImageData:
            return "Invalid image data received"
        case .fileSystemError(let reason):
            return "File system error: \(reason)"
        }
    }
}

// MARK: - EventPictogramGenerator

@MainActor
class EventPictogramGenerator: ObservableObject {
    private let aiService: AIServiceProtocol
    private let contentFilter: ContentPolicyFilter
    private let logger = os.Logger(subsystem: "InfiniteStories", category: "EventPictogramGenerator")

    // Storage configuration
    private let pictogramDirectory = "EventPictograms"
    private let thumbnailDirectory = "EventPictograms/thumbnails"
    private let pictogramSize = "512x512"
    private let thumbnailSize = CGSize(width: 128, height: 128)

    // Generation state
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var currentOperation: String = ""
    @Published var lastError: Error?

    init(
        aiService: AIServiceProtocol? = nil
    ) {
        // Use provided service or create a new one through factory
        if let service = aiService {
            self.aiService = service
        } else {
            // Create AI service through factory
            self.aiService = AIServiceFactory.createAIService()
        }
        self.contentFilter = ContentPolicyFilter.shared

        // Ensure directories exist
        Task {
            await ensureDirectoriesExist()
        }
    }

    // MARK: - Public Methods

    func generatePictogram(
        for event: CustomStoryEvent,
        style: PictogramStyle = .playful,
        regenerate: Bool = false
    ) async throws -> URL {
        // Check if pictogram already exists and regenerate is false
        if !regenerate && event.hasPictogram, let url = event.pictogramURL {
            logger.info("Using existing pictogram for event: \(event.title)")
            return url
        }

        isGenerating = true
        generationProgress = 0
        currentOperation = "Preparing to generate pictogram..."
        defer {
            isGenerating = false
            generationProgress = 1.0
            currentOperation = ""
        }

        logger.info("Starting pictogram generation for event: \(event.title)")

        do {
            // Step 1: Generate safe prompt
            currentOperation = "Creating pictogram prompt..."
            generationProgress = 0.2
            let basePrompt = createPictogramPrompt(for: event, style: style)
            let filteredPrompt = contentFilter.filterPrompt(basePrompt)

            logger.debug("Filtered pictogram prompt: \(filteredPrompt)")

            // Step 2: Generate with DALL-E
            currentOperation = "Generating pictogram with AI..."
            generationProgress = 0.4

            let imageData = try await generateImageWithDALLE(prompt: filteredPrompt)

            // Step 3: Process and save image
            currentOperation = "Processing and saving pictogram..."
            generationProgress = 0.6

            let filename = "\(event.id.uuidString)_\(Int(Date().timeIntervalSince1970)).png"
            let url = try await saveImageData(imageData, filename: filename)

            // Step 4: Generate thumbnail
            currentOperation = "Creating thumbnail..."
            generationProgress = 0.8

            try await generateThumbnail(from: url, for: event.id)

            // Step 5: Update model
            currentOperation = "Updating event..."
            generationProgress = 0.9

            event.pictogramPath = filename
            event.pictogramPrompt = filteredPrompt
            event.pictogramGeneratedAt = Date()
            event.pictogramStyle = style
            event.pictogramFailureCount = 0
            event.lastPictogramError = nil

            logger.info("Successfully generated pictogram for event: \(event.title)")

            return url

        } catch {
            // Update failure tracking
            event.pictogramFailureCount += 1
            event.lastPictogramError = error.localizedDescription
            lastError = error

            logger.error("Failed to generate pictogram: \(error.localizedDescription)")
            throw error
        }
    }

    func deletePictogram(for event: CustomStoryEvent) async {
        guard let path = event.pictogramPath else { return }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pictogramURL = documentsURL
            .appendingPathComponent(pictogramDirectory)
            .appendingPathComponent(path)
        let thumbnailURL = documentsURL
            .appendingPathComponent(thumbnailDirectory)
            .appendingPathComponent("\(event.id.uuidString)_thumb.png")

        do {
            // Delete main pictogram
            if FileManager.default.fileExists(atPath: pictogramURL.path) {
                try FileManager.default.removeItem(at: pictogramURL)
            }

            // Delete thumbnail
            if FileManager.default.fileExists(atPath: thumbnailURL.path) {
                try FileManager.default.removeItem(at: thumbnailURL)
            }

            // Update model
            event.pictogramPath = nil
            event.pictogramPrompt = nil
            event.pictogramGeneratedAt = nil
            event.pictogramStyle = nil

            logger.info("Deleted pictogram for event: \(event.title)")

        } catch {
            logger.error("Failed to delete pictogram: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func createPictogramPrompt(
        for event: CustomStoryEvent,
        style: PictogramStyle
    ) -> String {
        let ageContext = "suitable for children aged \(event.ageRange.minAge) to \(event.ageRange.maxAge)"
        let toneContext = event.tone.description.lowercased()

        return """
        Create a simple, iconic pictogram representing "\(event.title)".
        Context: \(event.eventDescription)
        Style: \(style.stylePrompt)
        Tone: \(toneContext)
        Requirements: Single iconic image, no text or letters, child-appropriate (\(ageContext)),
        clear symbolism that instantly conveys the event concept, suitable as an app icon,
        square aspect ratio, bold and recognizable from a distance, positive and engaging imagery
        """
    }

    private func generateImageWithDALLE(prompt: String) async throws -> Data {
        do {
            // Use a dummy hero for the pictogram generation
            let dummyHero = Hero(
                name: "EventIcon",
                primaryTrait: .kind,
                secondaryTrait: .brave,
                appearance: "",
                specialAbility: ""
            )

            // Generate image using the AI service's scene illustration method
            let response = try await aiService.generateSceneIllustration(
                prompt: prompt,
                hero: dummyHero,
                previousGenerationId: nil // No generation chain for pictograms
            )
            let imageData = response.imageData

            return imageData

        } catch {
            // Check for specific error types
            if error.localizedDescription.contains("rate") {
                throw PictogramError.rateLimited(retryAfter: 60)
            } else if error.localizedDescription.contains("content") {
                throw PictogramError.contentPolicyViolation
            } else {
                throw PictogramError.generationFailed(error.localizedDescription)
            }
        }
    }

    private func saveImageData(_ data: Data, filename: String) async throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pictogramDirectoryURL = documentsURL.appendingPathComponent(pictogramDirectory)
        let fileURL = pictogramDirectoryURL.appendingPathComponent(filename)

        do {
            // Ensure directory exists
            try FileManager.default.createDirectory(
                at: pictogramDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Save image data
            try data.write(to: fileURL)

            logger.debug("Saved pictogram to: \(fileURL.lastPathComponent)")

            return fileURL

        } catch {
            throw PictogramError.fileSystemError(error.localizedDescription)
        }
    }

    private func generateThumbnail(from imageURL: URL, for eventID: UUID) async throws {
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            throw PictogramError.invalidImageData
        }

        // Create thumbnail
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        let thumbnail = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }

        // Save thumbnail
        guard let thumbnailData = thumbnail.pngData() else {
            throw PictogramError.invalidImageData
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let thumbnailDirectoryURL = documentsURL.appendingPathComponent(thumbnailDirectory)
        let thumbnailURL = thumbnailDirectoryURL.appendingPathComponent("\(eventID.uuidString)_thumb.png")

        try FileManager.default.createDirectory(
            at: thumbnailDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        try thumbnailData.write(to: thumbnailURL)

        logger.debug("Generated thumbnail for event: \(eventID)")
    }

    private func ensureDirectoriesExist() async {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pictogramDirectoryURL = documentsURL.appendingPathComponent(pictogramDirectory)
        let thumbnailDirectoryURL = documentsURL.appendingPathComponent(thumbnailDirectory)

        do {
            try FileManager.default.createDirectory(
                at: pictogramDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try FileManager.default.createDirectory(
                at: thumbnailDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            logger.error("Failed to create directories: \(error.localizedDescription)")
        }
    }
}

// MARK: - Batch Operations

extension EventPictogramGenerator {
    func generatePictogramsInBatch(
        for events: [CustomStoryEvent],
        style: PictogramStyle = .playful,
        progressHandler: @escaping (Double, String) -> Void
    ) async {
        let totalEvents = events.count
        var processedCount = 0

        // Process in chunks to avoid rate limiting
        let chunkSize = 3
        let chunks = events.chunked(into: chunkSize)

        for (chunkIndex, chunk) in chunks.enumerated() {
            progressHandler(
                Double(processedCount) / Double(totalEvents),
                "Processing batch \(chunkIndex + 1) of \(chunks.count)..."
            )

            await withTaskGroup(of: Void.self) { group in
                for event in chunk {
                    group.addTask {
                        do {
                            _ = try await self.generatePictogram(for: event, style: style)
                        } catch {
                            self.logger.error("Batch generation failed for \(event.title): \(error.localizedDescription)")
                        }
                    }
                }
            }

            processedCount += chunk.count
            progressHandler(
                Double(processedCount) / Double(totalEvents),
                "\(processedCount) of \(totalEvents) pictograms generated"
            )

            // Rate limit delay between chunks
            if chunkIndex < chunks.count - 1 {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }

        progressHandler(1.0, "Batch generation complete")
    }
}

// MARK: - Array Extension for Chunking
// Note: Extension removed to avoid duplicate definition - using shared extension from IllustrationGenerator

// MARK: - Retry Manager

class PictogramRetryManager: ObservableObject {
    private let maxRetries = 3
    private let backoffMultiplier = 2.0

    func generateWithRetry(
        event: CustomStoryEvent,
        generator: EventPictogramGenerator,
        style: PictogramStyle = .playful
    ) async throws -> URL {
        var lastError: Error?
        var retryDelay: TimeInterval = 1.0

        for attempt in 1...maxRetries {
            do {
                return try await generator.generatePictogram(for: event, style: style)
            } catch PictogramError.rateLimited(let retryAfter) {
                retryDelay = retryAfter
                lastError = PictogramError.rateLimited(retryAfter: retryAfter)
            } catch PictogramError.contentPolicyViolation {
                // Don't retry content policy violations
                throw PictogramError.contentPolicyViolation
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    retryDelay *= backoffMultiplier
                }
            }
        }

        throw lastError ?? PictogramError.generationFailed("Unknown error after \(maxRetries) attempts")
    }
}