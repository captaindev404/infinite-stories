//
//  StoryGenerationView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData

struct StoryGenerationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let hero: Hero
    
    @StateObject private var viewModel = StoryViewModel()
    @State private var appSettings = AppSettings()
    @State private var selectedBuiltInEvent: StoryEvent? = .bedtime
    @State private var selectedCustomEvent: CustomStoryEvent? = nil
    @State private var showingEventPicker = false
    @State private var showIllustrationProgress = false
    @State private var dismissOnComplete = true
    @State private var generatedStory: Story?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 15) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("story.generation.title")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(String(localized: "story.generation.subtitle.\(hero.name)"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Hero info
                HeroInfoCard(hero: hero)
                
                // Event selection
                VStack(spacing: 15) {
                    Text("story.generation.adventure.prompt")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Button(action: { showingEventPicker = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(eventTitle)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(eventDescription.capitalized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                // Illustration Options (only show if feature enabled and hero has avatar)
                if AppConfiguration.enableStoryIllustrations && hero.hasAvatar {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "photo.artframe")
                                .foregroundColor(.purple)
                            Text("story.generation.visual.options")
                                .font(.headline)
                            Spacer()
                        }

                        Toggle(isOn: $viewModel.enableIllustrations) {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.enableIllustrations ? "sparkles.rectangle.stack.fill" : "rectangle.stack")
                                    .foregroundColor(viewModel.enableIllustrations ? .purple : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("story.generation.illustrations.toggle")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("story.generation.illustrations.description")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.automatic)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                        if viewModel.enableIllustrations {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("story.generation.illustrations.info")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
                
                // Generation status with sequential progress
                if viewModel.generationStage.isInProgress {
                    VStack(spacing: 20) {
                        // Spinning indicator
                        ProgressView()
                            .scaleEffect(1.2)

                        // Stage indicator
                        Text(viewModel.generationStage.displayText)
                            .font(.headline)
                            .foregroundColor(.primary)

                        // Step progress indicator
                        HStack(spacing: 8) {
                            StepIndicator(
                                step: 1,
                                label: String(localized: "story.generation.step.story"),
                                icon: "doc.text.fill",
                                isActive: viewModel.generationStage == .generatingStory,
                                isCompleted: stepCompleted(1)
                            )

                            StepConnector(isCompleted: stepCompleted(1))

                            StepIndicator(
                                step: 2,
                                label: String(localized: "story.generation.step.audio"),
                                icon: "speaker.wave.2.fill",
                                isActive: viewModel.generationStage == .generatingAudio,
                                isCompleted: stepCompleted(2)
                            )

                            if viewModel.enableIllustrations && hero.hasAvatar {
                                StepConnector(isCompleted: stepCompleted(2))

                                StepIndicator(
                                    step: 3,
                                    label: String(localized: "story.generation.step.images"),
                                    icon: "photo.fill",
                                    isActive: viewModel.generationStage == .generatingIllustrations,
                                    isCompleted: stepCompleted(3)
                                )
                            }
                        }
                        .padding(.horizontal, 30)

                        // Overall progress bar
                        VStack(spacing: 6) {
                            ProgressView(value: viewModel.overallProgress)
                                .progressViewStyle(.linear)
                                .frame(width: 220)
                                .tint(.orange)

                            Text(String(localized: "story.generation.progress.complete", defaultValue: "\(Int(viewModel.overallProgress * 100))% complete"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Substage text for illustrations
                        if viewModel.isGeneratingIllustrations && !viewModel.illustrationGenerationStage.isEmpty {
                            Text(viewModel.illustrationGenerationStage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("story.generation.progress.wait")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(16)
                    .padding(.horizontal)
                } else {
                    // Generate button
                    VStack(spacing: 15) {
                        Button(action: generateStory) {
                            Label("story.generation.button.generate", systemImage: "wand.and.stars")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Illustration errors
                if !viewModel.illustrationErrors.isEmpty {
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("story.generation.illustrations.error.title")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        Text("story.generation.illustrations.error.message")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                // Error message with step-specific retry
                if viewModel.generationStage.isFailed,
                   let failedStep = viewModel.generationStage.failedStep,
                   let errorMessage = viewModel.generationStage.errorMessage {
                    VStack(spacing: 15) {
                        // Error header with step icon
                        HStack(spacing: 10) {
                            Image(systemName: failedStep.icon)
                                .font(.title2)
                                .foregroundColor(.red)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "story.generation.error.failed", defaultValue: "\(failedStep.displayName) Failed"))
                                    .font(.headline)
                                    .foregroundColor(.red)

                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }

                        // Progress summary - show what was completed
                        if failedStep != .story {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("story.generation.error.story.success")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }

                            if failedStep == .illustrations {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("story.generation.error.audio.success")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }

                        Divider()

                        // Action buttons
                        HStack(spacing: 12) {
                            // Retry button
                            Button(action: {
                                Task {
                                    await viewModel.continueFromFailedStep(hero: hero)

                                    // Check for completion after retry
                                    if viewModel.generationStage == .completed {
                                        if let story = viewModel.currentStory {
                                            generatedStory = story
                                            try? await Task.sleep(nanoseconds: 500_000_000)
                                            dismiss()
                                        }
                                    }
                                }
                            }) {
                                Label(failedStep.retryButtonText, systemImage: "arrow.clockwise")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.orange)
                                    .cornerRadius(8)
                            }

                            // Skip button (only for audio/illustrations)
                            if viewModel.canSkipFailedStep {
                                Button(action: {
                                    viewModel.skipFailedStep()

                                    // If skipped to completed, dismiss
                                    if viewModel.generationStage == .completed {
                                        if let story = viewModel.currentStory {
                                            generatedStory = story
                                            dismiss()
                                        }
                                    }
                                }) {
                                    Label("story.generation.button.skip", systemImage: "forward.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                }
                            }

                            // Cancel button
                            Button(action: {
                                viewModel.clearError()
                                dismiss()
                            }) {
                                Text("story.generation.button.cancel")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEventPicker) {
                EnhancedEventPickerView(
                    selectedBuiltInEvent: $selectedBuiltInEvent,
                    selectedCustomEvent: $selectedCustomEvent
                )
            }
            .onAppear {
                viewModel.setModelContext(modelContext)
                // Note: refreshAIService() removed - all AI operations now via backend API
            }
            .sheet(isPresented: $showIllustrationProgress) {
                if let story = generatedStory {
                    IllustrationGenerationProgressView(viewModel: viewModel, story: story)
                        .interactiveDismissDisabled(viewModel.isGeneratingIllustrations)
                        .onDisappear {
                            dismiss()
                        }
                }
            }
        }
    }
    
    private func generateStory() {
        Task {
            // Start the sequential generation
            if let builtInEvent = selectedBuiltInEvent {
                await viewModel.generateStory(for: hero, event: builtInEvent)
            } else if let customEvent = selectedCustomEvent {
                await viewModel.generateStory(for: hero, customEvent: customEvent)
            }

            // Handle completion
            switch viewModel.generationStage {
            case .completed:
                // All generation steps completed successfully
                if let story = viewModel.currentStory {
                    generatedStory = story

                    // Brief delay to show completion state
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                    // Dismiss the view
                    dismiss()
                } else {
                    dismiss()
                }

            case .failed:
                // Error state - don't dismiss, let user see the error
                break

            default:
                // Still in progress or idle - should not reach here normally
                break
            }
        }
    }
    
    private var eventTitle: String {
        if let builtIn = selectedBuiltInEvent {
            return builtIn.rawValue
        } else if let custom = selectedCustomEvent {
            return custom.title
        }
        return String(localized: "story.generation.event.select")
    }
    
    private var eventDescription: String {
        if let builtIn = selectedBuiltInEvent {
            return builtIn.promptSeed
        } else if let custom = selectedCustomEvent {
            return custom.description
        }
        return String(localized: "story.generation.event.choose")
    }

    private var generationStatusText: String {
        if viewModel.isGeneratingIllustrations {
            return String(localized: "story.generation.status.illustrations")
        } else if viewModel.isGeneratingAudio {
            return String(localized: "story.generation.status.audio")
        } else {
            return String(localized: "story.generation.status.story")
        }
    }

    /// Helper to determine if a step has been completed
    private func stepCompleted(_ step: Int) -> Bool {
        switch viewModel.generationStage {
        case .idle:
            return false
        case .generatingStory:
            return false
        case .generatingAudio:
            return step < 2
        case .generatingIllustrations:
            return step < 3
        case .completed:
            return true
        case .failed:
            return false
        }
    }
}

// MARK: - Step Progress Indicator Views

/// Individual step indicator circle with label
struct StepIndicator: View {
    let step: Int
    let label: String
    let icon: String
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isActive ? .white : .secondary)
                }
            }
            .overlay(
                Circle()
                    .stroke(isActive ? Color.orange : Color.clear, lineWidth: 3)
                    .frame(width: 46, height: 46)
            )
            .animation(.easeInOut(duration: 0.3), value: isActive)
            .animation(.easeInOut(duration: 0.3), value: isCompleted)

            Text(label)
                .font(.caption2)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundColor(isActive || isCompleted ? .primary : .secondary)
        }
    }

    private var backgroundColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .orange
        } else {
            return Color(.systemGray4)
        }
    }
}

/// Connector line between step indicators
struct StepConnector: View {
    let isCompleted: Bool

    var body: some View {
        Rectangle()
            .fill(isCompleted ? Color.green : Color(.systemGray4))
            .frame(width: 30, height: 3)
            .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

struct HeroInfoCard: View {
    let hero: Hero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("story.generation.hero.label")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                HeroAvatarImageView.medium(hero)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(hero.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(hero.traitsDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !hero.specialAbility.isEmpty {
                        Text(String(localized: "story.generation.hero.special", defaultValue: "Special: \(hero.specialAbility)"))
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

struct EventPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEvent: StoryEvent
    
    var body: some View {
        NavigationView {
            List(StoryEvent.allCases, id: \.self) { event in
                Button(action: {
                    selectedEvent = event
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(event.promptSeed.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if event == selectedEvent {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("story.generation.event.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let hero = Hero(
        name: "Luna",
        primaryTrait: .brave,
        secondaryTrait: .magical,
        appearance: "sparkly blue eyes",
        specialAbility: "create beautiful dreams"
    )
    
    return StoryGenerationView(hero: hero)
        .modelContainer(for: Hero.self, inMemory: true)
}