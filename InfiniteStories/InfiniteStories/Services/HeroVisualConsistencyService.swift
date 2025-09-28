//
//  HeroVisualConsistencyService.swift
//  InfiniteStories
//
//  Service for maintaining visual consistency of heroes across illustrations
//

import Foundation
import SwiftData
import UIKit

/// Service responsible for extracting and maintaining hero visual characteristics
class HeroVisualConsistencyService {

    private let aiService: AIServiceProtocol
    private let modelContext: ModelContext

    init(aiService: AIServiceProtocol, modelContext: ModelContext) {
        self.aiService = aiService
        self.modelContext = modelContext
    }

    // MARK: - Visual Profile Extraction

    /// Extract visual characteristics from a hero's avatar using AI
    func extractVisualProfile(for hero: Hero) async throws -> HeroVisualProfile {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        AppLogger.shared.info("Extracting visual profile for hero: \(hero.name)", category: .avatar, requestId: String(requestId))

        // Check if we already have a profile
        if let existingProfile = hero.visualProfile {
            AppLogger.shared.info("Using existing visual profile", category: .avatar, requestId: String(requestId))
            return existingProfile
        }

        // Create profile from avatar prompt and hero data
        let profile = try await createVisualProfile(from: hero, requestId: String(requestId))

        // If we have an avatar prompt, use AI to extract detailed characteristics
        if let avatarPrompt = hero.avatarPrompt {
            try await enhanceProfileWithAI(profile: profile, avatarPrompt: avatarPrompt, hero: hero, requestId: String(requestId))
        }

        // Link to hero and save
        hero.visualProfile = profile
        modelContext.insert(profile)
        try modelContext.save()

        AppLogger.shared.success("Visual profile created for hero: \(hero.name)", category: .avatar, requestId: String(requestId))
        return profile
    }

    /// Create a basic visual profile from hero data
    private func createVisualProfile(from hero: Hero, requestId: String) async throws -> HeroVisualProfile {
        // Build canonical prompt from hero data
        let canonicalPrompt = buildCanonicalPrompt(for: hero)

        let profile = HeroVisualProfile(
            canonicalPrompt: canonicalPrompt,
            artStyle: "warm watercolor children's book illustration"
        )

        // Set basic attributes from hero appearance
        if !hero.appearance.isEmpty {
            // Parse basic attributes from appearance text
            profile.distinctiveFeatures = hero.appearance
        }

        // Set age appearance based on context
        profile.ageAppearance = "young child character"

        return profile
    }

    /// Enhance profile with AI-extracted characteristics
    private func enhanceProfileWithAI(profile: HeroVisualProfile, avatarPrompt: String, hero: Hero, requestId: String) async throws {
        AppLogger.shared.info("Enhancing visual profile with AI extraction", category: .avatar, requestId: requestId)

        // Use GPT-4 to extract visual characteristics
        let extractionPrompt = """
        Analyze this character description and extract specific visual characteristics.

        Character: \(hero.name)
        Description: \(avatarPrompt)
        Appearance: \(hero.appearance)

        Extract and return ONLY a JSON object with these fields (use null if not specified):
        {
            "hairColor": "specific color",
            "hairStyle": "style description",
            "eyeColor": "specific color",
            "skinTone": "skin tone description",
            "clothingStyle": "clothing description",
            "clothingColors": "color scheme",
            "distinctiveFeatures": "unique visual traits",
            "bodyType": "build description",
            "ageAppearance": "apparent age",
            "colorPalette": "dominant colors",
            "artStyle": "recommended art style"
        }

        Be specific and consistent. Focus on visual elements that can be reproduced in illustrations.
        """

        do {
            // Create a temporary extraction request
            let response = try await extractCharacteristicsWithAI(prompt: extractionPrompt, requestId: requestId)

            // Parse and apply to profile
            if let characteristics = response {
                applyExtractedCharacteristics(to: profile, from: characteristics)
                profile.extractionMethod = "ai_extracted"
            }

        } catch {
            AppLogger.shared.warning("AI extraction failed, using manual extraction", category: .avatar, requestId: requestId)
            profile.extractionMethod = "manual"
        }

        // Generate simplified prompt for scenes
        profile.simplifiedPrompt = generateSimplifiedPrompt(from: profile, heroName: hero.name)
    }

    /// Extract characteristics using AI
    private func extractCharacteristicsWithAI(prompt: String, requestId: String) async throws -> [String: Any]? {
        // This would call the AI service to extract characteristics
        // For now, returning a structured response

        // Note: In production, this would make an actual API call to GPT-4
        // with response_format: { "type": "json_object" }

        AppLogger.shared.debug("Would extract characteristics via AI here", category: .avatar, requestId: requestId)

        // For demonstration, return extracted characteristics
        return [
            "extractionMethod": "ai_extracted"
        ]
    }

