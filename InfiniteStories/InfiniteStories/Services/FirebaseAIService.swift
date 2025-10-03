//
//  FirebaseAIService.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/02/2025.
//
//  Firebase Cloud Functions implementation of AIServiceProtocol
//  Migrated from Supabase Edge Functions to Firebase Cloud Functions
//

import Foundation
import FirebaseCore
import FirebaseFunctions
import os.log

/// Firebase Cloud Functions implementation of AIServiceProtocol
/// This service integrates with Firebase Cloud Functions backend instead of calling OpenAI directly
class FirebaseAIService: AIServiceProtocol {

    // MARK: - Properties

    private lazy var functions = Functions.functions()
    var currentTask: URLSessionDataTask?

    // Feature flag for scene-based generation (matches OpenAIService)
    var enableSceneBasedGeneration: Bool = true

    // MARK: - Initialization

    init() {
        // Configure Firebase Functions for local development if needed
        #if DEBUG
        // Uncomment for local emulator testing
        // functions.useEmulator(withHost: "localhost", port: 5001)
        #endif

        AppLogger.shared.info("FirebaseAIService initialized", category: .api)
    }

    // MARK: - Story Generation

    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Story generation via Firebase started", category: .story, requestId: String(requestId))
        AppLogger.shared.debug("Parameters - Hero: \(request.hero.name), Event: \(request.event.rawValue), Language: \(request.language), Duration: \(Int(request.targetDuration/60))min", category: .story, requestId: String(requestId))

        // Build request data for Firebase Function
        let requestData: [String: Any] = [
            "hero_id": request.hero.id.uuidString,
            "hero": [
                "name": request.hero.name,
                "primary_trait": request.hero.primaryTrait.rawValue,
                "secondary_trait": request.hero.secondaryTrait.rawValue,
                "appearance": request.hero.appearance,
                "special_ability": request.hero.specialAbility,
                "avatar_prompt": request.hero.avatarPrompt ?? ""
            ],
            "event": [
                "type": "built_in",
                "data": [
                    "event": request.event.rawValue,
                    "prompt_seed": request.event.promptSeed
                ]
            ],
            "target_duration": Int(request.targetDuration),
            "language": request.language
        ]

