//
//  SyncService.swift
//  InfiniteStories
//
//  Created by Claude Code on 28/09/2025.
//

import Foundation
import SwiftData
import Network
import Combine

// MARK: - Simple Sync Status

enum SyncStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .failed: return "Failed"
        }
    }
}

// MARK: - Simplified Sync Service

class SyncService: ObservableObject {
    static let shared = SyncService()

    // MARK: - Properties

    private var modelContext: ModelContext?
    private let supabaseService = SupabaseService.shared
    private let networkMonitor = NWPathMonitor()
    private var syncTimer: Timer?

    // Observable sync state
    @Published var isOnline = false
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var pendingChangesCount = 0

    // Configuration
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private let batchSize = 50

    private init() {
        setupNetworkMonitoring()
        startPeriodicSync()
    }

    // MARK: - Public Interface

    /// Initialize with SwiftData context
    func initialize(modelContext: ModelContext) {
        self.modelContext = modelContext
        updatePendingChangesCount()
    }

    /// Trigger immediate sync
    @MainActor
    func sync() async throws {
        guard !isSyncing else { return }
        guard isOnline else { return }

        print("🔄 Starting simplified sync...")
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncTime = Date()
            updatePendingChangesCount()
        }

        do {
            // Simple two-way sync
            try await pushLocalChanges()
            try await pullRemoteChanges()
            print("✅ Sync completed successfully")
        } catch {
            print("❌ Sync failed: \(error)")
            throw error
        }
    }

    // MARK: - Simple Sync Operations

    /// Push local changes to Supabase
    @MainActor
    private func pushLocalChanges() async throws {
        guard let modelContext = modelContext else { return }

        // Sync heroes that need syncing
        let heroDescriptor = FetchDescriptor<Hero>(
            predicate: #Predicate<Hero> { $0.needsSync }
        )
        let heroesToSync = try modelContext.fetch(heroDescriptor)

        for hero in heroesToSync {
            try await supabaseService.saveHero(hero)
            print("📤 Synced hero: \(hero.name)")
        }

        // Sync stories that need syncing
        let storyDescriptor = FetchDescriptor<Story>(
            predicate: #Predicate<Story> { $0.needsSync }
        )
        let storiesToSync = try modelContext.fetch(storyDescriptor)

        for story in storiesToSync {
            try await supabaseService.saveStory(story)
            print("📤 Synced story: \(story.title)")
        }

        try modelContext.save()
    }

    /// Pull remote changes from Supabase
    @MainActor
    private func pullRemoteChanges() async throws {
        guard let modelContext = modelContext else {
            print("⚠️ No model context available for pull sync")
            return
        }

        let supabaseService = SupabaseService.shared

        // Fetch remote heroes and stories in parallel
        async let remoteHeroesTask = supabaseService.fetchHeroes()
        async let remoteStoriesTask = supabaseService.fetchStories()

        do {
            let remoteHeroes = try await remoteHeroesTask
            let remoteStories = try await remoteStoriesTask

            print("📥 Fetched \(remoteHeroes.count) heroes and \(remoteStories.count) stories from remote")

            // Process heroes
            for heroDict in remoteHeroes {
                try await processRemoteHero(heroDict, modelContext: modelContext)
            }

            // Process stories
            for storyDict in remoteStories {
                try await processRemoteStory(storyDict, modelContext: modelContext)
            }

            // Save all changes
            try modelContext.save()
            print("✅ Pull sync completed successfully")

        } catch {
            print("❌ Failed to pull remote changes: \(error)")
            throw error
        }
    }

    // MARK: - Helper Methods for Pull Sync

    @MainActor
    private func processRemoteHero(_ heroDict: [String: Any], modelContext: ModelContext) async throws {
        guard let idString = heroDict["id"] as? String,
              let remoteId = UUID(uuidString: idString),
              let name = heroDict["name"] as? String,
              let primaryTraitString = heroDict["primary_trait"] as? String,
              let secondaryTraitString = heroDict["secondary_trait"] as? String,
              let updatedAtString = heroDict["updated_at"] as? String else {
            print("⚠️ Invalid hero data, skipping")
            return
        }

        // Parse traits
        guard let primaryTrait = CharacterTrait(rawValue: primaryTraitString),
              let secondaryTrait = CharacterTrait(rawValue: secondaryTraitString) else {
            print("⚠️ Invalid traits for hero \(name), skipping")
            return
        }

        // Parse dates
        let remoteUpdatedAt = ISO8601DateFormatter.supabase.date(from: updatedAtString) ?? Date()

        // Check if hero already exists locally
        let descriptor = FetchDescriptor<Hero>(
            predicate: #Predicate<Hero> { $0.id == remoteId }
        )
        let existingHeroes = try modelContext.fetch(descriptor)

        if let existingHero = existingHeroes.first {
            // Hero exists - check if remote is newer
            if remoteUpdatedAt > existingHero.updatedAt {
                // Remote is newer - update local hero
                existingHero.name = name
                existingHero.primaryTrait = primaryTrait
                existingHero.secondaryTrait = secondaryTrait
                existingHero.appearance = heroDict["appearance"] as? String ?? ""
                existingHero.specialAbility = heroDict["special_ability"] as? String ?? ""
                existingHero.avatarPrompt = heroDict["avatar_prompt"] as? String
                existingHero.avatarGenerationId = heroDict["avatar_generation_id"] as? String
                existingHero.updatedAt = remoteUpdatedAt
                existingHero.lastSyncedAt = Date()
                existingHero.needsSync = false

                print("📥 Updated hero: \(name) (remote was newer)")
            } else if existingHero.needsSync {
                // Local has changes that need to be pushed
                print("⏭️ Skipping hero: \(name) (local has pending changes)")
            } else {
                // Already up to date
                existingHero.lastSyncedAt = Date()
                print("✓ Hero already up to date: \(name)")
            }
        } else {
            // Hero doesn't exist locally - create it
            let newHero = Hero(
                name: name,
                primaryTrait: primaryTrait,
                secondaryTrait: secondaryTrait,
                appearance: heroDict["appearance"] as? String ?? "",
                specialAbility: heroDict["special_ability"] as? String ?? ""
            )
            newHero.id = remoteId
            newHero.avatarPrompt = heroDict["avatar_prompt"] as? String
            newHero.avatarGenerationId = heroDict["avatar_generation_id"] as? String
            newHero.createdAt = ISO8601DateFormatter.supabase.date(from: heroDict["created_at"] as? String ?? "") ?? Date()
            newHero.updatedAt = remoteUpdatedAt
            newHero.lastSyncedAt = Date()
            newHero.needsSync = false

            modelContext.insert(newHero)
            print("📥 Created new hero from remote: \(name)")
        }
    }

    @MainActor
    private func processRemoteStory(_ storyDict: [String: Any], modelContext: ModelContext) async throws {
        guard let idString = storyDict["id"] as? String,
              let remoteId = UUID(uuidString: idString),
              let title = storyDict["title"] as? String,
              let content = storyDict["content"] as? String,
              let createdAtString = storyDict["created_at"] as? String else {
            print("⚠️ Invalid story data, skipping")
            return
        }

        // Parse dates
        let remoteCreatedAt = ISO8601DateFormatter.supabase.date(from: createdAtString) ?? Date()

        // Check if story already exists locally
        let descriptor = FetchDescriptor<Story>(
            predicate: #Predicate<Story> { $0.id == remoteId }
        )
        let existingStories = try modelContext.fetch(descriptor)

        if let existingStory = existingStories.first {
            // Story exists - check if remote is newer based on content changes
            // Since we don't have updated_at in the remote data, compare content
            if existingStory.content != content && !existingStory.needsSync {
                // Remote has different content and local doesn't have pending changes
                existingStory.title = title
                existingStory.content = content
                existingStory.isFavorite = storyDict["is_favorite"] as? Bool ?? false
                existingStory.playCount = storyDict["play_count"] as? Int ?? 0

                // Parse estimated duration
                if let durationString = storyDict["estimated_duration"] as? String {
                    // Extract seconds from format like "180 seconds"
                    let components = durationString.components(separatedBy: " ")
                    if let seconds = Double(components.first ?? "0") {
                        existingStory.estimatedDuration = seconds
                    }
                }

                existingStory.lastSyncedAt = Date()
                existingStory.needsSync = false

                print("📥 Updated story: \(title) (remote was different)")
            } else if existingStory.needsSync {
                // Local has changes that need to be pushed
                print("⏭️ Skipping story: \(title) (local has pending changes)")
            } else {
                // Already up to date
                existingStory.lastSyncedAt = Date()
                print("✓ Story already up to date: \(title)")
            }
        } else {
            // Story doesn't exist locally - create it

            // Find the hero if hero_id is provided
            var hero: Hero?
            if let heroIdString = storyDict["hero_id"] as? String,
               let heroId = UUID(uuidString: heroIdString) {
                let heroDescriptor = FetchDescriptor<Hero>(
                    predicate: #Predicate<Hero> { $0.id == heroId }
                )
                hero = try modelContext.fetch(heroDescriptor).first
            }

            // Determine event type
            var builtInEvent: StoryEvent?
            if let eventData = storyDict["event_data"] as? [String: Any],
               let eventRawValue = eventData["event"] as? String {
                builtInEvent = StoryEvent(rawValue: eventRawValue)
            }

            // Create the story with appropriate initializer
            let newStory: Story
            if let event = builtInEvent, let hero = hero {
                newStory = Story(title: title, content: content, event: event, hero: hero)
            } else if let hero = hero {
                // Custom event or no event specified
                newStory = Story(title: title, content: content, customEvent: nil, hero: hero)
            } else {
                // No hero - shouldn't normally happen but handle gracefully
                newStory = Story(title: title, content: content, customEvent: nil, hero: nil)
            }

            // Override the auto-generated ID with the remote ID
            newStory.id = remoteId
            newStory.createdAt = remoteCreatedAt
            newStory.isFavorite = storyDict["is_favorite"] as? Bool ?? false
            newStory.playCount = storyDict["play_count"] as? Int ?? 0

            // Parse estimated duration
            if let durationString = storyDict["estimated_duration"] as? String {
                let components = durationString.components(separatedBy: " ")
                if let seconds = Double(components.first ?? "0") {
                    newStory.estimatedDuration = seconds
                }
            }

            newStory.lastSyncedAt = Date()
            newStory.needsSync = false

            modelContext.insert(newStory)
            print("📥 Created new story from remote: \(title)")
        }
    }

    // MARK: - Simplified - data merging not yet implemented

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied

                // Auto-sync when coming online
                if path.status == .satisfied {
                    Task {
                        try? await self?.sync()
                    }
                }
            }
        }

        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }

    private func startPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            guard self?.isOnline == true && self?.isSyncing == false else { return }
            Task {
                try? await self?.sync()
            }
        }
    }

    private func updatePendingChangesCount() {
        guard let modelContext = modelContext else { return }

        do {
            let heroDescriptor = FetchDescriptor<Hero>(
                predicate: #Predicate<Hero> { $0.needsSync }
            )
            let pendingHeroes = try modelContext.fetch(heroDescriptor).count

            let storyDescriptor = FetchDescriptor<Story>(
                predicate: #Predicate<Story> { $0.needsSync }
            )
            let pendingStories = try modelContext.fetch(storyDescriptor).count

            pendingChangesCount = pendingHeroes + pendingStories
        } catch {
            print("Failed to count pending changes: \(error)")
            pendingChangesCount = 0
        }
    }

    // MARK: - Cleanup

    deinit {
        syncTimer?.invalidate()
        networkMonitor.cancel()
    }
}

// MARK: - Sync Status Summary

struct SimpleSyncStatus {
    let isOnline: Bool
    let isSyncing: Bool
    let lastSyncTime: Date?
    let pendingChanges: Int

    var statusDescription: String {
        if !isOnline {
            return "Offline"
        } else if isSyncing {
            return "Syncing..."
        } else if pendingChanges > 0 {
            return "\(pendingChanges) changes pending"
        } else if let lastSync = lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Ready to sync"
        }
    }
}