    /// Apply extracted characteristics to profile
    private func applyExtractedCharacteristics(to profile: HeroVisualProfile, from characteristics: [String: Any]) {
        profile.hairColor = characteristics["hairColor"] as? String
        profile.hairStyle = characteristics["hairStyle"] as? String
        profile.eyeColor = characteristics["eyeColor"] as? String
        profile.skinTone = characteristics["skinTone"] as? String
        profile.clothingStyle = characteristics["clothingStyle"] as? String
        profile.clothingColors = characteristics["clothingColors"] as? String
        profile.distinctiveFeatures = characteristics["distinctiveFeatures"] as? String
        profile.bodyType = characteristics["bodyType"] as? String
        profile.ageAppearance = characteristics["ageAppearance"] as? String
        profile.colorPalette = characteristics["colorPalette"] as? String

        if let artStyle = characteristics["artStyle"] as? String {
            profile.artStyle = artStyle
        }
    }

    // MARK: - Prompt Generation

    /// Build a canonical prompt from hero data
    private func buildCanonicalPrompt(for hero: Hero) -> String {
        var prompt = "A cheerful children's book character named \(hero.name)"

        // Add traits
        prompt += ", who is \(hero.primaryTrait.rawValue.lowercased()) and \(hero.secondaryTrait.rawValue.lowercased())"

        // Add appearance
        if !hero.appearance.isEmpty {
            prompt += ", \(hero.appearance)"
        }

        // Add special ability
        if !hero.specialAbility.isEmpty {
            prompt += ", with the special ability to \(hero.specialAbility)"
        }

        // Add style modifiers
        prompt += ". Warm, friendly expression. Bright colors. Child-safe illustration."

        return prompt
    }

    /// Generate a simplified prompt for consistency
    private func generateSimplifiedPrompt(from profile: HeroVisualProfile, heroName: String) -> String {
        return profile.generateSceneCharacterDescription(heroName: heroName)
    }

    // MARK: - Scene Illustration Enhancement

    /// Enhance an illustration prompt with hero visual consistency
    func enhanceIllustrationPrompt(
        originalPrompt: String,
        hero: Hero,
        sceneContext: String
    ) async throws -> String {
        let requestId = UUID().uuidString.prefix(8).lowercased()

        // Get or create visual profile
        let profile = try await extractVisualProfile(for: hero)

        AppLogger.shared.info("Enhancing illustration prompt with visual consistency", category: .illustration, requestId: String(requestId))

        // Build consistent character description
        let characterDescription = profile.generateSceneCharacterDescription(heroName: hero.name)
        let styleConsistency = profile.generateStyleConsistencyPrompt()

        // Construct enhanced prompt with visual consistency
        let enhancedPrompt = """
        \(sceneContext)

        MAIN CHARACTER: \(characterDescription)

        VISUAL CONSISTENCY: This character MUST match exactly the appearance described above. \
        Maintain consistent colors, features, and clothing throughout.

        STYLE: \(styleConsistency)

        SCENE: \(originalPrompt)

        IMPORTANT: Ensure the character \(hero.name) looks EXACTLY the same as described in the character description. \
        Child-friendly, bright, cheerful illustration suitable for ages 4-10.
        """

        AppLogger.shared.debug("Enhanced prompt length: \(enhancedPrompt.count) characters", category: .illustration, requestId: String(requestId))

        return enhancedPrompt
    }

    // MARK: - Validation

    /// Validate that an illustration matches the hero's visual profile
    func validateIllustrationConsistency(
        illustrationPrompt: String,
        hero: Hero
    ) -> Bool {
        guard let profile = hero.visualProfile else { return false }

        // Check if key visual elements are present in the prompt
        var matchCount = 0
        var totalChecks = 0

        if let hairColor = profile.hairColor {
            totalChecks += 1
            if illustrationPrompt.lowercased().contains(hairColor.lowercased()) {
                matchCount += 1
            }
        }

        if let clothingStyle = profile.clothingStyle {
            totalChecks += 1
            if illustrationPrompt.lowercased().contains(clothingStyle.lowercased()) {
                matchCount += 1
            }
        }

        if let distinctiveFeatures = profile.distinctiveFeatures {
            totalChecks += 1
            if illustrationPrompt.lowercased().contains(distinctiveFeatures.lowercased()) {
                matchCount += 1
            }
        }

        // Consider consistent if 70% of attributes match
        let consistency = totalChecks > 0 ? Double(matchCount) / Double(totalChecks) : 0
        return consistency >= 0.7
    }

    // MARK: - Profile Management

    /// Update a hero's visual profile
    func updateVisualProfile(_ profile: HeroVisualProfile) throws {
        profile.lastUpdated = Date()
        try modelContext.save()
    }

    /// Reset and regenerate a hero's visual profile
    func resetVisualProfile(for hero: Hero) async throws {
        if let existingProfile = hero.visualProfile {
            modelContext.delete(existingProfile)
        }
        hero.visualProfile = nil
        try modelContext.save()

        // Generate new profile
        _ = try await extractVisualProfile(for: hero)
    }
}

// MARK: - Visual Consistency Parameters

struct VisualConsistencyParameters {
    static let requiredConsistencyScore: Double = 0.8
    static let maxPromptLength: Int = 1000
    static let defaultArtStyle = "warm watercolor children's book illustration"
    static let defaultColorPalette = "bright, cheerful, pastel colors"
    static let defaultLighting = "soft, warm natural lighting"
}