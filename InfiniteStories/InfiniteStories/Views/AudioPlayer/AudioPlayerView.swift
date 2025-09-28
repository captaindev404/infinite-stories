//
//  AudioPlayerView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData
import UIKit

struct AudioPlayerView: View {
    let initialStory: Story
    let allStories: [Story]?
    let storyIndex: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = StoryViewModel()
    @State private var showingFullText = false
    @State private var showingEditView = false
    @State private var showingShareSheet = false
    @State private var audioFileURL: URL?
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""
    @State private var exportMetadata: [String: Any] = [:]
    @State private var showIllustrations = true // Toggle to show/hide illustrations
    @State private var preferCompactLayout = false // For smaller devices

    // Animation states
    @State private var playButtonPressed = false
    @State private var skipForwardPressed = false
    @State private var skipBackwardPressed = false
    @State private var previousButtonPressed = false
    @State private var nextButtonPressed = false

    init(story: Story, allStories: [Story]? = nil, storyIndex: Int? = nil) {
        self.initialStory = story
        self.allStories = allStories
        self.storyIndex = storyIndex

        // Force load illustrations relationship immediately (SwiftData lazy loading workaround)
        _ = story.illustrations.count
    }

    // Computed property to get the current story being played
    private var currentStory: Story {
        // If we're in queue mode and have a current story, use it
        // Otherwise fall back to the initial story
        let story = viewModel.currentStory ?? initialStory

        // Force load illustrations relationship if needed (SwiftData lazy loading workaround)
        _ = story.illustrations.count

        return story
    }
    
    var body: some View {
        if currentStory.title.isEmpty && currentStory.content.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Story data is missing")
                    .font(.headline)

                Text("This story appears to have no content")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let isCompact = geometry.size.height < 700 || preferCompactLayout
                let illustrationHeight = isCompact ? geometry.size.height * 0.35 : geometry.size.height * 0.45

                // Landscape Layout
                if isLandscape && showIllustrations && currentStory.hasIllustrations {
                    HStack(spacing: 0) {
                        // Left side: Illustrations
                        ZStack {
                            // Background gradient
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.purple.opacity(0.05),
                                    Color.orange.opacity(0.03)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                            // Illustration Carousel with sync support
                            IllustrationCarouselView(
                                illustrations: currentStory.sortedIllustrations,
                                currentTime: $viewModel.currentTime,
                                onRetryIllustration: { illustration in
                                    Task {
                                        await viewModel.retryFailedIllustration(illustration)
                                    }
                                },
                                onSeekToIllustration: { timestamp in
                                    // Only seek if audio is loaded and has duration
                                    if viewModel.duration > 0 {
                                        viewModel.seek(to: timestamp)
                                    }
                                }
                            )
                            .onAppear {
                                print("🖼️ === iPad IllustrationCarousel appeared ===")
                                print("🖼️ Current story: '\(currentStory.title)'")
                                print("🖼️ Total illustrations: \(currentStory.illustrations.count)")
                                print("🖼️ Sorted illustrations: \(currentStory.sortedIllustrations.count)")
                                print("🖼️ Generated illustrations: \(currentStory.generatedIllustrations.count)")
                                print("🖼️ Has illustrations: \(currentStory.hasIllustrations)")
                                for (idx, ill) in currentStory.sortedIllustrations.enumerated() {
                                    print("🖼️   [\(idx)] generated: \(ill.isGenerated), path: \(ill.imagePath ?? "nil")")
                                }
                                print("🖼️ ===========================")
                            }
                        }
                        .frame(width: geometry.size.width * 0.5)
                        .clipped()

                        Divider()

                        // Right side: Controls
                        landscapeControlsView(geometry: geometry, isCompact: true)
                            .frame(width: geometry.size.width * 0.5)
                    }
                } else {
                    // Portrait Layout
                    VStack(spacing: 0) {
                    // Illustration Section (if enabled and available)
                    if showIllustrations && currentStory.hasIllustrations {
                        ZStack {
                            // Background gradient
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.purple.opacity(0.05),
                                    Color.orange.opacity(0.03)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                            // Illustration Carousel with sync support
                            IllustrationCarouselView(
                                illustrations: currentStory.sortedIllustrations,
                                currentTime: $viewModel.currentTime,
                                onRetryIllustration: { illustration in
                                    Task {
                                        await viewModel.retryFailedIllustration(illustration)
                                    }
                                },
                                onSeekToIllustration: { timestamp in
                                    // Only seek if audio is loaded and has duration
                                    if viewModel.duration > 0 {
                                        viewModel.seek(to: timestamp)
                                    }
                                }
                            )
                            .onAppear {
                                print("🖼️ === iPhone IllustrationCarousel appeared ===")
                                print("🖼️ Current story: '\(currentStory.title)'")
                                print("🖼️ Total illustrations: \(currentStory.illustrations.count)")
                                print("🖼️ Sorted illustrations: \(currentStory.sortedIllustrations.count)")
                                print("🖼️ Generated illustrations: \(currentStory.generatedIllustrations.count)")
                                print("🖼️ Has illustrations: \(currentStory.hasIllustrations)")
                                for (idx, ill) in currentStory.sortedIllustrations.enumerated() {
                                    print("🖼️   [\(idx)] generated: \(ill.isGenerated), path: \(ill.imagePath ?? "nil")")
                                }
                                print("🖼️ ===========================")
                            }
                        }
                        .frame(height: illustrationHeight)
                        .clipped()
                        .overlay(
                            // Top gradient fade
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color(.systemBackground).opacity(0.8), location: 0),
                                    .init(color: Color(.systemBackground).opacity(0), location: 0.15)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 30)
                            .allowsHitTesting(false),
                            alignment: .top
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showIllustrations)
                    } else if showIllustrations && !currentStory.hasIllustrations {
                        // Placeholder when no illustrations available
                        VStack(spacing: 16) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))

