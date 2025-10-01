//
//  AIServiceFactory.swift
//  InfiniteStories
//
//  Factory pattern for creating AI Service implementations
//

import Foundation

/// Factory for creating the AI Service implementation
final class AIServiceFactory {

    /// Create the AI Service - always returns SupabaseAIService
    static func createAIService() -> AIServiceProtocol {
        // Always use Supabase Edge Functions for all AI operations
        return SupabaseAIService()
    }

    /// Get the current service name for display
    static var currentServiceName: String {
        return "Supabase Edge Functions"
    }

    /// Check if the service is properly configured
    static func isServiceConfigured() -> Bool {
        // Supabase is configured in SupabaseService.shared
        return true
    }
}