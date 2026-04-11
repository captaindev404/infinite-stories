//
//  InfiniteStoriesApp.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct InfiniteStoriesApp: App {
    @StateObject private var themeSettings = ThemeSettings.shared
    @StateObject private var authState = AuthStateManager()

    private func loadRocketSimConnect() {
        #if DEBUG
        guard (Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?.load() == true) else {
            print("Failed to load linker framework")
            return
        }
        print("RocketSim Connect successfully linked")
        #endif
    }
    
    init() {
        // Apply UI language override before views load
        LocalizationManager.shared.applyLanguageOverrideAtLaunch()

        loadRocketSimConnect()
        // Register background tasks when app launches
        BackgroundTaskManager.shared.registerBackgroundTasks()

        // Configure URLCache for automatic media caching (avatars, audio, illustrations)
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50 MB memory cache
            diskCapacity: 200 * 1024 * 1024,     // 200 MB disk cache
            directory: nil  // Use default cache directory
        )
        URLCache.shared = cache

        // Initialize illustration failure handling defaults
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "allowIllustrationFailures") == nil {
            defaults.set(true, forKey: "allowIllustrationFailures")
        }
        if defaults.object(forKey: "showIllustrationErrors") == nil {
            defaults.set(false, forKey: "showIllustrationErrors")
        }
        if defaults.object(forKey: "maxIllustrationRetries") == nil {
            defaults.set(3, forKey: "maxIllustrationRetries")
        }
    }
    
    var sharedModelContainer: ModelContainer = {
        // Minimal SwiftData schema - only for temporary state
        // Heroes, Stories, CustomStoryEvents, and HeroVisualProfiles are fetched from API, not persisted locally
        let schema = Schema([
            StoryIllustration.self        // Temporary local references (can be rebuilt from API)
        ])
        
        // Get the application support directory for SwiftData storage
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, 
                                            in: .userDomainMask).first!
        let storageURL = appSupportURL.appendingPathComponent("InfiniteStories")
        
        // Create the directory if it doesn't exist
        try? fileManager.createDirectory(at: storageURL, 
                                        withIntermediateDirectories: true, 
                                        attributes: nil)
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ ModelContainer created successfully")
            return container
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
            print("📝 Error details: \(String(describing: error))")
            
            // Clean up corrupted database files
            print("⚠️ Attempting to clean up database files...")
            
            // Clean application support directory SwiftData files
            if let enumerator = fileManager.enumerator(at: appSupportURL,
                                                      includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent.contains(".store") ||
                       fileURL.lastPathComponent.contains(".sqlite") {
                        try? fileManager.removeItem(at: fileURL)
                        print("🗑️ Removed: \(fileURL.lastPathComponent)")
                    }
                }
            }
            
            // Also clean documents directory (in case of legacy storage)
            let documentsURL = fileManager.urls(for: .documentDirectory, 
                                               in: .userDomainMask).first!
            let legacyFiles = ["default.store", "default.store-shm", "default.store-wal"]
            for fileName in legacyFiles {
                let fileURL = documentsURL.appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    try? fileManager.removeItem(at: fileURL)
                    print("🗑️ Removed legacy: \(fileName)")
                }
            }
            
            print("✅ Database cleanup complete. Creating fresh container...")
            
            // Try again with fresh database
            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("✅ Fresh ModelContainer created successfully")
                return container
            } catch let secondError {
                print("❌❌ Critical Error: Unable to create ModelContainer after cleanup")
                print("📝 Second attempt error: \(String(describing: secondError))")
                
                // Provide more detailed error information
                if let swiftDataError = secondError as? SwiftDataError {
                    print("🔍 SwiftData Error Type: \(swiftDataError)")
                }
                
                fatalError("""
                    Failed to initialize SwiftData ModelContainer.
                    
                    This may be due to:
                    1. Schema migration issues
                    2. Corrupted database files
                    3. Model definition problems
                    
                    Please try:
                    1. Deleting the app and reinstalling
                    2. Checking model definitions for SwiftData compatibility
                    
                    Error: \(secondError.localizedDescription)
                    """)
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Root view switching (BUG-28): when the session is expired we must
            // unmount MainTabView entirely so no tab bar, no background refresh,
            // no authed API call can fire. AuthenticationView covers the screen.
            if authState.isAuthenticated && !authState.sessionExpired {
                MainTabView()
                    .preferredColorScheme(themeSettings.themePreference.colorScheme)
                    .environmentObject(themeSettings)
                    .environmentObject(authState)
            } else {
                AuthenticationView()
                    .preferredColorScheme(themeSettings.themePreference.colorScheme)
                    .environmentObject(authState)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
