//
//  IllustrationSyncView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 16/09/2025.
//

import SwiftUI
import Combine

/// Synchronizes illustration display with audio playback timing
struct IllustrationSyncView: View {
    let story: Story
    @Binding var currentTime: TimeInterval
    @Binding var isPlaying: Bool
    let onRetryIllustration: ((StoryIllustration) -> Void)?

    @State private var currentIllustration: StoryIllustration?
    @State private var nextIllustration: StoryIllustration?
    @State private var transitionProgress: Double = 0
    @State private var showTransition: Bool = false

    // Animation control
    @State private var illustrationOpacity: Double = 1.0
    @State private var illustrationScale: CGFloat = 1.0
    @State private var timer: Timer?

    // Haptics
    private let hapticFeedback = UINotificationFeedbackGenerator()

    // Settings
    @AppStorage("allowIllustrationFailures") private var allowFailures = true

    init(
        story: Story,
        currentTime: Binding<TimeInterval>,
        isPlaying: Binding<Bool>,
        onRetryIllustration: ((StoryIllustration) -> Void)? = nil
    ) {
        self.story = story
        self._currentTime = currentTime
        self._isPlaying = isPlaying
        self.onRetryIllustration = onRetryIllustration
    }

    var body: some View {
        ZStack {
            if let current = currentIllustration {
                // Current illustration
                illustrationView(for: current)
                    .opacity(showTransition ? 1.0 - transitionProgress : 1.0)
                    .scaleEffect(illustrationScale)
                    .animation(.easeInOut(duration: 0.5), value: illustrationScale)
            }

            if showTransition, let next = nextIllustration {
                // Transitioning illustration
                illustrationView(for: next)
                    .opacity(transitionProgress)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale),
                        removal: .opacity
                    ))
            }

            // Overlay with timing information
            VStack {
                HStack {
                    if let current = currentIllustration {
                        TimingBadge(
                            sceneNumber: current.displayOrder + 1,
                            timestamp: current.formattedTimestamp,
                            isActive: true
                        )
                    }

                    Spacer()

                    if let next = nextIllustration {
                        TimingBadge(
                            sceneNumber: next.displayOrder + 1,
                            timestamp: next.formattedTimestamp,
                            isActive: false
                        )
                        .opacity(0.6)
                    }
                }
                .padding()

                Spacer()

                // Progress to next illustration
                if let next = nextIllustration {
                    TransitionProgressBar(
                        currentTime: currentTime,
                        nextTimestamp: next.timestamp,
                        previousTimestamp: currentIllustration?.timestamp ?? 0
                    )
                    .padding()
                }
            }
        }
        .onAppear {
            setupSync()
        }
        .onDisappear {
            cleanupSync()
        }
        .onChange(of: currentTime) { newTime in
            updateCurrentIllustration(for: newTime)
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                resumeAnimations()
            } else {
                pauseAnimations()
            }
        }
    }

    @ViewBuilder
    private func illustrationView(for illustration: StoryIllustration) -> some View {
        if illustration.isPlaceholder {
            // Show beautiful placeholder for failed illustrations
            IllustrationPlaceholderView(
                sceneNumber: illustration.displayOrder + 1,
                errorType: convertToGlobalErrorType(illustration.typedError),
                onRetry: onRetryIllustration != nil ? {
                    onRetryIllustration?(illustration)
                    hapticFeedback.notificationOccurred(.success)
                } : nil
            )
        } else if illustration.isGenerated, let imageURL = illustration.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .overlay(
                            // Subtle vignette
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.black.opacity(0.2)
                                ]),
                                center: .center,
                                startRadius: 200,
                                endRadius: 400
                            )
                        )
                case .failure:
                    // Show placeholder for loading failure
                    IllustrationPlaceholderView(
                        sceneNumber: illustration.displayOrder + 1,
                        errorType: .fileSystem,
                        onRetry: onRetryIllustration != nil ? {
                            onRetryIllustration?(illustration)
                        } : nil
                    )
                default:
                    IllustrationLoadingView(
                        sceneNumber: illustration.displayOrder + 1,
                        progress: nil
                    )
                }
            }
        } else {
            // Show loading view for pending illustrations
            IllustrationLoadingView(
                sceneNumber: illustration.displayOrder + 1,
                progress: nil
            )
        }
    }

    // MARK: - Sync Management

    private func setupSync() {
        // Initialize with current illustration
        updateCurrentIllustration(for: currentTime)

        // Start animation timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateTransitionProgress()
        }
    }

    private func cleanupSync() {
        timer?.invalidate()
        timer = nil
    }

    private func updateCurrentIllustration(for timestamp: TimeInterval) {
        // Filter out failed illustrations if setting doesn't allow them
        let availableIllustrations = allowFailures
            ? story.illustrations
            : story.illustrations.filter { !$0.isPlaceholder }

        let newCurrent = availableIllustrations
            .filter { timestamp >= $0.timestamp }
            .sorted { $0.timestamp > $1.timestamp }
            .first

        let newNext = availableIllustrations
            .filter { timestamp < $0.timestamp }
            .sorted { $0.timestamp < $1.timestamp }
            .first

        if newCurrent?.id != currentIllustration?.id {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIllustration = newCurrent
                nextIllustration = newNext
                showTransition = false
                transitionProgress = 0

                // Only haptic feedback for successful illustrations
                if newCurrent?.isGenerated == true {
                    hapticFeedback.notificationOccurred(.success)
                }

                // Trigger entrance animation
                illustrationScale = 0.95
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    illustrationScale = 1.0
                }
            }
        } else if newNext?.id != nextIllustration?.id {
            nextIllustration = newNext
        }
    }

    private func updateTransitionProgress() {
        guard let next = nextIllustration else { return }

        let timeToNext = next.timestamp - currentTime
        let transitionDuration = 1.0 // Start transition 1 second before

        if timeToNext <= transitionDuration && timeToNext > 0 {
            withAnimation(.linear(duration: 0.1)) {
                showTransition = true
                transitionProgress = 1.0 - (timeToNext / transitionDuration)
            }
        }
    }

    private func pauseAnimations() {
        timer?.invalidate()
    }

    private func resumeAnimations() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateTransitionProgress()
        }
    }

    // MARK: - Helper Functions

    private func convertToGlobalErrorType(_ storyError: StoryIllustration.IllustrationErrorType?) -> IllustrationErrorType {
        guard let storyError = storyError else { return .unknown }

        switch storyError {
        case .network:
            return .network
        case .invalidPrompt:
            return .invalidPrompt
        case .rateLimit:
            return .rateLimit
        case .apiError:
            return .apiError
        case .timeout:
            return .timeout
        case .fileSystem:
            return .fileSystem
        case .unknown:
            return .unknown
        }
    }
}

