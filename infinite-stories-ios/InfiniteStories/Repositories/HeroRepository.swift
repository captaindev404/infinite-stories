//
//  HeroRepository.swift
//  InfiniteStories
//
//  Hero data access - API-only (no local persistence)
//

import Foundation

// MARK: - Hero Repository Protocol

protocol HeroRepositoryProtocol {
    func fetchHeroes() async throws -> [Hero]
    func fetchHero(id: String) async throws -> Hero
    func createHero(name: String, age: Int, traits: [CharacterTrait], specialAbility: String?, appearance: String?) async throws -> Hero
    func updateHero(id: String, name: String?, traits: [CharacterTrait]?, specialAbility: String?, appearance: String?) async throws -> Hero
    func deleteHero(id: String) async throws
    func generateAvatar(heroId: String, prompt: String) async throws -> String // Returns avatar URL

    // Visual Profile
    func getVisualProfile(heroId: String) async throws -> HeroVisualProfile?
    func createVisualProfile(heroId: String, profile: HeroVisualProfile) async throws -> HeroVisualProfile
    func updateVisualProfile(heroId: String, profile: HeroVisualProfile) async throws -> HeroVisualProfile
    func deleteVisualProfile(heroId: String) async throws
    func extractVisualProfile(heroId: String) async throws -> HeroVisualProfile
}

// MARK: - Hero Repository Implementation

