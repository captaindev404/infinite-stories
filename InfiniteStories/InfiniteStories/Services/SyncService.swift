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

    /// Pull remote changes from Supabase (simplified for now)
    @MainActor
    private func pullRemoteChanges() async throws {
        // TODO: Implement pull when SupabaseService has fetch methods
        print("📥 Pull sync (simplified - not yet implemented)")
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