//
//  SupabaseService.swift
//  InfiniteStories
//
//  Complete Supabase integration using supabase-swift v2.33.1
//

import Foundation
import Supabase
import Functions

// MARK: - Supabase Service

final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    private let client: SupabaseClient
    private var currentUserId: UUID?

    private init() {
        // Use configuration based on environment
        let config = SupabaseConfig.current
        guard let url = URL(string: config.url) else {
            fatalError("Invalid Supabase URL: \(config.url)")
        }

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: config.anonKey
        )

        // Use a fixed dev user ID for local development
        if SupabaseConfig.isLocalDevelopment {
            self.currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        } else {
            // In production, this would be set after authentication
            self.currentUserId = nil
        }

        print("📡 SupabaseService initialized")
        print("🔗 URL: \(url.absoluteString)")
        print("🏗️ Environment: \(SupabaseConfig.isLocalDevelopment ? "Local Development" : "Production")")
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        do {
            // Try to fetch from a simple table to test connection
            let _ = try await client
                .from("heroes")
                .select("id")
                .limit(1)
                .execute()

            print("✅ Test connection successful")
            return true
        } catch {
            print("❌ Test connection failed: \(error)")
            throw error
        }
    }

    // MARK: - Hero Operations

    func saveHero(_ hero: Hero) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let heroCodable = HeroCodable(from: hero, userId: userId)

        do {
            let _ = try await client
                .from("heroes")
                .upsert(heroCodable)
                .execute()

            hero.lastSyncedAt = Date()
            hero.needsSync = false
            print("📤 Synced hero: \(hero.name)")
        } catch {
            print("❌ Failed to sync hero: \(error)")
            throw SupabaseError.apiError("Failed to sync hero: \(error.localizedDescription)")
        }
    }

    func fetchHeroes(limit: Int = 100) async throws -> [[String: Any]] {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        do {
            let heroes: [HeroCodable] = try await client
                .from("heroes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            // Convert to dictionaries
            let encoder = JSONEncoder()

            let result = try heroes.map { hero -> [String: Any] in
                let data = try encoder.encode(hero)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                return json
            }

            print("📥 Fetched \(result.count) heroes")
            return result
        } catch {
            print("❌ Failed to fetch heroes: \(error)")
            throw SupabaseError.apiError("Failed to fetch heroes: \(error.localizedDescription)")
        }
    }

    func deleteHero(_ heroId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        do {
            let _ = try await client
                .from("heroes")
                .delete()
                .eq("id", value: heroId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("🗑️ Deleted hero: \(heroId)")
        } catch {
            print("❌ Failed to delete hero: \(error)")
            throw SupabaseError.apiError("Failed to delete hero: \(error.localizedDescription)")
        }
    }

    // MARK: - Story Operations

    func saveStory(_ story: Story) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let storyCodable = StoryCodable(from: story, userId: userId)

        do {
            let _ = try await client
                .from("stories")
                .upsert(storyCodable)
                .execute()

            story.lastSyncedAt = Date()
            story.needsSync = false
            print("📤 Synced story: \(story.title)")
        } catch {
            print("❌ Failed to sync story: \(error)")
            throw SupabaseError.apiError("Failed to sync story: \(error.localizedDescription)")
        }
    }

    func fetchStories(limit: Int = 50) async throws -> [[String: Any]] {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        do {
            let stories: [StoryCodable] = try await client
                .from("stories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            // Convert to dictionaries
            let encoder = JSONEncoder()
            let result = try stories.map { story -> [String: Any] in
                let data = try encoder.encode(story)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                return json
            }

            print("📥 Fetched \(result.count) stories")
            return result
        } catch {
            print("❌ Failed to fetch stories: \(error)")
            throw SupabaseError.apiError("Failed to fetch stories: \(error.localizedDescription)")
        }
    }

    func fetchStoriesForHero(_ heroId: UUID, limit: Int = 20) async throws -> [[String: Any]] {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        do {
            let stories: [StoryCodable] = try await client
                .from("stories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("hero_id", value: heroId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            // Convert to dictionaries
            let encoder = JSONEncoder()
            let result = try stories.map { story -> [String: Any] in
                let data = try encoder.encode(story)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                return json
            }

            print("📥 Fetched \(result.count) stories for hero: \(heroId)")
            return result
        } catch {
            print("❌ Failed to fetch stories for hero: \(error)")
            throw SupabaseError.apiError("Failed to fetch stories for hero: \(error.localizedDescription)")
        }
    }

    // MARK: - Edge Functions

    func generateStory(heroId: String, eventType: String, eventData: [String: Any], targetDuration: Int, language: String) async throws -> [String: Any] {
        let requestBody = [
            "hero_id": heroId,
            "event": [
                "type": eventType,
                "data": eventData
            ],
            "target_duration": targetDuration,
            "language": language
        ] as [String: Any]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            let json = try await client.functions
                .invoke(
                    "story-generation",
                    options: FunctionInvokeOptions(body: jsonData)
                ) { data, response in
                    // Check HTTP status code
                    if response.statusCode >= 400 {
                            // Try to parse error from response body
                            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let errorMessage = errorJson["error"] as? String {
                                    throw SupabaseError.apiError("Story generation failed: \(errorMessage)")
                                } else if let errorDetail = errorJson["message"] as? String {
                                    throw SupabaseError.apiError("Story generation failed: \(errorDetail)")
                                }
                            }

                            // Provide specific error messages based on status code
                            switch response.statusCode {
                            case 400:
                                throw SupabaseError.apiError("Invalid request parameters for story generation")
                            case 401:
                                throw SupabaseError.authenticationError("Authentication failed for story generation")
                            case 403:
                                throw SupabaseError.authenticationError("Permission denied for story generation")
                            case 404:
                                throw SupabaseError.notFound
                            case 429:
                                throw SupabaseError.apiError("Rate limit exceeded. Please try again in a moment")
                            case 500..<600:
                                throw SupabaseError.apiError("Server error during story generation. Please try again")
                            default:
                                throw SupabaseError.apiError("Story generation failed with status \(response.statusCode)")
                            }
                        }

                    // Parse successful response
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw SupabaseError.unexpectedResponse
                    }

                    // Handle Edge Function wrapper format: { success: true, data: {...} }
                    if let success = json["success"] as? Bool, success == true,
                       let innerData = json["data"] as? [String: Any] {
                        return innerData
                    }

                    // Return direct response (backward compatibility)
                    return json
                }

            print("🎭 Generated story via edge function")
            return json
        } catch let error as SupabaseError {
            print("❌ Failed to generate story: \(error.errorDescription ?? error.localizedDescription)")
            throw error
        } catch {
            print("❌ Failed to generate story: \(error)")
            throw SupabaseError.apiError("Failed to generate story: \(error.localizedDescription)")
        }
    }

    func synthesizeAudio(text: String, voice: String, language: String, storyId: String? = nil) async throws -> [String: Any] {
        var requestBody: [String: Any] = [
            "text": text,
            "voice": voice,
            "language": language
        ]

        if let storyId = storyId {
            requestBody["story_id"] = storyId
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            let json = try await client.functions
                .invoke(
                    "audio-synthesis",
                    options: FunctionInvokeOptions(body: jsonData)
                ) { data, response in
                    // Check HTTP status code
                    if response.statusCode >= 400 {
                            // Try to parse error from response body
                            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let errorMessage = errorJson["error"] as? String {
                                    throw SupabaseError.apiError("Audio synthesis failed: \(errorMessage)")
                                } else if let errorDetail = errorJson["message"] as? String {
                                    throw SupabaseError.apiError("Audio synthesis failed: \(errorDetail)")
                                }
                            }

                            // Provide specific error messages based on status code
                            switch response.statusCode {
                            case 400:
                                throw SupabaseError.apiError("Invalid audio synthesis parameters")
                            case 401:
                                throw SupabaseError.authenticationError("Authentication failed for audio synthesis")
                            case 403:
                                throw SupabaseError.authenticationError("Permission denied for audio synthesis")
                            case 404:
                                throw SupabaseError.notFound
                            case 413:
                                throw SupabaseError.apiError("Text too long for audio synthesis")
                            case 429:
                                throw SupabaseError.apiError("Rate limit exceeded. Please try again in a moment")
                            case 500..<600:
                                throw SupabaseError.apiError("Server error during audio synthesis. Please try again")
                            default:
                                throw SupabaseError.apiError("Audio synthesis failed with status \(response.statusCode)")
                            }
                        }

                    // Parse successful response
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw SupabaseError.unexpectedResponse
                    }

                    // Handle Edge Function wrapper format: { success: true, data: {...} }
                    if let success = json["success"] as? Bool, success == true,
                       let innerData = json["data"] as? [String: Any] {
                        return innerData
                    }

                    // Return direct response (backward compatibility)
                    return json
                }

            print("🎵 Synthesized audio via edge function")
            return json
        } catch let error as SupabaseError {
            print("❌ Failed to synthesize audio: \(error.errorDescription ?? error.localizedDescription)")
            throw error
        } catch {
            print("❌ Failed to synthesize audio: \(error)")
            throw SupabaseError.apiError("Failed to synthesize audio: \(error.localizedDescription)")
        }
    }

    func extractScenes(storyContent: String, storyDuration: Int, heroId: String, heroName: String, eventContext: String) async throws -> [String: Any] {
        let requestBody = [
            "story_content": storyContent,
            "story_duration": storyDuration,
            "hero": [
                "id": heroId,
                "name": heroName
            ],
            "event_context": eventContext
        ] as [String: Any]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            let responseData = try await client.functions
                .invoke(
                    "extract-scenes",
                    options: FunctionInvokeOptions(body: jsonData)
                ) { data, response in
                    // Check response status
                    if response.statusCode != 200 {
                        print("⚠️ Scene extraction response status: \(response.statusCode)")
                    }
                    return data
                }

            // Parse JSON response
            guard let responseDict = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                throw SupabaseError.unexpectedResponse
            }

            // Check for error in response
            if let error = responseDict["error"] as? String {
                throw SupabaseError.apiError(error)
            }

            // Handle the Edge Function wrapper format: { success: true, data: {...} }
            if let success = responseDict["success"] as? Bool, success == true,
               let data = responseDict["data"] as? [String: Any] {
                print("✅ Scene extraction successful (wrapped response)")
                return data
            } else if responseDict["scenes"] != nil {
                // Direct response format (backward compatibility)
                print("✅ Scene extraction successful (direct response)")
                return responseDict
            }

            print("⚠️ Unexpected response format")
            throw SupabaseError.unexpectedResponse
        } catch {
            print("❌ Scene extraction failed: \(error)")
            throw error
        }
    }

    func generateAvatar(heroId: String, prompt: String, style: String = "watercolor", quality: String = "high", size: String = "1024x1024") async throws -> [String: Any] {
        let requestBody = [
            "hero_id": heroId,
            "prompt": prompt,
            "style": style,
            "quality": quality,
            "size": size
        ] as [String: Any]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            let json = try await client.functions
                .invoke(
                    "avatar-generation",
                    options: FunctionInvokeOptions(body: jsonData)
                ) { data, response in
                    // Check HTTP status code
                    if response.statusCode >= 400 {
                            // Try to parse error from response body
                            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let errorMessage = errorJson["error"] as? String {
                                    // Check for specific content policy violations
                                    if errorMessage.contains("content policy") || errorMessage.contains("safety system") {
                                        throw SupabaseError.apiError("Avatar prompt violates content policy. Please use child-friendly descriptions")
                                    }
                                    throw SupabaseError.apiError("Avatar generation failed: \(errorMessage)")
                                } else if let errorDetail = errorJson["message"] as? String {
                                    throw SupabaseError.apiError("Avatar generation failed: \(errorDetail)")
                                }
                            }

                            // Provide specific error messages based on status code
                            switch response.statusCode {
                            case 400:
                                throw SupabaseError.apiError("Invalid avatar generation parameters")
                            case 401:
                                throw SupabaseError.authenticationError("Authentication failed for avatar generation")
                            case 403:
                                throw SupabaseError.authenticationError("Permission denied for avatar generation")
                            case 404:
                                throw SupabaseError.notFound
                            case 413:
                                throw SupabaseError.apiError("Avatar prompt too long")
                            case 429:
                                throw SupabaseError.apiError("Rate limit exceeded. Please try again in a moment")
                            case 500..<600:
                                throw SupabaseError.apiError("Server error during avatar generation. Please try again")
                            default:
                                throw SupabaseError.apiError("Avatar generation failed with status \(response.statusCode)")
                            }
                        }

                    // Parse successful response
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw SupabaseError.unexpectedResponse
                    }

                    // Handle Edge Function wrapper format: { success: true, data: {...} }
                    if let success = json["success"] as? Bool, success == true,
                       let innerData = json["data"] as? [String: Any] {
                        return innerData
                    }

                    // Return direct response (backward compatibility)
                    return json
                }

            print("🎨 Generated avatar via edge function")
            return json
        } catch let error as SupabaseError {
            print("❌ Failed to generate avatar: \(error.errorDescription ?? error.localizedDescription)")
            throw error
        } catch {
            print("❌ Failed to generate avatar: \(error)")
            throw SupabaseError.apiError("Failed to generate avatar: \(error.localizedDescription)")
        }
    }

    func generateSceneIllustrations(
        storyId: String,
        heroId: String,
        scenes: [[String: Any]],
        heroVisualProfile: [String: Any]? = nil,
        processAsync: Bool = false
    ) async throws -> [String: Any] {
        var requestBody: [String: Any] = [
            "story_id": storyId,
            "hero_id": heroId,
            "scenes": scenes,
            "process_async": processAsync
        ]

        if let profile = heroVisualProfile {
            requestBody["hero_visual_profile"] = profile
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            let json = try await client.functions
                .invoke(
                    "scene-illustration",
                    options: FunctionInvokeOptions(body: jsonData)
                ) { data, response in
                    // Check HTTP status code
                    if response.statusCode >= 400 {
                            // Try to parse error from response body
                            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let errorMessage = errorJson["error"] as? String {
                                    // Check for specific content policy violations
                                    if errorMessage.contains("content policy") || errorMessage.contains("safety system") {
                                        throw SupabaseError.apiError("Scene prompt violates content policy. Please ensure all content is child-friendly")
                                    }
                                    // Check for quota errors
                                    if errorMessage.contains("quota") || errorMessage.contains("limit") {
                                        throw SupabaseError.apiError("Image generation quota exceeded. Please try again later")
                                    }
                                    throw SupabaseError.apiError("Scene illustration failed: \(errorMessage)")
                                } else if let errorDetail = errorJson["message"] as? String {
                                    throw SupabaseError.apiError("Scene illustration failed: \(errorDetail)")
                                } else if let errors = errorJson["errors"] as? [[String: Any]] {
                                    // Handle multiple scene errors
                                    let errorDescriptions = errors.compactMap { $0["error"] as? String }
                                    let combinedError = errorDescriptions.joined(separator: "; ")
                                    throw SupabaseError.apiError("Scene illustration errors: \(combinedError)")
                                }
                            }

                            // Provide specific error messages based on status code
                            switch response.statusCode {
                            case 400:
                                throw SupabaseError.apiError("Invalid scene illustration parameters")
                            case 401:
                                throw SupabaseError.authenticationError("Authentication failed for scene illustrations")
                            case 403:
                                throw SupabaseError.authenticationError("Permission denied for scene illustrations")
                            case 404:
                                throw SupabaseError.notFound
                            case 413:
                                throw SupabaseError.apiError("Too many scenes or prompts too long")
                            case 429:
                                throw SupabaseError.apiError("Rate limit exceeded. Please try again in a moment")
                            case 500..<600:
                                throw SupabaseError.apiError("Server error during scene illustration. Please try again")
                            default:
                                throw SupabaseError.apiError("Scene illustration failed with status \(response.statusCode)")
                            }
                        }

                    // Parse successful response
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw SupabaseError.unexpectedResponse
                    }

                    // Handle Edge Function wrapper format: { success: true, data: {...} }
                    var responseData = json
                    if let success = json["success"] as? Bool, success == true,
                       let innerData = json["data"] as? [String: Any] {
                        responseData = innerData
                    }

                    // Check for async processing response
                    if processAsync {
                        if let status = responseData["status"] as? String, status == "processing" {
                            print("🔄 Scene illustrations processing asynchronously")
                        }
                    } else {
                        // For synchronous processing, check if we have the expected illustrations
                        if let illustrations = responseData["illustrations"] as? [[String: Any]], illustrations.isEmpty {
                            print("⚠️ Warning: No illustrations generated in response")
                        }
                    }

                    return responseData
                }

            print("🖼️ Generated scene illustrations via edge function")
            return json
        } catch let error as SupabaseError {
            print("❌ Failed to generate scene illustrations: \(error.errorDescription ?? error.localizedDescription)")
            throw error
        } catch {
            print("❌ Failed to generate scene illustrations: \(error)")
            throw SupabaseError.apiError("Failed to generate scene illustrations: \(error.localizedDescription)")
        }
    }

    // MARK: - Realtime (Future implementation)

    func setupRealtimeSubscriptions() async {
        // TODO: Implement realtime subscriptions when needed
        print("📡 Realtime subscriptions not yet implemented")
    }

    func cleanupSubscriptions() async {
        // TODO: Implement subscription cleanup when needed
        print("🔚 Cleanup subscriptions not yet implemented")
    }

    // MARK: - Storage Operations

    // MARK: Avatar Storage

    /// Upload avatar image data to Supabase Storage
    /// - Parameters:
    ///   - heroId: The ID of the hero
    ///   - imageData: The avatar image data
    /// - Returns: The public URL of the uploaded avatar
    func uploadAvatar(heroId: UUID, imageData: Data) async throws -> String {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let fileName = "\(userId.uuidString)/\(heroId.uuidString)/avatar.png"
        print("📤 Uploading avatar: \(fileName)")

        do {
            // Upload to storage
            let _ = try await client.storage
                .from("hero-avatars")
                .upload(
                    path: fileName,
                    file: imageData,
                    options: FileOptions(
                        cacheControl: "86400", // 24 hours
                        contentType: "image/png",
                        upsert: true
                    )
                )

            // Get public URL
            let publicURL = try client.storage
                .from("hero-avatars")
                .getPublicURL(path: fileName)

            print("✅ Avatar uploaded: \(publicURL.absoluteString)")
            return publicURL.absoluteString
        } catch {
            print("❌ Failed to upload avatar: \(error)")
            throw SupabaseError.apiError("Failed to upload avatar: \(error.localizedDescription)")
        }
    }

    /// Download avatar image data from Supabase Storage
    /// - Parameter heroId: The ID of the hero
    /// - Returns: The avatar image data, or nil if not found
    func downloadAvatar(heroId: UUID) async throws -> Data? {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let fileName = "\(userId.uuidString)/\(heroId.uuidString)/avatar.png"
        print("📥 Downloading avatar: \(fileName)")

        do {
            let data = try await client.storage
                .from("hero-avatars")
                .download(path: fileName)

            print("✅ Avatar downloaded: \(data.count) bytes")
            return data
        } catch {
            // Check if it's a not found error
            if error.localizedDescription.contains("404") || error.localizedDescription.contains("not found") {
                print("ℹ️ Avatar not found: \(fileName)")
                return nil
            }
            print("❌ Failed to download avatar: \(error)")
            throw SupabaseError.apiError("Failed to download avatar: \(error.localizedDescription)")
        }
    }

    /// Delete avatar from Supabase Storage
    /// - Parameter heroId: The ID of the hero
    func deleteAvatar(heroId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let fileName = "\(userId.uuidString)/\(heroId.uuidString)/avatar.png"
        print("🗑️ Deleting avatar: \(fileName)")

        do {
            let _ = try await client.storage
                .from("hero-avatars")
                .remove(paths: [fileName])

            print("✅ Avatar deleted: \(fileName)")
        } catch {
            print("❌ Failed to delete avatar: \(error)")
            throw SupabaseError.apiError("Failed to delete avatar: \(error.localizedDescription)")
        }
    }

    // MARK: Audio Storage

    /// Upload story audio data to Supabase Storage
    /// - Parameters:
    ///   - storyId: The ID of the story
    ///   - audioData: The audio file data
    /// - Returns: The public URL of the uploaded audio
    func uploadStoryAudio(storyId: UUID, audioData: Data) async throws -> String {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let fileName = "\(userId.uuidString)/\(storyId.uuidString)/audio.mp3"
        print("📤 Uploading audio: \(fileName)")

        do {
            // Upload to storage
            let _ = try await client.storage
                .from("story-audio")
                .upload(
                    path: fileName,
                    file: audioData,
                    options: FileOptions(
                        cacheControl: "86400", // 24 hours
                        contentType: "audio/mpeg",
                        upsert: true
                    )
                )

            // Get public URL
            let publicURL = try client.storage
                .from("story-audio")
                .getPublicURL(path: fileName)

            print("✅ Audio uploaded: \(publicURL.absoluteString)")
            return publicURL.absoluteString
        } catch {
            print("❌ Failed to upload audio: \(error)")
            throw SupabaseError.apiError("Failed to upload audio: \(error.localizedDescription)")
        }
    }

    /// Download story audio data from Supabase Storage
    /// - Parameter storyId: The ID of the story
    /// - Returns: The audio file data, or nil if not found
    func downloadStoryAudio(storyId: UUID) async throws -> Data? {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let fileName = "\(userId.uuidString)/\(storyId.uuidString)/audio.mp3"
        print("📥 Downloading audio: \(fileName)")

        do {
            let data = try await client.storage
                .from("story-audio")
                .download(path: fileName)

            print("✅ Audio downloaded: \(data.count) bytes")
            return data
        } catch {
            // Check if it's a not found error
            if error.localizedDescription.contains("404") || error.localizedDescription.contains("not found") {
                print("ℹ️ Audio not found: \(fileName)")
                return nil
            }
            print("❌ Failed to download audio: \(error)")
            throw SupabaseError.apiError("Failed to download audio: \(error.localizedDescription)")
        }
    }

    /// Delete story audio from Supabase Storage
    /// - Parameter storyId: The ID of the story
    func deleteStoryAudio(storyId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let fileName = "\(userId.uuidString)/\(storyId.uuidString)/audio.mp3"
        print("🗑️ Deleting audio: \(fileName)")

        do {
            let _ = try await client.storage
                .from("story-audio")
                .remove(paths: [fileName])

            print("✅ Audio deleted: \(fileName)")
        } catch {
            print("❌ Failed to delete audio: \(error)")
            throw SupabaseError.apiError("Failed to delete audio: \(error.localizedDescription)")
        }
    }

    // MARK: Scene Illustration Storage

    /// Upload scene illustration to Supabase Storage
    /// - Parameters:
    ///   - storyId: The ID of the story
    ///   - sceneNumber: The scene number (1-based)
    ///   - imageData: The illustration image data
    /// - Returns: The public URL of the uploaded illustration
    func uploadSceneIllustration(storyId: UUID, sceneNumber: Int, imageData: Data) async throws -> String {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let fileName = "\(userId.uuidString)/\(storyId.uuidString)/scene_\(sceneNumber).png"
        print("📤 Uploading illustration: \(fileName)")

        do {
            // Upload to storage
            let _ = try await client.storage
                .from("story-illustrations")
                .upload(
                    path: fileName,
                    file: imageData,
                    options: FileOptions(
                        cacheControl: "86400", // 24 hours
                        contentType: "image/png",
                        upsert: true
                    )
                )

            // Get public URL
            let publicURL = try client.storage
                .from("story-illustrations")
                .getPublicURL(path: fileName)

            print("✅ Illustration uploaded: \(publicURL.absoluteString)")
            return publicURL.absoluteString
        } catch {
            print("❌ Failed to upload illustration: \(error)")
            throw SupabaseError.apiError("Failed to upload illustration: \(error.localizedDescription)")
        }
    }

    /// Download scene illustration from Supabase Storage
    /// - Parameters:
    ///   - storyId: The ID of the story
    ///   - sceneNumber: The scene number (1-based)
    /// - Returns: The illustration image data, or nil if not found
    func downloadSceneIllustration(storyId: UUID, sceneNumber: Int) async throws -> Data? {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let fileName = "\(userId.uuidString)/\(storyId.uuidString)/scene_\(sceneNumber).png"
        print("📥 Downloading illustration: \(fileName)")

        do {
            let data = try await client.storage
                .from("story-illustrations")
                .download(path: fileName)

            print("✅ Illustration downloaded: \(data.count) bytes")
            return data
        } catch {
            // Check if it's a not found error
            if error.localizedDescription.contains("404") || error.localizedDescription.contains("not found") {
                print("ℹ️ Illustration not found: \(fileName)")
                return nil
            }
            print("❌ Failed to download illustration: \(error)")
            throw SupabaseError.apiError("Failed to download illustration: \(error.localizedDescription)")
        }
    }

    /// Delete scene illustration from Supabase Storage
    /// - Parameters:
    ///   - storyId: The ID of the story
    ///   - sceneNumber: The scene number (1-based)
    func deleteSceneIllustration(storyId: UUID, sceneNumber: Int) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.authenticationError("No user ID available")
        }

        let fileName = "\(userId.uuidString)/\(storyId.uuidString)/scene_\(sceneNumber).png"
        print("🗑️ Deleting illustration: \(fileName)")

        do {
            let _ = try await client.storage
                .from("story-illustrations")
                .remove(paths: [fileName])

            print("✅ Illustration deleted: \(fileName)")
        } catch {
            print("❌ Failed to delete illustration: \(error)")
            throw SupabaseError.apiError("Failed to delete illustration: \(error.localizedDescription)")
        }
    }

    // MARK: Storage Helpers

    /// Get the public URL for a file in a storage bucket
    /// - Parameters:
    ///   - bucket: The storage bucket name
    ///   - path: The file path within the bucket
    /// - Returns: The public URL string, or nil if invalid
    func getPublicURL(bucket: String, path: String) -> String? {
        do {
            let url = try client.storage
                .from(bucket)
                .getPublicURL(path: path)
            return url.absoluteString
        } catch {
            print("❌ Failed to get public URL for \(bucket)/\(path): \(error)")
            return nil
        }
    }

    /// Delete all storage files for a hero
    /// - Parameter heroId: The ID of the hero
    func deleteAllHeroStorage(heroId: UUID) async throws {
        // Delete avatar
        do {
            try await deleteAvatar(heroId: heroId)
        } catch {
            print("⚠️ Could not delete avatar for hero \(heroId): \(error)")
        }

        // Note: Stories and their associated files (audio, illustrations) should be handled separately
        // This is just for cleaning up hero-specific storage
    }

    /// Delete all storage files for a story
    /// - Parameter storyId: The ID of the story
    func deleteAllStoryStorage(storyId: UUID) async throws {
        // Delete audio
        do {
            try await deleteStoryAudio(storyId: storyId)
        } catch {
            print("⚠️ Could not delete audio for story \(storyId): \(error)")
        }

        // Delete all illustrations (attempt up to 10 scenes)
        for sceneNumber in 1...10 {
            do {
                try await deleteSceneIllustration(storyId: storyId, sceneNumber: sceneNumber)
            } catch {
                // Stop when we hit a scene that doesn't exist
                if error.localizedDescription.contains("404") || error.localizedDescription.contains("not found") {
                    break
                }
                print("⚠️ Could not delete scene \(sceneNumber) for story \(storyId): \(error)")
            }
        }
    }

    // MARK: - Helpers

    func upsertHero(_ hero: Hero) async throws {
        try await saveHero(hero)
    }

    func upsertStory(_ story: Story) async throws {
        try await saveStory(story)
    }
}

// MARK: - Model Extensions for Sync

extension Hero {
    func markAsSynced() {
        lastSyncedAt = Date()
        needsSync = false
    }
}

extension Story {
    func markAsSynced() {
        lastSyncedAt = Date()
        needsSync = false
    }
}

// MARK: - SupabaseError for compatibility

enum SupabaseError: Error, LocalizedError {
    case apiError(String)
    case networkError(Error)
    case authenticationError(String)
    case decodingError(Error)
    case notFound
    case invalidConfiguration(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        case .decodingError(let error):
            return "Decoding Error: \(error.localizedDescription)"
        case .notFound:
            return "Requested resource was not found"
        case .invalidConfiguration(let message):
            return "Invalid Supabase configuration: \(message)"
        case .unexpectedResponse:
            return "Supabase returned an unexpected response"
        }
    }
}
