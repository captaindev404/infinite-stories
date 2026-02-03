//
//  StoryViewModel.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation
import SwiftData
import Combine
import BackgroundTasks
import UIKit

// MARK: - Generation Stage Enum

/// Represents which step in the pipeline failed
enum FailedGenerationStep: Equatable {
    case story
    case audio
    case illustrations

    var displayName: String {
        switch self {
        case .story: return "Story Generation"
        case .audio: return "Audio Generation"
        case .illustrations: return "Illustration Generation"
        }
    }

    var icon: String {
        switch self {
        case .story: return "doc.text.fill"
        case .audio: return "speaker.wave.2.fill"
        case .illustrations: return "photo.fill"
        }
    }

    var retryButtonText: String {
        switch self {
        case .story: return "Retry Story"
        case .audio: return "Retry Audio"
        case .illustrations: return "Retry Illustrations"
        }
    }
}

/// Represents the current stage of the story generation pipeline
enum StoryGenerationStage: Equatable {
    case idle
    case generatingStory
    case generatingAudio
    case generatingIllustrations
    case completed
    case failed(step: FailedGenerationStep, error: String)

    var displayText: String {
        switch self {
        case .idle:
            return ""
        case .generatingStory:
            return "Writing your story..."
        case .generatingAudio:
            return "Creating audio narration..."
        case .generatingIllustrations:
            return "Generating illustrations..."
        case .completed:
            return "Complete!"
        case .failed(let step, _):
            return "\(step.displayName) failed"
        }
    }

    var isInProgress: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        case .generatingStory, .generatingAudio, .generatingIllustrations:
            return true
        }
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var failedStep: FailedGenerationStep? {
        if case .failed(let step, _) = self { return step }
        return nil
    }

    var errorMessage: String? {
        if case .failed(_, let error) = self { return error }
        return nil
    }
}

@MainActor
class StoryViewModel: ObservableObject {
    @Published var isGeneratingStory = false
    @Published var isGeneratingAudio = false
    @Published var generationError: String?
    @Published var selectedEvent: StoryEvent = .bedtime

    // Sequential generation stage tracking
    @Published var generationStage: StoryGenerationStage = .idle
    @Published var overallProgress: Double = 0.0

    // Audio generation progress tracking
    @Published var audioGenerationProgress: Double = 0.0
    @Published var audioGenerationStage: String = ""
    @Published var currentAudioTask: URLSessionDataTask?

    // Audio playback state
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0

    // Illustration generation state
    @Published var isGeneratingIllustrations = false
    @Published var illustrationGenerationProgress: Double = 0.0
    @Published var illustrationGenerationStage: String = ""
    @Published var illustrationErrors: [String] = []
    @Published var enableIllustrations: Bool = AppConfiguration.enableStoryIllustrations

    // Story navigation
    @Published var currentStoryIndex: Int = 0
    @Published var storyQueue: [Story] = []
    @Published var isQueueMode: Bool = false
    @Published var currentStory: Story?

    // Timer for updating playback progress
    private var audioUpdateTimer: Timer?

    // Repository pattern dependencies
    private let heroRepository: HeroRepositoryProtocol
    private let storyRepository: StoryRepositoryProtocol
    private let customEventRepository: CustomEventRepositoryProtocol

    private let audioService: AudioServiceProtocol
    private let appSettings = AppSettings()

    // Session tracking for Reading Journey analytics
    private let sessionTracker = ListeningSessionTracker.shared

    // Illustration services
    let illustrationSyncManager = IllustrationSyncManager() // Made public for AudioPlayerView
    private var illustrationGenerationTask: Task<Void, Never>?

    // Background task support
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var currentGenerationTask: Task<Void, Never>?

    // MARK: - Initialization with Dependency Injection

