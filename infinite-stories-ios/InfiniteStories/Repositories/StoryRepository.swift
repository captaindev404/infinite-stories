//
//  StoryRepository.swift
//  InfiniteStories
//
//  Story data access - API-only (no local persistence)
//

import Foundation

// MARK: - Story Repository Protocol

protocol StoryRepositoryProtocol {
    func fetchStories(heroId: String?, limit: Int, offset: Int) async throws -> [Story]
    func fetchStory(id: String) async throws -> Story
    func generateStory(heroId: String, eventType: String?, customEventId: String?, language: String, generateAudio: Bool, generateIllustrations: Bool) async throws -> Story
    func updateStory(id: String, title: String?, content: String?, isFavorite: Bool?) async throws -> Story
    func deleteStory(id: String) async throws
    func generateAudio(storyId: String, language: String, voice: String) async throws -> String // Returns audio URL
    func generateIllustrations(storyId: String) async throws -> Story
}

// MARK: - Story Repository Implementation

@MainActor
class StoryRepository: StoryRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Fetch Operations

    // Protocol conformance method
    func fetchStories(heroId: String?, limit: Int, offset: Int) async throws -> [Story] {
        return try await fetchStories(heroId: heroId, limit: limit, offset: offset, heroes: nil)
    }

    // Extended method with heroes parameter
    func fetchStories(heroId: String?, limit: Int = 50, offset: Int = 0, heroes: [Hero]? = nil) async throws -> [Story] {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Fetching stories (heroId: \(heroId ?? "all"))")
        print("📚 DEBUG StoryRepository: Starting fetch with limit \(limit), offset \(offset)")

        // Backend wraps response in { data: { stories: [...] } }
        let wrapper: StoriesListWrapper = try await apiClient.request(
            .getStories(heroId: heroId, limit: limit, offset: offset, includeIllustrations: true)
        )
        print("📚 DEBUG StoryRepository: Got response")
        print("📚 DEBUG StoryRepository: Response has \(wrapper.data.stories.count) stories")

        let stories = wrapper.data.stories.map { convertToStory($0, heroes: heroes) }
        print("📚 DEBUG StoryRepository: Converted \(stories.count) stories")
        if !stories.isEmpty {
            print("📚 DEBUG StoryRepository: First story title: \(stories[0].title)")
        }
        Logger.api.success("Fetched \(stories.count) stories")

        return stories
    }

    func fetchStory(id: String) async throws -> Story {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Fetching story \(id)")

        let response: APIResponse<StoryResponse> = try await apiClient.request(
            .getStory(id: id, includeIllustrations: true)
        )

        guard let data = response.data else {
            throw APIError.notFound
        }

        let story = convertToStory(data)
        Logger.api.success("Fetched story: \(story.title)")

        return story
    }

    // MARK: - Generate Story

    func generateStory(
        heroId: String,
        eventType: String?,
        customEventId: String?,
        language: String,
        generateAudio: Bool,
        generateIllustrations: Bool
    ) async throws -> Story {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Generating story for hero \(heroId)")

        let request = StoryCreateRequest(
            heroId: heroId,
            title: nil, // Backend will generate
            eventType: eventType,
            customEventId: customEventId,
            language: language,
            generateAudio: generateAudio,
            generateIllustrations: generateIllustrations
        )

        let response: APIResponse<StoryResponse> = try await apiClient.request(
            .createStory(data: request),
            retryPolicy: .aggressive // Story generation is critical
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "StoryRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in create response"]
            ))
        }

        let story = convertToStory(data)
        Logger.api.success("Generated story: \(story.title)")

        return story
    }

    // MARK: - Update Story

    func updateStory(
        id: String,
        title: String?,
        content: String?,
        isFavorite: Bool?
    ) async throws -> Story {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Updating story \(id)")

        let request = StoryUpdateRequest(
            title: title,
            content: content,
            isFavorite: isFavorite
        )

        let response: APIResponse<StoryResponse> = try await apiClient.request(
            .updateStory(id: id, data: request)
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "StoryRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in update response"]
            ))
        }

        let story = convertToStory(data)
        Logger.api.success("Updated story: \(story.title)")

        return story
    }

    // MARK: - Delete Story

    func deleteStory(id: String) async throws {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Deleting story \(id)")

        try await apiClient.requestVoid(.deleteStory(id: id))

        Logger.api.success("Deleted story \(id)")
    }

    // MARK: - Generate Audio

    func generateAudio(storyId: String, language: String, voice: String) async throws -> String {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Generating audio for story \(storyId)")

        let response: APIResponse<AudioGenerationResponse> = try await apiClient.request(
            .generateAudio(storyId: storyId, language: language, voice: voice),
            retryPolicy: .aggressive
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "StoryRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in audio response"]
            ))
        }

        Logger.api.success("Generated audio: \(data.audioUrl)")

        return data.audioUrl
    }

    // MARK: - Generate Illustrations

    func generateIllustrations(storyId: String) async throws -> Story {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Generating illustrations for story \(storyId)")

        let response: APIResponse<StoryResponse> = try await apiClient.request(
            .generateIllustrations(storyId: storyId),
            retryPolicy: .aggressive
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "StoryRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in illustration response"]
            ))
        }

        let story = convertToStory(data)
        Logger.api.success("Generated \(story.illustrations.count) illustrations")

        return story
    }

    // MARK: - Helper: Convert API Response to Model

    private func convertToStory(_ response: StoryResponse, heroes: [Hero]? = nil) -> Story {
        // Determine if this is a built-in or custom event
        let builtInEvent: StoryEvent? = response.eventType.flatMap { StoryEvent(rawValue: $0) }

        // Try to find matching hero by backend ID
        let matchedHero: Hero = heroes?.first(where: { $0.backendId == response.heroId }) ?? Hero(
            name: "Unknown Hero",
            primaryTrait: .curious,
            secondaryTrait: .kind
        )

        let story: Story
        if let builtInEvent = builtInEvent {
            story = Story(
                title: response.title,
                content: response.content,
                event: builtInEvent,
                hero: matchedHero
            )
        } else {
            // For custom events, create a placeholder. The real
            // CustomStoryEvent is fetched separately via `customEventId`.
            // L10N-83: use an empty title as the sentinel — Story.eventTitle
            // detects `trimmed.isEmpty` and falls back to the localized
            // "story.card.event.custom" key. Never stuff a display string
            // into model data: it's locale-dependent and breaks equality
            // checks the moment the backend returns real titles.
            let placeholderCustomEvent = CustomStoryEvent(
                title: "",
                description: "",
                promptSeed: "",
                category: .adventure,
                ageRange: .elementary,
                tone: .calming
            )
            story = Story(
                title: response.title,
                content: response.content,
                customEvent: placeholderCustomEvent,
                hero: matchedHero
            )
        }

        // Set additional properties
        story.backendId = response.id // Store the backend ID
        story.createdAt = response.createdAt
        story.lastModified = response.updatedAt
        story.isFavorite = response.isFavorite
        story.playCount = response.playCount
        story.isGenerated = true
        story.audioNeedsRegeneration = false

        // Audio info
        if let audioUrl = response.audioUrl {
            story.audioFileName = audioUrl // Store URL as filename for now
            story.estimatedDuration = response.audioDuration ?? 0
        }

        // Illustrations
        if let illustrationsData = response.illustrations {
            story.illustrations = illustrationsData.map { convertToIllustration($0, story: story) }
        }

        return story
    }

    private func convertToIllustration(_ response: StoryIllustrationResponse, story: Story) -> StoryIllustration {
        let illustration = StoryIllustration(
            timestamp: response.audioTimestamp,
            imagePrompt: response.imagePrompt,
            displayOrder: response.displayOrder,
            textSegment: response.sceneDescription,
            previousGenerationId: response.previousGenerationId
        )

        // Set additional properties
        illustration.imagePath = response.imageUrl // Store URL as path
        illustration.isGenerated = response.generationStatus == "completed"
        illustration.generationId = response.generationId
        illustration.story = story

        return illustration
    }
}

// MARK: - Response DTOs (additional)

// Wrapper for the actual backend response which has data field
struct StoriesListWrapper: Decodable {
    let data: StoriesListResponse
}

struct StoriesListResponse: Decodable {
    let stories: [StoryResponse]
    let pagination: Pagination?
}

struct AudioGenerationResponse: Decodable {
    let audioUrl: String
    let audioDuration: Double
    let status: String

    // Computed property for backward compatibility
    var duration: Double { audioDuration }
}
