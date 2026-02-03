//
//  Hero.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation
import SwiftData

@Model
final class Hero: Identifiable {
    var id: UUID = UUID() // Local ID for SwiftData (not persisted in API-only architecture)
    var backendId: String? // Backend ID from API (cuid string)
    var name: String
    var primaryTrait: CharacterTrait
    var secondaryTrait: CharacterTrait
    var appearance: String
    var specialAbility: String
    var createdAt: Date
    var isActive: Bool
    var avatarImagePath: String?
    var avatarPrompt: String?
    var avatarGeneratedAt: Date?
    var avatarGenerationId: String? // GPT-Image-1 generation ID for multi-turn consistency
    @Transient var storyCount: Int = 0

    @Relationship(deleteRule: .nullify) var stories: [Story] = []
    // NOTE: visualProfile is now fetched from API, not stored in SwiftData
    // Use HeroRepository.getVisualProfile(heroId:) to fetch

    init(name: String, primaryTrait: CharacterTrait, secondaryTrait: CharacterTrait, appearance: String = "", specialAbility: String = "", backendId: String? = nil) {
        self.id = UUID()
        self.backendId = backendId
        self.name = name
        self.primaryTrait = primaryTrait
        self.secondaryTrait = secondaryTrait
        self.appearance = appearance
        self.specialAbility = specialAbility
        self.createdAt = Date()
        self.isActive = true
        self.avatarImagePath = nil
        self.avatarPrompt = nil
        self.avatarGeneratedAt = nil
        self.avatarGenerationId = nil
    }
    
    var traitsDescription: String {
        return "\(primaryTrait.rawValue) and \(secondaryTrait.rawValue)"
    }
    
    var fullDescription: String {
        var description = "\(name) is a \(primaryTrait.rawValue.lowercased()) and \(secondaryTrait.rawValue.lowercased()) character"
        
        if !appearance.isEmpty {
            description += " who looks like \(appearance)"
        }
        
        if !specialAbility.isEmpty {
            description += " and has the special ability to \(specialAbility)"
        }
        
        return description + "."
    }

    var avatarURL: URL? {
        guard let avatarImagePath = avatarImagePath else { return nil }

        // Check if avatarImagePath is already a full URL (from backend API)
        if avatarImagePath.starts(with: "http://") || avatarImagePath.starts(with: "https://") {
            return URL(string: avatarImagePath)
        }

        // Otherwise, it's a local file path
        let url = getDocumentsDirectory().appendingPathComponent("Avatars").appendingPathComponent(avatarImagePath)

        // Verify file actually exists
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        } else {
            print("Warning: Avatar file not found at \(url.path)")
            return nil
        }
    }

    var hasAvatar: Bool {
        guard let avatarImagePath = avatarImagePath else { return false }

        // For remote URLs, assume they exist (will be handled by AsyncImage)
        if avatarImagePath.starts(with: "http://") || avatarImagePath.starts(with: "https://") {
            return true
        }

        // For local files, check if they exist
        let url = getDocumentsDirectory().appendingPathComponent("Avatars").appendingPathComponent(avatarImagePath)
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}