    init(
        heroRepository: HeroRepositoryProtocol,
        storyRepository: StoryRepositoryProtocol,
        customEventRepository: CustomEventRepositoryProtocol,
        audioService: AudioServiceProtocol = AudioService()
    ) {
        self.heroRepository = heroRepository
        self.storyRepository = storyRepository
        self.customEventRepository = customEventRepository
        self.audioService = audioService

        setupBackgroundHandlers()

        // Set navigation delegate if it's the AudioService implementation
        if let audioService = audioService as? AudioService {
            audioService.navigationDelegate = self

            // Set up playback completion callback for session tracking
            audioService.onPlaybackCompleted = { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handlePlaybackCompleted()
                }
            }
        }
    }

    // Legacy init for backward compatibility (will be deprecated)
    convenience init(audioService: AudioServiceProtocol = AudioService()) {
        // Create default repositories for API-only architecture
        self.init(
            heroRepository: HeroRepository(),
            storyRepository: StoryRepository(),
            customEventRepository: CustomEventRepository(),
            audioService: audioService
        )
    }

    func setModelContext(_ context: ModelContext) {
        // Note: Illustration generation now happens via backend API
        // IllustrationGenerator is no longer needed as illustrations are generated server-side
        // This method kept for backward compatibility but is now a no-op
    }

    func refreshAIService() {
        // No-op: AI service removed - all AI operations now handled by backend API
        // Keep for backward compatibility with existing views
    }
    
    func generateStory(for hero: Hero, event: StoryEvent) async {
        print("📱 === Sequential Story Generation Flow Started ===")
        print("📱 Hero: \(hero.name) (\(hero.traitsDescription))")
        print("📱 Event: \(event.rawValue)")
        print("📱 Illustrations enabled: \(enableIllustrations), Hero has avatar: \(hero.hasAvatar)")

        isGeneratingStory = true
        generationError = nil
        generationStage = .generatingStory
        overallProgress = 0.0

        // Disable idle timer during story generation
        IdleTimerManager.shared.disableIdleTimer(for: "StoryGeneration")

        // Begin background task for story generation
        backgroundTaskId = BackgroundTaskManager.shared.beginBackgroundTask(
            withName: "StoryGeneration",
            expirationHandler: { [weak self] in
                self?.handleBackgroundTaskExpiration()
            }
        )

        // Track which step we're on for error reporting
        var currentFailedStep: FailedGenerationStep = .story
        var storyBackendId: String?

        do {
            // STEP 1: Generate Story Content
            print("📱 🚀 Step 1/3: Generating story content...")
            currentFailedStep = .story
            generationStage = .generatingStory
            overallProgress = 0.1

            guard let heroBackendId = hero.backendId else {
                throw NSError(domain: "StoryViewModel", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Hero has no backend ID"])
            }

            // Generate story only (audio and illustrations will be generated separately)
            let story = try await storyRepository.generateStory(
                heroId: heroBackendId,
                eventType: event.rawValue,
                customEventId: nil,
                language: appSettings.preferredLanguage,
                generateAudio: false,  // Will generate separately
                generateIllustrations: false  // Will generate separately if enabled
            )

            print("📱 ✅ Story content generated successfully")
            print("📱 📊 Story - Title: \(story.title)")
            print("📱 📊 Story - Content length: \(story.content.count) characters")

            currentStory = story
            storyBackendId = story.backendId
            overallProgress = 0.33

            // STEP 2: Generate Audio
            print("📱 🎵 Step 2/3: Generating audio narration...")
            currentFailedStep = .audio
            generationStage = .generatingAudio
            isGeneratingAudio = true

            guard let backendId = story.backendId else {
                throw NSError(domain: "StoryViewModel", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Story has no backend ID for audio generation"])
            }

            let audioUrl = try await storyRepository.generateAudio(
                storyId: backendId,
                language: appSettings.preferredLanguage,
                voice: appSettings.preferredVoice
            )

            print("📱 ✅ Audio generated successfully: \(audioUrl)")
            story.audioFileName = audioUrl
            story.clearAudioRegenerationFlag()
            currentStory = story
            isGeneratingAudio = false
            overallProgress = 0.66

            // STEP 3: Generate Illustrations (if enabled and hero has avatar)
            if enableIllustrations && hero.hasAvatar {
                print("📱 🎨 Step 3/3: Generating illustrations...")
                currentFailedStep = .illustrations
                generationStage = .generatingIllustrations
                isGeneratingIllustrations = true
                illustrationGenerationProgress = 0.0
                illustrationGenerationStage = "Preparing illustrations..."

                let updatedStory = try await storyRepository.generateIllustrations(storyId: backendId)

                currentStory = updatedStory
                isGeneratingIllustrations = false
                illustrationGenerationProgress = 1.0
                illustrationGenerationStage = "Complete!"

                let generatedCount = updatedStory.illustrations.filter { $0.isGenerated }.count
                print("📱 ✅ Illustrations generated: \(generatedCount)/\(updatedStory.illustrations.count)")
                AppLogger.shared.success("Generated \(generatedCount) illustrations", category: .illustration)
            } else {
                if !enableIllustrations {
                    print("📱 ⏭️ Skipping illustrations - disabled by user preference")
                    AppLogger.shared.info("Illustration generation disabled by user preference", category: .illustration)
                }
                if !hero.hasAvatar {
                    print("📱 ⏭️ Skipping illustrations - hero needs avatar first")
                    AppLogger.shared.info("Skipping illustrations - hero needs avatar first", category: .illustration)
                }
            }

            // All steps completed
            overallProgress = 1.0
            generationStage = .completed

        } catch {
            print("📱 ❌ Story generation failed at step \(currentFailedStep.displayName): \(error)")
            let errorMessage = handleAIError(error)
            generationError = errorMessage
            generationStage = .failed(step: currentFailedStep, error: errorMessage)
            isGeneratingAudio = false
            isGeneratingIllustrations = false
        }

        isGeneratingStory = false

        // Re-enable idle timer after generation
        IdleTimerManager.shared.enableIdleTimer(for: "StoryGeneration")

        // End background task
        if backgroundTaskId != .invalid {
            BackgroundTaskManager.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }

        print("📱 === Sequential Story Generation Flow Completed ===")
        print("📱 Final stage: \(generationStage)")
        print("📱 Final state - Error: \(generationError ?? "None")")
    }
    
    func generateStory(for hero: Hero, customEvent: CustomStoryEvent) async {
        print("📱 === Sequential Custom Story Generation Flow Started ===")
        print("📱 Hero: \(hero.name) (\(hero.traitsDescription))")
        print("📱 Custom Event: \(customEvent.title)")
        print("📱 Illustrations enabled: \(enableIllustrations), Hero has avatar: \(hero.hasAvatar)")

        isGeneratingStory = true
        generationError = nil
        generationStage = .generatingStory
        overallProgress = 0.0

        // Disable idle timer during story generation
        IdleTimerManager.shared.disableIdleTimer(for: "StoryGeneration")

        // Begin background task for story generation
        backgroundTaskId = BackgroundTaskManager.shared.beginBackgroundTask(
            withName: "StoryGeneration",
            expirationHandler: { [weak self] in
                self?.handleBackgroundTaskExpiration()
            }
        )

        // Track which step we're on for error reporting
        var currentFailedStep: FailedGenerationStep = .story

        do {
            // First enhance the custom event if needed
            if !customEvent.aiEnhanced {
                print("📱 ✨ Enhancing custom event...")
                _ = try await customEventRepository.enhanceEvent(customEvent)
            }

            // STEP 1: Generate Story Content
            print("📱 🚀 Step 1/3: Generating custom story content...")
            currentFailedStep = .story
            generationStage = .generatingStory
            overallProgress = 0.1

            guard let heroBackendId = hero.backendId else {
                throw NSError(domain: "StoryViewModel", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Hero has no backend ID"])
            }

            // Custom events are stored locally, so they don't have backend IDs
            // We'll pass nil for customEventId since the backend doesn't have this custom event
            let story = try await storyRepository.generateStory(
                heroId: heroBackendId,
                eventType: nil,
                customEventId: nil, // Custom events are local only
                language: appSettings.preferredLanguage,
                generateAudio: false,  // Will generate separately
                generateIllustrations: false  // Will generate separately if enabled
            )

            print("📱 ✅ Custom story content generated successfully")
            print("📱 📊 Story - Title: \(story.title)")
            print("📱 📊 Story - Content length: \(story.content.count) characters")

            currentStory = story
            overallProgress = 0.33

            // STEP 2: Generate Audio
            print("📱 🎵 Step 2/3: Generating audio narration...")
            currentFailedStep = .audio
            generationStage = .generatingAudio
            isGeneratingAudio = true

            guard let storyBackendId = story.backendId else {
                throw NSError(domain: "StoryViewModel", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Story has no backend ID for audio generation"])
            }

            let audioUrl = try await storyRepository.generateAudio(
                storyId: storyBackendId,
                language: appSettings.preferredLanguage,
                voice: appSettings.preferredVoice
            )

            print("📱 ✅ Audio generated successfully: \(audioUrl)")
            story.audioFileName = audioUrl
            story.clearAudioRegenerationFlag()
            currentStory = story
            isGeneratingAudio = false
            overallProgress = 0.66

            // STEP 3: Generate Illustrations (if enabled and hero has avatar)
            if enableIllustrations && hero.hasAvatar {
                print("📱 🎨 Step 3/3: Generating illustrations...")
                currentFailedStep = .illustrations
                generationStage = .generatingIllustrations
                isGeneratingIllustrations = true
                illustrationGenerationProgress = 0.0
                illustrationGenerationStage = "Preparing illustrations..."

                let updatedStory = try await storyRepository.generateIllustrations(storyId: storyBackendId)

                currentStory = updatedStory
                isGeneratingIllustrations = false
                illustrationGenerationProgress = 1.0
                illustrationGenerationStage = "Complete!"

                let generatedCount = updatedStory.illustrations.filter { $0.isGenerated }.count
                print("📱 ✅ Illustrations generated: \(generatedCount)/\(updatedStory.illustrations.count)")
                AppLogger.shared.success("Generated \(generatedCount) illustrations", category: .illustration)
            } else {
                if !enableIllustrations {
                    print("📱 ⏭️ Skipping illustrations - disabled by user preference")
                    AppLogger.shared.info("Illustration generation disabled by user preference", category: .illustration)
                }
                if !hero.hasAvatar {
                    print("📱 ⏭️ Skipping illustrations - hero needs avatar first")
                    AppLogger.shared.info("Skipping illustrations - hero needs avatar first", category: .illustration)
                }
            }

            // All steps completed
            overallProgress = 1.0
            generationStage = .completed

            // Note: Custom event usage count increment would need backend API support
            // For now, custom events are local-only in SwiftData

        } catch {
            print("📱 ❌ Custom story generation failed at step \(currentFailedStep.displayName): \(error)")
            let errorMessage = handleAIError(error)
            generationError = errorMessage
            generationStage = .failed(step: currentFailedStep, error: errorMessage)
            isGeneratingAudio = false
            isGeneratingIllustrations = false
        }

        isGeneratingStory = false

        // Re-enable idle timer after generation
        IdleTimerManager.shared.enableIdleTimer(for: "StoryGeneration")

        // End background task
        if backgroundTaskId != .invalid {
            BackgroundTaskManager.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }

        print("📱 === Sequential Custom Story Generation Flow Completed ===")
        print("📱 Final stage: \(generationStage)")
        print("📱 Final state - Error: \(generationError ?? "None")")
    }
    
    
    func playStory(_ story: Story) {
        print("📱 🎵 === Audio Playback Started ===")
        print("📱 🎵 Story: \(story.title)")

        // Force load illustrations relationship (SwiftData lazy loading)
        _ = story.illustrations.count

        // Update current story
        currentStory = story

        // Configure illustration sync if story has illustrations
        if story.hasIllustrations {
            illustrationSyncManager.configure(story: story, audioService: audioService)
        }

        // Start session tracking for Reading Journey analytics
        if let storyBackendId = story.backendId {
            sessionTracker.startSession(storyId: storyBackendId)
            // Also set the story ID in AudioService for reference
            if let audioService = audioService as? AudioService {
                audioService.setCurrentStoryId(storyBackendId)
            }
        }

        // Check if audio needs regeneration or generation
        guard let audioFileName = story.audioFileName, !story.audioNeedsRegeneration else {
            print("📱 🎵 Audio needs generation or regeneration...")
            Task {
                do {
                    // Generate audio via repository API
                    guard let storyBackendId = story.backendId else {
                        throw NSError(domain: "StoryViewModel", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Story has no backend ID"])
                    }

                    let audioUrl = try await storyRepository.generateAudio(
                        storyId: storyBackendId,
                        language: appSettings.preferredLanguage,
                        voice: appSettings.preferredVoice
                    )

                    print("📱 🎵 Audio generated, URL: \(audioUrl)")
                    // Update story with new audio URL
                    story.audioFileName = audioUrl
                    story.clearAudioRegenerationFlag()

                    // Play via URLCache
                    if let url = URL(string: audioUrl) {
                        playAudioFromURL(url, story: story)
                    }
                    story.incrementPlayCount()
                    startAudioUpdateTimer()
                    updateNowPlayingForStory(story)
                    currentStory = story
                } catch {
                    print("📱 🎵 ❌ Audio generation failed: \(error)")
                    generationError = "Failed to generate audio: \(error.localizedDescription)"
                }
            }
            return
        }

        print("📱 🎵 Playing existing audio file: \(audioFileName)")
        playAudioFile(fileName: audioFileName, story: story)
        story.incrementPlayCount()

        // Report play count to backend
        if let storyBackendId = story.backendId {
            Task {
                try? await APIClient.shared.requestVoid(.updatePlayCount(storyId: storyBackendId))
            }
        }

        // Update Now Playing info
        updateNowPlayingForStory(story)

        // Start the timer to update audio state
        startAudioUpdateTimer()
    }
    
    private func playAudioFile(fileName: String, story: Story? = nil) {
        // Check if fileName is a URL or local file path
        if fileName.starts(with: "http://") || fileName.starts(with: "https://") {
            // It's a URL, play from URLCache
            if let url = URL(string: fileName) {
                playAudioFromURL(url, story: story)
            }
            return
        }

        // It's a local file path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)

        print("📱 🎵 Attempting to play audio from: \(audioURL.path)")
        print("📱 🎵 File exists: \(FileManager.default.fileExists(atPath: audioURL.path))")

        do {
            // Create metadata if story is provided
            if let story = story {
                let artwork = createArtworkForStory(story)
                let metadata = AudioMetadata(
                    title: story.title,
                    artist: story.hero?.name,
                    artwork: artwork
                )
                try audioService.playAudio(from: audioURL, metadata: metadata)
            } else {
                try audioService.playAudio(from: audioURL)
            }
            updateAudioState()
            startAudioUpdateTimer()
            print("📱 🎵 ✅ Audio playback started successfully")
        } catch {
            print("📱 🎵 ❌ Audio playback failed: \(error.localizedDescription)")
            generationError = "Failed to play audio file. Please regenerate the audio."
        }
    }

    private func playAudioFromURL(_ url: URL, story: Story? = nil) {
        print("📱 🎵 Attempting to play audio from URL: \(url.absoluteString)")

        do {
            // Create metadata if story is provided
            if let story = story {
                let artwork = createArtworkForStory(story)
                let metadata = AudioMetadata(
                    title: story.title,
                    artist: story.hero?.name,
                    artwork: artwork
                )
                try audioService.playAudio(from: url, metadata: metadata)
            } else {
                try audioService.playAudio(from: url)
            }
            updateAudioState()
            startAudioUpdateTimer()
            print("📱 🎵 ✅ Audio playback started successfully")
        } catch {
            print("📱 🎵 ❌ Audio playback failed: \(error.localizedDescription)")
            generationError = "Failed to play audio. Please check your internet connection."
        }
    }

    func stopAudio(endSession: Bool = true) {
        // End session tracking when stopping audio (user dismissed)
        if endSession {
            Task {
                await sessionTracker.endSession(completed: false)
            }
        }

        audioService.stopAudio()
        updateAudioState()
        stopAudioUpdateTimer()

        // Clear the story ID in AudioService
        if let audioService = audioService as? AudioService {
            audioService.setCurrentStoryId(nil)
        }
    }

    func pauseAudio() {
        // Pause session tracking
        sessionTracker.pauseSession()

        audioService.pauseAudio()
        updateAudioState()
        stopAudioUpdateTimer()
    }

    func resumeAudio() {
        // Resume session tracking
        sessionTracker.resumeSession()

        audioService.resumeAudio()
        updateAudioState()
        startAudioUpdateTimer()
    }
    
    func seek(to time: TimeInterval) {
        audioService.seek(to: time)
        updateAudioState()

        // Update illustration sync when seeking
        if currentStory?.hasIllustrations == true {
            NotificationCenter.default.post(
                name: .audioPlaybackTimeChanged,
                object: nil,
                userInfo: ["time": time]
            )
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            pauseAudio()
        } else if isPaused {
            resumeAudio()
        }
        // If neither playing nor paused, do nothing (need to call playStory first)
    }
    
    func skipForward(_ seconds: TimeInterval = 15) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func skipBackward(_ seconds: TimeInterval = 15) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        audioService.setPlaybackSpeed(speed)
    }
    
    
    private func updateAudioState() {
        isPlaying = audioService.isPlaying
        currentTime = audioService.currentTime
        duration = audioService.duration

        // Calculate pause state: we have content (duration > 0) but not currently playing
        isPaused = duration > 0 && !isPlaying && currentTime > 0

        // Notify illustration sync manager of time updates
        if isPlaying {
            NotificationCenter.default.post(
                name: .audioPlaybackTimeChanged,
                object: nil,
                userInfo: ["time": currentTime]
            )
        }
    }
    
    private func startAudioUpdateTimer() {
        // Stop any existing timer
        stopAudioUpdateTimer()
        
        // Create a new timer that updates every 0.1 seconds
        audioUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateAudioState()
                
                // Stop timer if audio is no longer playing
                if !self.isPlaying {
                    self.stopAudioUpdateTimer()
                }
            }
        }
    }
    
    private func stopAudioUpdateTimer() {
        audioUpdateTimer?.invalidate()
        audioUpdateTimer = nil
    }

    // MARK: - Session Tracking

    /// Handle playback completing naturally (story reached the end)
    private func handlePlaybackCompleted() async {
        Logger.audio.info("Playback completed naturally, ending session as completed")

        // End the session with completed = true since the story finished naturally
        await sessionTracker.endSession(completed: true)

        // Clear the story ID in AudioService
        if let audioService = audioService as? AudioService {
            audioService.setCurrentStoryId(nil)
        }
    }

    /// End the current listening session (for use when view is dismissed)
    func endListeningSession(completed: Bool = false) async {
        await sessionTracker.endSession(completed: completed)

        // Clear the story ID in AudioService
        if let audioService = audioService as? AudioService {
            audioService.setCurrentStoryId(nil)
        }
    }

    /// End the current listening session synchronously (for use in deinit or onDisappear)
    func endListeningSessionSync(completed: Bool = false) {
        sessionTracker.endSessionSync(completed: completed)

        // Clear the story ID in AudioService
        if let audioService = audioService as? AudioService {
            audioService.setCurrentStoryId(nil)
        }
    }

    private func handleAIError(_ error: Error) -> String {
        // Handle API errors from backend
        if let apiError = error as? APIError {
            switch apiError {
            case .networkUnavailable:
                return "Network error. Please check your internet connection"
            case .unauthorized:
                return "Please sign in to continue"
            case .forbidden:
                return "You don't have access to this resource"
            case .notFound:
                return "Resource not found"
            case .rateLimitExceeded:
                return "Rate limit exceeded. Please try again later"
            case .validationError(let fields):
                let errors = fields.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                return "Validation error: \(errors)"
            case .serverError:
                return "Server error. Please try again later"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to parse response: \(error.localizedDescription)"
            case .unknown(let error):
                return "Unexpected error: \(error.localizedDescription)"
            }
        } else {
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    func clearError() {
        generationError = nil
        illustrationErrors.removeAll()
        generationStage = .idle
        overallProgress = 0.0
    }

    // MARK: - Retry Failed Generation Steps

    /// Retry audio generation for the current story
    func retryAudioGeneration() async {
        guard let story = currentStory, let storyBackendId = story.backendId else {
            generationError = "No story available to generate audio for"
            return
        }

        print("📱 🔄 Retrying audio generation...")
        generationError = nil
        generationStage = .generatingAudio
        isGeneratingAudio = true
        overallProgress = 0.5

        do {
            let audioUrl = try await storyRepository.generateAudio(
                storyId: storyBackendId,
                language: appSettings.preferredLanguage,
                voice: appSettings.preferredVoice
            )

            print("📱 ✅ Audio retry successful: \(audioUrl)")
            story.audioFileName = audioUrl
            story.clearAudioRegenerationFlag()
            currentStory = story
            isGeneratingAudio = false
            overallProgress = 1.0
            generationStage = .completed

        } catch {
            print("📱 ❌ Audio retry failed: \(error)")
            let errorMessage = handleAIError(error)
            generationError = errorMessage
            generationStage = .failed(step: .audio, error: errorMessage)
            isGeneratingAudio = false
        }
    }

    /// Retry illustration generation for the current story
    func retryIllustrationGeneration() async {
        guard let story = currentStory, let storyBackendId = story.backendId else {
            generationError = "No story available to generate illustrations for"
            return
        }

        print("📱 🔄 Retrying illustration generation...")
        generationError = nil
        generationStage = .generatingIllustrations
        isGeneratingIllustrations = true
        illustrationGenerationProgress = 0.0
        illustrationGenerationStage = "Preparing illustrations..."
        overallProgress = 0.7

        do {
            let updatedStory = try await storyRepository.generateIllustrations(storyId: storyBackendId)

            currentStory = updatedStory
            isGeneratingIllustrations = false
            illustrationGenerationProgress = 1.0
            illustrationGenerationStage = "Complete!"
            overallProgress = 1.0
            generationStage = .completed

            let generatedCount = updatedStory.illustrations.filter { $0.isGenerated }.count
            print("📱 ✅ Illustration retry successful: \(generatedCount) illustrations")
            AppLogger.shared.success("Retry generated \(generatedCount) illustrations", category: .illustration)

        } catch {
            print("📱 ❌ Illustration retry failed: \(error)")
            let errorMessage = handleAIError(error)
            generationError = errorMessage
            generationStage = .failed(step: .illustrations, error: errorMessage)
            isGeneratingIllustrations = false
        }
    }

    /// Continue from failed step - useful when story was created but audio/illustrations failed
    func continueFromFailedStep(hero: Hero) async {
        guard let failedStep = generationStage.failedStep else {
            print("📱 ⚠️ No failed step to retry from")
            return
        }

        print("📱 🔄 Continuing from failed step: \(failedStep.displayName)")

        switch failedStep {
        case .story:
            // Can't retry story from here - need to start fresh
            clearError()

        case .audio:
            await retryAudioGeneration()

            // If audio succeeded and illustrations were requested, continue
            if generationStage == .completed && enableIllustrations && hero.hasAvatar {
                if let story = currentStory, let backendId = story.backendId {
                    // Continue to illustrations
                    generationStage = .generatingIllustrations
                    isGeneratingIllustrations = true
                    overallProgress = 0.7

                    do {
                        let updatedStory = try await storyRepository.generateIllustrations(storyId: backendId)
                        currentStory = updatedStory
                        isGeneratingIllustrations = false
                        overallProgress = 1.0
                        generationStage = .completed
                    } catch {
                        let errorMessage = handleAIError(error)
                        generationError = errorMessage
                        generationStage = .failed(step: .illustrations, error: errorMessage)
                        isGeneratingIllustrations = false
                    }
                }
            }

        case .illustrations:
            await retryIllustrationGeneration()
        }
    }

    /// Check if we can skip the failed step (e.g., skip illustrations and use the story as-is)
    var canSkipFailedStep: Bool {
        guard let failedStep = generationStage.failedStep else { return false }
        // Can skip illustrations (story will work without them)
        // Cannot skip story or audio (they're required)
        return failedStep == .illustrations
    }

    /// Skip the failed step and mark as complete
    func skipFailedStep() {
        guard canSkipFailedStep else { return }

        print("📱 ⏭️ Skipping failed illustrations, marking as complete")
        generationError = nil
        generationStage = .completed
        overallProgress = 1.0
        isGeneratingIllustrations = false
    }

    // MARK: - Story Management

    func deleteStoryWithCleanup(_ story: Story) async {
        do {
            // Delete via repository API
            guard let storyBackendId = story.backendId else {
                throw NSError(domain: "StoryViewModel", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Story has no backend ID"])
            }
            try await storyRepository.deleteStory(id: storyBackendId)

            // URLCache will handle cleanup of media files automatically
            // No manual file deletion needed

            print("📱 🗑 Story deleted: \(story.title)")
        } catch {
            print("📱 ❌ Failed to delete story: \(error)")
            generationError = "Failed to delete story: \(error.localizedDescription)"
        }
    }

    private func deleteAudioFile(fileName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: audioURL.path) {
                try FileManager.default.removeItem(at: audioURL)
                print("📱 🗑 Deleted audio file: \(fileName)")
            }
        } catch {
            print("📱 ❌ Failed to delete audio file: \(error)")
        }
    }

    func regenerateAudioForStory(_ story: Story, withProgress: Bool = false) async {
        print("📱 🔄 Regenerating audio for story: \(story.title)")

        if withProgress {
            audioGenerationProgress = 0.0
            audioGenerationStage = "Preparing story..."
        }

        // Delete old audio file if it exists
        if let oldAudioFileName = story.audioFileName {
            deleteAudioFile(fileName: oldAudioFileName)
            story.audioFileName = nil
        }

        // Clear the regeneration flag
        story.clearAudioRegenerationFlag()

        if withProgress {
            audioGenerationProgress = 0.2
            audioGenerationStage = "Generating audio with backend..."
        }

        do {
            // Generate new audio via repository
            guard let storyBackendId = story.backendId else {
                throw NSError(domain: "StoryViewModel", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Story has no backend ID"])
            }

            let audioUrl = try await storyRepository.generateAudio(
                storyId: storyBackendId,
                language: appSettings.preferredLanguage,
                voice: appSettings.preferredVoice
            )
            // Update story with new audio URL
            story.audioFileName = audioUrl
            story.clearAudioRegenerationFlag()
            currentStory = story
        } catch {
            print("📱 ❌ Audio regeneration failed: \(error)")
            generationError = "Failed to regenerate audio: \(error.localizedDescription)"
        }

        if withProgress {
            audioGenerationProgress = 1.0
            audioGenerationStage = "Complete!"
        }
    }

    func cancelAudioGeneration() {
        print("📱 ❌ Cancelling audio generation")
        currentAudioTask?.cancel()
        currentAudioTask = nil
        isGeneratingAudio = false
        audioGenerationProgress = 0.0
        audioGenerationStage = ""

        // Re-enable idle timer
        IdleTimerManager.shared.enableIdleTimer(for: "AudioGeneration")
    }
    
    func checkAndRegenerateAudioIfNeeded(_ story: Story) {
        if story.audioNeedsRegeneration {
            Task {
                await regenerateAudioForStory(story)
            }
        }
    }
    
    // MARK: - Background Task Support
    
    private func setupBackgroundHandlers() {
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Listen for background task resume notifications
        // Background task notifications are for scheduled tasks, not immediate continuation
        // We use UIBackgroundTask for immediate background continuation instead
        // NotificationCenter.default.addObserver(
        //     self,
        //     selector: #selector(resumeStoryGeneration(_:)),
        //     name: .resumeStoryGeneration,
        //     object: nil
        // )
        
        // NotificationCenter.default.addObserver(
        //     self,
        //     selector: #selector(resumeAudioProcessing(_:)),
        //     name: .resumeAudioProcessing,
        //     object: nil
        // )
    }
    
    @objc private func appDidEnterBackground() {
        if isGeneratingStory || isGeneratingAudio {
            print("📱 App entering background during generation, using background task")
            // Don't schedule BGProcessingTask for immediate continuation
            // The UIBackgroundTask is already handled in generateStory/generateAudio
        }
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App entering foreground")
        // Resume any paused operations if needed
    }
    
    @objc private func resumeStoryGeneration(_ notification: Notification) {
        guard let bgTask = notification.userInfo?["backgroundTask"] as? BGProcessingTask else { return }
        
        print("📱 Resuming story generation from background task")
        
        // Continue story generation if it was interrupted
        if isGeneratingStory {
            bgTask.setTaskCompleted(success: true)
        } else {
            bgTask.setTaskCompleted(success: false)
        }
    }
    
    @objc private func resumeAudioProcessing(_ notification: Notification) {
        guard let bgTask = notification.userInfo?["backgroundTask"] as? BGProcessingTask else { return }
        
        print("📱 Resuming audio processing from background task")
        
        // Continue audio generation if it was interrupted
        if isGeneratingAudio {
            bgTask.setTaskCompleted(success: true)
        } else {
            bgTask.setTaskCompleted(success: false)
        }
    }
    
    private func handleBackgroundTaskExpiration() {
        print("📱 ⚠️ Background task is about to expire")

        // Cancel current generation task if needed
        currentGenerationTask?.cancel()
        illustrationGenerationTask?.cancel()

        // Save state for resumption
        // You could save partial progress here if needed

        // Re-enable idle timer
        IdleTimerManager.shared.enableIdleTimer(for: "StoryGeneration")
        IdleTimerManager.shared.enableIdleTimer(for: "AudioGeneration")
        IdleTimerManager.shared.enableIdleTimer(for: "IllustrationGeneration")
    }
    
    // MARK: - Story Queue Management

    func setupStoryQueue(stories: [Story], startIndex: Int = 0) {
        storyQueue = stories
        currentStoryIndex = startIndex
        isQueueMode = true
        currentStory = stories.isEmpty ? nil : stories[startIndex]

        // Set navigation delegate
        if let audioService = audioService as? AudioService {
            audioService.navigationDelegate = self
        }
    }

    func clearQueue() {
        storyQueue = []
        currentStoryIndex = 0
        isQueueMode = false
        currentStory = nil
    }

    private func updateNowPlayingForStory(_ story: Story) {
        // Create artwork from hero avatar or default image
        let artwork = createArtworkForStory(story)

        if let audioService = audioService as? AudioService {
            audioService.updateNowPlayingInfo(
                title: story.title,
                artist: story.hero?.name,
                duration: story.estimatedDuration,
                artwork: artwork
            )
        }
    }

    private func createArtworkForStory(_ story: Story) -> UIImage? {
        // Create a simple artwork image with story info
        let size = CGSize(width: 600, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Background gradient
            let colors = [UIColor.systemPurple.cgColor, UIColor.systemBlue.cgColor]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            )!

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint.zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // Add story title
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let titleRect = CGRect(x: 50, y: size.height/2 - 50, width: size.width - 100, height: 100)
            story.title.draw(in: titleRect, withAttributes: attributes)

            // Add hero name if available
            if let heroName = story.hero?.name {
                let heroAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 32),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                    .paragraphStyle: paragraphStyle
                ]

                let heroRect = CGRect(x: 50, y: size.height/2 + 50, width: size.width - 100, height: 50)
                "Featuring \(heroName)".draw(in: heroRect, withAttributes: heroAttributes)
            }
        }
    }

    // MARK: - Illustration Generation

    func generateIllustrationsForStory(_ story: Story) async {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let startTime = Date()

        AppLogger.shared.info("=== ILLUSTRATION GENERATION WORKFLOW STARTED ===", category: .illustration, requestId: String(requestId))
        AppLogger.shared.info("Story: \(story.title)", category: .illustration, requestId: String(requestId))
        AppLogger.shared.info("Story ID: \(story.id)", category: .illustration, requestId: String(requestId))

        // Check if we can generate illustrations
        guard let hero = story.hero else {
            AppLogger.shared.error("Cannot generate illustrations - no hero associated with story", category: .illustration, requestId: String(requestId))
            return
        }

        AppLogger.shared.info("Hero: \(hero.name), Has Avatar: \(hero.hasAvatar)", category: .illustration, requestId: String(requestId))

        guard hero.hasAvatar else {
            AppLogger.shared.warning("Cannot generate illustrations - hero needs avatar first", category: .illustration, requestId: String(requestId))
            illustrationErrors.append("Hero must have an avatar before generating story illustrations")
            return
        }

        isGeneratingIllustrations = true
        illustrationGenerationProgress = 0.0
        illustrationGenerationStage = "Preparing illustrations..."
        illustrationErrors.removeAll()

        AppLogger.shared.info("Disabling idle timer for illustration generation", category: .illustration, requestId: String(requestId))
        IdleTimerManager.shared.disableIdleTimer(for: "IllustrationGeneration")

        do {
            illustrationGenerationProgress = 0.3
            illustrationGenerationStage = "Generating images with AI..."
            AppLogger.shared.info("Starting AI image generation via repository", category: .illustration, requestId: String(requestId))

            // Use repository to generate illustrations via backend API
            guard let storyBackendId = story.backendId else {
                throw NSError(domain: "StoryViewModel", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Story has no backend ID"])
            }

            let updatedStory = try await storyRepository.generateIllustrations(storyId: storyBackendId)
            currentStory = updatedStory

            // Backend handles all illustration generation
            // No local generator needed

            illustrationGenerationProgress = 1.0
            illustrationGenerationStage = "Illustrations complete!"

            // Log final status
            let generatedCount = updatedStory.illustrations.filter { $0.isGenerated }.count
            AppLogger.shared.success("Generated \(generatedCount)/\(updatedStory.illustrations.count) illustrations successfully", category: .illustration, requestId: String(requestId))

            AppLogger.shared.logPerformance(operation: "Complete Illustration Generation", startTime: startTime, requestId: String(requestId))

        } catch {
            AppLogger.shared.error("Illustration generation failed", category: .illustration, requestId: String(requestId), error: error)
            illustrationErrors.append(error.localizedDescription)
        }

        isGeneratingIllustrations = false

        AppLogger.shared.info("Re-enabling idle timer", category: .illustration, requestId: String(requestId))
        IdleTimerManager.shared.enableIdleTimer(for: "IllustrationGeneration")

        AppLogger.shared.info("=== ILLUSTRATION GENERATION WORKFLOW COMPLETED ===", category: .illustration, requestId: String(requestId))
        AppLogger.shared.info("Final Status - Errors: \(illustrationErrors.count), Progress: \(illustrationGenerationProgress * 100)%", category: .illustration, requestId: String(requestId))
    }

    func regenerateIllustration(_ illustration: StoryIllustration) async {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        AppLogger.shared.info("Regenerating single illustration", category: .illustration, requestId: String(requestId))

        // Note: Individual illustration regeneration now requires regenerating all illustrations via backend
        // This is because illustrations are generated server-side in a batch
        guard let story = illustration.story, let storyId = story.backendId else {
            AppLogger.shared.error("Cannot regenerate - story not found or not saved", category: .illustration, requestId: String(requestId))
            illustrationErrors.append("Cannot regenerate - story not available")
            return
        }

        do {
            AppLogger.shared.info("Regenerating illustrations for story via backend API", category: .illustration, requestId: String(requestId))
            _ = try await storyRepository.generateIllustrations(storyId: storyId)
            AppLogger.shared.success("Illustrations regenerated successfully", category: .illustration, requestId: String(requestId))
        } catch {
            AppLogger.shared.error("Failed to regenerate illustrations", category: .illustration, requestId: String(requestId), error: error)
            illustrationErrors.append("Failed to regenerate illustrations: \(error.localizedDescription)")
        }
    }

    func cancelIllustrationGeneration() {
        AppLogger.shared.warning("Cancelling illustration generation", category: .illustration)
        illustrationGenerationTask?.cancel()
        illustrationGenerationTask = nil
        isGeneratingIllustrations = false
        illustrationGenerationProgress = 0.0
        illustrationGenerationStage = ""

        // Re-enable idle timer
        IdleTimerManager.shared.enableIdleTimer(for: "IllustrationGeneration")
        AppLogger.shared.info("Illustration generation cancelled and cleaned up", category: .illustration)
    }

    // MARK: - Retry Failed Illustrations

    /// Retry a single failed illustration
    func retryFailedIllustration(_ illustration: StoryIllustration) async {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        AppLogger.shared.info("Retrying failed illustration #\(illustration.displayOrder + 1)", category: .illustration, requestId: String(requestId))

        // Note: Individual illustration retry now requires regenerating all illustrations via backend
        guard let story = illustration.story, let storyId = story.backendId else {
            AppLogger.shared.error("Cannot retry - story not found or not saved", category: .illustration, requestId: String(requestId))
            illustrationErrors.append("Cannot retry - story not available")
            return
        }

        // Update UI state
        isGeneratingIllustrations = true
        illustrationGenerationStage = "Retrying illustration #\(illustration.displayOrder + 1)..."
        illustrationErrors.removeAll()

        do {
            // Reset the illustration's retry count and error state
            illustration.resetError()
            illustration.retryCount = 0  // Reset retry count for manual retry

            // Regenerate all illustrations via backend API
            _ = try await storyRepository.generateIllustrations(storyId: storyId)

            AppLogger.shared.success("Successfully retried illustration #\(illustration.displayOrder + 1)", category: .illustration, requestId: String(requestId))
            illustrationGenerationStage = "Illustration retry successful!"
        } catch {
            AppLogger.shared.error("Failed to retry illustration", category: .illustration, requestId: String(requestId), error: error)
            illustrationErrors.append("Failed to retry illustration: \(error.localizedDescription)")
            illustrationGenerationStage = "Illustration retry failed"
        }

        // Reset UI state after a delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            isGeneratingIllustrations = false
            illustrationGenerationStage = ""
        }
    }

    /// Retry all failed illustrations for a story
    func retryAllFailedIllustrations(for story: Story) async {
        let requestId = UUID().uuidString.prefix(8).lowercased()
        let failedIllustrations = story.illustrations.filter { $0.isPlaceholder && !$0.hasReachedRetryLimit }

        guard !failedIllustrations.isEmpty else {
            AppLogger.shared.info("No failed illustrations to retry", category: .illustration, requestId: String(requestId))
            return
        }

        AppLogger.shared.info("Retrying \(failedIllustrations.count) failed illustrations", category: .illustration, requestId: String(requestId))

        guard let storyId = story.backendId else {
            AppLogger.shared.error("Story not saved to backend - cannot retry", category: .illustration, requestId: String(requestId))
            illustrationErrors.append("Cannot retry - story not available")
            return
        }

        // Update UI state
        isGeneratingIllustrations = true
        illustrationGenerationProgress = 0.0
        illustrationGenerationStage = "Retrying failed illustrations..."
        illustrationErrors.removeAll()

        // Regenerate all illustrations via backend API
        do {
            _ = try await storyRepository.generateIllustrations(storyId: storyId)
            AppLogger.shared.success("Successfully retried all failed illustrations", category: .illustration, requestId: String(requestId))
        } catch {
            AppLogger.shared.error("Failed to retry illustrations", category: .illustration, requestId: String(requestId), error: error)
            illustrationErrors.append("Failed to retry illustrations: \(error.localizedDescription)")
        }

        // Update UI state
        illustrationGenerationProgress = 1.0
        illustrationGenerationStage = "Retry complete!"

        // Reset UI state after a delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            isGeneratingIllustrations = false
            illustrationGenerationProgress = 0.0
            illustrationGenerationStage = ""
        }
    }

    /// Check if a story has any failed illustrations that can be retried
    func hasRetryableFailedIllustrations(_ story: Story) -> Bool {
        return story.illustrations.contains { $0.isPlaceholder && !$0.hasReachedRetryLimit }
    }

    /// Get count of failed illustrations for a story
    func failedIllustrationCount(for story: Story) -> Int {
        return story.illustrations.filter { $0.isPlaceholder }.count
    }

    // MARK: - Illustration Sync with Audio

    func seekToIllustration(_ illustration: StoryIllustration) {
        // Seek audio to illustration timestamp
        seek(to: illustration.timestamp)

        // Move carousel to this illustration
        illustrationSyncManager.moveToIllustration(illustration)
    }

    func onIllustrationCarouselSwipe(to index: Int) {
        // User swiped carousel, enter manual mode
        illustrationSyncManager.moveToIndex(index)

        // Optionally seek audio to match
        if let illustration = illustrationSyncManager.illustrationForPage(index) {
            seek(to: illustration.timestamp)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        // Note: Cannot call main actor-isolated sessionTracker from deinit
        // The ListeningSessionTracker handles app lifecycle events and will
        // persist session state on app termination/background via its own observers

        // Ensure idle timer is re-enabled
        IdleTimerManager.shared.enableIdleTimer(for: "StoryGeneration")
        IdleTimerManager.shared.enableIdleTimer(for: "AudioGeneration")
        IdleTimerManager.shared.enableIdleTimer(for: "IllustrationGeneration")
    }
}

