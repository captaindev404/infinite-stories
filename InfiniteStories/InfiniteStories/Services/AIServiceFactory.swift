//
//  AIServiceFactory.swift
//  InfiniteStories
//
//  Factory pattern for creating AI Service implementations
//

import Foundation

/// Factory for creating the AI Service implementation
final class AIServiceFactory {

    /// Feature flag for Firebase migration
    /// Set to true to use Firebase Cloud Functions, false for Supabase Edge Functions
    /// Can be configured via UserDefaults for gradual rollout
    static var useFirebaseBackend: Bool {
        // Check UserDefaults for feature flag, default to false for backward compatibility
        UserDefaults.standard.bool(forKey: "useFirebaseBackend")
    }

    /// Enable Firebase backend for testing
    static func enableFirebaseBackend(_ enable: Bool) {
        UserDefaults.standard.set(enable, forKey: "useFirebaseBackend")
        print("🔄 AI Service backend switched to: \(enable ? "Firebase" : "Supabase")")
    }

    /// Create the AI Service based on feature flag
    static func createAIService() -> AIServiceProtocol {
        if useFirebaseBackend {
            // Use Firebase Cloud Functions
            print("🔥 Using Firebase Cloud Functions for AI operations")
            return FirebaseAIService()
        } else {
            // Use Supabase Edge Functions (default for backward compatibility)
            print("⚡ Using Supabase Edge Functions for AI operations")
            return SupabaseAIService()
        }
    }

    /// Get the current service name for display
    static var currentServiceName: String {
        return useFirebaseBackend ? "Firebase Cloud Functions" : "Supabase Edge Functions"
    }

    /// Check if the service is properly configured
    static func isServiceConfigured() -> Bool {
        if useFirebaseBackend {
            // Firebase is configured in InfiniteStoriesApp init
            return true
        } else {
            // Supabase is configured in SupabaseService.shared
            return true
        }
    }

    /// Get migration status for debugging
    static var migrationStatus: String {
        let backend = useFirebaseBackend ? "Firebase" : "Supabase"
        return "Currently using: \(backend) backend"
    }
}