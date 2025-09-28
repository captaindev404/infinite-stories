//
//  Hero.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation
import SwiftData

// MARK: - Helper Types for Supabase Compatibility

/// Codable wrapper for Hero to enable Supabase sync
struct HeroCodable: Codable {
    let id: String
    let userId: String
    let name: String
    let primaryTrait: String
    let secondaryTrait: String
    let appearance: String
    let specialAbility: String
    let createdAt: String
    let updatedAt: String
    let isActive: Bool
    let avatarPrompt: String?
    let avatarGenerationId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case primaryTrait = "primary_trait"
        case secondaryTrait = "secondary_trait"
        case appearance
        case specialAbility = "special_ability"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isActive = "is_active"
        case avatarPrompt = "avatar_prompt"
        case avatarGenerationId = "avatar_generation_id"
    }

    init(from hero: Hero, userId: UUID) {
        self.id = hero.id.uuidString
        self.userId = userId.uuidString
        self.name = hero.name
        self.primaryTrait = hero.primaryTrait.rawValue
        self.secondaryTrait = hero.secondaryTrait.rawValue
        self.appearance = hero.appearance
        self.specialAbility = hero.specialAbility
        self.createdAt = ISO8601DateFormatter.supabase.string(from: hero.createdAt)
        self.updatedAt = ISO8601DateFormatter.supabase.string(from: hero.updatedAt)
        self.isActive = hero.isActive
        self.avatarPrompt = hero.avatarPrompt
        self.avatarGenerationId = hero.avatarGenerationId
    }
}

@Model
final class Hero {
    var id: UUID = UUID() // Single UUID for both local and remote
    var name: String
    var primaryTrait: CharacterTrait
    var secondaryTrait: CharacterTrait
    var appearance: String
    var specialAbility: String
    var createdAt: Date
    var updatedAt: Date = Date() // Track when last modified
    var isActive: Bool
    var avatarImagePath: String?
    var avatarPrompt: String?
    var avatarGeneratedAt: Date?
    var avatarGenerationId: String? // GPT-Image-1 generation ID for multi-turn consistency

    // Simple sync properties
    var lastSyncedAt: Date? // When last synced to Supabase
    var needsSync: Bool = true // Whether changes need to be synced

    @Relationship(deleteRule: .nullify) var stories: [Story] = []
    @Relationship var visualProfile: HeroVisualProfile?
    
    init(name: String, primaryTrait: CharacterTrait, secondaryTrait: CharacterTrait, appearance: String = "", specialAbility: String = "") {
        self.name = name
        self.primaryTrait = primaryTrait
        self.secondaryTrait = secondaryTrait
        self.appearance = appearance
        self.specialAbility = specialAbility
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
        self.avatarImagePath = nil
        self.avatarPrompt = nil
        self.avatarGeneratedAt = nil
        self.avatarGenerationId = nil
        self.lastSyncedAt = nil
        self.needsSync = true
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
        // Check both that we have a path and the file exists
        guard let avatarImagePath = avatarImagePath else { return false }
        let url = getDocumentsDirectory().appendingPathComponent("Avatars").appendingPathComponent(avatarImagePath)
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    // MARK: - Simple Sync Methods

    /// Mark hero as needing sync (call after any change)
    func markAsModified() {
        updatedAt = Date()
        needsSync = true
    }

    /// Sync status for UI
    var syncStatusDescription: String {
        if let lastSync = lastSyncedAt, !needsSync {
            let formatter = RelativeDateTimeFormatter()
            return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else if needsSync {
            return "Needs sync"
        } else {
            return "Not synced"
        }
    }
}