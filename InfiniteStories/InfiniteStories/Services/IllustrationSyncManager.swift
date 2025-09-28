//
//  IllustrationSyncManager.swift
//  InfiniteStories
//
//  Created by Captain Dev on 16/09/2025.
//

import Foundation
import SwiftUI
import Combine

/// Manager for coordinating illustration display with audio playback
class IllustrationSyncManager: ObservableObject {

    // MARK: - Published Properties

    /// Currently displayed illustration
    @Published var currentIllustration: StoryIllustration?

    /// Index of current illustration in the carousel
    @Published var currentIllustrationIndex: Int = 0

    /// Next illustration that will be shown
    @Published var nextIllustration: StoryIllustration?

    /// Progress to the next illustration (0.0 to 1.0)
    @Published var progressToNext: Double = 0.0

    /// Whether carousel is in manual mode (user swiped)
    @Published var isManualMode: Bool = false

    /// Preloaded images cache
    @Published var preloadedImages: [UUID: UIImage] = [:]

    // MARK: - Private Properties

    private var story: Story?
    private var illustrations: [StoryIllustration] = []
    private var audioService: AudioServiceProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var manualModeTimer: Timer?
    private let preloadRadius = 2 // Number of images to preload in each direction

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Monitor audio playback time changes
        NotificationCenter.default.publisher(for: .audioPlaybackTimeChanged)
            .compactMap { $0.userInfo?["time"] as? TimeInterval }
            .sink { [weak self] time in
                guard let self = self else { return }
                if !self.isManualMode {
                    self.updateIllustrationForTime(time)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    /// Configure the sync manager for a story with illustrations
    func configure(story: Story, audioService: AudioServiceProtocol) {
        self.story = story
        self.audioService = audioService
        self.illustrations = story.sortedIllustrations.filter { $0.isGenerated }

        // Reset state
        currentIllustrationIndex = 0
        currentIllustration = illustrations.first
        nextIllustration = illustrations.count > 1 ? illustrations[1] : nil
        isManualMode = false
        progressToNext = 0.0

        // Preload initial images
        preloadImagesAroundIndex(0)
    }

    // MARK: - Audio Sync

    /// Update the displayed illustration based on audio timestamp
    private func updateIllustrationForTime(_ time: TimeInterval) {
        guard let story = story else { return }

        // Find the appropriate illustration for this timestamp
        if let illustration = story.illustrationAt(timestamp: time) {
            // Check if this is a different illustration than current
            if illustration.id != currentIllustration?.id {
                setCurrentIllustration(illustration)
            }

            // Calculate progress to next illustration
            updateProgressToNext(currentTime: time)
        }
    }

    /// Calculate progress to the next illustration
    private func updateProgressToNext(currentTime: TimeInterval) {
        guard let current = currentIllustration,
              let next = nextIllustration else {
            progressToNext = 0.0
            return
        }

        let timeBetween = next.timestamp - current.timestamp
        let timeElapsed = currentTime - current.timestamp

        if timeBetween > 0 {
            progressToNext = min(1.0, max(0.0, timeElapsed / timeBetween))
        } else {
            progressToNext = 0.0
        }
    }

    // MARK: - Carousel Control

    /// Move to a specific illustration
    func moveToIllustration(_ illustration: StoryIllustration) {
        setCurrentIllustration(illustration)
        enterManualMode()

        // If audio is playing, seek to the illustration's timestamp
        if let audioService = audioService, audioService.isPlaying {
            audioService.seek(to: illustration.timestamp)
        }
    }

    /// Move to the next illustration
    func moveToNext() {
        guard currentIllustrationIndex < illustrations.count - 1 else { return }

        currentIllustrationIndex += 1
        setCurrentIllustration(illustrations[currentIllustrationIndex])
        enterManualMode()

        // Seek audio if playing
        if let audioService = audioService, audioService.isPlaying {
            audioService.seek(to: currentIllustration?.timestamp ?? 0)
        }
    }

    /// Move to the previous illustration
    func moveToPrevious() {
        guard currentIllustrationIndex > 0 else { return }

        currentIllustrationIndex -= 1
        setCurrentIllustration(illustrations[currentIllustrationIndex])
        enterManualMode()

        // Seek audio if playing
        if let audioService = audioService, audioService.isPlaying {
            audioService.seek(to: currentIllustration?.timestamp ?? 0)
        }
    }

    /// Move to illustration at specific index
    func moveToIndex(_ index: Int) {
        guard index >= 0 && index < illustrations.count else { return }

        currentIllustrationIndex = index
        setCurrentIllustration(illustrations[index])
        enterManualMode()

        // Seek audio if playing
        if let audioService = audioService, audioService.isPlaying {
            audioService.seek(to: currentIllustration?.timestamp ?? 0)
        }
    }

    // MARK: - Manual Mode

    /// Enter manual mode when user interacts with carousel
    private func enterManualMode() {
        isManualMode = true

        // Cancel any existing timer
        manualModeTimer?.invalidate()

        // Return to auto mode after 5 seconds of inactivity
        manualModeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.exitManualMode()
        }
    }

    /// Exit manual mode and return to audio sync
    private func exitManualMode() {
        isManualMode = false
        manualModeTimer?.invalidate()
        manualModeTimer = nil

        // Resync with current audio time
        if let audioService = audioService {
            updateIllustrationForTime(audioService.currentTime)
        }
    }

    // MARK: - Image Preloading

    /// Preload images around the current index for smooth transitions
    private func preloadImagesAroundIndex(_ index: Int) {
        let startIndex = max(0, index - preloadRadius)
        let endIndex = min(illustrations.count - 1, index + preloadRadius)

        for i in startIndex...endIndex {
            let illustration = illustrations[i]
            preloadImage(for: illustration)
        }

        // Clean up distant images from cache
        cleanupDistantImages(currentIndex: index)
    }

    /// Preload a single image
    private func preloadImage(for illustration: StoryIllustration) {
        // Skip if already loaded
        guard preloadedImages[illustration.id] == nil,
              let url = illustration.imageURL else { return }

        DispatchQueue.global(qos: .background).async { [weak self] in
            if let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    self?.preloadedImages[illustration.id] = image
                }
            }
        }
    }

    /// Remove distant images from cache to manage memory
    private func cleanupDistantImages(currentIndex: Int) {
        let keepRange = max(0, currentIndex - preloadRadius * 2)...min(illustrations.count - 1, currentIndex + preloadRadius * 2)

        for (index, illustration) in illustrations.enumerated() {
            if !keepRange.contains(index) {
                preloadedImages.removeValue(forKey: illustration.id)
            }
        }
    }

    // MARK: - Helper Methods

    /// Set the current illustration and update related state
    private func setCurrentIllustration(_ illustration: StoryIllustration) {
        currentIllustration = illustration

        // Find index
        if let index = illustrations.firstIndex(where: { $0.id == illustration.id }) {
            currentIllustrationIndex = index

            // Update next illustration
            if index < illustrations.count - 1 {
                nextIllustration = illustrations[index + 1]
            } else {
                nextIllustration = nil
            }

            // Preload surrounding images
            preloadImagesAroundIndex(index)
        }

        // Reset progress
        progressToNext = 0.0
    }

    /// Get preloaded image for an illustration
    func getImage(for illustration: StoryIllustration) -> UIImage? {
        // Check cache first
        if let cached = preloadedImages[illustration.id] {
            return cached
        }

        // Load synchronously if not cached (fallback)
        if let url = illustration.imageURL,
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }

        return nil
    }

    /// Calculate which illustration should be visible for a given page index in carousel
    func illustrationForPage(_ page: Int) -> StoryIllustration? {
        guard page >= 0 && page < illustrations.count else { return nil }
        return illustrations[page]
    }

    /// Get all illustrations for display in carousel
    var allIllustrations: [StoryIllustration] {
        return illustrations
    }

    /// Check if can move to next illustration
    var canMoveNext: Bool {
        return currentIllustrationIndex < illustrations.count - 1
    }

    /// Check if can move to previous illustration
    var canMovePrevious: Bool {
        return currentIllustrationIndex > 0
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let audioPlaybackTimeChanged = Notification.Name("audioPlaybackTimeChanged")
}