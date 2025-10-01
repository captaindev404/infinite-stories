//
//  SupabaseAIService.swift
//  InfiniteStories
//
//  Refactored AI Service that uses Supabase Edge Functions instead of direct OpenAI API calls
//

import Foundation
import SwiftUI

/// Supabase-backed implementation of AIServiceProtocol
/// Routes all AI operations through Supabase Edge Functions for centralized management
class SupabaseAIService: AIServiceProtocol {

    // MARK: - Properties

    private let supabaseService: SupabaseService
    var currentTask: URLSessionDataTask?

    // MARK: - Initialization

    init() {
        self.supabaseService = SupabaseService.shared
        AppLogger.shared.info("SupabaseAIService initialized", category: .api)
    }

    // MARK: - Story Generation

    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Story generation via Supabase started", category: .story, requestId: String(requestId))
        AppLogger.shared.debug("Hero: \(request.hero.name), Event: \(request.event.rawValue), Duration: \(Int(request.targetDuration/60))min", category: .story, requestId: String(requestId))

        // Convert hero to dictionary for Edge Function
        let heroData = heroToDictionary(request.hero)

        // Convert event to dictionary (just the data part)
        let eventData: [String: Any] = [
            "name": request.event.rawValue,
            "prompt_seed": request.event.promptSeed,
            "icon": request.event.icon
        ]

