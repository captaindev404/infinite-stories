//
//  SupabaseConfig.swift
//  InfiniteStories
//
//  Supabase configuration for different environments
//

import Foundation

struct SupabaseConfig {
    static var current: SupabaseConfig {
        #if DEBUG
        return development
        #else
        return production
        #endif
    }

    let url: String
    let anonKey: String
    let serviceRoleKey: String?

    // MARK: - Development Configuration (Local)
    static let development = SupabaseConfig(
        url: "http://127.0.0.1:54321",
        anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0",
        serviceRoleKey: nil // Not needed for client
    )

    // MARK: - Production Configuration
    static let production = SupabaseConfig(
        url: "https://your-project-ref.supabase.co",
        anonKey: "your-production-anon-key",
        serviceRoleKey: nil
    )

    // MARK: - Staging Configuration (Optional)
    static let staging = SupabaseConfig(
        url: "https://your-staging-ref.supabase.co",
        anonKey: "your-staging-anon-key",
        serviceRoleKey: nil
    )
}

// MARK: - Environment Detection Helper
extension SupabaseConfig {
    static var isLocalDevelopment: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["USE_LOCAL_SUPABASE"] == "true" ||
               current.url.contains("127.0.0.1") ||
               current.url.contains("localhost")
        #else
        return false
        #endif
    }

    static func configure(for environment: String) -> SupabaseConfig {
        switch environment.lowercased() {
        case "local", "development":
            return development
        case "staging":
            return staging
        case "production":
            return production
        default:
            return current
        }
    }
}