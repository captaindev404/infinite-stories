//
//  AppConfiguration.swift
//  InfiniteStories
//
//  Configuration to switch between original and improved UI
//

import Foundation

struct AppConfiguration {
    // MARK: - UI Configuration
    
    /// Set to true to use the enhanced magical UI, false for the original simple UI
    static let useImprovedUI = true
    
    /// Enable or disable floating animations (clouds, stars) for performance
    static let enableFloatingAnimations = true
    
    /// Maximum number of recent stories to show on home screen
    static let maxRecentStories = 3
    
    /// Animation durations (in seconds)
    struct AnimationDurations {
        static let heroAnimation: Double = 2.0
        static let sparkleAnimation: Double = 1.5
        static let cloudMovement: Double = 20.0
        static let starRotation: Double = 30.0
        static let buttonPress: Double = 0.3
    }
    
    /// Performance settings
    struct Performance {
        /// Minimum processor count to enable all visual effects
        static let minProcessorCountForEffects = 4
        
        /// Reduce animation complexity on older devices
        static let adaptivePerformance = true
        
        /// Maximum floating elements to render
        static let maxFloatingElements = 10
    }
    
    // MARK: - Feature Flags

    /// Enable pull-to-refresh on the home screen
    static let enablePullToRefresh = true

    /// Show stats dashboard on home screen
    static let showStatsDashboard = true

    /// Enable haptic feedback for buttons
    static let enableHapticFeedback = true

    /// Enable story illustration generation
    /// Set to false to defer illustration feature to V2
    /// Note: Avatar generation remains enabled
    static let enableStoryIllustrations = false
    
    // MARK: - Theme Settings
    
    /// Default theme preference for new users
    static let defaultThemePreference = "system"
    
    /// Enable smooth theme transition animations
    static let enableThemeTransitions = true
    
    // MARK: - Backend Configuration

    /// Backend API base URL
    /// - Simulator (Debug): localhost for local development
    /// - Device (Debug): dev server for testing on real devices
    /// - Beta (TestFlight): staging server for beta testing
    /// - Release (App Store): production server
    #if DEBUG
        #if targetEnvironment(simulator)
        static let backendBaseURL = "http://localhost:3001"
        #else
        static let backendBaseURL = "https://infinite-stories-web-dev.captaindev.io"
        #endif
    #elseif TESTFLIGHT
    static let backendBaseURL = "https://infinite-stories-web-staging.captaindev.io"
    #else
    static let backendBaseURL = "https://infinite-stories-web.captaindev.io"
    #endif

    // MARK: - Debug Settings

    #if DEBUG
    /// Print detailed logs for debugging
    static let verboseLogging = true
    #else
    static let verboseLogging = false
    #endif
}