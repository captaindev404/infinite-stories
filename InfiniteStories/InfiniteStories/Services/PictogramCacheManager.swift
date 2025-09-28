//
//  PictogramCacheManager.swift
//  InfiniteStories
//
//  Cache management for custom event pictograms
//

import Foundation
import UIKit
import SwiftUI
import os.log

// MARK: - PictogramCacheManager

@MainActor
class PictogramCacheManager: ObservableObject {
    static let shared = PictogramCacheManager()

    private let logger = os.Logger(subsystem: "InfiniteStories", category: "PictogramCacheManager")
    private let pictogramDirectory = "EventPictograms"
    private let thumbnailDirectory = "EventPictograms/thumbnails"

    // Memory cache for frequently accessed pictograms
    private var memoryCache = NSCache<NSString, UIImage>()
    private var thumbnailCache = NSCache<NSString, UIImage>()

    // Cache configuration
    private let maxMemoryCacheCount = 50
    private let maxThumbnailCacheCount = 100
    private let maxDiskCacheSizeMB = 100

    // Cache statistics
    @Published var totalCacheSize: Int64 = 0
    @Published var pictogramCount: Int = 0
    @Published var thumbnailCount: Int = 0

    private init() {
        configureCache()
        Task {
            await calculateCacheSize()
        }
    }

    // MARK: - Public Methods

    func image(for eventID: UUID) -> UIImage? {
        let key = eventID.uuidString as NSString
        return memoryCache.object(forKey: key)
    }

    func thumbnail(for eventID: UUID) -> UIImage? {
        let key = "\(eventID.uuidString)_thumb" as NSString
        return thumbnailCache.object(forKey: key)
    }

    func store(_ image: UIImage?, for eventID: UUID) {
        guard let image = image else { return }
        let key = eventID.uuidString as NSString
        memoryCache.setObject(image, forKey: key)
    }

    func storeThumbnail(_ image: UIImage?, for eventID: UUID) {
        guard let image = image else { return }
        let key = "\(eventID.uuidString)_thumb" as NSString
        thumbnailCache.setObject(image, forKey: key)
    }

    func preloadPictograms(for events: [CustomStoryEvent]) async {
        await withTaskGroup(of: Void.self) { group in
            for event in events where event.hasPictogram {
                group.addTask {
                    await self.preloadPictogram(for: event)
                }
            }
        }
    }

    func preloadPictogram(for event: CustomStoryEvent) async {
        guard event.hasPictogram, let url = event.pictogramURL else { return }

        // Check if already cached
        if image(for: event.id) != nil { return }

        // Load from disk
        if let image = UIImage(contentsOfFile: url.path) {
            store(image, for: event.id)
            logger.debug("Preloaded pictogram for: \(event.title)")
        }

        // Load thumbnail
        await preloadThumbnail(for: event.id)
    }