// MARK: - AudioNavigationDelegate

extension StoryViewModel: AudioNavigationDelegate {
    nonisolated func playNextStory() {
        Task { @MainActor in
            guard isQueueMode,
                  currentStoryIndex < storyQueue.count - 1 else {
                return
            }

            currentStoryIndex += 1
            let nextStory = storyQueue[currentStoryIndex]
            // Force load illustrations relationship (SwiftData lazy loading)
            _ = nextStory.illustrations.count
            currentStory = nextStory

            // Stop current playback
            stopAudio()

            // Play next story
            playStory(nextStory)

            // Update Now Playing info
            updateNowPlayingForStory(nextStory)
        }
    }

    nonisolated func playPreviousStory() {
        Task { @MainActor in
            guard isQueueMode else {
                // If not in queue mode, restart current story
                seek(to: 0)
                return
            }

            // If within first 3 seconds, go to previous story
            if currentTime < 3.0 && currentStoryIndex > 0 {
                currentStoryIndex -= 1
                let previousStory = storyQueue[currentStoryIndex]
                // Force load illustrations relationship (SwiftData lazy loading)
                _ = previousStory.illustrations.count
                currentStory = previousStory

                stopAudio()
                playStory(previousStory)
                updateNowPlayingForStory(previousStory)
            } else {
                // Otherwise, restart current story
                seek(to: 0)
            }
        }
    }
}

// Note: AppSettings has been moved to Settings/AppSettings.swift