        do {
            // Call Firebase Cloud Function
            let callable = functions.httpsCallable("storyGeneration")
            let result = try await callable.call(requestData)

            // Parse response
            guard let responseData = result.data as? [String: Any] else {
                AppLogger.shared.error("Invalid response format from Firebase Function", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            guard let title = responseData["title"] as? String,
                  let content = responseData["content"] as? String,
                  let estimatedDuration = responseData["estimated_duration"] as? Double else {
                AppLogger.shared.error("Missing required fields in Firebase response", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            // Parse optional scenes data
            var scenes: [StoryScene]? = nil
            if let scenesData = responseData["scenes"] as? [[String: Any]] {
                scenes = scenesData.compactMap { sceneData -> StoryScene? in
                    guard let sceneNumber = sceneData["scene_number"] as? Int,
                          let textSegment = sceneData["text_segment"] as? String,
                          let illustrationPrompt = sceneData["illustration_prompt"] as? String,
                          let timestamp = sceneData["timestamp"] as? Double,
                          let emotionStr = sceneData["emotion"] as? String,
                          let importanceStr = sceneData["importance"] as? String else {
                        return nil
                    }

                    return StoryScene(
                        sceneNumber: sceneNumber,
                        textSegment: textSegment,
                        illustrationPrompt: illustrationPrompt,
                        timestamp: timestamp,
                        emotion: SceneEmotion(rawValue: emotionStr) ?? .peaceful,
                        importance: SceneImportance(rawValue: importanceStr) ?? .major
                    )
                }
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Story generated via Firebase - Duration: \(String(format: "%.2f", responseTime))s", category: .story, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Firebase Story Generation", startTime: startTime, requestId: String(requestId))

            return StoryGenerationResponse(
                title: title,
                content: content,
                estimatedDuration: estimatedDuration,
                scenes: scenes
            )

        } catch {
            AppLogger.shared.error("Firebase story generation failed", category: .api, requestId: String(requestId), error: error)
            throw mapFirebaseError(error)
        }
    }

    func generateStoryWithCustomEvent(request: CustomStoryGenerationRequest) async throws -> StoryGenerationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Custom story generation via Firebase started", category: .story, requestId: String(requestId))
        AppLogger.shared.debug("Hero: \(request.hero.name), Event: \(request.customEvent.title), Duration: \(Int(request.targetDuration/60))min", category: .story, requestId: String(requestId))

        // Build request data for Firebase Function
        let requestData: [String: Any] = [
            "hero_id": request.hero.id.uuidString,
            "hero": [
                "name": request.hero.name,
                "primary_trait": request.hero.primaryTrait.rawValue,
                "secondary_trait": request.hero.secondaryTrait.rawValue,
                "appearance": request.hero.appearance,
                "special_ability": request.hero.specialAbility,
                "avatar_prompt": request.hero.avatarPrompt ?? ""
            ],
            "event": [
                "type": "custom",
                "data": [
                    "title": request.customEvent.title,
                    "description": request.customEvent.eventDescription,
                    "prompt_seed": request.customEvent.promptSeed,
                    "tone": request.customEvent.tone.rawValue,
                    "age_range": request.customEvent.ageRange.rawValue,
                    "keywords": request.customEvent.keywords
                ]
            ],
            "target_duration": Int(request.targetDuration),
            "language": request.language
        ]

        do {
            // Call Firebase Cloud Function
            let callable = functions.httpsCallable("storyGeneration")
            let result = try await callable.call(requestData)

            // Parse response (same format as regular story)
            guard let responseData = result.data as? [String: Any] else {
                AppLogger.shared.error("Invalid response format from Firebase Function", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            guard let title = responseData["title"] as? String,
                  let content = responseData["content"] as? String,
                  let estimatedDuration = responseData["estimated_duration"] as? Double else {
                AppLogger.shared.error("Missing required fields in Firebase response", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            // Parse optional scenes data
            var scenes: [StoryScene]? = nil
            if let scenesData = responseData["scenes"] as? [[String: Any]] {
                scenes = scenesData.compactMap { sceneData -> StoryScene? in
                    guard let sceneNumber = sceneData["scene_number"] as? Int,
                          let textSegment = sceneData["text_segment"] as? String,
                          let illustrationPrompt = sceneData["illustration_prompt"] as? String,
                          let timestamp = sceneData["timestamp"] as? Double,
                          let emotionStr = sceneData["emotion"] as? String,
                          let importanceStr = sceneData["importance"] as? String else {
                        return nil
                    }

                    return StoryScene(
                        sceneNumber: sceneNumber,
                        textSegment: textSegment,
                        illustrationPrompt: illustrationPrompt,
                        timestamp: timestamp,
                        emotion: SceneEmotion(rawValue: emotionStr) ?? .peaceful,
                        importance: SceneImportance(rawValue: importanceStr) ?? .major
                    )
                }
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Custom story generated via Firebase - Duration: \(String(format: "%.2f", responseTime))s", category: .story, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Firebase Custom Story Generation", startTime: startTime, requestId: String(requestId))

            return StoryGenerationResponse(
                title: title,
                content: content,
                estimatedDuration: estimatedDuration,
                scenes: scenes
            )

        } catch {
            AppLogger.shared.error("Firebase custom story generation failed", category: .api, requestId: String(requestId), error: error)
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Scene Extraction

    func extractScenesFromStory(request: SceneExtractionRequest) async throws -> [StoryScene] {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Scene extraction via Firebase started", category: .illustration, requestId: String(requestId))
        AppLogger.shared.debug("Story duration: \(Int(request.storyDuration)) seconds", category: .illustration, requestId: String(requestId))

        // Build request data for Firebase Function
        let requestData: [String: Any] = [
            "story_content": request.storyContent,
            "story_duration": request.storyDuration,
            "hero": [
                "name": request.hero.name,
                "appearance": request.hero.appearance,
                "avatar_prompt": request.hero.avatarPrompt ?? ""
            ],
            "event_context": request.eventContext
        ]

        do {
            // Call Firebase Cloud Function
            let callable = functions.httpsCallable("extractScenes")
            let result = try await callable.call(requestData)

            // Parse response
            guard let responseData = result.data as? [String: Any],
                  let scenesData = responseData["scenes"] as? [[String: Any]] else {
                AppLogger.shared.error("Invalid response format from Firebase Function", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            let scenes = scenesData.compactMap { sceneData -> StoryScene? in
                guard let sceneNumber = sceneData["scene_number"] as? Int,
                      let textSegment = sceneData["text_segment"] as? String,
                      let illustrationPrompt = sceneData["illustration_prompt"] as? String,
                      let timestamp = sceneData["timestamp"] as? Double,
                      let emotionStr = sceneData["emotion"] as? String,
                      let importanceStr = sceneData["importance"] as? String else {
                    return nil
                }

                return StoryScene(
                    sceneNumber: sceneNumber,
                    textSegment: textSegment,
                    illustrationPrompt: illustrationPrompt,
                    timestamp: timestamp,
                    emotion: SceneEmotion(rawValue: emotionStr) ?? .peaceful,
                    importance: SceneImportance(rawValue: importanceStr) ?? .major
                )
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Extracted \(scenes.count) scenes via Firebase - Duration: \(String(format: "%.2f", responseTime))s", category: .illustration, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Firebase Scene Extraction", startTime: startTime, requestId: String(requestId))

            return scenes

        } catch {
            AppLogger.shared.error("Firebase scene extraction failed", category: .api, requestId: String(requestId), error: error)
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Audio Synthesis

    func generateSpeech(text: String, voice: String, language: String) async throws -> Data {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("TTS generation via Firebase started", category: .audio, requestId: String(requestId))
        AppLogger.shared.debug("Voice: \(voice), Language: \(language), Text length: \(text.count) characters", category: .audio, requestId: String(requestId))

        // Build request data for Firebase Function
        let requestData: [String: Any] = [
            "text": text,
            "voice": voice,
            "language": language
        ]

        do {
            // Call Firebase Cloud Function
            let callable = functions.httpsCallable("audioSynthesis")
            let result = try await callable.call(requestData)

            // Parse response
            guard let responseData = result.data as? [String: Any] else {
                AppLogger.shared.error("Invalid response format from Firebase Function", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            // Audio data can be returned as base64 string or URL
            var audioData: Data?

            if let base64Audio = responseData["audio_data"] as? String,
               let data = Data(base64Encoded: base64Audio) {
                audioData = data
            } else if let audioURL = responseData["audio_url"] as? String,
                      let url = URL(string: audioURL) {
                // Download audio from Firebase Storage URL
                let (data, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    audioData = data
                } else {
                    AppLogger.shared.error("Failed to download audio from Firebase Storage", category: .audio, requestId: String(requestId))
                    throw AIServiceError.invalidResponse
                }
            }

            guard let finalAudioData = audioData else {
                AppLogger.shared.error("No audio data in Firebase response", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Audio generated via Firebase - Size: \(finalAudioData.count / 1024)KB, Duration: \(String(format: "%.2f", responseTime))s", category: .audio, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Firebase TTS Generation", startTime: startTime, requestId: String(requestId))

            return finalAudioData

        } catch {
            AppLogger.shared.error("Firebase TTS generation failed", category: .api, requestId: String(requestId), error: error)
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Avatar Generation

    func generateAvatar(request: AvatarGenerationRequest) async throws -> AvatarGenerationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Avatar generation via Firebase started", category: .avatar, requestId: String(requestId))
        AppLogger.shared.debug("Hero: \(request.hero.name), Size: \(request.size), Quality: \(request.quality)", category: .avatar, requestId: String(requestId))

        // Build request data for Firebase Function
        let requestData: [String: Any] = [
            "hero": [
                "id": request.hero.id.uuidString,
                "name": request.hero.name,
                "primary_trait": request.hero.primaryTrait.rawValue,
                "secondary_trait": request.hero.secondaryTrait.rawValue,
                "appearance": request.hero.appearance,
                "special_ability": request.hero.specialAbility
            ],
            "prompt": request.prompt,
            "size": request.size,
            "quality": request.quality
        ]

        do {
            // Call Firebase Cloud Function
            let callable = functions.httpsCallable("avatarGeneration")
            let result = try await callable.call(requestData)

            // Parse response
            guard let responseData = result.data as? [String: Any] else {
                AppLogger.shared.error("Invalid response format from Firebase Function", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            // Image data can be returned as base64 string or URL
            var imageData: Data?

            if let base64Image = responseData["image_data"] as? String,
               let data = Data(base64Encoded: base64Image) {
                imageData = data
            } else if let imageURL = responseData["image_url"] as? String,
                      let url = URL(string: imageURL) {
                // Download image from Firebase Storage URL
                let (data, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    imageData = data
                } else {
                    AppLogger.shared.error("Failed to download avatar from Firebase Storage", category: .avatar, requestId: String(requestId))
                    throw AIServiceError.invalidResponse
                }
            }

            guard let finalImageData = imageData else {
                AppLogger.shared.error("No image data in Firebase response", category: .api, requestId: String(requestId))
                throw AIServiceError.imageGenerationFailed
            }

            let revisedPrompt = responseData["revised_prompt"] as? String
            let generationId = responseData["generation_id"] as? String

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Avatar generated via Firebase - Size: \(finalImageData.count / 1024)KB, Duration: \(String(format: "%.2f", responseTime))s", category: .avatar, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Firebase Avatar Generation", startTime: startTime, requestId: String(requestId))

            return AvatarGenerationResponse(
                imageData: finalImageData,
                revisedPrompt: revisedPrompt,
                generationId: generationId
            )

        } catch {
            AppLogger.shared.error("Firebase avatar generation failed", category: .api, requestId: String(requestId), error: error)

            // Check for content policy violations
            if let nsError = error as NSError?,
               let errorMessage = nsError.userInfo["message"] as? String,
               errorMessage.lowercased().contains("content_policy") {
                throw AIServiceError.contentPolicyViolation(errorMessage)
            }

            throw mapFirebaseError(error)
        }
    }

    // MARK: - Scene Illustration

    func generateSceneIllustration(prompt: String, hero: Hero, previousGenerationId: String? = nil) async throws -> SceneIllustrationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Scene illustration via Firebase started", category: .illustration, requestId: String(requestId))
        AppLogger.shared.info("Hero: \(hero.name)", category: .illustration, requestId: String(requestId))

        // Build request data for Firebase Function
        var requestData: [String: Any] = [
            "prompt": prompt,
            "hero": [
                "id": hero.id.uuidString,
                "name": hero.name,
                "appearance": hero.appearance,
                "avatar_prompt": hero.avatarPrompt ?? "",
                "primary_trait": hero.primaryTrait.rawValue,
                "secondary_trait": hero.secondaryTrait.rawValue
            ]
        ]

        // Add previous generation ID for multi-turn consistency if provided
        if let previousGenerationId = previousGenerationId {
            requestData["previous_generation_id"] = previousGenerationId
        }

        do {
            // Call Firebase Cloud Function
            let callable = functions.httpsCallable("sceneIllustration")
            let result = try await callable.call(requestData)

            // Parse response
            guard let responseData = result.data as? [String: Any] else {
                AppLogger.shared.error("Invalid response format from Firebase Function", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            // Image data can be returned as base64 string or URL
            var imageData: Data?

            if let base64Image = responseData["image_data"] as? String,
               let data = Data(base64Encoded: base64Image) {
                imageData = data
            } else if let imageURL = responseData["image_url"] as? String,
                      let url = URL(string: imageURL) {
                // Download image from Firebase Storage URL
                let (data, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    imageData = data
                } else {
                    AppLogger.shared.error("Failed to download illustration from Firebase Storage", category: .illustration, requestId: String(requestId))
                    throw AIServiceError.invalidResponse
                }
            }

            guard let finalImageData = imageData else {
                AppLogger.shared.error("No image data in Firebase response", category: .api, requestId: String(requestId))
                throw AIServiceError.imageGenerationFailed
            }

            let revisedPrompt = responseData["revised_prompt"] as? String
            let generationId = responseData["generation_id"] as? String

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.success("Scene illustration generated via Firebase - Size: \(finalImageData.count / 1024)KB, Duration: \(String(format: "%.2f", responseTime))s", category: .illustration, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Firebase Scene Illustration", startTime: startTime, requestId: String(requestId))

            return SceneIllustrationResponse(
                imageData: finalImageData,
                revisedPrompt: revisedPrompt,
                generationId: generationId
            )

        } catch {
            AppLogger.shared.error("Firebase scene illustration failed", category: .api, requestId: String(requestId), error: error)

            // Check for content policy violations
            if let nsError = error as NSError?,
               let errorMessage = nsError.userInfo["message"] as? String,
               errorMessage.lowercased().contains("content_policy") {
                throw AIServiceError.contentPolicyViolation(errorMessage)
            }

            throw mapFirebaseError(error)
        }
    }

    // MARK: - Task Management

    func cancelCurrentTask() {
        AppLogger.shared.info("Cancelling current Firebase task", category: .api)
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Helper Methods

    /// Map Firebase errors to AIServiceError
    private func mapFirebaseError(_ error: Error) -> AIServiceError {
        if let nsError = error as NSError? {
            let code = FunctionsErrorCode(rawValue: nsError.code)

            switch code {
            case .unavailable:
                return AIServiceError.networkError(error)
            case .unauthenticated, .permissionDenied:
                return AIServiceError.invalidAPIKey
            case .resourceExhausted:
                return AIServiceError.rateLimitExceeded
            case .invalidArgument:
                return AIServiceError.invalidPrompt
            case .internal:
                if let message = nsError.userInfo["message"] as? String {
                    return AIServiceError.apiError(message)
                }
                return AIServiceError.apiError("Internal Firebase error")
            default:
                if let message = nsError.userInfo["message"] as? String {
                    return AIServiceError.apiError(message)
                }
                return AIServiceError.networkError(error)
            }
        }

        return AIServiceError.networkError(error)
    }
}

// MARK: - Firebase Service Configuration

extension FirebaseAIService {
    /// Configure Firebase Functions for different environments
    static func configure(environment: String = "production") {
        switch environment {
        case "development", "local":
            // Use local emulator for development
            Functions.functions().useEmulator(withHost: "localhost", port: 5001)
            AppLogger.shared.info("Firebase Functions configured for local emulator", category: .api)
        case "staging":
            // Could configure staging environment if needed
            AppLogger.shared.info("Firebase Functions configured for staging", category: .api)
        default:
            // Production configuration (default)
            AppLogger.shared.info("Firebase Functions configured for production", category: .api)
        }
    }
}