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
    @StateObject private var appSettings = AppSettings()
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
                    
                    Text("Generate New Story")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Create a magical adventure for \(hero.name)!")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Hero info
                HeroInfoCard(hero: hero)
                
                // Event selection
                VStack(spacing: 15) {
                    Text("What kind of adventure?")
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

                // Illustration Options (only show if hero has avatar)
                if hero.hasAvatar {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "photo.artframe")
                                .foregroundColor(.purple)
                            Text("Visual Story Options")
                                .font(.headline)
                            Spacer()
                        }

                        Toggle(isOn: $viewModel.enableIllustrations) {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.enableIllustrations ? "sparkles.rectangle.stack.fill" : "rectangle.stack")
                                    .foregroundColor(viewModel.enableIllustrations ? .purple : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Generate Illustrations")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Add beautiful AI-generated images to your story")
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
                                Text("Illustrations will be generated after the story is created")
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
                
                // Generation status
                if viewModel.isGeneratingStory || viewModel.isGeneratingIllustrations {
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.2)

                        Text(generationStatusText)
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if viewModel.isGeneratingIllustrations {
                            Text(viewModel.illustrationGenerationStage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if viewModel.illustrationGenerationProgress > 0 {
                                ProgressView(value: viewModel.illustrationGenerationProgress)
                                    .progressViewStyle(.linear)
                                    .frame(width: 200)
                            }
                        } else {
                            Text("This may take a moment")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } else {
                    // Generate button
                    VStack(spacing: 15) {
                        if !appSettings.hasValidAPIKey {
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("API Key Required")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                
                                Text("You need to configure your OpenAI API key in Settings to generate stories.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        Button(action: generateStory) {
                            Label("Generate Story", systemImage: "wand.and.stars")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(appSettings.hasValidAPIKey ? Color.orange : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!appSettings.hasValidAPIKey)
                    }
                    .padding(.horizontal)
                }
                
                // Illustration errors
                if !viewModel.illustrationErrors.isEmpty {
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Some illustrations couldn't be generated")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        Text("Your story was created successfully, but some images may be missing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                // Error message
                if let error = viewModel.generationError {
                    VStack(spacing: 10) {
                        Text("Oops! Something went wrong")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            viewModel.clearError()
                        }
                        .buttonStyle(.bordered)
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
                viewModel.refreshAIService() // Refresh AI service to get latest API key
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
            if let builtInEvent = selectedBuiltInEvent {
                await viewModel.generateStory(for: hero, event: builtInEvent)
            } else if let customEvent = selectedCustomEvent {
                await viewModel.generateStory(for: hero, customEvent: customEvent)
            }

            // If successful, handle post-generation
            if viewModel.generationError == nil {
                // Get the generated story
                if let story = viewModel.currentStory {
                    generatedStory = story

                    // Show illustration progress if generating
                    if viewModel.enableIllustrations && hero.hasAvatar && viewModel.isGeneratingIllustrations {
                        showIllustrationProgress = true
                    } else {
                        // No illustrations, just dismiss
                        dismiss()
                    }
                } else {
                    // No story found, just dismiss
                    dismiss()
                }
            }
        }
    }
    
    private var eventTitle: String {
        if let builtIn = selectedBuiltInEvent {
            return builtIn.rawValue
        } else if let custom = selectedCustomEvent {
            return custom.title
        }
        return "Select an Event"
    }
    
    private var eventDescription: String {
        if let builtIn = selectedBuiltInEvent {
            return builtIn.promptSeed
        } else if let custom = selectedCustomEvent {
            return custom.eventDescription
        }
        return "Choose an adventure type"
    }

    private var generationStatusText: String {
        if viewModel.isGeneratingIllustrations {
            return "Creating illustrations..."
        } else if viewModel.isGeneratingAudio {
            return "Creating audio..."
        } else {
            return "Writing your story..."
        }
    }
}

struct HeroInfoCard: View {
    let hero: Hero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Hero")
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
                        Text("Special: \(hero.specialAbility)")
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
            .navigationTitle("Choose Adventure")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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