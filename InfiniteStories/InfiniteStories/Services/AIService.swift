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

class OpenAIService: AIServiceProtocol {
    private let apiKey: String
    private let chatURL = "https://api.openai.com/v1/chat/completions"
    private let ttsURL = "https://api.openai.com/v1/audio/speech"
    private let imageURL = "https://api.openai.com/v1/images/generations"
    var currentTask: URLSessionDataTask?

    // Feature flag for scene-based generation (can be configured)
    var enableSceneBasedGeneration: Bool = true

    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generateStory(request: StoryGenerationRequest) async throws -> StoryGenerationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Story generation started", category: .story, requestId: String(requestId))
        AppLogger.shared.debug("Parameters - Hero: \(request.hero.name), Event: \(request.event.rawValue), Language: \(request.language), Duration: \(Int(request.targetDuration/60))min", category: .story, requestId: String(requestId))

        guard !apiKey.isEmpty else {
            AppLogger.shared.error("API key is empty", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidAPIKey
        }
        
        let prompt = buildPrompt(for: request)
        print("🤖 📝 Generated Prompt:")
        print("🤖 \(prompt)")
        print("🤖 ==================")
        
        let requestBody = [
            "model": "gpt-4o",  // Latest OpenAI model as of 2024
            "messages": [
                [
                    "role": "system",
                    "content": PromptLocalizer.getSystemMessage(for: request.language)
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 2000,
            "temperature": 0.8
        ] as [String : Any]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("🤖 ❌ Error: Failed to serialize request JSON")
            throw AIServiceError.invalidResponse
        }

        // Comprehensive HTTP Request Logging
        logFullHTTPRequest(
            url: chatURL,
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(apiKey.prefix(10))...[REDACTED]"
            ],
            bodyData: jsonData,
            requestId: String(requestId)
        )

        var urlRequest = URLRequest(url: URL(string: chatURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("🤖 ❌ Error: Invalid HTTP response")
                throw AIServiceError.networkError(URLError(.badServerResponse))
            }

            // Log response details
            let responseTime = Date().timeIntervalSince(startTime)
            logHTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields,
                dataSize: data.count,
                responseTime: responseTime,
                requestId: String(requestId)
            )
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    print("🤖 ⏳ Error: Rate limit exceeded")
                    throw AIServiceError.rateLimitExceeded
                }
                print("🤖 ❌ HTTP Error: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("🤖 📥 Error Response: \(errorString)")
                }
                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            // Log the raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("🤖 📥 Raw Response: \(responseString)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("🤖 ❌ Error: Failed to parse JSON response")
                throw AIServiceError.invalidResponse
            }
            
            print("🤖 ✅ Successfully parsed response")
            print("🤖 📖 Generated Story Content:")
            print("🤖 \(content)")
            print("🤖 ==================")
            
            let result = parseStoryResponse(content: content, request: request)
            print("🤖 📊 Final Result - Title: \(result.title)")
            print("🤖 📊 Final Result - Duration: \(Int(result.estimatedDuration/60)) minutes")
            print("🤖 📊 Final Result - Word Count: \(result.content.split(separator: " ").count)")
            print("🤖 === Story Generation Completed ===")
            
            return result
            
        } catch let error as AIServiceError {
            print("🤖 ❌ AI Service Error: \(error)")
            throw error
        } catch {
            print("🤖 ❌ Network Error: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }
    
    func generateStoryWithCustomEvent(request: CustomStoryGenerationRequest) async throws -> StoryGenerationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Custom story generation started", category: .story, requestId: String(requestId))
        AppLogger.shared.debug("Hero: \(request.hero.name), Event: \(request.customEvent.title), Duration: \(Int(request.targetDuration/60))min", category: .story, requestId: String(requestId))
        
        guard !apiKey.isEmpty else {
            print("🤖 ❌ Error: API key is empty")
            throw AIServiceError.invalidAPIKey
        }
        
        let prompt = buildPromptForCustomEvent(request: request)
        print("🤖 📝 Generated Custom Prompt:")
        print("🤖 \(prompt)")
        print("🤖 ==================")
        
        let requestBody = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": PromptLocalizer.getSystemMessage(for: request.language)
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 2000,
            "temperature": 0.8
        ] as [String : Any]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("🤖 ❌ Error: Failed to serialize request JSON")
            throw AIServiceError.invalidResponse
        }

        // Comprehensive HTTP Request Logging
        logFullHTTPRequest(
            url: chatURL,
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(apiKey.prefix(10))...[REDACTED]"
            ],
            bodyData: jsonData,
            requestId: String(requestId)
        )

        var urlRequest = URLRequest(url: URL(string: chatURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("🤖 ❌ Error: Invalid HTTP response")
                throw AIServiceError.networkError(URLError(.badServerResponse))
            }

            // Log response details
            let responseTime = Date().timeIntervalSince(startTime)
            logHTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields,
                dataSize: data.count,
                responseTime: responseTime,
                requestId: String(requestId)
            )
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    print("🤖 ⏳ Error: Rate limit exceeded")
                    throw AIServiceError.rateLimitExceeded
                }
                print("🤖 ❌ HTTP Error: \(httpResponse.statusCode)")
                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("🤖 ❌ Error: Failed to parse JSON response")
                throw AIServiceError.invalidResponse
            }
            
            print("🤖 ✅ Successfully parsed custom story response")
            
            let result = parseCustomStoryResponse(content: content, request: request)
            print("🤖 📊 Final Result - Title: \(result.title)")
            print("🤖 📊 Final Result - Duration: \(Int(result.estimatedDuration/60)) minutes")
            print("🤖 === Custom Story Generation Completed ===")
            
            return result
            
        } catch let error as AIServiceError {
            print("🤖 ❌ AI Service Error: \(error)")
            throw error
        } catch {
            print("🤖 ❌ Network Error: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }

    func extractScenesFromStory(request: SceneExtractionRequest) async throws -> [StoryScene] {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Scene extraction started", category: .illustration, requestId: String(requestId))
        AppLogger.shared.debug("Story duration: \(Int(request.storyDuration)) seconds", category: .illustration, requestId: String(requestId))

        guard !apiKey.isEmpty else {
            AppLogger.shared.error("API key is empty", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidAPIKey
        }

        // Build the prompt for scene extraction
        let prompt = """
        You are an expert at analyzing children's bedtime stories and identifying key visual moments for illustration.

        Analyze the following story and identify the most important scenes for illustration. Consider:
        - Natural narrative breaks and transitions
        - Key emotional moments
        - Visual variety (different settings, actions, moods)
        - Story pacing (distribute scenes evenly throughout)

        Story Context: \(request.eventContext)
        Story Duration: \(Int(request.storyDuration)) seconds

        STORY TEXT:
        \(request.storyContent)

        INSTRUCTIONS:
        1. Identify the optimal number of scenes for this story (typically 1 scene per 15-20 seconds of narration)
        2. Choose scenes that best represent the story arc
        3. For each scene, provide:
           - The exact text segment from the story
           - A detailed illustration prompt for DALL-E 3
           - Estimated timestamp when this scene would occur during audio playback
           - The emotional tone and importance

        The illustration prompts should:
        - Be child-friendly and magical
        - Use warm, watercolor or soft digital art style
        - Be specific about colors, composition, and atmosphere
        - Include the hero character in the scene
        - Be under 150 words each

        Return your analysis as a JSON object matching this structure:
        {
            "scenes": [
                {
                    "sceneNumber": 1,
                    "textSegment": "exact text from story",
                    "timestamp": 0.0,
                    "illustrationPrompt": "detailed DALL-E 3 prompt",
                    "emotion": "joyful|peaceful|exciting|mysterious|heartwarming|adventurous|contemplative",
                    "importance": "key|major|minor"
                }
            ],
            "sceneCount": total_number,
            "reasoning": "brief explanation of scene selection"
        }
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert at visual storytelling and scene analysis for children's books."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 2000,
            "temperature": 0.7,
            "response_format": ["type": "json_object"]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            AppLogger.shared.error("Failed to serialize request JSON", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidResponse
        }

        var urlRequest = URLRequest(url: URL(string: chatURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.shared.error("Invalid HTTP response", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            logHTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields,
                dataSize: data.count,
                responseTime: Date().timeIntervalSince(startTime),
                requestId: String(requestId)
            )

            guard httpResponse.statusCode == 200 else {
                if let errorString = String(data: data, encoding: .utf8) {
                    AppLogger.shared.error("API Error: \(errorString)", category: .api, requestId: String(requestId))
                }
                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
            }

            // Parse the JSON response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                AppLogger.shared.error("Failed to parse API response", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            // Parse the JSON content
            guard let jsonData = content.data(using: .utf8) else {
                AppLogger.shared.error("Failed to convert content to data", category: .api, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            let decoder = JSONDecoder()
            let sceneResponse = try decoder.decode(SceneExtractionJSONResponse.self, from: jsonData)

            // Convert JSON scenes to StoryScene objects and sort by sceneNumber to ensure proper order
            let scenes = sceneResponse.scenes
                .sorted { $0.sceneNumber < $1.sceneNumber }
                .map { jsonScene in
                StoryScene(
                    sceneNumber: jsonScene.sceneNumber,
                    textSegment: jsonScene.textSegment,
                    illustrationPrompt: jsonScene.illustrationPrompt,
                    timestamp: jsonScene.timestamp,
                    emotion: SceneEmotion(rawValue: jsonScene.emotion) ?? .peaceful,
                    importance: SceneImportance(rawValue: jsonScene.importance) ?? .major
                )
            }

            AppLogger.shared.success("Extracted \(scenes.count) scenes from story", category: .illustration, requestId: String(requestId))
            AppLogger.shared.debug("Scene selection reasoning: \(sceneResponse.reasoning)", category: .illustration, requestId: String(requestId))
            AppLogger.shared.logPerformance(operation: "Scene Extraction", startTime: startTime, requestId: String(requestId))

            return scenes

        } catch let error as DecodingError {
            AppLogger.shared.error("JSON decoding error: \(error)", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidResponse
        } catch let error as AIServiceError {
            AppLogger.shared.error("AI Service error: \(error)", category: .api, requestId: String(requestId))
            throw error
        } catch {
            AppLogger.shared.error("Network error: \(error.localizedDescription)", category: .api, requestId: String(requestId))
            throw AIServiceError.networkError(error)
        }
    }

    private func buildPrompt(for request: StoryGenerationRequest) -> String {
        let targetMinutes = Int(request.targetDuration / 60)

        // Build trait description
        let traits = "\(request.hero.primaryTrait.description), \(request.hero.secondaryTrait.description), \(request.hero.appearance.isEmpty ? "lovable appearance" : request.hero.appearance), \(request.hero.specialAbility.isEmpty ? "warm heart" : request.hero.specialAbility)"

        // Get base prompt template
        let prompt = PromptLocalizer.getPromptTemplate(
            for: request.language,
            storyLength: targetMinutes,
            hero: request.hero.name,
            traits: traits,
            event: request.event.promptSeed
        )

        // Add clean story generation instructions
        return prompt + """


        IMPORTANT INSTRUCTIONS:
        - Write a complete, flowing story without any formatting markers
        - Use natural, conversational language suitable for audio narration
        - Include dialogue and sound effects naturally in the text
        - Avoid special characters or formatting that would sound strange when read aloud
        - Make the story engaging and immersive for bedtime listening
        - DO NOT include scene markers, titles, or any meta-information
        - Just tell the story from beginning to end
        """
    }

    private func buildPromptForCustomEvent(request: CustomStoryGenerationRequest) -> String {
        let targetMinutes = Int(request.targetDuration / 60)
        let event = request.customEvent

        // Build trait description
        let traits = "\(request.hero.primaryTrait.description), \(request.hero.secondaryTrait.description), \(request.hero.appearance.isEmpty ? "lovable appearance" : request.hero.appearance), \(request.hero.specialAbility.isEmpty ? "warm heart" : request.hero.specialAbility)"

        // Build enhanced prompt with custom event details
        var prompt = PromptLocalizer.getPromptTemplate(
            for: request.language,
            storyLength: targetMinutes,
            hero: request.hero.name,
            traits: traits,
            event: event.promptSeed
        )

        // Add additional context from custom event
        if !event.keywords.isEmpty {
            prompt += "\n\nPlease include these elements in the story: \(event.keywords.joined(separator: ", "))"
        }

        // Add tone guidance
        prompt += "\n\nThe story should have a \(event.tone.rawValue.lowercased()) tone."

        // Add age-appropriate guidance
        prompt += "\nMake sure the story is appropriate for children aged \(event.ageRange.rawValue)."

        // Add clean story generation instructions
        prompt += """


        IMPORTANT INSTRUCTIONS:
        - Write a complete, flowing story without any formatting markers
        - Use natural, conversational language suitable for audio narration
        - Include dialogue and sound effects naturally in the text
        - Avoid special characters or formatting that would sound strange when read aloud
        - Make the story engaging and immersive for bedtime listening
        - DO NOT include scene markers, titles, or any meta-information
        - Just tell the story from beginning to end
        """

        return prompt
    }
    
    private func parseCustomStoryResponse(content: String, request: CustomStoryGenerationRequest) -> StoryGenerationResponse {
        // The content is now a clean story without any formatting
        let storyContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Use the custom event title
        let title = request.customEvent.title

        // Estimate duration based on word count (average 200 words per minute)
        let wordCount = storyContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let estimatedDuration = TimeInterval(wordCount) / 200.0 * 60.0 // Convert to seconds

        return StoryGenerationResponse(
            title: title,
            content: storyContent,
            estimatedDuration: estimatedDuration,
            scenes: nil // Scenes will be extracted in a separate API call
        )
    }
    
    private func parseStoryResponse(content: String, request: StoryGenerationRequest) -> StoryGenerationResponse {
        // The content is now a clean story without any formatting
        let storyContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Generate a title based on the hero and event
        let title = "\(request.hero.name) and the \(request.event.rawValue)"

        // Estimate duration based on word count (average 200 words per minute)
        let wordCount = storyContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let estimatedDuration = TimeInterval(wordCount) / 200.0 * 60.0 // Convert to seconds

        return StoryGenerationResponse(
            title: title,
            content: storyContent,
            estimatedDuration: estimatedDuration,
            scenes: nil // Scenes will be extracted in a separate API call
        )
    }
    
    func generateSpeech(text: String, voice: String, language: String) async throws -> Data {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("TTS generation started", category: .audio, requestId: String(requestId))
        AppLogger.shared.debug("Voice: \(voice), Language: \(language), Text length: \(text.count) characters", category: .audio, requestId: String(requestId))

        guard !apiKey.isEmpty else {
            AppLogger.shared.error("API key is empty", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidAPIKey
        }

        // Use the tts-1-hd model with voice instructions
        return try await generateSpeechWithModel(text: text, voice: voice, language: language, requestId: String(requestId), startTime: startTime)
    }
    
    /// TTS generation using the tts-1-hd model with voice instructions
    private func generateSpeechWithModel(text: String, voice: String, language: String, requestId: String, startTime: Date) async throws -> Data {
        AppLogger.shared.debug("Using tts-1-hd model", category: .audio, requestId: requestId)
        
        // Craft child-friendly storytelling instructions based on the voice and language
        let instructions = getStorytellingInstructions(for: voice, language: language)
        
        // Prepare request body with the model and instructions
        let requestBody: [String: Any] = [
            "model": "tts-1-hd",
            "input": text,
            "voice": voice,
            "instructions": instructions,
            "response_format": "mp3"
        ]
        
        AppLogger.shared.debug("Voice instructions length: \(instructions.count) characters", category: .audio, requestId: requestId)

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            AppLogger.shared.error("Failed to encode TTS request JSON", category: .api, requestId: requestId)
            throw AIServiceError.invalidResponse
        }
        
        // Create URL request
        var urlRequest = URLRequest(url: URL(string: ttsURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData
        
        AppLogger.shared.logRequest(url: ttsURL, method: "POST", requestId: requestId, bodySize: jsonData.count)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            if let httpResponse = response as? HTTPURLResponse {
                let responseTime = Date().timeIntervalSince(startTime)
                AppLogger.shared.logResponse(statusCode: httpResponse.statusCode, responseTime: responseTime, requestId: requestId, dataSize: data.count)

                if httpResponse.statusCode == 200 {
                    AppLogger.shared.success("Audio generated - Size: \(data.count / 1024)KB", category: .audio, requestId: requestId)
                    AppLogger.shared.logPerformance(operation: "TTS generation", startTime: startTime, requestId: requestId)
                    return data
                } else {
                    // Try to parse error message
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        AppLogger.shared.error("TTS API error: \(message)", category: .audio, requestId: requestId)
                        throw AIServiceError.apiError(message)
                    } else {
                        AppLogger.shared.error("TTS HTTP error: \(httpResponse.statusCode)", category: .audio, requestId: requestId)
                        throw AIServiceError.invalidResponse
                    }
                }
            } else {
                AppLogger.shared.error("Invalid TTS response type", category: .audio, requestId: requestId)
                throw AIServiceError.invalidResponse
            }
        } catch let error as AIServiceError {
            AppLogger.shared.error("TTS generation failed", category: .audio, requestId: requestId, error: error)
            throw error
        } catch {
            AppLogger.shared.error("TTS network error", category: .audio, requestId: requestId, error: error)
            throw AIServiceError.networkError(error)
        }
    }
    
    /// Get appropriate storytelling instructions based on the selected voice and language
    private func getStorytellingInstructions(for voice: String, language: String) -> String {
        // Voice-specific instructions for optimal children's storytelling
        switch voice.lowercased() {
        case "coral":
            let baseInstructions = "Speak with a warm, gentle, and nurturing tone perfect for bedtime stories. Use a calm and soothing pace with clear pronunciation. Add subtle emotional expressions to bring characters to life while maintaining a peaceful atmosphere that helps children relax and drift off to sleep."
            return baseInstructions + " " + PromptLocalizer.getLanguageInstruction(for: language)
            
        case "nova":
            let baseInstructions = "Use a friendly, cheerful, and engaging storyteller voice that captivates young listeners. Speak clearly at a moderate pace with gentle enthusiasm. Create distinct character voices while keeping the overall tone calming and suitable for bedtime. Emphasize wonder and magic in the narrative."
            return baseInstructions + " " + PromptLocalizer.getLanguageInstruction(for: language)
            
        case "fable":
            let baseInstructions = "Adopt a wise, comforting grandfather-like tone that makes children feel safe and loved. Use a slower, deliberate pace with warm inflections. Add gentle dramatic pauses for effect and speak as if sharing a treasured tale. Keep the voice soft and reassuring throughout."
            return baseInstructions + " " + PromptLocalizer.getLanguageInstruction(for: language)
            
        case "alloy":
            let baseInstructions = "Speak with a clear, pleasant, and neutral tone that's easy for children to understand. Use moderate pacing with good articulation. Add subtle warmth and friendliness while maintaining consistency. Perfect for educational elements in the story."
            return baseInstructions + " " + PromptLocalizer.getLanguageInstruction(for: language)
            
        case "echo":
            let baseInstructions = "Use a soft, dreamy, and ethereal voice that creates a magical atmosphere. Speak gently with a flowing rhythm that mimics the natural cadence of bedtime stories. Add whisper-like qualities for mysterious moments while keeping the overall tone comforting."
            return baseInstructions + " " + PromptLocalizer.getLanguageInstruction(for: language)
            
        case "onyx":
            let baseInstructions = "Deliver the story with a deep, warm, and reassuring voice like a protective parent. Use a slow, steady pace that helps children feel secure. Add gravitas to important moments while maintaining gentleness. Perfect for adventure stories that need to stay calming."
            return baseInstructions + " " + PromptLocalizer.getLanguageInstruction(for: language)
            
        case "shimmer":
            let baseInstructions = "Speak with a bright, melodic, and enchanting voice that sparkles with imagination. Use varied intonation to paint vivid pictures while keeping the energy level appropriate for bedtime. Add musical qualities to dialogue and maintain a soothing undertone throughout."
            return baseInstructions + " " + PromptLocalizer.getLanguageInstruction(for: language)
            
        default:
            // Generic instructions for any voice
            let baseInstructions = "Speak in a warm, gentle, and engaging tone perfect for children's bedtime stories. Use clear pronunciation at a calm, steady pace. Add appropriate emotional expression to bring characters to life while maintaining a soothing atmosphere that helps children relax. Create distinct but subtle character voices and emphasize the wonder and magic of the story."
            return baseInstructions + " " + PromptLocalizer.getLanguageInstruction(for: language)
        }
    }

    /// Basic fallback sanitization for DALL-E 3 prompts when AI sanitization is not available
    /// Enhanced basic sanitization that ensures DALL-E 3 compliance
    /// - Parameter prompt: The prompt to sanitize
    /// - Returns: A fully sanitized prompt safe for DALL-E 3
    private func enhancedBasicSanitization(_ prompt: String) -> String {
        // First, remove all non-ASCII characters to avoid foreign language issues
        let asciiOnly = prompt.unicodeScalars
            .filter { $0.isASCII }
            .map { String($0) }
            .joined()

        // Then apply all safety transformations
        return basicPromptSanitization(asciiOnly)
    }

    /// - Parameter prompt: The prompt to sanitize
    /// - Returns: A sanitized prompt with problematic terms replaced
    private func basicPromptSanitization(_ prompt: String) -> String {
        var sanitized = prompt

        // Critical phrase replacements for child safety - order matters (longer phrases first)
        let phraseReplacements = [
            // Isolation phrases
            "standing alone": "standing with friends",
            "sitting alone": "sitting with companions",
            "walking alone": "walking with friends",
            "all alone": "with magical friends",
            "by himself": "with his friends",
            "by herself": "with her friends",
            "by themselves": "with their companions",

            // Dark/scary phrases
            "dark forest": "bright enchanted garden",
            "dark woods": "sunny magical meadow",
            "scary forest": "magical garden",
            "haunted house": "magical castle",
            "abandoned house": "cozy cottage",

            // Violence phrases
            "fighting with": "playing with",
            "in battle": "on an adventure"
        ]

        // Apply phrase replacements
        for (problematic, safe) in phraseReplacements {
            sanitized = sanitized.replacingOccurrences(
                of: problematic,
                with: safe,
                options: [.caseInsensitive],
                range: nil
            )
        }

        // Word replacements - use word boundaries for accuracy
        let wordReplacements = [
            // Isolation words
            "\\balone\\b": "with friends",
            "\\blonely\\b": "happy with companions",
            "\\bisolated\\b": "surrounded by friendly creatures",
            "\\babandoned\\b": "in a cozy magical place",
            "\\bsolitary\\b": "with cheerful friends",
            "\\bsolo\\b": "with companions",

            // Dark/scary words
            "\\bdark\\b": "bright",
            "\\bscary\\b": "wonderful",
            "\\bfrightening\\b": "magical",
            "\\bterrifying\\b": "amazing",
            "\\bspooky\\b": "enchanting",
            "\\bhaunted\\b": "magical",
            "\\bmysterious\\b": "delightful",
            "\\bshadowy\\b": "glowing",
            "\\bgloomy\\b": "bright",
            "\\beerie\\b": "cheerful",
            "\\bcreepy\\b": "friendly",

            // Violence words
            "\\bfighting\\b": "playing",
            "\\bbattle\\b": "adventure",
            "\\bweapon\\b": "magical wand",
            "\\bsword\\b": "toy wand",
            "\\bswords\\b": "toy wands",
            "\\battacking\\b": "playing with",

            // Negative emotion words
            "\\bsad\\b": "happy",
            "\\bcrying\\b": "smiling",
            "\\btears\\b": "sparkles",
            "\\bupset\\b": "curious",
            "\\bangry\\b": "determined",
            "\\bscared\\b": "excited",
            "\\bafraid\\b": "brave",
            "\\bworried\\b": "thoughtful",
            "\\bfrightened\\b": "amazed"
        ]

        // Apply word replacements using regex
        for (problematic, safe) in wordReplacements {
            do {
                let regex = try NSRegularExpression(pattern: problematic, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: sanitized.utf16.count)
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    options: [],
                    range: range,
                    withTemplate: safe
                )
            } catch {
                // Fallback to simple replacement if regex fails
                let simplePattern = problematic.replacingOccurrences(of: "\\b", with: "")
                sanitized = sanitized.replacingOccurrences(
                    of: simplePattern,
                    with: safe,
                    options: [.caseInsensitive],
                    range: nil
                )
            }
        }

        // Ensure the character is not alone
        if !sanitized.lowercased().contains("friends") &&
           !sanitized.lowercased().contains("companions") &&
           !sanitized.lowercased().contains("family") &&
           !sanitized.lowercased().contains("creatures") {
            // Add companions to the scene
            sanitized = sanitized.replacingOccurrences(of: ".", with: "")
            sanitized += " surrounded by friendly magical creatures and companions."
        }

        // Add brightness if not present
        if !sanitized.lowercased().contains("bright") &&
           !sanitized.lowercased().contains("colorful") &&
           !sanitized.lowercased().contains("sunny") &&
           !sanitized.lowercased().contains("cheerful") {
            sanitized += " The scene is bright, colorful, cheerful, and child-friendly with warm sunlight and a magical atmosphere."
        }

        AppLogger.shared.warning("⚠️ Using basic fallback sanitization", category: .illustration)
        AppLogger.shared.debug("Fallback sanitized prompt: \(sanitized)", category: .illustration)
        return sanitized
    }

    /// Dynamically sanitize DALL-E 3 prompts using OpenAI GPT-4 to ensure policy compliance
    /// - Parameter originalPrompt: The original DALL-E 3 prompt that needs sanitization
    /// - Returns: A sanitized prompt that is safe for DALL-E 3 API
    func sanitizePromptWithAI(_ originalPrompt: String) async throws -> String {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        AppLogger.shared.info("🧹 AI-based prompt sanitization started", category: .illustration, requestId: String(requestId))
        AppLogger.shared.debug("Original prompt length: \(originalPrompt.count) characters", category: .illustration, requestId: String(requestId))

        guard !apiKey.isEmpty else {
            AppLogger.shared.error("API key is empty", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidAPIKey
        }

        // Log only in debug mode
        #if DEBUG
        AppLogger.shared.debug("Original prompt for sanitization: \(originalPrompt.prefix(100))...", category: .illustration, requestId: String(requestId))
        #endif

        // Create a comprehensive sanitization prompt for GPT-4
        let sanitizationPrompt = """
        You are a DALL-E 3 prompt sanitizer specializing in children's content. Your task is to rewrite the following image generation prompt to be 100% compliant with OpenAI's DALL-E 3 content policy while preserving the creative intent.

        CRITICAL GPT-IMAGE-1 POLICY VIOLATIONS TO AVOID:
        1. NEVER depict children in isolation, distress, danger, or negative situations
        2. NEVER show children alone, lonely, abandoned, lost, scared, crying, or sad
        3. NEVER include darkness, shadows, scary elements, or anything frightening
        4. NEVER depict violence, weapons, fighting, battles, or conflict
        5. NEVER show unsafe situations or activities that could harm children
        6. NEVER use words that imply negative emotions or isolation

        MANDATORY TRANSFORMATIONS:
        - ALL children MUST be shown with friends, family, or friendly magical creatures
        - ALL scenes MUST be bright, colorful, and cheerful
        - ALL emotions MUST be positive (happy, excited, curious, playful)
        - ALL environments MUST feel safe, warm, and welcoming
        - ALL interactions MUST be friendly and playful

        SPECIFIC WORD REPLACEMENTS (APPLY ALL):
        - "alone" / "by himself" / "by herself" → "with friends" or "with magical companions"
        - "lonely" / "solitary" / "isolated" → "surrounded by friendly creatures"
        - "dark" / "shadowy" / "dim" → "bright" / "glowing" / "sunlit"
        - "forest" → "magical garden" or "enchanted meadow"
        - "scary" / "frightening" / "spooky" → "wonderful" / "delightful" / "magical"
        - "mysterious" → "enchanting and delightful"
        - "sad" / "crying" / "upset" → "happy" / "smiling" / "cheerful"
        - Any weapons → "magical wands" or "toy props"
        - Any violence → "playful games" or "friendly adventures"

        ORIGINAL PROMPT TO SANITIZE:
        \(originalPrompt)

        IMPORTANT: Return ONLY the sanitized prompt. Ensure EVERY child in the image has companions. Add "surrounded by friends" if needed. The scene MUST be bright and cheerful with NO exceptions.
        """

        let requestBody = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a strict DALL-E 3 content policy enforcer. You MUST rewrite prompts to be 100% safe for children. ALWAYS ensure children are shown with companions, NEVER alone. ALWAYS make scenes bright and positive. Remove ALL negative or scary elements. Output ONLY the sanitized prompt."
                ],
                [
                    "role": "user",
                    "content": sanitizationPrompt
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.3  // Lower temperature for more consistent sanitization
        ] as [String : Any]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            AppLogger.shared.error("❌ Failed to serialize sanitization request JSON", category: .illustration, requestId: String(requestId))
            throw AIServiceError.invalidResponse
        }

        var urlRequest = URLRequest(url: URL(string: chatURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.shared.error("❌ Invalid HTTP response for sanitization", category: .illustration, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                AppLogger.shared.error("❌ Sanitization API error: HTTP \(httpResponse.statusCode)", category: .illustration, requestId: String(requestId))

                // Try to parse error message
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    AppLogger.shared.error("API error message: \(message)", category: .illustration, requestId: String(requestId))
                    throw AIServiceError.apiError("Sanitization failed: \(message)")
                }

                throw AIServiceError.apiError("Sanitization failed with HTTP \(httpResponse.statusCode)")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let sanitizedPrompt = message["content"] as? String else {
                AppLogger.shared.error("❌ Failed to parse sanitization response", category: .illustration, requestId: String(requestId))
                throw AIServiceError.invalidResponse
            }

            // Clean up the sanitized prompt (remove any extra whitespace)
            let cleanedPrompt = sanitizedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

            // Log the sanitization results
            AppLogger.shared.success("✅ PROMPT SANITIZATION COMPLETE", category: .illustration, requestId: String(requestId))
            AppLogger.shared.info("=== SANITIZED PROMPT ===", category: .illustration, requestId: String(requestId))
            AppLogger.shared.debug("Sanitized: \(cleanedPrompt)", category: .illustration, requestId: String(requestId))

            // Log changes made
            if originalPrompt != cleanedPrompt {
                AppLogger.shared.warning("⚠️ Prompt was modified by AI sanitization", category: .illustration, requestId: String(requestId))
                AppLogger.shared.debug("Original length: \(originalPrompt.count) → Sanitized length: \(cleanedPrompt.count)", category: .illustration, requestId: String(requestId))

                // Log specific changes for debugging
                let originalWords = Set(originalPrompt.lowercased().components(separatedBy: .whitespacesAndNewlines))
                let sanitizedWords = Set(cleanedPrompt.lowercased().components(separatedBy: .whitespacesAndNewlines))
                let removedWords = originalWords.subtracting(sanitizedWords)
                let addedWords = sanitizedWords.subtracting(originalWords)

                if !removedWords.isEmpty {
                    AppLogger.shared.debug("Words removed: \(removedWords.joined(separator: ", "))", category: .illustration, requestId: String(requestId))
                }
                if !addedWords.isEmpty {
                    AppLogger.shared.debug("Words added: \(addedWords.joined(separator: ", "))", category: .illustration, requestId: String(requestId))
                }
            } else {
                AppLogger.shared.info("✓ Prompt deemed safe, no changes needed", category: .illustration, requestId: String(requestId))
            }

            return cleanedPrompt

        } catch let error as AIServiceError {
            AppLogger.shared.error("❌ Sanitization failed with AI error", category: .illustration, requestId: String(requestId), error: error)
            throw error
        } catch {
            AppLogger.shared.error("❌ Sanitization network/parsing error", category: .illustration, requestId: String(requestId), error: error)
            throw AIServiceError.networkError(error)
        }
    }

    func generateAvatar(request: AvatarGenerationRequest) async throws -> AvatarGenerationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Avatar generation started", category: .avatar, requestId: String(requestId))
        AppLogger.shared.debug("Hero: \(request.hero.name), Size: \(request.size), Quality: \(request.quality)", category: .avatar, requestId: String(requestId))

        guard !apiKey.isEmpty else {
            AppLogger.shared.error("API key is empty", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidAPIKey
        }

        // Skip AI-based sanitization and use enhanced basic sanitization directly
        // This is more reliable and avoids the extra API call that can fail
        AppLogger.shared.info("Using enhanced basic sanitization for avatar", category: .avatar, requestId: String(requestId))
        let filteredPrompt = enhancedBasicSanitization(request.prompt)

        // Log filtering activity if any changes were made
        if request.prompt != filteredPrompt {
            AppLogger.shared.warning("AI content filtering applied to avatar prompt", category: .avatar, requestId: String(requestId))
            AppLogger.shared.debug("Original: \(request.prompt.count) → Sanitized: \(filteredPrompt.count) chars", category: .avatar, requestId: String(requestId))
        }

        // Map quality parameter from DALL-E 3 format to DALL-E 3 format
        let gptImageQuality: String
        switch request.quality.lowercased() {
        case "standard":
            gptImageQuality = "medium"
        case "hd":
            gptImageQuality = "high"
        case "low", "medium", "high":
            gptImageQuality = request.quality // Already in DALL-E 3 format
        default:
            gptImageQuality = "high" // Default to high quality
        }

        // Log the final sanitized avatar generation prompt
        AppLogger.shared.info("=== AVATAR GENERATION PROMPT (FULLY SANITIZED) ===", category: .avatar, requestId: String(requestId))
        AppLogger.shared.logDALLERequest(
            prompt: filteredPrompt,
            size: request.size,
            quality: gptImageQuality,
            requestId: String(requestId)
        )

        var requestBody: [String: Any] = [
            "model": "dall-e-3",
            "prompt": filteredPrompt,
            "n": 1,
            "size": request.size,
            "quality": gptImageQuality, // DALL-E 3 uses low/medium/high instead of standard/hd
            "background": "auto",
            "output_format": "png",
            "moderation": "auto"
        ]

        // Add previous generation ID if available for multi-turn consistency
        if let previousGenerationId = request.previousGenerationId {
            requestBody["previous_generation_id"] = previousGenerationId
            AppLogger.shared.info("Using previous generation ID for avatar consistency: \(previousGenerationId)", category: .avatar, requestId: String(requestId))
        }

        // Log complete request body
        AppLogger.shared.info("=== GPT-IMAGE-1 AVATAR REQUEST BODY ===", category: .avatar, requestId: String(requestId))
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            AppLogger.shared.debug("Request JSON: \(jsonString)", category: .avatar, requestId: String(requestId))

            // Log only in debug mode
            #if DEBUG
            AppLogger.shared.debug("DALL-E 3 Avatar Request - Model: dall-e-3, Size: \(request.size)", category: .avatar, requestId: String(requestId))
            #endif
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            AppLogger.shared.error("Failed to serialize request JSON", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidResponse
        }

        AppLogger.shared.logRequest(url: imageURL, method: "POST", requestId: String(requestId), bodySize: jsonData.count)

        var urlRequest = URLRequest(url: URL(string: imageURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.shared.error("Invalid HTTP response", category: .api, requestId: String(requestId))
                throw AIServiceError.networkError(URLError(.badServerResponse))
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.logResponse(statusCode: httpResponse.statusCode, responseTime: responseTime, requestId: String(requestId), dataSize: data.count)

            guard httpResponse.statusCode == 200 else {
                // Log error response details
                if let errorString = String(data: data, encoding: .utf8) {
                    AppLogger.shared.error("DALL-E 3 Error Response: \(errorString)", category: .avatar, requestId: String(requestId))

                    // Try to parse error JSON for more details
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let errorType = error["type"] as? String,
                       let errorMessage = error["message"] as? String {
                        AppLogger.shared.error("Error details - Type: \(errorType), Message: \(errorMessage)", category: .avatar, requestId: String(requestId))

                        // Handle specific error types
                        if errorType == "invalid_request_error" && errorMessage.lowercased().contains("content_policy_violation") {
                            AppLogger.shared.error("Content policy violation detected in avatar prompt", category: .avatar, requestId: String(requestId))
                            throw AIServiceError.contentPolicyViolation(errorMessage)
                        }
                    }
                }

                if httpResponse.statusCode == 429 {
                    AppLogger.shared.error("Rate limit exceeded", category: .api, requestId: String(requestId))
                    throw AIServiceError.rateLimitExceeded
                }

                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
            }

            // Log successful response
            AppLogger.shared.info("=== GPT-IMAGE-1 AVATAR RESPONSE ===", category: .avatar, requestId: String(requestId))

            // Log the full request/response for debugging
            AppLogger.shared.info("✅ DALL-E 3 Request Successful - Full Payload:", category: .avatar, requestId: String(requestId))
            AppLogger.shared.info("URL: \(imageURL)", category: .avatar, requestId: String(requestId))
            AppLogger.shared.info("Method: POST", category: .avatar, requestId: String(requestId))
            AppLogger.shared.info("Headers: Content-Type: application/json, Authorization: Bearer [REDACTED]", category: .avatar, requestId: String(requestId))
            if let prettyJson = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
               let prettyString = String(data: prettyJson, encoding: .utf8) {
                AppLogger.shared.info("Request Body:\n\(prettyString)", category: .avatar, requestId: String(requestId))
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]],
                  let firstImage = dataArray.first,
                  let b64Json = firstImage["b64_json"] as? String,
                  let imageData = Data(base64Encoded: b64Json) else {
                AppLogger.shared.error("Failed to parse image response", category: .api, requestId: String(requestId))

                // Log what we received for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    AppLogger.shared.debug("Raw response (first 500 chars): \(String(responseString.prefix(500)))", category: .avatar, requestId: String(requestId))
                }
                throw AIServiceError.invalidResponse
            }

            let revisedPrompt = firstImage["revised_prompt"] as? String

            // Log success with details
            AppLogger.shared.logDALLEResponse(
                success: true,
                revisedPrompt: revisedPrompt,
                imageSize: imageData.count,
                requestId: String(requestId)
            )

            // Extract DALL-E 3 specific response fields for cost tracking
            if let usage = json["usage"] as? [String: Any],
               let totalTokens = usage["total_tokens"] as? Int,
               let inputTokens = usage["input_tokens"] as? Int,
               let outputTokens = usage["output_tokens"] as? Int {
                AppLogger.shared.info("DALL-E 3 avatar token usage - Input: \(inputTokens), Output: \(outputTokens), Total: \(totalTokens)", category: .avatar, requestId: String(requestId))
            }

            AppLogger.shared.logPerformance(operation: "Avatar Generation", startTime: startTime, requestId: String(requestId))

            // Extract DALL-E 3 generation ID for multi-turn consistency
            // Check multiple possible field names for generation ID
            let generationId = firstImage["generation_id"] as? String ??
                              firstImage["generationId"] as? String ??
                              firstImage["gen_id"] as? String ??
                              json["generation_id"] as? String ??
                              json["generationId"] as? String ??
                              json["gen_id"] as? String

            if let generationId = generationId {
                AppLogger.shared.info("Avatar generation ID extracted: \(generationId)", category: .avatar, requestId: String(requestId))
            } else {
                AppLogger.shared.warning("No generation ID found in avatar response", category: .avatar, requestId: String(requestId))
                AppLogger.shared.debug("Available response keys: \(Array(json.keys))", category: .avatar, requestId: String(requestId))
                if !dataArray.isEmpty {
                    AppLogger.shared.debug("Available image keys: \(Array(firstImage.keys))", category: .avatar, requestId: String(requestId))
                }
            }

            return AvatarGenerationResponse(
                imageData: imageData,
                revisedPrompt: revisedPrompt,
                generationId: generationId
            )

        } catch let error as AIServiceError {
            AppLogger.shared.logDALLEResponse(success: false, requestId: String(requestId), error: error)
            throw error
        } catch {
            AppLogger.shared.error("Network error during avatar generation", category: .api, requestId: String(requestId), error: error)
            AppLogger.shared.logDALLEResponse(success: false, requestId: String(requestId), error: error)
            throw AIServiceError.networkError(error)
        }
    }

    func generateSceneIllustration(prompt: String, hero: Hero, previousGenerationId: String?) async throws -> SceneIllustrationResponse {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("Scene Illustration Generation Started", category: .illustration, requestId: String(requestId))
        AppLogger.shared.info("Hero: \(hero.name)", category: .illustration, requestId: String(requestId))

        if let previousGenerationId = previousGenerationId {
            AppLogger.shared.info("Using previous generation ID for consistency: \(previousGenerationId)", category: .illustration, requestId: String(requestId))
        } else {
            AppLogger.shared.debug("No previous generation ID provided - first illustration or fallback", category: .illustration, requestId: String(requestId))
        }

        guard !apiKey.isEmpty else {
            AppLogger.shared.error("API key is empty", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidAPIKey
        }

        // Log original prompt
        AppLogger.shared.info("=== ORIGINAL SCENE PROMPT ===", category: .illustration, requestId: String(requestId))
        AppLogger.shared.logPrompt(prompt, type: "DALL-E 3-Scene-Original", requestId: String(requestId), hero: hero.name)

        // Enhance the prompt with child-friendly artistic style
        let enhancedPrompt = enhanceIllustrationPrompt(prompt, hero: hero)

        // Skip AI-based sanitization and use enhanced basic sanitization directly
        // This is more reliable and avoids the extra API call that can fail
        AppLogger.shared.info("Using enhanced basic sanitization for scene", category: .illustration, requestId: String(requestId))
        let filteredPrompt = enhancedBasicSanitization(enhancedPrompt)

        // Log filtering activity if any changes were made
        if enhancedPrompt != filteredPrompt {
            AppLogger.shared.warning("AI content filtering applied to scene illustration prompt", category: .illustration, requestId: String(requestId))
            AppLogger.shared.debug("Enhanced: \(enhancedPrompt.count) → Sanitized: \(filteredPrompt.count) chars", category: .illustration, requestId: String(requestId))
        }

        // Log final sanitized prompt
        AppLogger.shared.info("=== FULLY SANITIZED SCENE PROMPT ===", category: .illustration, requestId: String(requestId))
        AppLogger.shared.logDALLERequest(
            prompt: filteredPrompt,
            size: "1024x1024",
            quality: "standard",
            requestId: String(requestId)
        )

        var requestBody: [String: Any] = [
            "model": "dall-e-3",
            "prompt": filteredPrompt,
            "n": 1,
            "size": "1024x1024",
            "quality": "high", // DALL-E 3 uses low/medium/high instead of standard
            "background": "auto",
            "output_format": "png",
            "moderation": "auto"
        ]

        // Add previous generation ID if available for multi-turn consistency
        if let previousGenerationId = previousGenerationId {
            requestBody["previous_generation_id"] = previousGenerationId
        }

        // Log complete request body
        AppLogger.shared.info("=== GPT-IMAGE-1 REQUEST BODY ===", category: .illustration, requestId: String(requestId))
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            AppLogger.shared.debug("Request JSON: \(jsonString)", category: .illustration, requestId: String(requestId))

            // Log only in debug mode
            #if DEBUG
            AppLogger.shared.debug("DALL-E 3 Scene Request - Model: dall-e-3, Size: 1024x1024", category: .illustration, requestId: String(requestId))
            #endif
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            AppLogger.shared.error("Failed to serialize request JSON", category: .api, requestId: String(requestId))
            throw AIServiceError.invalidResponse
        }

        AppLogger.shared.logRequest(url: imageURL, method: "POST", requestId: String(requestId), bodySize: jsonData.count)

        var urlRequest = URLRequest(url: URL(string: imageURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.shared.error("Invalid HTTP response", category: .api, requestId: String(requestId))
                throw AIServiceError.networkError(URLError(.badServerResponse))
            }

            let responseTime = Date().timeIntervalSince(startTime)
            AppLogger.shared.logResponse(statusCode: httpResponse.statusCode, responseTime: responseTime, requestId: String(requestId), dataSize: data.count)

            guard httpResponse.statusCode == 200 else {
                // Log error response details
                if let errorString = String(data: data, encoding: .utf8) {
                    AppLogger.shared.error("DALL-E 3 Error Response: \(errorString)", category: .illustration, requestId: String(requestId))

                    // Try to parse error JSON for more details
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let errorType = error["type"] as? String,
                       let errorMessage = error["message"] as? String {
                        AppLogger.shared.error("Error details - Type: \(errorType), Message: \(errorMessage)", category: .illustration, requestId: String(requestId))

                        // Handle specific error types
                        if errorType == "invalid_request_error" && errorMessage.lowercased().contains("content_policy_violation") {
                            AppLogger.shared.error("Content policy violation detected in scene illustration prompt", category: .illustration, requestId: String(requestId))
                            throw AIServiceError.contentPolicyViolation(errorMessage)
                        }
                    }
                }

                if httpResponse.statusCode == 429 {
                    AppLogger.shared.error("Rate limit exceeded", category: .api, requestId: String(requestId))
                    throw AIServiceError.rateLimitExceeded
                }

                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
            }

            // Log successful response
            AppLogger.shared.info("=== GPT-IMAGE-1 RESPONSE ===", category: .illustration, requestId: String(requestId))

            // Log the full request/response for debugging
            AppLogger.shared.info("✅ DALL-E 3 Request Successful - Full Payload:", category: .illustration, requestId: String(requestId))
            AppLogger.shared.info("URL: \(imageURL)", category: .illustration, requestId: String(requestId))
            AppLogger.shared.info("Method: POST", category: .illustration, requestId: String(requestId))
            AppLogger.shared.info("Headers: Content-Type: application/json, Authorization: Bearer [REDACTED]", category: .illustration, requestId: String(requestId))
            if let prettyJson = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
               let prettyString = String(data: prettyJson, encoding: .utf8) {
                AppLogger.shared.info("Request Body:\n\(prettyString)", category: .illustration, requestId: String(requestId))
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]],
                  let firstImage = dataArray.first,
                  let b64Json = firstImage["b64_json"] as? String,
                  let imageData = Data(base64Encoded: b64Json) else {
                AppLogger.shared.error("Failed to parse image response", category: .api, requestId: String(requestId))

                // Log what we received for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    AppLogger.shared.debug("Raw response (first 500 chars): \(String(responseString.prefix(500)))", category: .illustration, requestId: String(requestId))
                }
                throw AIServiceError.invalidResponse
            }

            // Extract revised prompt if available
            let revisedPrompt = firstImage["revised_prompt"] as? String

            // Extract DALL-E 3 generation ID for multi-turn consistency
            // Check multiple possible field names for generation ID
            let generationId = firstImage["generation_id"] as? String ??
                              firstImage["generationId"] as? String ??
                              firstImage["gen_id"] as? String ??
                              json["generation_id"] as? String ??
                              json["generationId"] as? String ??
                              json["gen_id"] as? String
            
            let genId = firstImage["id"] as? String  // TODO fix generation Id retrieval

            if let generationId = generationId {
                AppLogger.shared.info("Scene illustration generation ID extracted: \(generationId)", category: .illustration, requestId: String(requestId))
            } else {
                AppLogger.shared.warning("No generation ID found in scene illustration response", category: .illustration, requestId: String(requestId))
                AppLogger.shared.debug("Available response keys: \(Array(json.keys))", category: .illustration, requestId: String(requestId))
                if !dataArray.isEmpty {
                    AppLogger.shared.debug("Available image keys: \(Array(firstImage.keys))", category: .illustration, requestId: String(requestId))
                }
            }

            // Log success with details
            AppLogger.shared.logDALLEResponse(
                success: true,
                revisedPrompt: revisedPrompt,
                imageSize: imageData.count,
                requestId: String(requestId)
            )

            // Extract DALL-E 3 specific response fields for cost tracking
            if let usage = json["usage"] as? [String: Any],
               let totalTokens = usage["total_tokens"] as? Int,
               let inputTokens = usage["input_tokens"] as? Int,
               let outputTokens = usage["output_tokens"] as? Int {
                AppLogger.shared.info("DALL-E 3 illustration token usage - Input: \(inputTokens), Output: \(outputTokens), Total: \(totalTokens)", category: .illustration, requestId: String(requestId))
            }

            AppLogger.shared.logPerformance(operation: "Scene Illustration Generation", startTime: startTime, requestId: String(requestId))

            return SceneIllustrationResponse(
                imageData: imageData,
                revisedPrompt: revisedPrompt,
                generationId: generationId
            )

        } catch let error as AIServiceError {
            AppLogger.shared.logDALLEResponse(success: false, requestId: String(requestId), error: error)
            throw error
        } catch {
            AppLogger.shared.error("Network error during illustration generation", category: .api, requestId: String(requestId), error: error)
            AppLogger.shared.logDALLEResponse(success: false, requestId: String(requestId), error: error)
            throw AIServiceError.networkError(error)
        }
    }

    private func enhanceIllustrationPrompt(_ prompt: String, hero: Hero) -> String {
        // Add consistent style guidelines for children's book illustrations
        let styleGuidance = """
        Create a beautiful children's book illustration in a warm, whimsical style. \
        Use soft colors, gentle lighting, and a magical atmosphere. \
        The art style should be similar to modern children's picture books with \
        watercolor or soft digital painting techniques. \
        Ensure the image is appropriate for children aged 4-10. \
        Avoid any scary, violent, or inappropriate content. \
        Focus on creating a sense of wonder and joy.
        """

        // Build comprehensive hero consistency requirements
        var heroConsistency = """
        The main character \(hero.name) should be clearly visible and match this EXACT description: \
        \(hero.appearance.isEmpty ? "a lovable, friendly character" : hero.appearance).
        """

        // Include avatar prompt for maximum consistency if available
        if let avatarPrompt = hero.avatarPrompt {
            heroConsistency += """


            VISUAL REFERENCE (MUST MATCH EXACTLY): \(avatarPrompt)
            """
        }

        // Add trait consistency
        heroConsistency += """


        Character traits: \(hero.primaryTrait.description) and \(hero.secondaryTrait.description) \
        should be reflected in their expression and posture.

        CRITICAL: The character MUST look IDENTICAL to their established appearance. \
        Same hair color, clothing, features, and overall design in every illustration.
        """

        return "\(prompt)\n\n\(heroConsistency)\n\n\(styleGuidance)"
    }

    // Helper method to save illustration image to file system
    func saveIllustrationImage(_ imageData: Data, for storyId: UUID, sceneNumber: Int) throws -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let illustrationsPath = documentsPath.appendingPathComponent("StoryIllustrations")

        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: illustrationsPath, withIntermediateDirectories: true, attributes: nil)

        // Create unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(storyId.uuidString)_scene\(sceneNumber)_\(timestamp).jpg"
        let fileURL = illustrationsPath.appendingPathComponent(filename)

        // Save image data
        try imageData.write(to: fileURL)

        print("🎨 💾 Saved illustration to: \(filename)")
        return filename
    }

    // Batch generation method for multiple scenes
    func generateIllustrationsForScenes(_ scenes: [StoryScene], hero: Hero, storyId: UUID) async -> [(scene: StoryScene, imageData: Data?, error: Error?)] {
        var results: [(scene: StoryScene, imageData: Data?, error: Error?)] = []

        // Sort scenes by sceneNumber to ensure correct order
        let sortedScenes = scenes.sorted { $0.sceneNumber < $1.sceneNumber }

        // Track the last successful generation ID for chaining
        var lastGenerationId: String? = hero.avatarGenerationId

        AppLogger.shared.info("Starting batch illustration generation for \(sortedScenes.count) scenes", category: .illustration)
        if let avatarGenId = hero.avatarGenerationId {
            AppLogger.shared.debug("Initial generation ID from hero avatar: \(avatarGenId)", category: .illustration)
        } else {
            AppLogger.shared.warning("Hero has no avatar generation ID, visual consistency may be limited", category: .illustration)
        }

        for (index, scene) in sortedScenes.enumerated() {
            do {
                AppLogger.shared.info("Generating illustration for scene \(scene.sceneNumber) (\(index + 1)/\(sortedScenes.count))", category: .illustration)

                // Use the last successful generation ID for visual consistency chaining
                let response = try await generateSceneIllustration(
                    prompt: scene.illustrationPrompt,
                    hero: hero,
                    previousGenerationId: lastGenerationId
                )

                // Update the last generation ID if we got a new one
                if let newGenerationId = response.generationId {
                    AppLogger.shared.debug("Scene \(scene.sceneNumber) generated with ID: \(newGenerationId)", category: .illustration)
                    lastGenerationId = newGenerationId
                } else {
                    AppLogger.shared.warning("Scene \(scene.sceneNumber) did not return a generation ID", category: .illustration)
                }

                results.append((scene: scene, imageData: response.imageData, error: nil))
                AppLogger.shared.success("Successfully generated illustration for scene \(scene.sceneNumber)", category: .illustration)

                // Add delay between requests to avoid rate limits (except for the last scene)
                if index < sortedScenes.count - 1 {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                }
            } catch {
                AppLogger.shared.error("Failed to generate illustration for scene \(scene.sceneNumber): \(error)", category: .illustration)
                results.append((scene: scene, imageData: nil, error: error))

                // Continue using the last successful generation ID to maintain some consistency
                // even when individual scenes fail
                AppLogger.shared.info("Continuing with last successful generation ID for consistency", category: .illustration)
            }
        }

        let successCount = results.filter { $0.imageData != nil }.count
        AppLogger.shared.info("Batch illustration generation completed: \(successCount)/\(sortedScenes.count) successful", category: .illustration)

        return results
    }

    func cancelCurrentTask() {
        print("🚫 Cancelling current AI service task")
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Comprehensive HTTP Request Logging

    private func logFullHTTPRequest(
        url: String,
        method: String,
        headers: [String: String],
        bodyData: Data?,
        requestId: String
    ) {
        print("\n")
        print("=== OpenAI API Request ===")
        print("Request ID: \(requestId)")
        print("Timestamp: \(Date())")
        print("URL: \(url)")
        print("Method: \(method)")
        print("Headers:")
        for (key, value) in headers {
            print("  \(key): \(value)")
        }

        if let bodyData = bodyData {
            print("Body Size: \(bodyData.count) bytes")
            if let prettyJson = try? JSONSerialization.jsonObject(with: bodyData, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: prettyJson, options: [.prettyPrinted]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                print("Body (formatted JSON):")
                print(prettyString)
            } else if let bodyString = String(data: bodyData, encoding: .utf8) {
                print("Body (raw):")
                print(bodyString)
            }
        }
        print("=== End Request ===\n")

        // Also log to AppLogger for persistence
        AppLogger.shared.info("HTTP Request to \(url)", category: .api, requestId: requestId)
        AppLogger.shared.debug("Method: \(method), Body size: \(bodyData?.count ?? 0) bytes", category: .api, requestId: requestId)
    }

    private func logHTTPResponse(
        statusCode: Int,
        headers: [AnyHashable: Any],
        dataSize: Int,
        responseTime: TimeInterval,
        requestId: String
    ) {
        print("\n")
        print("=== OpenAI API Response ===")
        print("Request ID: \(requestId)")
        print("Status Code: \(statusCode)")
        print("Response Time: \(String(format: "%.2f", responseTime)) seconds")
        print("Data Size: \(dataSize) bytes (\(dataSize / 1024) KB)")
        print("Headers:")
        for (key, value) in headers {
            if let keyStr = key as? String {
                print("  \(keyStr): \(value)")
            }
        }
        print("=== End Response ===\n")

        // Also log to AppLogger
        AppLogger.shared.info("HTTP Response: \(statusCode)", category: .api, requestId: requestId)
        AppLogger.shared.debug("Response time: \(String(format: "%.2f", responseTime))s, Size: \(dataSize / 1024)KB", category: .api, requestId: requestId)
    }
}
