//
//  ContentPolicyFilter.swift
//  InfiniteStories
//
//  Created by Claude Code on 17/09/2025.
//

import Foundation

/// Result of prompt validation
struct ValidationResult {
    let isValid: Bool
    let riskLevel: RiskLevel
    let problematicTerms: [String]
    let recommendations: [String]
}

/// Risk level for content validation
enum RiskLevel {
    case low
    case medium
    case high

    var description: String {
        switch self {
        case .low: return "Safe for DALL-E API"
        case .medium: return "Requires filtering before API call"
        case .high: return "High risk - review prompt before proceeding"
        }
    }
}

/// Service for filtering DALL-E prompts to prevent content policy violations
class ContentPolicyFilter {

    /// Shared instance for consistent filtering across the app
    static let shared = ContentPolicyFilter()

    private init() {}

    /// Filter a DALL-E prompt to ensure it complies with OpenAI's content policy
    /// - Parameter prompt: The original prompt
    /// - Returns: A filtered version safe for DALL-E API
    func filterPrompt(_ prompt: String) -> String {
        var filteredPrompt = prompt
        var appliedReplacements: [String: String] = [:]

        // Apply phrase replacements FIRST for context-aware filtering
        for (problematicPhrase, replacementPhrase) in phraseReplacements {
            let originalPrompt = filteredPrompt
            filteredPrompt = filteredPrompt.replacingOccurrences(
                of: problematicPhrase,
                with: replacementPhrase,
                options: .caseInsensitive
            )
            if originalPrompt != filteredPrompt {
                appliedReplacements[problematicPhrase] = replacementPhrase
            }
        }

        // Apply term replacements
        for (problematic, replacement) in termReplacements {
            // Case-insensitive replacement with word boundaries
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: problematic))\\b"

            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(filteredPrompt.startIndex..., in: filteredPrompt)
                let originalPrompt = filteredPrompt
                filteredPrompt = regex.stringByReplacingMatches(
                    in: filteredPrompt,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
                if originalPrompt != filteredPrompt {
                    appliedReplacements[problematic] = replacement
                }
            } catch {
                // Fallback to simple string replacement if regex fails
                let originalPrompt = filteredPrompt
                filteredPrompt = filteredPrompt.replacingOccurrences(
                    of: problematic,
                    with: replacement,
                    options: .caseInsensitive
                )
                if originalPrompt != filteredPrompt {
                    appliedReplacements[problematic] = replacement
                }
            }
        }

        // Additional safety checks and cleanup
        filteredPrompt = applySafetyCleanup(filteredPrompt)

        // Log detailed replacement information for debugging
        if !appliedReplacements.isEmpty {
            logDetailedReplacements(appliedReplacements)
        }

        return filteredPrompt
    }

    /// Check if a prompt contains potentially problematic content
    /// - Parameter prompt: The prompt to check
    /// - Returns: Array of problematic terms found
    func detectProblematicContent(_ prompt: String) -> [String] {
        let lowercasedPrompt = prompt.lowercased()
        var foundTerms: [String] = []

        // Check phrases first (more specific)
        for (problematicPhrase, _) in phraseReplacements {
            if lowercasedPrompt.contains(problematicPhrase.lowercased()) {
                foundTerms.append(problematicPhrase)
            }
        }

        // Check individual terms
        for (problematic, _) in termReplacements {
            if lowercasedPrompt.contains(problematic.lowercased()) {
                foundTerms.append(problematic)
            }
        }

        return foundTerms
    }

    /// Pre-validate a prompt before sending to DALL-E API
    /// - Parameter prompt: The prompt to validate
    /// - Returns: ValidationResult indicating safety level
    func preValidatePrompt(_ prompt: String) -> ValidationResult {
        let problematicContent = detectProblematicContent(prompt)
        let criticalTerms = getCriticalTerms()

        // Check for critical violations that should block API calls
        let criticalViolations = problematicContent.filter { term in
            criticalTerms.contains { critical in
                term.lowercased().contains(critical.lowercased())
            }
        }

        if !criticalViolations.isEmpty {
            return ValidationResult(
                isValid: false,
                riskLevel: .high,
                problematicTerms: criticalViolations,
                recommendations: generateRecommendations(for: criticalViolations)
            )
        }

        if !problematicContent.isEmpty {
            return ValidationResult(
                isValid: true,
                riskLevel: .medium,
                problematicTerms: problematicContent,
                recommendations: ["Content will be automatically filtered before API call"]
            )
        }

        return ValidationResult(
            isValid: true,
            riskLevel: .low,
            problematicTerms: [],
            recommendations: []
        )
    }

    // MARK: - Private Methods

    /// Apply additional safety cleanup to the prompt
    private func applySafetyCleanup(_ prompt: String) -> String {
        var cleaned = prompt

        // Remove any remaining potentially harmful patterns
        let harmfulPatterns = [
            "\\b(kill|murder|death|die|dead)\\b",
            "\\b(violence|violent|attack|fight)\\b",
            "\\b(blood|gore|scary|terrifying)\\b",
            "\\b(weapon|gun|sword|knife|bomb)\\b"
        ]

        for pattern in harmfulPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: range,
                    withTemplate: "magical"
                )
            } catch {
                // Continue if regex fails
                continue
            }
        }

        // Ensure child-friendly language
        cleaned = ensureChildFriendlyLanguage(cleaned)

        return cleaned
    }

    /// Ensure the language remains child-friendly
    private func ensureChildFriendlyLanguage(_ prompt: String) -> String {
        var childFriendly = prompt

        // Add positive qualifiers if the prompt seems too neutral
        if !childFriendly.contains("magical") && !childFriendly.contains("wonderful") && !childFriendly.contains("beautiful") {
            childFriendly = "A wonderful, magical scene: " + childFriendly
        }

        // Ensure peaceful tone (Fixed: consistent with termReplacements)
        childFriendly = childFriendly.replacingOccurrences(of: "dark ", with: "bright ")
        childFriendly = childFriendly.replacingOccurrences(of: "dangerous", with: "adventurous")
        // Note: "scary" is already handled in termReplacements, removed to avoid double replacement

        return childFriendly
    }

    // MARK: - Term Replacement Maps

    /// Map of problematic terms to safe alternatives
    private let termReplacements: [String: String] = [
        // Technology/Hacking terms
        "hack": "program",
        "hacks": "programs",
        "hacking": "programming",
        "hacker": "programmer",
        "exploit": "discover",
        "breach": "explore",
        "crack": "solve",
        "virus": "helpful program",
        "malware": "computer helper",

        // Violence/Weapons
        "weapon": "magical tool",
        "sword": "magical wand",
        "gun": "magic pointer",
        "knife": "magic cutter",
        "bomb": "surprise package",
        "explosion": "magical burst of light",
        "attack": "approach",
        "fight": "play",
        "battle": "adventure",
        "war": "big adventure",
        "kill": "help",
        "murder": "surprise",
        "death": "sleep",
        "die": "rest",
        "dead": "sleeping",

        // Scary/Negative terms (Fixed: consistent positive replacements)
        "scary": "magical",
        "terrifying": "amazing",
        "horrible": "wonderful",
        "terrible": "challenging",
        "awful": "difficult",
        "nightmare": "dream",
        "monster": "friendly creature",
        "demon": "magical being",
        "ghost": "friendly spirit",
        "zombie": "sleepy friend",
        "mysterious": "magical",

        // Isolation/Loneliness terms (Critical for child safety)
        "alone": "with friends",
        "lonely": "seeking friends",
        "isolated": "exploring",
        "abandoned": "discovering",
        "solitary": "independent",
        "by himself": "on an adventure",
        "by herself": "on an adventure",
        "all by": "happily",
        "left alone": "exploring freely",
        "on his own": "independently",
        "on her own": "independently",

        // French isolation terms
        "seul": "avec des amis",
        "seule": "avec des amis",
        "isolé": "en exploration",
        "isolée": "en exploration",
        "abandonné": "en découverte",
        "abandonnée": "en découverte",
        "solitaire": "indépendant",
        "tout seul": "en aventure",
        "toute seule": "en aventure",

        // Spanish isolation terms
        "aislado": "explorando",
        "aislada": "explorando",
        "abandonado": "descubriendo",
        "abandonada": "descubriendo",

        // German isolation terms
        "allein": "mit Freunden",
        "einsam": "Freunde suchend",
        "isoliert": "erkundend",
        "verlassen": "entdeckend",

        // Italian isolation terms
        "isolato": "esplorando",
        "isolata": "esplorando",
        "abbandonato": "scoprendo",
        "abbandonata": "scoprendo",

        // Inappropriate content
        "steal": "borrow",
        "rob": "ask for",
        "thief": "borrower",
        "criminal": "mischievous character",
        "prison": "timeout place",
        "jail": "thinking room",

        // Dark themes
        "darkness": "gentle light",
        "shadow": "gentle shade",
        "evil": "mischievous",
        "wicked": "playful",
        "curse": "magic spell",
        "poison": "bitter medicine",
        "danger": "adventure",
        "dangerous": "adventurous",

        // Destruction
        "destroy": "change",
        "demolish": "rebuild",
        "ruin": "redesign",
        "break": "fix creatively",
        "smash": "reshape",
        "crash": "land suddenly"
    ]

    /// Map of problematic phrases to safe alternatives
    private let phraseReplacements: [String: String] = [
        // Technology phrases
        "hack into": "connect with",
        "hack the system": "understand the computer",
        "break into": "visit",
        "steal data": "copy information",
        "cyber attack": "computer adventure",

        // Violence phrases
        "fight scene": "play scene",
        "battle scene": "adventure scene",
        "weapon in hand": "magical tool in hand",
        "blood and gore": "colorful paint",
        "life or death": "very important",

        // Scary phrases (Fixed: consistent magical replacements)
        "dark and scary": "bright and magical",
        "scary and dark": "magical and bright",
        "terrifying monster": "amazing creature",
        "haunted house": "magical house",
        "graveyard scene": "peaceful garden",
        "mysterious and gentle": "magical and wonderful",
        "dark mysterious": "bright magical",

        // Critical isolation phrases (Multi-language)
        // English
        "all alone": "with friends",
        "completely alone": "happily exploring",
        "left alone": "free to explore",
        "home alone": "at home with family",
        "alone in the": "exploring the",
        "alone at": "visiting",
        "by himself": "on an adventure",
        "by herself": "on an adventure",
        "all by himself": "independently",
        "all by herself": "independently",
        "feeling lonely": "seeking friends",
        "so lonely": "ready for friends",
        "very lonely": "wanting friendship",

        // French isolation phrases (Critical for DALL-E violations)
        "es-tu tout seul": "es-tu avec des amis",
        "est-tu tout seul": "est-tu avec des amis",
        "tout seul": "avec des amis",
        "toute seule": "avec des amis",
        "complètement seul": "en exploration heureuse",
        "complètement seule": "en exploration heureuse",
        "laissé seul": "libre d'explorer",
        "laissée seule": "libre d'explorer",
        "se sent seul": "cherche des amis",
        "se sent seule": "cherche des amis",
        "très seul": "prêt pour des amis",
        "très seule": "prête pour des amis",

        // Spanish isolation phrases
        "muy solo": "buscando amigos",
        "muy sola": "buscando amigos",
        "se siente solo": "busca amigos",
        "se siente sola": "busca amigos",
        "niño solo": "niño con amigos",
        "niña sola": "niña con amigos",

        // German isolation phrases
        "ganz allein": "mit Freunden",
        "völlig allein": "glücklich erkundend",
        "sehr einsam": "Freundschaft suchend",
        "fühlt sich einsam": "sucht Freunde",

        // Italian isolation phrases
        "completamente solo": "esplorando felicemente",
        "completamente sola": "esplorando felicemente",
        "molto solo": "cercando amici",
        "molto sola": "cercando amici",
        "si sente solo": "cerca amici",
        "si sente sola": "cerca amici",
        "bambino solo": "bambino con amici",
        "bambina sola": "bambina con amici",

        // Criminal phrases
        "bank robbery": "bank visit",
        "stealing treasure": "finding treasure",
        "criminal activity": "adventure activity",
        "illegal operation": "secret mission",

        // Adult-child interaction concerns
        "stranger danger": "meeting new friends",
        "unknown adult": "new friend",
        "adult stranger": "friendly person",
        "come with me": "let's explore together",
        "secret between us": "wonderful surprise",
        "don't tell anyone": "special adventure"
    ]
}

