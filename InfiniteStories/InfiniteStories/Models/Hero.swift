//
//  Hero.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation
import SwiftData

@Model
final class Hero {
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

    @Relationship(deleteRule: .nullify) var stories: [Story] = []
    @Relationship var visualProfile: HeroVisualProfile?
    
    init(name: String, primaryTrait: CharacterTrait, secondaryTrait: CharacterTrait, appearance: String = "", specialAbility: String = "") {
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
}