//
//  CustomEventAIAssistant.swift
//  InfiniteStories
//
//  Created on 2025-09-14.
//

import Foundation
import SwiftUI

class CustomEventAIAssistant: ObservableObject {
    private let aiService: AIServiceProtocol
    private let language: String
    private let appSettings = AppSettings()
    
    @Published var isProcessing = false
    @Published var suggestions: [String] = []
    @Published var lastError: String?
    
    init() {
        // Initialize with the AI service through factory
        self.aiService = AIServiceFactory.createAIService()
        self.language = appSettings.preferredLanguage
    }
    
    // MARK: - Title Generation
    
    func generateTitle(from description: String) async -> String? {
        guard !description.isEmpty else { return nil }
        
        await MainActor.run {
            isProcessing = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        let prompt = buildTitlePrompt(description: description)
        
        do {
            // Use the AI service to generate a title
            let response = try await callOpenAI(prompt: prompt, maxTokens: 20)
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            await MainActor.run {
                lastError = "Failed to generate title: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Prompt Enhancement
    
    func enhancePromptSeed(
        title: String,
        description: String,
        category: EventCategory,
        ageRange: AgeRange,
        tone: StoryTone
    ) async -> String {
        await MainActor.run {
            isProcessing = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        let prompt = buildEnhancementPrompt(
            title: title,
            description: description,
            category: category,
            ageRange: ageRange,
            tone: tone
        )
        
        do {
            let response = try await callOpenAI(prompt: prompt, maxTokens: 150)
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            await MainActor.run {
                lastError = "Failed to enhance prompt: \(error.localizedDescription)"
            }
            // Return the original description as fallback
            return description
        }
    }
    
    // MARK: - Keyword Generation
    
    func generateKeywords(for event: String, description: String) async -> [String] {
        await MainActor.run {
            isProcessing = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        let prompt = buildKeywordsPrompt(event: event, description: description)
        
        do {
            let response = try await callOpenAI(prompt: prompt, maxTokens: 50)
            let keywords = response
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(8)
                .map { String($0) }
            
            return Array(keywords)
        } catch {
            await MainActor.run {
                lastError = "Failed to generate keywords: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    // MARK: - Similar Events Suggestion
    
    func suggestSimilarEvents(to description: String) async -> [String] {
        await MainActor.run {
            isProcessing = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        let prompt = buildSimilarEventsPrompt(description: description)
        
        do {
            let response = try await callOpenAI(prompt: prompt, maxTokens: 60)
            let suggestions = response
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
                .map { String($0) }
            
            return Array(suggestions)
        } catch {
            await MainActor.run {
                lastError = "Failed to suggest events: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func callOpenAI(prompt: String, maxTokens: Int) async throws -> String {
        // TODO: This should be refactored to use the AI service protocol
        // For now, returning a placeholder since direct OpenAI calls are removed
        throw AIServiceError.apiError("Direct OpenAI calls have been removed. Please use Supabase Edge Functions.")
    }
    
    private func getSystemPrompt() -> String {
        let languageInstruction = language != "en" ? 
            "Always respond in \(language)." : 
            "Respond in English."
        
        return """
        You are a creative assistant helping parents create custom story events for their children's bedtime stories.
        Your responses should be child-appropriate, imaginative, and suitable for bedtime.
        \(languageInstruction)
        Be concise and creative.
        """
    }
    
    // MARK: - Prompt Builders
    
    private func buildTitlePrompt(description: String) -> String {
        return """
        Based on this story event description, generate a creative and child-friendly title.
        The title should be 3-5 words maximum and capture the essence of the event.
        
        Description: \(description)
        
        Return only the title, nothing else.
        """
    }
    
    private func buildEnhancementPrompt(
        title: String,
        description: String,
        category: EventCategory,
        ageRange: AgeRange,
        tone: StoryTone
    ) -> String {
        return """
        Create an enhanced story prompt seed for children's bedtime stories.
        
        Event Title: \(title)
        Description: \(description)
        Category: \(category.rawValue)
        Age Range: \(ageRange.rawValue)
        Tone: \(tone.rawValue)
        
        Generate a one-sentence prompt seed that:
        1. Captures the essence of the event
        2. Is appropriate for \(ageRange.rawValue)
        3. Matches the \(tone.rawValue) tone
        4. Sparks imagination and wonder
        5. Is suitable for bedtime stories
        6. Includes elements that would appeal to children
        
        The prompt should guide the story generation to create engaging, age-appropriate content.
        
        Return only the prompt seed sentence, nothing else.
        """
    }
    
    private func buildKeywordsPrompt(event: String, description: String) -> String {
        return """
        Generate 5-8 keywords for this children's story event.
        
        Event: \(event)
        Description: \(description)
        
        Keywords should be:
        - Child-appropriate
        - Story-relevant
        - Imaginative and fun
        - Varied (mix of emotions, actions, objects, themes)
        - Single words or short phrases
        
        Return keywords as comma-separated values.
        """
    }
    
    private func buildSimilarEventsPrompt(description: String) -> String {
        return """
        Based on this story event description, suggest 3 similar but different event ideas.
        
        Description: \(description)
        
        Each suggestion should be:
        - A brief title (3-5 words)
        - Different but related to the original
        - Child-appropriate
        - Suitable for bedtime stories
        
        Format your response as: Title1|Title2|Title3
        """
    }
}

// MARK: - Error Types

enum CustomEventAIError: LocalizedError {
    case apiKeyMissing
    case networkError(String)
    case parsingError
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key is not configured"
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError:
            return "Failed to parse AI response"
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}