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

enum AudioServiceError: Error {
    case speechUnavailable
    case fileCreationFailed
    case playbackFailed
}

protocol AudioServiceProtocol {
    func generateAudioFile(from text: String, fileName: String, voice: String) async throws -> URL
    func playAudio(from url: URL) throws
    func playTextToSpeechDirectly(text: String)
    func pauseAudio()
    func resumeAudio()
    func seek(to time: TimeInterval)
    func setAIService(_ service: AIServiceProtocol)
    func stopAudio()
    func setPlaybackSpeed(_ speed: Float)
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var isUsingSpeechSynthesis: Bool { get }
}

class AudioService: NSObject, ObservableObject, AudioServiceProtocol, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var currentAudioURL: URL?
    private var currentUtterance: AVSpeechUtterance?
    var isUsingSpeechSynthesis: Bool = false
    private var aiService: AIServiceProtocol?
    private var currentPlaybackSpeed: Float = 1.0
    
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var playbackTimer: Timer?
    private var speechTimer: Timer?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupNotificationObservers()
    }
    
    deinit {
        // Clean up and ensure idle timer is re-enabled
        enableIdleTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    func setAIService(_ service: AIServiceProtocol) {
        self.aiService = service
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
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
    }
    
    // MARK: - Idle Timer Management
    
    private func disableIdleTimer() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
            print("📱 ✅ Idle timer disabled - phone will not sleep during playback")
        }
    }
    
    private func enableIdleTimer() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
            print("📱 ✅ Idle timer enabled - phone can sleep normally")
        }
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
            // Interruption began (phone call, etc.)
            if isPlaying {
                pauseAudio()
            }
        case .ended:
            // Interruption ended
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Resume playback if appropriate
                    resumeAudio()
                }
            }
        @unknown default:
            break
        }
    }
    
    func generateAudioFile(from text: String, fileName: String, voice: String = "nova") async throws -> URL {
        print("🎵 === Audio Generation Started ===")
        print("🎵 Using voice: \(voice)")
        print("🎵 Text length: \(text.count) characters")
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileName = "\(fileName).mp3"
        let audioURL = documentsPath.appendingPathComponent(audioFileName)
        
        // Try OpenAI TTS first, fallback to local TTS if it fails
        if let aiService = aiService {
            do {
                print("🎵 Attempting OpenAI TTS generation...")
                let audioData = try await aiService.generateSpeech(text: text, voice: voice)
                
                // Save the MP3 data to file
                try audioData.write(to: audioURL)
                print("🎵 ✅ OpenAI audio saved: \(audioURL.path)")
                print("🎵 File size: \(audioData.count) bytes")
                return audioURL
                
            } catch {
                print("🎵 ⚠️ OpenAI TTS failed: \(error.localizedDescription)")
                print("🎵 Falling back to local TTS...")
            }
        } else {
            print("🎵 ⚠️ No AI service available, using local TTS...")
        }
        
        // Fallback to local TTS (save as text file for AVSpeechSynthesizer)
        let fallbackFileName = "\(fileName)_tts.txt"
        let fallbackURL = documentsPath.appendingPathComponent(fallbackFileName)
        
        do {
            try text.write(to: fallbackURL, atomically: true, encoding: .utf8)
            print("🎵 ✅ Fallback TTS file saved: \(fallbackURL.path)")
            return fallbackURL
        } catch {
            print("🎵 ❌ Failed to save fallback TTS file: \(error)")
            throw AudioServiceError.fileCreationFailed
        }
    }
    
    func playAudio(from url: URL) throws {
        stopAudio()
        
        // Check if this is a TTS text file (fallback)
        if url.pathExtension == "txt" && url.lastPathComponent.contains("_tts") {
            print("🎵 Playing text-to-speech from: \(url.path)")
            playTextToSpeech(from: url)
        } else if url.pathExtension == "mp3" {
            // Try to play OpenAI generated MP3 file
            print("🎵 Playing MP3 audio file from: \(url.path)")
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
                isUsingSpeechSynthesis = false
                
                print("🎵 MP3 duration: \(duration) seconds")
                print("🎵 Playback rate: \(currentPlaybackSpeed)x")
                
                if player.play() {
                    isPlaying = true
                    startPlaybackTimer()
                    disableIdleTimer()  // Prevent phone from sleeping during playback
                    print("🎵 ✅ MP3 playback started successfully")
                } else {
                    throw AudioServiceError.playbackFailed
                }
            } catch {
                print("🎵 ❌ Failed to play MP3 file: \(error)")
                print("🎵 MP3 file appears to be invalid")
                throw AudioServiceError.playbackFailed
            }
        } else {
            // Try to play as regular audio file (legacy)
            print("🎵 Playing legacy audio file from: \(url.path)")
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
                isUsingSpeechSynthesis = false
                
                if player.play() {
                    isPlaying = true
                    startPlaybackTimer()
                    disableIdleTimer()  // Prevent phone from sleeping during playback
                } else {
                    throw AudioServiceError.playbackFailed
                }
            } catch {
                print("🎵 ❌ Failed to play legacy audio file: \(error)")
                throw AudioServiceError.playbackFailed
            }
        }
    }
    
    private func playTextToSpeech(from url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            playTextToSpeechDirectly(text: text)
        } catch {
            print("🎵 Failed to read TTS text file: \(error)")
        }
    }
    
    func playTextToSpeechDirectly(text: String) {
        print("🎵 Starting TTS playback for text: \(text.prefix(50))...")
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        // Apply the current playback speed to TTS rate
        // TTS rate: 0.0 = slowest, 0.5 = normal, 1.0 = fastest
        // Map our speed (0.5x-2.0x) to TTS rate (0.25-0.65)
        let ttsRate: Float = {
            switch currentPlaybackSpeed {
            case 0.5: return 0.25
            case 0.75: return 0.35
            case 1.0: return 0.5  // Normal speed
            case 1.25: return 0.55
            case 1.5: return 0.6
            case 2.0: return 0.65
            default: return 0.5
            }
        }()
        
        utterance.rate = ttsRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        print("🎵 TTS playback speed: \(currentPlaybackSpeed)x (TTS rate: \(ttsRate))")
        
        // Estimate duration based on playback speed
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let baseDuration = TimeInterval(wordCount) / 2.5 // 150 words per minute at 1x speed
        duration = baseDuration / TimeInterval(currentPlaybackSpeed)
        
        currentUtterance = utterance
        currentAudioURL = nil // No file URL since we're playing directly
        isUsingSpeechSynthesis = true
        currentTime = 0
        
        synthesizer.speak(utterance)
        isPlaying = true
        startSpeechTimer()
        disableIdleTimer()  // Prevent phone from sleeping during TTS playback
        
        print("🎵 TTS playback started, estimated duration: \(duration) seconds")
    }
    
    func stopAudio() {
        if isUsingSpeechSynthesis {
            synthesizer.stopSpeaking(at: .immediate)
            stopSpeechTimer()
        } else {
            audioPlayer?.stop()
            stopPlaybackTimer()
        }
        isPlaying = false
        currentTime = 0
        isUsingSpeechSynthesis = false
        enableIdleTimer()  // Re-enable idle timer when stopping
    }
    
    func pauseAudio() {
        if isUsingSpeechSynthesis {
            synthesizer.pauseSpeaking(at: .immediate)
            stopSpeechTimer()
        } else {
            audioPlayer?.pause()
            stopPlaybackTimer()
        }
        isPlaying = false
        enableIdleTimer()  // Re-enable idle timer when pausing
    }
    
    func resumeAudio() {
        if isUsingSpeechSynthesis {
            synthesizer.continueSpeaking()
            startSpeechTimer()
            isPlaying = true
            disableIdleTimer()  // Disable idle timer when resuming
        } else {
            guard let player = audioPlayer else { return }
            if player.play() {
                isPlaying = true
                startPlaybackTimer()
                disableIdleTimer()  // Disable idle timer when resuming
            }
        }
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        currentPlaybackSpeed = speed
        
        if let player = audioPlayer {
            // For AVAudioPlayer
            player.rate = speed
            print("🎵 Set AVAudioPlayer rate to: \(speed)x")
        }
        
        if isUsingSpeechSynthesis && currentUtterance != nil {
            // For TTS, we need to restart with new rate since we can't change mid-playback
            print("🎵 TTS rate change requires restart (not supported mid-playback)")
        }
    }
    
    func seek(to time: TimeInterval) {
        print("🎵 Seeking to: \(time) seconds")
        
        // This method should only be called for MP3 files now
        // TTS seeking is blocked at the UI level
        if let player = audioPlayer, player.duration > 0 {
            let seekTime = min(max(time, 0), player.duration)
            print("🎵 MP3 seeking - using AVAudioPlayer to time: \(seekTime)")
            player.currentTime = seekTime
            currentTime = seekTime
            print("🎵 Seek completed - new time: \(currentTime)")
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
    
    private func startSpeechTimer() {
        speechTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isUsingSpeechSynthesis, self.isPlaying else { return }
            self.currentTime += 0.1
            // Cap the current time at duration to prevent going over
            if self.currentTime > self.duration {
                self.currentTime = self.duration
            }
        }
    }
    
    private func stopSpeechTimer() {
        speechTimer?.invalidate()
        speechTimer = nil
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
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🎵 Speech synthesis started")
        isPlaying = true
        startSpeechTimer()
        disableIdleTimer()  // Ensure idle timer is disabled when TTS starts
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🎵 Speech synthesis finished")
        isPlaying = false
        currentTime = 0
        stopSpeechTimer()
        isUsingSpeechSynthesis = false
        enableIdleTimer()  // Re-enable idle timer when TTS finishes
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🎵 Speech synthesis cancelled")
        isPlaying = false
        currentTime = 0
        stopSpeechTimer()
        isUsingSpeechSynthesis = false
        enableIdleTimer()  // Re-enable idle timer when TTS is cancelled
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("🎵 Speech synthesis paused")
        isPlaying = false
        stopSpeechTimer()
        enableIdleTimer()  // Re-enable idle timer when TTS is paused
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("🎵 Speech synthesis continued")
        isPlaying = true
        startSpeechTimer()
        disableIdleTimer()  // Disable idle timer when TTS continues
    }
}