        do {
            // Convert language name to code for Supabase backend
            let languageCode = AppSettings.supportedLanguageToCode(request.language)

            // Call Supabase Edge Function with proper event structure
            let response = try await supabaseService.generateStory(
                heroId: request.hero.id.uuidString,
                eventType: "built_in",
                eventData: eventData,
                targetDuration: Int(request.targetDuration),
                language: languageCode
            )

            // Parse response
            AppLogger.shared.debug("Story generation response keys: \(response.keys.joined(separator: ", "))", category: .story, requestId: String(requestId))

            let title = response["title"] as? String ?? "\(request.hero.name) and the \(request.event.rawValue)"

            // Ensure content is not empty - throw error if it is
            guard let content = response["content"] as? String, !content.isEmpty else {
                AppLogger.shared.error("Story generation returned empty content", category: .story, requestId: String(requestId))
                AppLogger.shared.debug("Full response: \(response)", category: .story, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            let estimatedDuration = TimeInterval(response["estimated_duration"] as? Int ?? 300)
            AppLogger.shared.debug("Story content received: \(content.count) characters", category: .story, requestId: String(requestId))

            // Parse scenes if available
            var scenes: [StoryScene]? = nil
            if let scenesData = response["scenes"] as? [[String: Any]] {
                scenes = try parseScenes(from: scenesData)
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Story generated via Supabase - Duration: \(responseTime)s", category: .story, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Supabase Story Generation", startTime: startTime, requestId: String(requestId))

            return StoryGenerationResponse(
                title: title,
                content: content,
                estimatedDuration: estimatedDuration,
                scenes: scenes
            )

        } catch {
            AppLogger.shared.error("Story generation failed", category: .story, requestId: String(requestId), error: error)
            throw mapSupabaseError(error)
        }
    }

    func generateStoryWithCustomEvent(request: CustomStoryGenerationRequest) async throws -> StoryGenerationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Custom story generation via Supabase started", category: .story, requestId: String(requestId))
        AppLogger.shared.debug("Hero: \(request.hero.name), Event: \(request.customEvent.title)", category: .story, requestId: String(requestId))

        // Convert hero and custom event to dictionaries
        let heroData = heroToDictionary(request.hero)
        let eventData = customEventToDictionary(request.customEvent)

        do {
            // Convert language name to code for Supabase backend
            let languageCode = AppSettings.supportedLanguageToCode(request.language)

            // Call Supabase Edge Function with custom event properly structured
            let response = try await supabaseService.generateStory(
                heroId: request.hero.id.uuidString,
                eventType: "custom",
                eventData: eventData,
                targetDuration: Int(request.targetDuration),
                language: languageCode
            )

            // Parse response
            AppLogger.shared.debug("Custom story generation response keys: \(response.keys.joined(separator: ", "))", category: .story, requestId: String(requestId))

            let title = response["title"] as? String ?? request.customEvent.title

            // Ensure content is not empty - throw error if it is
            guard let content = response["content"] as? String, !content.isEmpty else {
                AppLogger.shared.error("Custom story generation returned empty content", category: .story, requestId: String(requestId))
                AppLogger.shared.debug("Full response: \(response)", category: .story, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            let estimatedDuration = TimeInterval(response["estimated_duration"] as? Int ?? 300)
            AppLogger.shared.debug("Custom story content received: \(content.count) characters", category: .story, requestId: String(requestId))

            // Parse scenes if available
            var scenes: [StoryScene]? = nil
            if let scenesData = response["scenes"] as? [[String: Any]] {
                scenes = try parseScenes(from: scenesData)
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Custom story generated - Duration: \(responseTime)s", category: .story, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Supabase Custom Story Generation", startTime: startTime, requestId: String(requestId))

            return StoryGenerationResponse(
                title: title,
                content: content,
                estimatedDuration: estimatedDuration,
                scenes: scenes
            )

        } catch {
            AppLogger.shared.error("Custom story generation failed", category: .story, requestId: String(requestId), error: error)
            throw mapSupabaseError(error)
        }
    }

    // MARK: - Scene Extraction

    func extractScenesFromStory(request: SceneExtractionRequest) async throws -> [StoryScene] {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Scene extraction via Supabase started", category: .illustration, requestId: String(requestId))
        AppLogger.shared.debug("Story duration: \(Int(request.storyDuration)) seconds", category: .illustration, requestId: String(requestId))

        // Log the story content being sent
        if request.storyContent.isEmpty {
            AppLogger.shared.error("Attempting to extract scenes from empty story content!", category: .illustration, requestId: String(requestId))
        } else {
            AppLogger.shared.debug("Story content for scene extraction: \(request.storyContent.count) characters", category: .illustration, requestId: String(requestId))
            AppLogger.shared.debug("Story preview: \(String(request.storyContent.prefix(100)))...", category: .illustration, requestId: String(requestId))
        }

        do {
            // Call the dedicated extract-scenes Edge Function
            let response = try await supabaseService.extractScenes(
                storyContent: request.storyContent,
                storyDuration: Int(request.storyDuration),
                heroId: request.hero.id.uuidString,
                heroName: request.hero.name,
                eventContext: request.eventContext
            )

            // Parse the scenes from response
            guard let scenesData = response["scenes"] as? [[String: Any]] else {
                AppLogger.shared.warning("No scenes found in extraction response", category: .illustration, requestId: String(requestId))
                return []
            }

            let scenes = try parseScenes(from: scenesData)

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Scenes extracted - Count: \(scenes.count), Duration: \(responseTime)s", category: .illustration, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Supabase Scene Extraction", startTime: startTime, requestId: String(requestId))

            return scenes

        } catch {
            AppLogger.shared.error("Scene extraction failed", category: .illustration, requestId: String(requestId), error: error)
            throw mapSupabaseError(error)
        }
    }

    // MARK: - Audio Synthesis

    func generateSpeech(text: String, voice: String, language: String) async throws -> Data {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        // Validate that text is not empty before calling the Edge Function
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AppLogger.shared.error("Cannot generate audio for empty text", category: .audio, requestId: String(requestId))
            throw AIServiceError.invalidRequest("Text content is required for audio synthesis")
        }

        AppLogger.shared.info("TTS generation via Supabase started", category: .audio, requestId: String(requestId))
        AppLogger.shared.debug("Voice: \(voice), Language: \(language), Text length: \(text.count)", category: .audio, requestId: String(requestId))

        do {
            // Convert language name to code for Supabase backend (e.g., "French" -> "fr")
            let languageCode = AppSettings.supportedLanguageToCode(language)
            AppLogger.shared.debug("Converted language '\(language)' to code '\(languageCode)'", category: .audio, requestId: String(requestId))

            // Call Supabase Edge Function with language code
            let response = try await supabaseService.synthesizeAudio(
                text: text,
                voice: voice,
                language: languageCode
            )

            // Get audio URL from response
            guard let audioURLString = response["audio_url"] as? String else {
                throw AIServiceError.invalidResponse
            }

            // Download audio file
            let audioData = try await downloadFile(from: audioURLString, requestId: String(requestId))

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Audio generated - Size: \(audioData.count / 1024)KB, Duration: \(responseTime)s", category: .audio, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Supabase TTS Generation", startTime: startTime, requestId: String(requestId))

            return audioData

        } catch {
            AppLogger.shared.error("TTS generation failed", category: .audio, requestId: String(requestId), error: error)
            throw mapSupabaseError(error)
        }
    }

    // MARK: - Avatar Generation

    func generateAvatar(request: AvatarGenerationRequest) async throws -> AvatarGenerationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Avatar generation via Supabase started", category: .avatar, requestId: String(requestId))
        AppLogger.shared.debug("Hero: \(request.hero.name), Size: \(request.size)", category: .avatar, requestId: String(requestId))

        // Map quality parameter to Supabase format
        let quality = mapQualityToSupabase(request.quality)

        do {
            // Prepare extended request with previous generation ID if available
            var avatarRequest: [String: Any] = [
                "hero_id": request.hero.id.uuidString,
                "prompt": request.prompt,
                "quality": quality,
                "size": request.size,
                "style": "watercolor"  // Default style for children's illustrations
            ]

            if let previousGenId = request.previousGenerationId {
                avatarRequest["previous_generation_id"] = previousGenId
                AppLogger.shared.info("Using previous generation ID for consistency: \(previousGenId)", category: .avatar, requestId: String(requestId))
            }

            // Call Supabase Edge Function with extended parameters
            let response = try await callEdgeFunction(
                "avatar-generation",
                body: avatarRequest,
                requestId: String(requestId)
            )

            // Get image URL from response
            guard let imageURLString = response["avatar_url"] as? String else {
                throw AIServiceError.invalidResponse
            }

            // Download image
            let imageData = try await downloadFile(from: imageURLString, requestId: String(requestId))

            // Extract metadata
            let revisedPrompt = response["revised_prompt"] as? String
            let generationId = response["generation_id"] as? String

            if let generationId = generationId {
                AppLogger.shared.info("Avatar generation ID: \(generationId)", category: .avatar, requestId: String(requestId))
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Avatar generated - Size: \(imageData.count / 1024)KB, Duration: \(responseTime)s", category: .avatar, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Supabase Avatar Generation", startTime: startTime, requestId: String(requestId))

            return AvatarGenerationResponse(
                imageData: imageData,
                revisedPrompt: revisedPrompt,
                generationId: generationId
            )

        } catch {
            AppLogger.shared.error("Avatar generation failed", category: .avatar, requestId: String(requestId), error: error)
            throw mapSupabaseError(error)
        }
    }

    // MARK: - Scene Illustration

    func generateSceneIllustration(prompt: String, hero: Hero, previousGenerationId: String?) async throws -> SceneIllustrationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Scene illustration via Supabase started", category: .illustration, requestId: String(requestId))
        AppLogger.shared.debug("Hero: \(hero.name)", category: .illustration, requestId: String(requestId))

        if let previousGenId = previousGenerationId {
            AppLogger.shared.info("Using previous generation ID: \(previousGenId)", category: .illustration, requestId: String(requestId))
        }

        do {
            // Prepare scene data
            let sceneData: [String: Any] = [
                "prompt": prompt,
                "scene_number": 1,
                "timestamp": 0
            ]

            // Prepare visual profile if available
            var visualProfile: [String: Any]? = nil
            if let avatarPrompt = hero.avatarPrompt {
                visualProfile = [
                    "canonical_prompt": avatarPrompt,
                    "appearance": hero.appearance
                ]
            }

            // Call Supabase Edge Function for single scene
            let response = try await supabaseService.generateSceneIllustrations(
                storyId: UUID().uuidString, // Temporary ID for single scene
                heroId: hero.id.uuidString,
                scenes: [sceneData],
                heroVisualProfile: visualProfile,
                processAsync: false
            )

            // Parse response
            guard let illustrations = response["illustrations"] as? [[String: Any]],
                  let firstIllustration = illustrations.first else {
                // Check if async processing
                if let status = response["status"] as? String, status == "pending" {
                    throw AIServiceError.apiError("Async processing initiated, illustration pending")
                }
                throw AIServiceError.invalidResponse
            }

            // Get image URL and download
            guard let imageURLString = firstIllustration["image_url"] as? String else {
                throw AIServiceError.invalidResponse
            }

            let imageData = try await downloadFile(from: imageURLString, requestId: String(requestId))

            // Extract metadata
            let revisedPrompt = firstIllustration["revised_prompt"] as? String
            let generationId = firstIllustration["generation_id"] as? String

            if let generationId = generationId {
                AppLogger.shared.info("Scene generation ID: \(generationId)", category: .illustration, requestId: String(requestId))
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Scene illustration generated - Duration: \(responseTime)s", category: .illustration, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Supabase Scene Illustration", startTime: startTime, requestId: String(requestId))

            return SceneIllustrationResponse(
                imageData: imageData,
                revisedPrompt: revisedPrompt,
                generationId: generationId
            )

        } catch {
            AppLogger.shared.error("Scene illustration failed", category: .illustration, requestId: String(requestId), error: error)
            throw mapSupabaseError(error)
        }
    }

    // MARK: - Task Cancellation

    func cancelCurrentTask() {
        AppLogger.shared.info("Cancelling current Supabase AI task", category: .api)
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Helper Methods

    /// Convert Hero model to dictionary for Edge Functions
    private func heroToDictionary(_ hero: Hero) -> [String: Any] {
        return [
            "id": hero.id.uuidString,
            "name": hero.name,
            "primary_trait": hero.primaryTrait.rawValue,
            "secondary_trait": hero.secondaryTrait.rawValue,
            "appearance": hero.appearance,
            "special_ability": hero.specialAbility,
            "avatar_prompt": hero.avatarPrompt ?? "",
            "avatar_generation_id": hero.avatarGenerationId ?? ""
        ]
    }

    /// Convert CustomStoryEvent to dictionary for Edge Functions
    private func customEventToDictionary(_ event: CustomStoryEvent) -> [String: Any] {
        return [
            "id": event.id.uuidString,
            "title": event.title,
            "description": event.eventDescription,
            "prompt_seed": event.promptSeed,
            "keywords": event.keywords,
            "category": event.category.rawValue,
            "tone": event.tone.rawValue,
            "age_range": event.ageRange.rawValue,
            "pictogram": event.pictogramPath ?? "✨"
        ]
    }

    /// Parse scenes from Edge Function response
    private func parseScenes(from scenesData: [[String: Any]]) throws -> [StoryScene] {
        return scenesData.compactMap { sceneDict in
            guard let sceneNumber = sceneDict["scene_number"] as? Int,
                  let textSegment = sceneDict["text_segment"] as? String,
                  let illustrationPrompt = sceneDict["illustration_prompt"] as? String,
                  let timestamp = sceneDict["timestamp"] as? Double else {
                return nil
            }

            let emotionString = sceneDict["emotion"] as? String ?? "peaceful"
            let importanceString = sceneDict["importance"] as? String ?? "major"

            return StoryScene(
                sceneNumber: sceneNumber,
                textSegment: textSegment,
                illustrationPrompt: illustrationPrompt,
                timestamp: TimeInterval(timestamp),
                emotion: SceneEmotion(rawValue: emotionString) ?? .peaceful,
                importance: SceneImportance(rawValue: importanceString) ?? .major
            )
        }
    }

    /// Map quality parameter to Supabase format
    private func mapQualityToSupabase(_ quality: String) -> String {
        switch quality.lowercased() {
        case "standard", "low":
            return "low"
        case "hd", "high":
            return "high"
        default:
            return "medium"
        }
    }

    /// Download file from URL
    private func downloadFile(from urlString: String, requestId: String) async throws -> Data {
        // Handle mock URLs during development
        if urlString.starts(with: "mock://") {
            AppLogger.shared.warning("Mock URL detected, returning placeholder data", category: .api, requestId: requestId)

            // Return appropriate placeholder based on mock URL
            if urlString.contains("audio") {
                // Return a silent audio file placeholder
                return Data()
            } else if urlString.contains("avatar") || urlString.contains("image") {
                // Return a 1x1 transparent PNG
                let transparentPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==") ?? Data()
                return transparentPNG
            }
            return Data()
        }

        // Handle base64 data URLs
        if urlString.starts(with: "data:") {
            let components = urlString.components(separatedBy: ",")
            if components.count == 2,
               let base64Data = Data(base64Encoded: components[1]) {
                AppLogger.shared.debug("Decoded base64 data: \(base64Data.count / 1024)KB", category: .api, requestId: requestId)
                return base64Data
            }
            throw AIServiceError.invalidResponse
        }

        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidResponse
        }

        AppLogger.shared.debug("Downloading file from: \(url.absoluteString)", category: .api, requestId: requestId)

        do {
            // Create URL request with timeout
            var request = URLRequest(url: url)
            request.timeoutInterval = 60 // 60 seconds timeout for file downloads
            request.cachePolicy = .reloadIgnoringLocalCacheData

            // Use a custom URLSession with download task for better memory management
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForResource = 120 // 2 minutes max
            let session = URLSession(configuration: configuration)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.networkError(URLError(.badServerResponse))
            }

            // Accept various success codes
            guard (200...299).contains(httpResponse.statusCode) else {
                AppLogger.shared.error("HTTP error \(httpResponse.statusCode) downloading file", category: .api, requestId: requestId)
                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
            }

            AppLogger.shared.debug("Downloaded \(data.count / 1024)KB from \(url.lastPathComponent)", category: .api, requestId: requestId)
            return data

        } catch {
            AppLogger.shared.error("File download failed", category: .api, requestId: requestId, error: error)
            throw AIServiceError.networkError(error)
        }
    }

    /// Call a Supabase Edge Function directly
    private func callEdgeFunction(_ functionName: String, body: [String: Any], requestId: String) async throws -> [String: Any] {
        AppLogger.shared.debug("Calling Edge Function: \(functionName)", category: .api, requestId: requestId)

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)

            // Direct call to avatar generation for now as it's implemented in SupabaseService
            if functionName == "avatar-generation" {
                let heroId = body["hero_id"] as? String ?? ""
                let prompt = body["prompt"] as? String ?? ""
                let quality = body["quality"] as? String ?? "high"
                let size = body["size"] as? String ?? "1024x1024"
                let style = body["style"] as? String ?? "watercolor"

                return try await supabaseService.generateAvatar(
                    heroId: heroId,
                    prompt: prompt,
                    style: style,
                    quality: quality,
                    size: size
                )
            }

            // For other functions, return mock data for now
            AppLogger.shared.warning("Edge Function \(functionName) not yet implemented, returning mock", category: .api, requestId: requestId)
            return [:]

        } catch {
            AppLogger.shared.error("Edge Function call failed: \(functionName)", category: .api, requestId: requestId, error: error)
            throw error
        }
    }


    /// Map Supabase errors to AIServiceError
    private func mapSupabaseError(_ error: Error) -> AIServiceError {
        if let supabaseError = error as? SupabaseError {
            switch supabaseError {
            case .apiError(let message):
                // Check for specific error types
                if message.lowercased().contains("rate limit") {
                    return .rateLimitExceeded
                } else if message.lowercased().contains("content policy") {
                    return .contentPolicyViolation(message)
                } else if message.lowercased().contains("not found") {
                    return .apiError("Resource not found")
                }
                return .apiError(message)

            case .networkError(let networkError):
                return .networkError(networkError)

            case .authenticationError(let message):
                return .apiError("Authentication failed: \(message)")

            case .decodingError:
                return .invalidResponse

            case .notFound:
                return .apiError("Resource not found")

            case .invalidConfiguration(let message):
                return .apiError("Configuration error: \(message)")

            case .unexpectedResponse:
                return .invalidResponse
            }
        }

        // Check for URL errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(urlError)
            case .timedOut:
                return .apiError("Request timed out")
            default:
                return .networkError(urlError)
            }
        }

        // Default mapping
        return .networkError(error)
    }
}

// MARK: - AppLogger Extensions for Supabase

extension AppLogger {
    func logSupabaseRequest(_ function: String, requestId: String, bodySize: Int? = nil) {
        let metadata: [String: Any] = [
            "function": function,
            "body_size": bodySize ?? 0
        ]
        log("Supabase Edge Function Request: \(function)", level: .network, category: .api, requestId: requestId, metadata: metadata)
    }

    func logSupabaseResponse(_ function: String, success: Bool, responseTime: TimeInterval, requestId: String) {
        let level: LogLevel = success ? .success : .error
        let metadata: [String: Any] = [
            "function": function,
            "response_time": String(format: "%.2fs", responseTime),
            "success": success
        ]
        log("Supabase Response: \(function)", level: level, category: .api, requestId: requestId, metadata: metadata)
    }
}

// MARK: - Additional Required Imports

// Note: Supabase is imported through SupabaseService, no direct import needed