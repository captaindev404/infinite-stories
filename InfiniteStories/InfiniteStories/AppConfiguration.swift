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
    
    // MARK: - Theme Settings
    
    /// Default theme preference for new users
    static let defaultThemePreference = "system"
    
    /// Enable smooth theme transition animations
    static let enableThemeTransitions = true
    
    // MARK: - Debug Settings
    
    #if DEBUG
    /// Print detailed logs for debugging
    static let verboseLogging = true
    #else
    static let verboseLogging = false
    #endif
}