    func preloadThumbnail(for eventID: UUID) async {
        // Check if already cached
        if thumbnail(for: eventID) != nil { return }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let thumbnailURL = documentsURL
            .appendingPathComponent(thumbnailDirectory)
            .appendingPathComponent("\(eventID.uuidString)_thumb.png")

        if FileManager.default.fileExists(atPath: thumbnailURL.path),
           let image = UIImage(contentsOfFile: thumbnailURL.path) {
            storeThumbnail(image, for: eventID)
        }
    }

    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        logger.info("Cleared memory cache")
    }

    // MARK: - Cleanup Operations

    func cleanupUnusedPictograms(activeEvents: [CustomStoryEvent]) async -> Int {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pictogramDirectoryURL = documentsURL.appendingPathComponent(pictogramDirectory)

        var deletedCount = 0
        let activeFileNames = Set(activeEvents.compactMap { $0.pictogramPath })

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: pictogramDirectoryURL,
                includingPropertiesForKeys: nil
            )

            for fileURL in contents {
                let fileName = fileURL.lastPathComponent

                // Skip directories
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    continue
                }

                // Delete if not in active set
                if !activeFileNames.contains(fileName) {
                    try FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                    logger.debug("Deleted unused pictogram: \(fileName)")
                }
            }

        } catch {
            logger.error("Failed to cleanup pictograms: \(error.localizedDescription)")
        }

        // Also cleanup orphaned thumbnails
        deletedCount += await cleanupOrphanedThumbnails(activeEventIDs: activeEvents.map { $0.id })

        await calculateCacheSize()
        return deletedCount
    }

    private func cleanupOrphanedThumbnails(activeEventIDs: [UUID]) async -> Int {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let thumbnailDirectoryURL = documentsURL.appendingPathComponent(thumbnailDirectory)

        var deletedCount = 0
        let activeIDs = Set(activeEventIDs.map { $0.uuidString })

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: thumbnailDirectoryURL,
                includingPropertiesForKeys: nil
            )

            for fileURL in contents {
                let fileName = fileURL.deletingPathExtension().lastPathComponent

                // Extract event ID from thumbnail filename
                let eventID = fileName.replacingOccurrences(of: "_thumb", with: "")

                if !activeIDs.contains(eventID) {
                    try FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                    logger.debug("Deleted orphaned thumbnail: \(fileName)")
                }
            }

        } catch {
            logger.error("Failed to cleanup thumbnails: \(error.localizedDescription)")
        }

        return deletedCount
    }

    // MARK: - Integrity Validation

    func validatePictogramIntegrity(events: [CustomStoryEvent]) async -> [CustomStoryEvent] {
        var eventsWithMissingPictograms: [CustomStoryEvent] = []

        for event in events {
            if let _ = event.pictogramPath, !event.hasPictogram {
                eventsWithMissingPictograms.append(event)
                logger.warning("Missing pictogram for event: \(event.title)")

                // Clear invalid reference
                event.pictogramPath = nil
                event.pictogramGeneratedAt = nil
            }
        }

        return eventsWithMissingPictograms
    }

    // MARK: - Cache Statistics

    func calculateCacheSize() async {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pictogramDirectoryURL = documentsURL.appendingPathComponent(pictogramDirectory)

        var totalSize: Int64 = 0
        var pictogramCount = 0
        var thumbnailCount = 0

        do {
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            let enumerator = FileManager.default.enumerator(
                at: pictogramDirectoryURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))

                if let isDirectory = resourceValues.isDirectory, !isDirectory,
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)

                    if fileURL.path.contains("thumbnails") {
                        thumbnailCount += 1
                    } else {
                        pictogramCount += 1
                    }
                }
            }

        } catch {
            logger.error("Failed to calculate cache size: \(error.localizedDescription)")
        }

        self.totalCacheSize = totalSize
        self.pictogramCount = pictogramCount
        self.thumbnailCount = thumbnailCount

        logger.info("Cache stats - Size: \(self.formatBytes(totalSize)), Pictograms: \(pictogramCount), Thumbnails: \(thumbnailCount)")
    }

    func isUnderSizeLimit() -> Bool {
        let maxSizeBytes = Int64(maxDiskCacheSizeMB * 1024 * 1024)
        return totalCacheSize < maxSizeBytes
    }

    // MARK: - Private Methods

    private func configureCache() {
        memoryCache.countLimit = maxMemoryCacheCount
        thumbnailCache.countLimit = maxThumbnailCacheCount

        // Respond to memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        clearMemoryCache()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Cache Warming

extension PictogramCacheManager {
    func warmCache(with events: [CustomStoryEvent]) async {
        // Sort by usage count and recency to prioritize frequently used events
        let sortedEvents = events.sorted { event1, event2 in
            // First by favorite status
            if event1.isFavorite != event2.isFavorite {
                return event1.isFavorite
            }
            // Then by usage count
            if event1.usageCount != event2.usageCount {
                return event1.usageCount > event2.usageCount
            }
            // Finally by last used date
            let date1 = event1.lastUsed ?? event1.createdAt
            let date2 = event2.lastUsed ?? event2.createdAt
            return date1 > date2
        }

        // Preload top N events
        let eventsToPreload = Array(sortedEvents.prefix(20))
        await preloadPictograms(for: eventsToPreload)
    }
}

// MARK: - Image Loading Helper

struct CachedPictogramImage: View {
    let event: CustomStoryEvent
    @StateObject private var cacheManager = PictogramCacheManager.shared
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(width: 64, height: 64)
            } else {
                // Fallback to SF Symbol
                Image(systemName: event.iconName)
                    .font(.system(size: 30))
                    .foregroundColor(Color(hex: event.colorHex))
                    .frame(width: 64, height: 64)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        // Check memory cache first
        if let cached = cacheManager.image(for: event.id) {
            self.image = cached
            self.isLoading = false
            return
        }

        // Try to load thumbnail for list views
        if let thumbnail = cacheManager.thumbnail(for: event.id) {
            self.image = thumbnail
            self.isLoading = false
            return
        }

        // Load from disk if available
        if let url = event.pictogramURL,
           let diskImage = UIImage(contentsOfFile: url.path) {
            cacheManager.store(diskImage, for: event.id)
            self.image = diskImage
        }

        self.isLoading = false
    }
}