//
//  AvatarPromptAssistant.swift
//  InfiniteStories
//
//  AI-powered assistant for generating optimal avatar prompts
//

import Foundation

struct AvatarPromptSuggestion {
    let prompt: String
    let description: String
    let style: AvatarStyle
}

enum AvatarStyle: String, CaseIterable {
    case cartoonKids = "cartoon children's book illustration"
    case watercolor = "soft watercolor painting"
    case digitalArt = "digital character art"
    case pixar = "3D Pixar-style animation"
    case storybook = "classic storybook illustration"

    var description: String {
        switch self {
        case .cartoonKids:
            return "Cartoon style perfect for children's books"
        case .watercolor:
            return "Gentle watercolor with soft edges"
        case .digitalArt:
            return "Clean digital character art"
        case .pixar:
            return "3D animated character style"
        case .storybook:
            return "Classic illustrated storybook style"
        }
    }
}

class AvatarPromptAssistant {

    static func generatePrompt(for hero: Hero, style: AvatarStyle = .cartoonKids, customElements: String = "") -> String {
        var prompt = buildBasePrompt(for: hero, style: style)

        if !customElements.isEmpty {
            prompt += ", \(customElements)"
        }

        prompt += ", \(getQualityAndSafetyModifiers())"

        return prompt
    }

    static func getSuggestedPrompts(for hero: Hero) -> [AvatarPromptSuggestion] {
        return AvatarStyle.allCases.map { style in
            AvatarPromptSuggestion(
                prompt: generatePrompt(for: hero, style: style),
                description: style.description,
                style: style
            )
        }
    }

    static func enhanceUserPrompt(_ userPrompt: String, for hero: Hero) -> String {
        var enhancedPrompt = userPrompt

        // Add hero context if not present
        if !userPrompt.lowercased().contains(hero.name.lowercased()) {
            enhancedPrompt = "A character named \(hero.name), \(enhancedPrompt)"
        }

        // Add traits if not detailed enough
        if userPrompt.split(separator: " ").count < 10 {
            let traits = "who is \(hero.primaryTrait.rawValue.lowercased()) and \(hero.secondaryTrait.rawValue.lowercased())"
            enhancedPrompt += ", \(traits)"

            if !hero.appearance.isEmpty {
                enhancedPrompt += ", with \(hero.appearance)"
            }
        }

        // Ensure child-friendly style
        if !userPrompt.lowercased().contains("children") &&
           !userPrompt.lowercased().contains("cartoon") &&
           !userPrompt.lowercased().contains("illustration") {
            enhancedPrompt += ", in a child-friendly cartoon illustration style"
        }

        enhancedPrompt += ", \(getQualityAndSafetyModifiers())"

        return enhancedPrompt
    }

    private static func buildBasePrompt(for hero: Hero, style: AvatarStyle) -> String {
        var prompt = "A \(style.rawValue) of \(hero.name)"

        // Add character traits
        prompt += ", a \(hero.primaryTrait.rawValue.lowercased()) and \(hero.secondaryTrait.rawValue.lowercased()) character"

        // Add appearance details
        if !hero.appearance.isEmpty {
            prompt += ", \(hero.appearance)"
        } else {
            prompt += ", with a warm and friendly appearance"
        }

        // Add special ability if present
        if !hero.specialAbility.isEmpty {
            prompt += ", known for their ability to \(hero.specialAbility)"
        }

        // Add style-specific elements
        switch style {
        case .cartoonKids:
            prompt += ", with big expressive eyes and a cheerful smile"
        case .watercolor:
            prompt += ", painted with soft brushstrokes and gentle colors"
        case .digitalArt:
            prompt += ", with clean lines and vibrant colors"
        case .pixar:
            prompt += ", with rounded features and expressive facial animation"
        case .storybook:
            prompt += ", with classic illustrated book charm"
        }

        return prompt
    }

    private static func getQualityAndSafetyModifiers() -> String {
        return "high quality, child-friendly, safe for children, appropriate for bedtime stories, wholesome, innocent, magical, fantasy character portrait, no scary or dark elements, bright and cheerful, professional children's book illustration"
    }

    static func getRandomPromptIdeas() -> [String] {
        return [
            "wearing a magical cape that sparkles in the moonlight",
            "holding a glowing crystal that represents their inner strength",
            "surrounded by friendly forest creatures",
            "standing in a magical garden filled with rainbow flowers",
            "wearing a crown made of stars and clouds",
            "with a loyal pet companion by their side",
            "reading a book that glows with magical words",
            "painting with brushes that create real magic",
            "flying on a cloud through a sunset sky",
            "discovering a hidden treasure in an enchanted cave"
        ]
    }
}