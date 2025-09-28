//
//  AudioRegenerationView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData

enum AudioGenerationStage: Equatable {
    case preparing
    case generating
    case finalizing
    case completed
    case failed(String)

    var statusMessage: String {
        switch self {
        case .preparing:
            return "Preparing story..."
        case .generating:
            return "Generating audio..."
        case .finalizing:
            return "Finalizing audio file..."
        case .completed:
            return "Audio ready!"
        case .failed(let error):
            return error
        }
    }

    var icon: String {
        switch self {
        case .preparing:
            return "doc.text"
        case .generating:
            return "waveform"
        case .finalizing:
            return "checkmark.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var iconColor: Color {
        switch self {
        case .preparing:
            return .blue
        case .generating:
            return .purple
        case .finalizing:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

struct AudioRegenerationView: View {
    let story: Story
    let onCompletion: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = StoryViewModel()

    @State private var currentStage: AudioGenerationStage = .preparing
    @State private var progress: Double = 0.0
    @State private var showCancelConfirmation = false
    @State private var isGenerating = true
    @State private var animateProgress = false
    @State private var pulseAnimation = false

    private let totalDuration: Double = 30.0 // Estimated duration in seconds

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.1),
                        Color.blue.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // Animated icon
                    ZStack {
                        // Background circles
                        Circle()
                            .fill(currentStage.iconColor.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                                value: pulseAnimation
                            )

                        Circle()
                            .fill(currentStage.iconColor.opacity(0.2))
                            .frame(width: 150, height: 150)
                            .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(0.2),
                                value: pulseAnimation
                            )

                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                .frame(width: 120, height: 120)

                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    currentStage.iconColor,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.5), value: progress)
                        }

                        // Center icon
                        Image(systemName: currentStage.icon)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(currentStage.iconColor)
                            .scaleEffect(isGenerating && currentStage == .generating ? 1.0 : 1.2)
                            .animation(
                                isGenerating && currentStage == .generating ?
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                                .spring(response: 0.3, dampingFraction: 0.6),
                                value: currentStage.icon
                            )
                    }

                    // Status text
                    VStack(spacing: 12) {
                        Text(currentStage.statusMessage)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut, value: currentStage.statusMessage)

                        if case .failed = currentStage {
                            // Error state
                        } else if currentStage != .completed {
                            Text("This may take about 30 seconds")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Progress percentage
                        if isGenerating && currentStage != .completed {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(currentStage.iconColor)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Action buttons
                    VStack(spacing: 16) {
                        if case .completed = currentStage {
                            Button(action: {
                                onCompletion?()
                                dismiss()
                            }) {
                                Label("Play Story", systemImage: "play.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }

                            Button("Done") {
                                dismiss()
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                        } else if case .failed = currentStage {
                            Button(action: retryGeneration) {
                                Label("Try Again", systemImage: "arrow.clockwise")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }

                            Button("Cancel") {
                                dismiss()
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                        } else {
                            Button("Cancel") {
                                if progress > 0.5 {
                                    showCancelConfirmation = true
                                } else {
                                    cancelGeneration()
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                startGeneration()
            }
            .onDisappear {
                if isGenerating {
                    IdleTimerManager.shared.enableIdleTimer(for: "AudioRegeneration")
                }
            }
            .alert("Cancel Audio Generation?", isPresented: $showCancelConfirmation) {
                Button("Continue", role: .cancel) { }
                Button("Cancel Generation", role: .destructive) {
                    cancelGeneration()
                }
            } message: {
                Text("Audio generation is more than halfway complete. Are you sure you want to cancel?")
            }
        }
    }

    private func startGeneration() {
        viewModel.setModelContext(modelContext)
        viewModel.refreshAIService()

        // Start animations
        withAnimation {
            pulseAnimation = true
        }

        // Disable idle timer
        IdleTimerManager.shared.disableIdleTimer(for: "AudioRegeneration")

        // Start generation process
        Task {
            await performGeneration()
        }

        // Simulate progress
        simulateProgress()
    }

    private func performGeneration() async {
        // Stage 1: Preparing
        await updateStage(.preparing)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Stage 2: Generating
        await updateStage(.generating)

        // Perform actual generation
        await viewModel.regenerateAudioForStory(story)

        // Check if generation was successful
        if story.audioFileName != nil && !story.audioNeedsRegeneration {
            // Stage 3: Finalizing
            await updateStage(.finalizing)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Stage 4: Completed
            await updateStage(.completed)
            await completeGeneration()
        } else if let error = viewModel.generationError {
            await updateStage(.failed(error))
            await failGeneration()
        } else {
            await updateStage(.failed("Audio generation failed. Please try again."))
            await failGeneration()
        }
    }

    @MainActor
    private func updateStage(_ stage: AudioGenerationStage) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStage = stage
        }

        // Update progress based on stage
        switch stage {
        case .preparing:
            progress = 0.1
        case .generating:
            // Progress will be animated
            break
        case .finalizing:
            progress = 0.9
        case .completed:
            progress = 1.0
        case .failed:
            // Keep current progress
            break
        }
    }

    private func simulateProgress() {
        guard isGenerating else { return }

        Task {
            for i in 1...80 {
                guard isGenerating else { break }

                try? await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000 / 80))

                await MainActor.run {
                    if currentStage == .generating {
                        withAnimation(.linear(duration: 0.1)) {
                            progress = 0.1 + (0.8 * Double(i) / 80.0)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func completeGeneration() {
        isGenerating = false
        pulseAnimation = false

        // Re-enable idle timer
        IdleTimerManager.shared.enableIdleTimer(for: "AudioRegeneration")

        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor
    private func failGeneration() {
        isGenerating = false
        pulseAnimation = false

        // Re-enable idle timer
        IdleTimerManager.shared.enableIdleTimer(for: "AudioRegeneration")

        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func cancelGeneration() {
        // TODO: Implement actual cancellation when URLSessionTask reference is available
        isGenerating = false
        pulseAnimation = false

        // Re-enable idle timer
        IdleTimerManager.shared.enableIdleTimer(for: "AudioRegeneration")

        dismiss()
    }

    private func retryGeneration() {
        currentStage = .preparing
        progress = 0.0
        isGenerating = true
        pulseAnimation = true
        startGeneration()
    }
}

// Preview
struct AudioRegenerationView_Previews: PreviewProvider {
    static var previews: some View {
        let story = Story(
            title: "Test Story",
            content: "Once upon a time...",
            event: .bedtime,
            hero: Hero(name: "Luna", primaryTrait: .brave, secondaryTrait: .magical)
        )

        AudioRegenerationView(story: story, onCompletion: nil)
            .modelContainer(for: Story.self, inMemory: true)
    }
}