// MARK: - Extensions for Logging

extension ContentPolicyFilter {
    /// Log filtering activity for debugging
    func logFiltering(original: String, filtered: String, problematicTerms: [String]) {
        if original != filtered {
            print("🛡️ Content Filter Applied")
            print("🛡️ Problematic terms found: \(problematicTerms.joined(separator: ", "))")
            print("🛡️ Original length: \(original.count) -> Filtered length: \(filtered.count)")

            // Log significant changes
            if abs(original.count - filtered.count) > 20 {
                print("🛡️ Significant content changes applied")
            }
        }
    }

    /// Log detailed replacement information for debugging
    private func logDetailedReplacements(_ replacements: [String: String]) {
        print("🔍 Detailed Content Replacements:")
        for (original, replacement) in replacements {
            print("🔍   '\(original)' → '\(replacement)'")
        }
    }

    /// Get list of critical terms that should trigger high-risk validation
    private func getCriticalTerms() -> [String] {
        return [
            // Isolation terms (critical for child safety)
            "alone", "lonely", "seul", "seule", "tout seul", "toute seule",
            "es-tu tout seul", "est-tu tout seul", "all alone", "left alone",
            "by himself", "by herself", "isolated", "abandoned",

            // Adult-child interaction concerns
            "stranger", "secret between us", "don't tell anyone", "come with me",
            "unknown adult", "adult stranger",

            // Violence/weapons that DALL-E particularly flags
            "weapon", "gun", "knife", "sword", "kill", "murder", "death",
            "blood", "violence", "attack", "fight"
        ]
    }

    /// Generate recommendations for addressing critical violations
    private func generateRecommendations(for violations: [String]) -> [String] {
        var recommendations: [String] = []

        let isolationTerms = ["alone", "lonely", "seul", "seule", "tout seul", "toute seule"]
        let hasIsolationTerms = violations.contains { violation in
            isolationTerms.contains { isolation in
                violation.lowercased().contains(isolation.lowercased())
            }
        }

        if hasIsolationTerms {
            recommendations.append("Consider adding friends or companions to the scene")
            recommendations.append("Focus on group activities and social interactions")
        }

        let violenceTerms = ["weapon", "gun", "knife", "sword", "kill", "murder", "fight"]
        let hasViolenceTerms = violations.contains { violation in
            violenceTerms.contains { violence in
                violation.lowercased().contains(violence.lowercased())
            }
        }

        if hasViolenceTerms {
            recommendations.append("Replace violent elements with magical or playful alternatives")
            recommendations.append("Focus on adventure and problem-solving rather than conflict")
        }

        return recommendations
    }
}
