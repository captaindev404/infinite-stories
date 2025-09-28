//
//  AudioService.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import Foundation
import AVFoundation
import Combine
import UIKit
import MediaPlayer

enum AudioServiceError: Error {
    case fileCreationFailed
    case playbackFailed
    case audioGenerationFailed(String)
    case noAIService
}

protocol AudioNavigationDelegate: AnyObject {
    func playNextStory()
    func playPreviousStory()
}

struct AudioMetadata {
    let title: String
    let artist: String?
    let artwork: UIImage?
}

protocol AudioServiceProtocol {
    func generateAudioFile(from text: String, fileName: String, voice: String, language: String) async throws -> URL
    func playAudio(from url: URL) throws
    func playAudio(from url: URL, metadata: AudioMetadata?) throws
    func pauseAudio()
    func resumeAudio()
    func seek(to time: TimeInterval)
    func setAIService(_ service: AIServiceProtocol)
    func stopAudio()
    func setPlaybackSpeed(_ speed: Float)
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
}

class AudioService: NSObject, ObservableObject, AudioServiceProtocol, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var currentAudioURL: URL?
    private var aiService: AIServiceProtocol?
    private var currentPlaybackSpeed: Float = 1.0

    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var playbackTimer: Timer?

    // Lock screen controls
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingInfo = MPNowPlayingInfoCenter.default()
    weak var navigationDelegate: AudioNavigationDelegate?
    
    override init() {
        super.init()
        setupAudioSession()
        setupNotificationObservers()
        setupRemoteCommandCenter()
    }
    
    deinit {
        // Clean up command center
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.changePlaybackRateCommand.removeTarget(nil)

        UIApplication.shared.endReceivingRemoteControlEvents()

        // Clean up and ensure idle timer is re-enabled
        IdleTimerManager.shared.enableIdleTimer(for: "AudioService")
        NotificationCenter.default.removeObserver(self)
    }
    
    func setAIService(_ service: AIServiceProtocol) {
        self.aiService = service
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowAirPlay, .allowBluetoothA2DP, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    private func setupRemoteCommandCenter() {
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.resumeAudio()
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.pauseAudio()
            return .success
        }

        // Skip forward (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }

            let interval = skipEvent.interval
            self.seek(to: min(self.currentTime + interval, self.duration))
            return .success
        }

        // Skip backward (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }

            let interval = skipEvent.interval
            self.seek(to: max(self.currentTime - interval, 0))
            return .success
        }

        // Previous track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.navigationDelegate?.playPreviousStory()
            return .success
        }

        // Next track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.navigationDelegate?.playNextStory()
            return .success
        }

        // Change playback position (scrubbing)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            self.seek(to: positionEvent.positionTime)
            return .success
        }

        // Playback rate command (for speed control)
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let self = self,
                  let rateEvent = event as? MPChangePlaybackRateCommandEvent else {
                return .commandFailed
            }

            self.setPlaybackSpeed(rateEvent.playbackRate)
            return .success
        }
    }
    
    // MARK: - Idle Timer Management
    
    private func disableIdleTimer() {
        IdleTimerManager.shared.disableIdleTimer(for: "AudioService-Playback")
        print("📱 ✅ Idle timer disabled - phone will not sleep during playback")
    }
    
    private func enableIdleTimer() {
        IdleTimerManager.shared.enableIdleTimer(for: "AudioService-Playback")
        print("📱 ✅ Idle timer enabled - phone can sleep normally")
    }
    
    // MARK: - App Lifecycle Handlers
    
    @objc private func appWillResignActive() {
        // App is going to background or being interrupted
        // The audio session will continue playing in background due to .playback category
        // But we should re-enable idle timer for safety
        if !isPlaying {
            enableIdleTimer()
        }
    }
    
    @objc private func appDidBecomeActive() {
        // App became active again
        // If audio is playing, ensure idle timer is disabled
        if isPlaying {
            disableIdleTimer()
        }
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Store playback state before interruption
            let wasPlaying = isPlaying
            UserDefaults.standard.set(wasPlaying, forKey: "wasPlayingBeforeInterruption")

            if isPlaying {
                pauseAudio()
            }

        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            // Check if we should resume
            let wasPlaying = UserDefaults.standard.bool(forKey: "wasPlayingBeforeInterruption")

            if options.contains(.shouldResume) && wasPlaying {
                // Delay resume slightly to ensure audio session is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.resumeAudio()
                }
            }

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones were unplugged, pause playback
            if isPlaying {
                pauseAudio()
            }

        case .categoryChange:
            // Audio category changed, ensure our category is still set
            setupAudioSession()

        default:
            break
        }
    }
    
    func updateNowPlayingInfo(title: String, artist: String? = nil, duration: TimeInterval? = nil, artwork: UIImage? = nil) {
        var info = [String: Any]()

        // Basic metadata
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist ?? "InfiniteStories"
        info[MPMediaItemPropertyAlbumTitle] = "Bedtime Stories"

        // Playback info
        if let duration = duration ?? self.audioPlayer?.duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = self.audioPlayer?.rate ?? 1.0

        // Artwork
        if let artwork = artwork {
            let artworkItem = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            info[MPMediaItemPropertyArtwork] = artworkItem
        } else {
            // Use default artwork
            if let defaultImage = UIImage(named: "AppIcon") {
                let artworkItem = MPMediaItemArtwork(boundsSize: defaultImage.size) { _ in defaultImage }
                info[MPMediaItemPropertyArtwork] = artworkItem
            }
        }

        // Language/additional metadata
        info[MPNowPlayingInfoPropertyIsLiveStream] = false
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        nowPlayingInfo.nowPlayingInfo = info
    }

    func generateAudioFile(from text: String, fileName: String, voice: String = "nova", language: String = "English") async throws -> URL {
        print("🎵 === Audio Generation Started ===")
        print("🎵 Using voice: \(voice)")
        print("🎵 Text length: \(text.count) characters")
        
        // Check if AI service is available
        guard let aiService = aiService else {
            print("🎵 ❌ No AI service configured")
            throw AudioServiceError.noAIService
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileName = "\(fileName).mp3"
        let audioURL = documentsPath.appendingPathComponent(audioFileName)
        
        do {
            print("🎵 Generating audio with OpenAI API...")
            let audioData = try await aiService.generateSpeech(text: text, voice: voice, language: language)
            
            // Save the MP3 data to file
            try audioData.write(to: audioURL)
            print("🎵 ✅ Audio file saved: \(audioURL.path)")
            print("🎵 File size: \(audioData.count) bytes")
            return audioURL
            
        } catch {
            print("🎵 ❌ Audio generation failed: \(error.localizedDescription)")
            throw AudioServiceError.audioGenerationFailed(error.localizedDescription)
        }
    }
    
    func playAudio(from url: URL, metadata: AudioMetadata? = nil) throws {
        stopAudio()
        
        print("🎵 Playing audio file from: \(url.path)")
        print("🎵 File extension: \(url.pathExtension)")
        
        // Only play MP3 files - no TTS fallback
        guard url.pathExtension == "mp3" else {
            print("🎵 ❌ Invalid audio file format. Only MP3 files are supported.")
            throw AudioServiceError.playbackFailed
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            guard let player = audioPlayer else {
                throw AudioServiceError.playbackFailed
            }
            
            // Enable rate adjustment for playback speed control
            player.enableRate = true
            player.rate = currentPlaybackSpeed
            
            duration = player.duration
            currentAudioURL = url
            
            print("🎵 MP3 duration: \(duration) seconds")
            print("🎵 Playback rate: \(currentPlaybackSpeed)x")
            
            if player.play() {
                isPlaying = true
                startPlaybackTimer()
                disableIdleTimer()  // Prevent phone from sleeping during playback
                print("🎵 ✅ Audio playback started successfully")

                // Update Now Playing info when starting playback
                if let metadata = metadata {
                    updateNowPlayingInfo(
                        title: metadata.title,
                        artist: metadata.artist,
                        duration: player.duration,
                        artwork: metadata.artwork
                    )
                }
            } else {
                throw AudioServiceError.playbackFailed
            }
        } catch {
            print("🎵 ❌ Failed to play audio file: \(error)")
            throw AudioServiceError.playbackFailed
        }
    }

    // Convenience method for backward compatibility
    func playAudio(from url: URL) throws {
        try playAudio(from: url, metadata: nil)
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        stopPlaybackTimer()
        isPlaying = false
        currentTime = 0
        enableIdleTimer()  // Re-enable idle timer when stopping
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        stopPlaybackTimer()
        isPlaying = false
        enableIdleTimer()  // Re-enable idle timer when pausing
    }
    
    func resumeAudio() {
        guard let player = audioPlayer else { return }
        if player.play() {
            isPlaying = true
            startPlaybackTimer()
            disableIdleTimer()  // Disable idle timer when resuming
        }
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        currentPlaybackSpeed = speed
        
        if let player = audioPlayer {
            player.rate = speed
            print("🎵 Set playback rate to: \(speed)x")
        }
    }
    
    func seek(to time: TimeInterval) {
        print("🎵 Seeking to: \(time) seconds")

        if let player = audioPlayer, player.duration > 0 {
            let seekTime = min(max(time, 0), player.duration)
            print("🎵 Seeking to time: \(seekTime)")
            player.currentTime = seekTime
            currentTime = seekTime
            print("🎵 Seek completed - new time: \(currentTime)")

            // Update Now Playing elapsed time
            if var info = nowPlayingInfo.nowPlayingInfo {
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seekTime
                nowPlayingInfo.nowPlayingInfo = info
            }
        } else {
            print("🎵 No valid audio player or duration available for seeking")
        }
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
        enableIdleTimer()  // Re-enable idle timer when playback finishes
        print("🎵 Audio playback finished")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        stopPlaybackTimer()
        enableIdleTimer()  // Re-enable idle timer on error
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
    }
}