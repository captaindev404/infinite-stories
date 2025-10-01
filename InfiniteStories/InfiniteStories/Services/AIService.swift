//
//  AIService.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation
import os.log

struct StoryGenerationRequest {
    let hero: Hero
    let event: StoryEvent
    let targetDuration: TimeInterval // in seconds (5-10 minutes = 300-600 seconds)
    let language: String // Target language for story generation
}

struct CustomStoryGenerationRequest {
    let hero: Hero
    let customEvent: CustomStoryEvent
    let targetDuration: TimeInterval // in seconds (5-10 minutes = 300-600 seconds)
    let language: String // Target language for story generation
}

struct StoryGenerationResponse {
    let title: String
    let content: String
    let estimatedDuration: TimeInterval
    let scenes: [StoryScene]? // Optional for backward compatibility
}

// New structure for scene-based story generation
struct StoryScene {
    let sceneNumber: Int
    let textSegment: String
    let illustrationPrompt: String
    let timestamp: TimeInterval // Estimated timestamp in seconds
    let emotion: SceneEmotion
    let importance: SceneImportance
}

enum SceneEmotion: String {
    case joyful = "joyful"
    case peaceful = "peaceful"
    case exciting = "exciting"
    case mysterious = "mysterious"
    case heartwarming = "heartwarming"
    case adventurous = "adventurous"
    case contemplative = "contemplative"
}

enum SceneImportance: String {
    case key = "key"      // Critical story moments
    case major = "major"  // Important developments
    case minor = "minor"  // Supporting scenes
}

struct AvatarGenerationRequest {
    let hero: Hero
    let prompt: String
    let size: String // "1024x1024", "1792x1024", or "1024x1792"
    let quality: String // "low", "medium", or "high" for DALL-E 3
    let previousGenerationId: String? // Optional previous generation ID for consistency
}

struct AvatarGenerationResponse {
    let imageData: Data
    let revisedPrompt: String?
    let generationId: String? // DALL-E 3 generation ID for multi-turn consistency
}

struct SceneIllustrationResponse {
    let imageData: Data
    let revisedPrompt: String?
    let generationId: String? // DALL-E 3 generation ID for multi-turn consistency
}

enum AIServiceError: Error {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case invalidRequest(String)
    case apiError(String)
    case rateLimitExceeded
    case imageGenerationFailed
    case fileSystemError
    case invalidPrompt
    case contentPolicyViolation(String)
}

// JSON structures for scene extraction
struct SceneExtractionRequest {
    let storyContent: String
    let storyDuration: TimeInterval
    let hero: Hero
    let eventContext: String
}

struct SceneExtractionJSONResponse: Codable {
    let scenes: [SceneJSON]
    let sceneCount: Int
    let reasoning: String
}

struct SceneJSON: Codable {
    let sceneNumber: Int
    let textSegment: String
    let timestamp: Double
    let illustrationPrompt: String
    let emotion: String
    let importance: String
}

// Extension to convert StoryScene to StoryIllustration
extension StoryScene {
    func toStoryIllustration(previousGenerationId: String? = nil) -> StoryIllustration {
        return StoryIllustration(
            timestamp: timestamp,
            imagePrompt: illustrationPrompt,
            displayOrder: sceneNumber - 1, // Convert to 0-based index
            textSegment: textSegment,
            previousGenerationId: previousGenerationId // Pass through generation ID for chaining
        )
    }
}

// Extension to StoryGenerationResponse for convenience
extension StoryGenerationResponse {
    var hasScenes: Bool {
        return scenes != nil && !scenes!.isEmpty
    }

    var cleanContent: String {
        // Return story content without scene markers
        return content
    }

    func createIllustrations(heroAvatarGenerationId: String? = nil) -> [StoryIllustration] {
        guard let scenes = scenes else { return [] }
        return scenes.enumerated().map { (index, scene) in
            // First illustration should use hero's avatar generation ID for chaining
            let previousGenId = index == 0 ? heroAvatarGenerationId : nil
            return scene.toStoryIllustration(previousGenerationId: previousGenId)
        }
    }
}

protocol AIServiceProtocol {
    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse
    func generateStoryWithCustomEvent(request: CustomStoryGenerationRequest) async throws -> StoryGenerationResponse
    func extractScenesFromStory(request: SceneExtractionRequest) async throws -> [StoryScene]
    func generateSpeech(text: String, voice: String, language: String) async throws -> Data
    func generateAvatar(request: AvatarGenerationRequest) async throws -> AvatarGenerationResponse
    func generateSceneIllustration(prompt: String, hero: Hero, previousGenerationId: String?) async throws -> SceneIllustrationResponse
    func cancelCurrentTask()
    var currentTask: URLSessionDataTask? { get set }
}

// OpenAIService has been removed - all AI operations now go through Supabase Edge Functions via SupabaseAIService