@MainActor
class HeroRepository: HeroRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Fetch Operations

    func fetchHeroes() async throws -> [Hero] {
        // Check network first
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Fetching heroes from backend")

        // Call API - backend wraps response in { data: { heroes: [...] } }
        let wrapper: HeroesListWrapper = try await apiClient.request(
            .getHeroes(limit: 100, offset: 0, includeStories: false)
        )

        // Convert API response to Hero models
        let heroes = wrapper.data.heroes.map { convertToHero($0) }
        Logger.api.success("Fetched \(heroes.count) heroes")

        return heroes
    }

    func fetchHero(id: String) async throws -> Hero {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Fetching hero \(id)")

        let response: APIResponse<HeroResponse> = try await apiClient.request(
            .getHero(id: id, includeStories: false)
        )

        guard let data = response.data else {
            throw APIError.notFound
        }

        let hero = convertToHero(data)
        Logger.api.success("Fetched hero: \(hero.name)")

        return hero
    }

    // MARK: - Create Operation

    func createHero(
        name: String,
        age: Int,
        traits: [CharacterTrait],
        specialAbility: String?,
        appearance: String?
    ) async throws -> Hero {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Creating hero: \(name)")

        // Build request with specialAbilities as array (backend expects array)
        let specialAbilitiesArray: [String]? = specialAbility.flatMap { ability in
            ability.isEmpty ? nil : [ability]
        }

        let request = HeroCreateRequest(
            name: name,
            age: age,
            traits: traits.map { $0.rawValue },
            specialAbilities: specialAbilitiesArray,
            appearance: appearance,
            hairColor: nil,
            eyeColor: nil,
            skinTone: nil,
            height: nil
        )

        // Call API
        let response: APIResponse<HeroResponse> = try await apiClient.request(
            .createHero(data: request)
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "HeroRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in create response"]
            ))
        }

        let hero = convertToHero(data)
        Logger.api.success("Created hero: \(hero.name) (ID: \(data.id))")

        return hero
    }

    // MARK: - Update Operation

    func updateHero(
        id: String,
        name: String?,
        traits: [CharacterTrait]?,
        specialAbility: String?,
        appearance: String?
    ) async throws -> Hero {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Updating hero \(id)")

        // Build request with specialAbilities as array (backend expects array)
        let specialAbilitiesArray: [String]? = specialAbility.flatMap { ability in
            ability.isEmpty ? nil : [ability]
        }

        let request = HeroUpdateRequest(
            name: name,
            age: nil,
            traits: traits?.map { $0.rawValue },
            specialAbilities: specialAbilitiesArray,
            appearance: appearance,
            hairColor: nil,
            eyeColor: nil,
            skinTone: nil,
            height: nil,
            avatarUrl: nil
        )

        // Call API
        let response: APIResponse<HeroResponse> = try await apiClient.request(
            .updateHero(id: id, data: request)
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "HeroRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in update response"]
            ))
        }

        let hero = convertToHero(data)
        Logger.api.success("Updated hero: \(hero.name)")

        return hero
    }

    // MARK: - Delete Operation

    func deleteHero(id: String) async throws {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Deleting hero \(id)")

        // Call API
        try await apiClient.requestVoid(.deleteHero(id: id))

        Logger.api.success("Deleted hero \(id)")
    }

    // MARK: - Avatar Generation

    func generateAvatar(heroId: String, prompt: String) async throws -> String {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Generating avatar for hero \(heroId)")

        // Call API
        let response: APIResponse<AvatarGenerationResponse> = try await apiClient.request(
            .generateAvatar(heroId: heroId, prompt: prompt),
            retryPolicy: .aggressive // Avatar generation is critical
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "HeroRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in avatar response"]
            ))
        }

        Logger.api.success("Generated avatar: \(data.avatarUrl)")

        return data.avatarUrl
    }

    // MARK: - Visual Profile Operations

    func getVisualProfile(heroId: String) async throws -> HeroVisualProfile? {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Fetching visual profile for hero \(heroId)")

        do {
            let response: APIResponse<HeroVisualProfileResponse> = try await apiClient.request(
                .getVisualProfile(heroId: heroId)
            )

            guard let data = response.data else {
                Logger.api.info("No visual profile found for hero \(heroId)")
                return nil
            }

            let profile = data.toModel()
            Logger.api.success("Fetched visual profile for hero \(heroId)")

            return profile
        } catch APIError.notFound {
            // No profile exists, return nil
            return nil
        }
    }

    func createVisualProfile(heroId: String, profile: HeroVisualProfile) async throws -> HeroVisualProfile {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Creating visual profile for hero \(heroId)")

        let request = VisualProfileCreateRequest(from: profile)

        let response: APIResponse<HeroVisualProfileResponse> = try await apiClient.request(
            .createVisualProfile(heroId: heroId, data: request)
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "HeroRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in create visual profile response"]
            ))
        }

        let createdProfile = data.toModel()
        Logger.api.success("Created visual profile for hero \(heroId)")

        return createdProfile
    }

    func updateVisualProfile(heroId: String, profile: HeroVisualProfile) async throws -> HeroVisualProfile {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Updating visual profile for hero \(heroId)")

        let request = VisualProfileUpdateRequest(from: profile)

        let response: APIResponse<HeroVisualProfileResponse> = try await apiClient.request(
            .updateVisualProfile(heroId: heroId, data: request)
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "HeroRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in update visual profile response"]
            ))
        }

        let updatedProfile = data.toModel()
        Logger.api.success("Updated visual profile for hero \(heroId)")

        return updatedProfile
    }

    func deleteVisualProfile(heroId: String) async throws {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Deleting visual profile for hero \(heroId)")

        try await apiClient.requestVoid(.deleteVisualProfile(heroId: heroId))

        Logger.api.success("Deleted visual profile for hero \(heroId)")
    }

    func extractVisualProfile(heroId: String) async throws -> HeroVisualProfile {
        guard NetworkMonitor.shared.isConnected else {
            throw APIError.networkUnavailable
        }

        Logger.api.info("Extracting visual profile for hero \(heroId) using AI")

        let response: APIResponse<HeroVisualProfileResponse> = try await apiClient.request(
            .extractVisualProfile(heroId: heroId),
            retryPolicy: .aggressive // AI extraction is a longer operation
        )

        guard let data = response.data else {
            throw APIError.unknown(NSError(
                domain: "HeroRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No data in extract visual profile response"]
            ))
        }

        let extractedProfile = data.toModel()
        Logger.api.success("Extracted visual profile for hero \(heroId)")

        return extractedProfile
    }

    // MARK: - Helper: Convert API Response to Model

    private func convertToHero(_ response: HeroResponse) -> Hero {
        // Determine primary and secondary traits
        let primaryTrait = CharacterTrait(rawValue: response.traits.first ?? "curious") ?? .curious
        let secondaryTrait = CharacterTrait(rawValue: response.traits.count > 1 ? response.traits[1] : response.traits.first ?? "kind") ?? .kind

        // Use appearance from response if available, otherwise build from individual fields
        let appearance = response.appearance ?? buildAppearance(response)

        // Create Hero model (transient, not persisted)
        let hero = Hero(
            name: response.name,
            primaryTrait: primaryTrait,
            secondaryTrait: secondaryTrait,
            appearance: appearance,
            specialAbility: response.specialAbilities?.first ?? "",
            backendId: response.id // Store the backend ID
        )

        // Set additional properties
        hero.createdAt = response.createdAt
        hero.isActive = true

        // Avatar info
        if let avatarUrl = response.avatarUrl {
            hero.avatarImagePath = avatarUrl // Store URL as path for now
        }
        hero.avatarGenerationId = response.avatarGenerationId
        hero.avatarGeneratedAt = response.updatedAt
        hero.storyCount = response._count?.stories ?? 0

        return hero
    }

    private func buildAppearance(_ response: HeroResponse) -> String {
        var parts: [String] = []

        if let hair = response.hairColor {
            parts.append("\(hair) hair")
        }
        if let eyes = response.eyeColor {
            parts.append("\(eyes) eyes")
        }
        if let skin = response.skinTone {
            parts.append("\(skin) skin")
        }
        if let height = response.height {
            parts.append(height)
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Response DTOs (additional)

// Wrapper for the actual backend response which has data field
struct HeroesListWrapper: Decodable {
    let data: HeroesListResponse
}

struct HeroesListResponse: Decodable {
    let heroes: [HeroResponse]
    let pagination: Pagination?
}

struct AvatarGenerationResponse: Decodable {
    let heroId: String  // Backend uses cuid strings, not UUIDs
    let avatarUrl: String
    let generationId: String?
}