// MARK: - Supporting Views

struct TimingBadge: View {
    let sceneNumber: Int
    let timestamp: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isActive ? "play.fill" : "pause.fill")
                .font(.caption2)

            Text("Scene \(sceneNumber)")
                .font(.caption)
                .fontWeight(.semibold)

            Text("•")

            Text(timestamp)
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundColor(isActive ? .white : .white.opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isActive ? Color.orange : Color.gray)
                .opacity(0.9)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct TransitionProgressBar: View {
    let currentTime: TimeInterval
    let nextTimestamp: TimeInterval
    let previousTimestamp: TimeInterval

    private var progress: Double {
        let totalDuration = nextTimestamp - previousTimestamp
        let elapsed = currentTime - previousTimestamp
        return min(max(elapsed / totalDuration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)

                    // Progress
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 4)

            // Time remaining
            HStack {
                Text("Next scene in:")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))

                Text(formatTimeRemaining(nextTimestamp - currentTime))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
        )
    }

    private func formatTimeRemaining(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Illustration Timeline View

struct IllustrationTimelineView: View {
    let illustrations: [StoryIllustration]
    let totalDuration: TimeInterval
    @Binding var currentTime: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Timeline track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)

                // Progress track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange)
                    .frame(width: (currentTime / totalDuration) * geometry.size.width, height: 4)

                // Illustration markers
                ForEach(illustrations, id: \.id) { illustration in
                    IllustrationMarker(
                        illustration: illustration,
                        position: (illustration.timestamp / totalDuration) * geometry.size.width,
                        isActive: currentTime >= illustration.timestamp
                    )
                }

                // Current position indicator
                Circle()
                    .fill(Color.purple)
                    .frame(width: 12, height: 12)
                    .position(
                        x: (currentTime / totalDuration) * geometry.size.width,
                        y: geometry.size.height / 2
                    )
                    .shadow(color: .purple.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 20)
    }
}

struct IllustrationMarker: View {
    let illustration: StoryIllustration
    let position: CGFloat
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? Color.orange : Color.gray)
            .frame(width: 8, height: 8)
            .position(x: position, y: 10)
            .onTapGesture {
                // Could trigger jump to this illustration
            }
    }
}

// MARK: - Preview

#Preview {
    IllustrationSyncView(
        story: Story(
            title: "Test Story",
            content: "Story content",
            event: .bedtime,
            hero: Hero(name: "Luna", primaryTrait: .brave, secondaryTrait: .magical)
        ),
        currentTime: .constant(30),
        isPlaying: .constant(true),
        onRetryIllustration: nil
    )
}