                            Text("No illustrations available")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Generate illustrations to enhance the story")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: illustrationHeight * 0.6)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6).opacity(0.3))
                    }

                    // Story Info Header
                    VStack(spacing: 8) {
                        // Title and Hero
                        VStack(spacing: 4) {
                            Text(currentStory.title)
                                .font(isCompact ? .headline : .title3)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            if let hero = currentStory.hero {
                                Text("Featuring \(hero.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, isCompact ? 8 : 12)

                        // Controls Bar
                        HStack(spacing: 20) {
                            // Illustration Toggle (if illustrations exist)
                            if currentStory.hasIllustrations {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showIllustrations.toggle()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: showIllustrations ? "photo.fill" : "photo")
                                            .font(.system(size: 14))
                                        Text(showIllustrations ? "Hide" : "Show")
                                            .font(.caption)
                                    }
                                    .foregroundColor(showIllustrations ? .orange : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(showIllustrations ? Color.orange.opacity(0.15) : Color(.systemGray6))
                                    )
                                }
                            }

                            // Compact Layout Toggle (for iPads and larger screens)
                            if geometry.size.height > 700 {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        preferCompactLayout.toggle()
                                    }
                                }) {
                                    Image(systemName: preferCompactLayout ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Story Info
                            HStack(spacing: 12) {
                                if !currentStory.content.isEmpty {
                                    Label("\(wordCount) words", systemImage: "text.word.spacing")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Label("\(currentStory.playCount)", systemImage: "play.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground))

                    // Divider
                    Divider()

                    // Audio Controls Section
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: isCompact ? 12 : 20) {
                            // Interactive Progress Slider
                            if viewModel.duration > 0 {
                                VStack(spacing: 6) {
                                    // Interactive slider for audio playback
                                    Slider(
                                        value: Binding(
                                            get: { viewModel.currentTime },
                                            set: { newTime in
                                                viewModel.seek(to: newTime)
                                            }
                                        ),
                                        in: 0...viewModel.duration
                                    )
                                    .accentColor(.orange)

                                    HStack {
                                        Text(formatTime(viewModel.currentTime))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()

                                        Spacer()

                                        Text(formatTime(viewModel.duration))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }

                            // Main Playback Controls
                            HStack(spacing: isCompact ? 16 : 24) {
                                // Previous Story Button
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        if viewModel.isQueueMode {
                                            viewModel.playPreviousStory()
                                        } else {
                                            // Restart current story
                                            viewModel.seek(to: 0)
                                        }
                                    }
                                }) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: isCompact ? 20 : 24))
                                        .foregroundColor(canGoToPrevious ? .orange : .gray)
                                }
                                .scaleEffect(previousButtonPressed ? 0.9 : 1.0)
                                .disabled(!canGoToPrevious && viewModel.duration == 0)
                                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        previousButtonPressed = pressing
                                    }
                                }, perform: {})

                                // Skip Backward 15s
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        viewModel.skipBackward()
                                    }
                                }) {
                                    Image(systemName: "gobackward.15")
                                        .font(.system(size: isCompact ? 20 : 24))
                                        .foregroundColor(.orange)
                                }
                                .scaleEffect(skipBackwardPressed ? 0.9 : 1.0)
                                .disabled(viewModel.duration == 0)
                                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        skipBackwardPressed = pressing
                                    }
                                }, perform: {})

                                Spacer()

                                // Main Play/Pause Button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        if viewModel.isPlaying || viewModel.isPaused {
                                            viewModel.togglePlayPause()
                                        } else {
                                            viewModel.playStory(currentStory)
                                        }
                                    }
                                }) {
                                    Image(systemName: playButtonIcon)
                                        .font(.system(size: isCompact ? 48 : 56))
                                        .foregroundColor(.orange)
                                }
                                .scaleEffect(playButtonPressed ? 0.95 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: playButtonPressed)
                                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        playButtonPressed = pressing
                                    }
                                }, perform: {})

                                Spacer()

                                // Skip Forward 15s
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        viewModel.skipForward()
                                    }
                                }) {
                                    Image(systemName: "goforward.15")
                                        .font(.system(size: isCompact ? 20 : 24))
                                        .foregroundColor(.orange)
                                }
                                .scaleEffect(skipForwardPressed ? 0.9 : 1.0)
                                .disabled(viewModel.duration == 0)
                                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        skipForwardPressed = pressing
                                    }
                                }, perform: {})

                                // Next Story Button
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        if viewModel.isQueueMode {
                                            viewModel.playNextStory()
                                        }
                                    }
                                }) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: isCompact ? 20 : 24))
                                        .foregroundColor(canGoToNext ? .orange : .gray)
                                }
                                .scaleEffect(nextButtonPressed ? 0.9 : 1.0)
                                .disabled(!canGoToNext)
                                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        nextButtonPressed = pressing
                                    }
                                }, perform: {})
                            }
                            .padding(.horizontal, 20)

                            // Secondary Controls
                            HStack(spacing: 16) {
                                // Audio regeneration indicator
                                if currentStory.audioNeedsRegeneration {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.caption)
                                        Text("Audio outdated")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(6)
                                }

                                // Speed Control
                                Menu {
                                    Button("0.5x") { viewModel.setPlaybackSpeed(0.5) }
                                    Button("0.75x") { viewModel.setPlaybackSpeed(0.75) }
                                    Button("1.0x") { viewModel.setPlaybackSpeed(1.0) }
                                    Button("1.25x") { viewModel.setPlaybackSpeed(1.25) }
                                    Button("1.5x") { viewModel.setPlaybackSpeed(1.5) }
                                    Button("2.0x") { viewModel.setPlaybackSpeed(2.0) }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "speedometer")
                                        Text(String(format: "%.2gx", viewModel.playbackSpeed))
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(8)
                                }

                                Spacer()

                                // Stop Button (smaller, secondary)
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.stopAudio()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "stop.fill")
                                        Text("Stop")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .opacity((viewModel.isPlaying || viewModel.isPaused) ? 1.0 : 0.5)
                                .disabled(!(viewModel.isPlaying || viewModel.isPaused))
                            }
                            .padding(.horizontal)

                            // Story Text Preview (if illustrations are hidden or unavailable)
                            if !showIllustrations || !currentStory.hasIllustrations {
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "text.book.closed")
                                            .font(.caption)
                                        Text("Story Text")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        if !currentStory.content.isEmpty {
                                            Button(action: {
                                                showingFullText = true
                                            }) {
                                                Text("Read Full")
                                                    .font(.caption)
                                                    .foregroundColor(.purple)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)

                                    ScrollView {
                                        Text(currentStory.content.isEmpty ? "No story content available" : currentStory.content)
                                            .font(.system(.body, design: .serif))
                                            .lineSpacing(4)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(maxHeight: isCompact ? 100 : 150)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6).opacity(0.5))
                                    )
                                    .padding(.horizontal)
                                }
                                .padding(.top, 8)
                            }

                            // Story metadata
                            HStack {
                                Text("Created: \(currentStory.formattedDate)")
                                Spacer()
                                if currentStory.playCount > 0 {
                                    Text("Played \(currentStory.playCount) \(currentStory.playCount == 1 ? "time" : "times")")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                }
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Audio Player")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.stopAudio()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button(action: {
                            currentStory.isFavorite.toggle()
                            try? modelContext.save()
                        }) {
                            Image(systemName: currentStory.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(currentStory.isFavorite ? .red : .secondary)
                        }
                        
                        Button(action: {
                            showingEditView = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.purple)
                        }
                        
                        // Export Audio Button
                        Button(action: {
                            exportAudioFile()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(currentStory.hasAudio ? .blue : .gray)
                        }
                        .disabled(!currentStory.hasAudio && currentStory.audioFileName == nil)
                        .opacity(currentStory.hasAudio || currentStory.audioFileName != nil ? 1.0 : 0.6)
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                StoryEditView(story: currentStory)
            }
            .sheet(isPresented: $showingFullText) {
                NavigationView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(currentStory.title)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let hero = currentStory.hero {
                                Text("Featuring \(hero.name)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            Text(currentStory.content)
                                .font(.system(.body, design: .serif))
                                .lineSpacing(6)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle("Full Story")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingFullText = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let audioFileURL = audioFileURL {
                    ShareSheet(activityItems: [audioFileURL])
                }
            }
            .alert("Export Error", isPresented: $showingExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage)
            }
            .onAppear {
                print("🎵 === AudioPlayerView appeared ===")
                print("🎵 Initial story title: '\(initialStory.title)'")
                print("🎵 Initial story content length: \(initialStory.content.count) characters")
                print("🎵 Initial story content preview: '\(initialStory.shortContent)'")
                print("🎵 Hero name: '\(initialStory.hero?.name ?? "No hero")'")
                print("🎵 Story created: \(initialStory.formattedDate)")
                print("🎵 Play count: \(initialStory.playCount)")
                print("🎵 Has audio: \(initialStory.hasAudio)")
                print("🖼️ Total illustrations: \(initialStory.illustrations.count)")
                print("🖼️ Generated illustrations: \(initialStory.generatedIllustrations.count)")
                print("🖼️ Has illustrations (any generated): \(initialStory.hasIllustrations)")
                for (index, illustration) in initialStory.illustrations.enumerated() {
                    print("🖼️   [\(index)] isGenerated: \(illustration.isGenerated), imagePath: \(illustration.imagePath ?? "nil")")
                }
                print("🎵 ==============================")
                viewModel.setModelContext(modelContext)

                // Setup story queue if stories are provided
                if let allStories = allStories,
                   let storyIndex = storyIndex {
                    viewModel.setupStoryQueue(stories: allStories, startIndex: storyIndex)
                    print("🎵 Queue mode enabled with \(allStories.count) stories")
                } else {
                    // If no queue, set the initial story as current
                    viewModel.currentStory = initialStory
                }
            }
            .onDisappear {
                viewModel.stopAudio()
                // Ensure idle timer is re-enabled when leaving the player
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
    
    // MARK: - Helper Views

    @ViewBuilder
    private func landscapeControlsView(geometry: GeometryProxy, isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            // Story Info Header
            VStack(spacing: 8) {
                Text(currentStory.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let hero = currentStory.hero {
                    Text("Featuring \(hero.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal)

            Spacer()

            // Audio Controls
            VStack(spacing: 16) {
                // Progress Slider
                if viewModel.duration > 0 {
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { viewModel.currentTime },
                                set: { newTime in
                                    viewModel.seek(to: newTime)
                                }
                            ),
                            in: 0...viewModel.duration
                        )
                        .accentColor(.orange)

                        HStack {
                            Text(formatTime(viewModel.currentTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()

                            Spacer()

                            Text(formatTime(viewModel.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal)
                }

                // Main Playback Controls
                HStack(spacing: 20) {
                    Button(action: {
                        if viewModel.isQueueMode {
                            viewModel.playPreviousStory()
                        } else {
                            viewModel.seek(to: 0)
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(canGoToPrevious ? .orange : .gray)
                    }
                    .disabled(!canGoToPrevious && viewModel.duration == 0)

                    Button(action: {
                        viewModel.skipBackward()
                    }) {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                    .disabled(viewModel.duration == 0)

                    Button(action: {
                        if viewModel.isPlaying || viewModel.isPaused {
                            viewModel.togglePlayPause()
                        } else {
                            viewModel.playStory(currentStory)
                        }
                    }) {
                        Image(systemName: playButtonIcon)
                            .font(.system(size: 44))
                            .foregroundColor(.orange)
                    }

                    Button(action: {
                        viewModel.skipForward()
                    }) {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                    .disabled(viewModel.duration == 0)

                    Button(action: {
                        if viewModel.isQueueMode {
                            viewModel.playNextStory()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(canGoToNext ? .orange : .gray)
                    }
                    .disabled(!canGoToNext)
                }
                .padding(.horizontal)

                // Secondary Controls
                HStack(spacing: 12) {
                    Menu {
                        Button("0.5x") { viewModel.setPlaybackSpeed(0.5) }
                        Button("0.75x") { viewModel.setPlaybackSpeed(0.75) }
                        Button("1.0x") { viewModel.setPlaybackSpeed(1.0) }
                        Button("1.25x") { viewModel.setPlaybackSpeed(1.25) }
                        Button("1.5x") { viewModel.setPlaybackSpeed(1.5) }
                        Button("2.0x") { viewModel.setPlaybackSpeed(2.0) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                            Text(String(format: "%.2gx", viewModel.playbackSpeed))
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(6)
                    }

                    Button(action: {
                        viewModel.stopAudio()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                    .opacity((viewModel.isPlaying || viewModel.isPaused) ? 1.0 : 0.5)
                    .disabled(!(viewModel.isPlaying || viewModel.isPaused))

                    Button(action: {
                        withAnimation {
                            showIllustrations.toggle()
                        }
                    }) {
                        Image(systemName: showIllustrations ? "photo.fill" : "photo")
                            .font(.caption)
                            .foregroundColor(showIllustrations ? .orange : .secondary)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(showIllustrations ? Color.orange.opacity(0.15) : Color(.systemGray6))
                            )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Metadata
            HStack {
                Text("Created: \(currentStory.formattedDate)")
                Spacer()
                if currentStory.playCount > 0 {
                    Text("\(currentStory.playCount) plays")
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding()
        }
    }

    private var playButtonIcon: String {
        if viewModel.isPlaying {
            return "pause.circle.fill"
        } else if viewModel.isPaused {
            return "play.circle.fill"
        } else {
            return "play.circle.fill"
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var wordCount: Int {
        currentStory.content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    private var estimatedReadingTime: Int {
        // Average reading speed is about 200 words per minute
        max(1, (wordCount + 199) / 200)
    }

    private var canGoToPrevious: Bool {
        viewModel.isQueueMode && viewModel.currentStoryIndex > 0
    }

    private var canGoToNext: Bool {
        viewModel.isQueueMode && viewModel.currentStoryIndex < viewModel.storyQueue.count - 1
    }

    private func exportAudioFile() {
        guard let audioFileName = currentStory.audioFileName else {
            exportErrorMessage = "This story doesn't have an audio file yet. Please play the story first to generate audio."
            showingExportError = true
            return
        }

        Task {
            await performAudioExport(audioFileName: audioFileName)
        }
    }

    @MainActor
    private func performAudioExport(audioFileName: String) async {
        let fileManager = FileManager.default

        do {
            // Get documents directory
            let documentsURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )

            let audioPath = documentsURL.appendingPathComponent(audioFileName)

            // Verify file exists
            guard fileManager.fileExists(atPath: audioPath.path) else {
                throw AudioExportError.fileNotFound
            }

            // Create temp directory for export
            let tempDir = fileManager.temporaryDirectory
                .appendingPathComponent("AudioExports", isDirectory: true)

            try fileManager.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Generate clean filename
            let exportFileName = sanitizeFileName("\(currentStory.title).mp3")
            let tempFileURL = tempDir.appendingPathComponent(exportFileName)

            // Remove existing temp file if needed
            if fileManager.fileExists(atPath: tempFileURL.path) {
                try fileManager.removeItem(at: tempFileURL)
            }

            // Copy with proper attributes
            try fileManager.copyItem(at: audioPath, to: tempFileURL)

            // Set file attributes for sharing
            try fileManager.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: tempFileURL.path
            )

            // Prepare metadata
            let metadata = createAudioMetadata(for: tempFileURL)

            // Show share sheet
            await MainActor.run {
                self.audioFileURL = tempFileURL
                self.exportMetadata = metadata
                self.showingShareSheet = true
            }

        } catch {
            await MainActor.run {
                handleExportError(error)
            }
        }
    }

    private func sanitizeFileName(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createAudioMetadata(for url: URL) -> [String: Any] {
        var metadata: [String: Any] = [:]

        // Add story metadata
        metadata["title"] = currentStory.title
        metadata["artist"] = currentStory.hero?.name ?? "InfiniteStories"
        metadata["album"] = "Bedtime Stories"
        metadata["genre"] = "Children's Stories"

        // Add creation date
        metadata["year"] = Calendar.current.component(.year, from: currentStory.createdAt)

        // Add custom metadata
        metadata["comment"] = "Created with InfiniteStories app"

        return metadata
    }

    private func handleExportError(_ error: Error) {
        if let exportError = error as? AudioExportError {
            exportErrorMessage = exportError.localizedDescription
        } else {
            exportErrorMessage = "Unable to export audio: \(error.localizedDescription)"
        }
        showingExportError = true
    }
}

enum AudioExportError: LocalizedError {
    case fileNotFound
    case invalidFileName
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found. Please play the story to generate audio."
        case .invalidFileName:
            return "Invalid file name. Please try again."
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}

// MARK: - Enhanced ShareSheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // Configure for iPad
        if let popover = controller.popoverPresentationController {
            popover.sourceView = context.coordinator.sourceView
            popover.sourceRect = CGRect(x: context.coordinator.sourceView.bounds.midX,
                                       y: context.coordinator.sourceView.bounds.midY,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        // Exclude irrelevant activities
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .postToWeibo,
            .postToVimeo,
            .postToTencentWeibo
        ]

        // Set completion handler
        controller.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                // Clean up temp file after successful share
                if let url = activityItems.first as? URL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        let sourceView = UIView()
    }
}

#Preview {
    let story = Story(
        title: "Luna's Magical Adventure",
        content: "Once upon a time in a magical forest, Luna the brave and magical hero discovered a secret that would change everything...",
        event: .bedtime,
        hero: Hero(name: "Luna", primaryTrait: .brave, secondaryTrait: .magical)
    )
    
    AudioPlayerView(story: story)
        .modelContainer(for: Story.self, inMemory: true)
}