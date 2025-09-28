//
//  HeroVisualProfile.swift
//  InfiniteStories
//
//  Hero Visual Profile for maintaining consistent appearance across illustrations
//

import Foundation
import SwiftData

/// Stores detailed visual characteristics of a hero for consistent illustration generation
@Model
final class HeroVisualProfile {
    var id: UUID

    // Core visual attributes extracted from avatar
    var hairColor: String?
    var hairStyle: String?
    var eyeColor: String?
    var skinTone: String?
    var clothingStyle: String?
    var clothingColors: String?
    var distinctiveFeatures: String?
    var bodyType: String?
    var ageAppearance: String?

    // Artistic style attributes
    var artStyle: String
    var colorPalette: String?
    var lightingPreference: String?

    // Reference prompts
    var canonicalPrompt: String // The definitive prompt that worked for avatar
    var simplifiedPrompt: String // Simplified version for scene illustrations

    // Metadata
    var createdAt: Date
    var lastUpdated: Date
    var extractionMethod: String // "manual", "ai_extracted", "hybrid"

    // Relationship
    @Relationship var hero: Hero?

    init(canonicalPrompt: String, artStyle: String = "cartoon children's book illustration") {
        self.id = UUID()
        self.canonicalPrompt = canonicalPrompt
        self.simplifiedPrompt = canonicalPrompt // Will be refined
        self.artStyle = artStyle
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.extractionMethod = "manual"
    }

    /// Generate a consistent character description for scene illustrations
    func generateSceneCharacterDescription(heroName: String) -> String {
        var description = "\(heroName)"

        // Build appearance details
        var appearanceDetails: [String] = []

        if let ageAppearance = ageAppearance {
            appearanceDetails.append(ageAppearance)
        }

        if let skinTone = skinTone {
            appearanceDetails.append("\(skinTone) skin")
        }

        if let hairStyle = hairStyle, let hairColor = hairColor {
            appearanceDetails.append("\(hairColor) \(hairStyle)")
        }

        if let eyeColor = eyeColor {
            appearanceDetails.append("\(eyeColor) eyes")
        }

        if !appearanceDetails.isEmpty {
            description += " (a character with \(appearanceDetails.joined(separator: ", ")))"
        }

        // Add clothing if specified
        if let clothingStyle = clothingStyle {
            description += " wearing \(clothingStyle)"
            if let clothingColors = clothingColors {
                description += " in \(clothingColors)"
            }
        }

        // Add distinctive features
        if let distinctiveFeatures = distinctiveFeatures {
            description += ", \(distinctiveFeatures)"
        }

        return description
    }

    /// Create a style consistency prompt segment
    func generateStyleConsistencyPrompt() -> String {
        return """
        Art style: \(artStyle). \
        \(colorPalette ?? "Bright, cheerful colors"). \
        \(lightingPreference ?? "Warm, soft lighting").
        """
    }
}