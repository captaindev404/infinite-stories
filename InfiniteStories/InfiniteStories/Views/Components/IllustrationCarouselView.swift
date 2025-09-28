//
//  IllustrationCarouselView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 16/09/2025.
//

import SwiftUI
import AVFoundation

struct IllustrationCarouselView: View {
    let illustrations: [StoryIllustration]
    @Binding var currentTime: TimeInterval
    let onRetryIllustration: ((StoryIllustration) -> Void)?
    let onSeekToIllustration: ((TimeInterval) -> Void)?

    @State private var selectedIndex: Int = 0
    @State private var isFullScreen: Bool = false
    @State private var showingDescription: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var kenBurnsOffset: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var failedIllustrations: Set<UUID> = []
    @State private var showSeekFeedback: Bool = false
    @State private var seekFeedbackOpacity: Double = 0
    @State private var showTapToSeekHint: Bool = false

    // Animation timers
    @State private var kenBurnsTimer: Timer?

    // Haptic feedback
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    private let seekHapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    // Settings
    @AppStorage("allowIllustrationFailures") private var allowFailures = true
    @AppStorage("showIllustrationErrors") private var showErrors = true

    init(
        illustrations: [StoryIllustration],
        currentTime: Binding<TimeInterval>,
        onRetryIllustration: ((StoryIllustration) -> Void)? = nil,
        onSeekToIllustration: ((TimeInterval) -> Void)? = nil
    ) {
        self.illustrations = illustrations
        self._currentTime = currentTime
        self.onRetryIllustration = onRetryIllustration
        self.onSeekToIllustration = onSeekToIllustration
    }

    private var currentIllustration: StoryIllustration? {
        guard selectedIndex < illustrations.count else { return nil }
        return illustrations[selectedIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient for elegance
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.1),
                        Color.orange.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Main carousel
                    carouselContent(geometry: geometry)
                        .frame(height: isFullScreen ? geometry.size.height : geometry.size.height * 0.75)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFullScreen)

                    if !isFullScreen {
                        // Thumbnail strip
                        IllustrationThumbnailStrip(
                            illustrations: illustrations,
                            selectedIndex: $selectedIndex,
                            onThumbnailTap: { index in
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedIndex = index
                                }
                                hapticFeedback.impactOccurred()
                                resetKenBurnsAnimation()

                                // Also seek to this illustration's timestamp when thumbnail is tapped
                                if index < illustrations.count {
                                    seekToIllustration(illustrations[index])
                                }
                            }
                        )
                        .frame(height: geometry.size.height * 0.15)
                        .padding(.horizontal)

                        // Playback indicator
                        playbackProgressIndicator
                            .frame(height: geometry.size.height * 0.1)
                            .padding(.horizontal)
                    }
                }

                // Tap to seek hint overlay
                if showTapToSeekHint {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "hand.tap.fill")
                                .font(.title2)
                            Text("Tap any illustration to jump to that part of the story")
                                .font(.subheadline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .padding()
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            print("🖼️ IllustrationCarouselView appeared with \(illustrations.count) illustrations")
            for (i, ill) in illustrations.enumerated() {
                print("🖼️   [\(i)] generated: \(ill.isGenerated), placeholder: \(ill.isPlaceholder), path: \(ill.imagePath ?? "nil")")
            }
            updateSelectedIndexForTime()
            startKenBurnsAnimation()

            // Show tap to seek hint after a brief delay if we have a seek handler
            if onSeekToIllustration != nil && !UserDefaults.standard.bool(forKey: "hasSeenTapToSeekHint") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showTapToSeekHint = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showTapToSeekHint = false
                        }
                        UserDefaults.standard.set(true, forKey: "hasSeenTapToSeekHint")
                    }
                }
            }
        }
        .onDisappear {
            stopKenBurnsAnimation()
        }
        .onChange(of: currentTime) { _ in
            updateSelectedIndexForTime()
        }
        .onChange(of: selectedIndex) { _ in
            resetKenBurnsAnimation()
        }
    }

    @ViewBuilder
    private func carouselContent(geometry: GeometryProxy) -> some View {
        if illustrations.isEmpty {
            emptyStateView
                .onAppear {
                    print("🖼️ IllustrationCarouselView: Showing empty state - no illustrations")
                }
        } else {
            TabView(selection: $selectedIndex) {
                ForEach(Array(illustrations.enumerated()), id: \.element.id) { index, illustration in
                    illustrationCard(illustration: illustration, geometry: geometry, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedIndex)
        }
    }

    @ViewBuilder
    private func illustrationCard(illustration: StoryIllustration, geometry: GeometryProxy, index: Int) -> some View {
        ZStack {
            if illustration.isPlaceholder || failedIllustrations.contains(illustration.id) {
                // Show error placeholder
                IllustrationPlaceholderView(
                    sceneNumber: illustration.displayOrder + 1,
                    errorType: convertToGlobalErrorType(illustration.typedError),
                    onRetry: onRetryIllustration != nil ? {
                        retryIllustration(illustration)
                    } : nil
                )
                .frame(width: geometry.size.width, height: isFullScreen ? geometry.size.height : geometry.size.height * 0.75)
            } else if illustration.isGenerated, let imageURL = illustration.imageURL {
                // Actual image with effects
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        loadingView
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: isFullScreen ? geometry.size.height : geometry.size.height * 0.75)
                            .clipped()
                            .scaleEffect(selectedIndex == index ? kenBurnsScale * zoomScale : 1.0)
                            .offset(selectedIndex == index ? kenBurnsOffset : .zero)
                            .animation(selectedIndex == index ? .linear(duration: 20).repeatForever(autoreverses: true) : .default, value: kenBurnsScale)
                            .overlay(
                                // Gradient overlay for text readability
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black.opacity(0),
                                        Color.black.opacity(showingDescription ? 0.6 : 0.2)
                                    ]),
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                // Scene description
                                descriptionOverlay(for: illustration)
                                    .opacity(showingDescription ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.3), value: showingDescription)
                                , alignment: .bottom
                            )
                    case .failure:
                        // Mark as failed and show placeholder
                        IllustrationPlaceholderView(
                            sceneNumber: illustration.displayOrder + 1,
                            errorType: .fileSystem,
                            onRetry: onRetryIllustration != nil ? {
                                retryIllustration(illustration)
                            } : nil
                        )
                        .frame(width: geometry.size.width, height: isFullScreen ? geometry.size.height : geometry.size.height * 0.75)
                        .onAppear {
                            failedIllustrations.insert(illustration.id)
                        }
                    @unknown default:
                        loadingView
                    }
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                // Placeholder for non-generated illustrations (pending)
                placeholderView(for: illustration, geometry: geometry)
            }

            // Parallax effect based on drag
            if selectedIndex == index {
                Color.clear
                    .offset(x: dragOffset.width * 0.3, y: dragOffset.height * 0.3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isFullScreen ? 0 : 20))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .overlay(
            // Seek feedback overlay
            ZStack {
                if showSeekFeedback {
                    VStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Jumping to \(illustration.formattedTimestamp)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .opacity(seekFeedbackOpacity)
                    .animation(.easeInOut(duration: 0.3), value: seekFeedbackOpacity)
                }
            }
        )
        .onTapGesture(count: 2) {
            toggleFullScreen()
        }
        .onTapGesture(count: 1) {
            // Single tap to seek to this illustration's timestamp
            seekToIllustration(illustration)
        }
        .onLongPressGesture {
            withAnimation {
                showingDescription.toggle()
            }
            hapticFeedback.impactOccurred()
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    zoomScale = lastZoomScale * value
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        let newScale = lastZoomScale * value
                        if newScale < 1 {
                            zoomScale = 1
                            lastZoomScale = 1
                        } else if newScale > 3 {
                            zoomScale = 3
                            lastZoomScale = 3
                        } else {
                            lastZoomScale = newScale
                        }
                    }
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if zoomScale > 1 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        dragOffset = .zero
                    }
                }
        )
    }

    @ViewBuilder
    private func descriptionOverlay(for illustration: StoryIllustration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scene \(illustration.displayOrder + 1)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))

            Text(illustration.textSegment)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(illustration.formattedTimestamp)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0.6)
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }

    @ViewBuilder
    private var playbackProgressIndicator: some View {
        VStack(spacing: 4) {
            // Timeline with illustration markers
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    // Illustration markers (clickable)
                    ForEach(Array(illustrations.enumerated()), id: \.element.id) { index, illustration in
                        Circle()
                            .fill(index == selectedIndex ? Color.orange : Color.gray)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                                    .opacity(index == selectedIndex ? 1 : 0)
                            )
                            .position(
                                x: CGFloat(illustration.timestamp / 300.0) * geometry.size.width, // Assuming 5 min max duration
                                y: geometry.size.height / 2
                            )
                            .onTapGesture {
                                // Jump to this illustration
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedIndex = index
                                }
                                seekToIllustration(illustration)
                                hapticFeedback.impactOccurred()
                            }
                    }

                    // Current time indicator
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 12, height: 12)
                        .position(
                            x: CGFloat(currentTime / 300.0) * geometry.size.width,
                            y: geometry.size.height / 2
                        )
                        .shadow(color: .purple.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 20)

            if let current = currentIllustration {
                Text("Scene \(current.displayOrder + 1) • \(current.formattedTimestamp)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        ZStack {
            Color.gray.opacity(0.1)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
        }
    }

    // MARK: - Helper Methods for Error Handling

    private func retryIllustration(_ illustration: StoryIllustration) {
        hapticFeedback.impactOccurred()
        failedIllustrations.remove(illustration.id)
        onRetryIllustration?(illustration)
    }

    private func checkIllustrationErrors() {
        for illustration in illustrations {
            if illustration.isPlaceholder && !illustration.hasReachedRetryLimit {
                failedIllustrations.insert(illustration.id)
            }
        }
    }

    @ViewBuilder
    private func placeholderView(for illustration: StoryIllustration, geometry: GeometryProxy) -> some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.3),
                    Color.orange.opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.8))

                Text("Illustration Coming Soon")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Scene \(illustration.displayOrder + 1)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: geometry.size.width, height: isFullScreen ? geometry.size.height : geometry.size.height * 0.75)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Illustrations Available")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Illustrations will appear here once generated")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Helper Functions

    private func updateSelectedIndexForTime() {
        // Find the appropriate illustration for current playback time
        for (index, illustration) in illustrations.enumerated().reversed() {
            if currentTime >= illustration.timestamp {
                if selectedIndex != index {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        selectedIndex = index
                    }
                }
                break
            }
        }
    }

    private func toggleFullScreen() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isFullScreen.toggle()
        }
        hapticFeedback.impactOccurred()
    }

    private func startKenBurnsAnimation() {
        kenBurnsTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 20)) {
                kenBurnsScale = kenBurnsScale == 1.0 ? 1.1 : 1.0
                kenBurnsOffset = CGSize(
                    width: CGFloat.random(in: -20...20),
                    height: CGFloat.random(in: -20...20)
                )
            }
        }
    }

    private func stopKenBurnsAnimation() {
        kenBurnsTimer?.invalidate()
        kenBurnsTimer = nil
    }

    private func resetKenBurnsAnimation() {
        withAnimation(.linear(duration: 0.5)) {
            kenBurnsScale = 1.0
            kenBurnsOffset = .zero
        }
        stopKenBurnsAnimation()
        startKenBurnsAnimation()
    }

    // MARK: - Audio Sync Functions

    private func seekToIllustration(_ illustration: StoryIllustration) {
        // Check if we have a seek handler
        guard let seekHandler = onSeekToIllustration else { return }

        // Trigger haptic feedback
        seekHapticFeedback.impactOccurred()

        // Show feedback overlay
        showSeekFeedback = true
        seekFeedbackOpacity = 1.0

        // Seek to the illustration's timestamp
        seekHandler(illustration.timestamp)

        // Hide feedback after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                seekFeedbackOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showSeekFeedback = false
            }
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

// MARK: - Preview

#Preview {
    IllustrationCarouselView(
        illustrations: [],
        currentTime: .constant(30),
        onRetryIllustration: nil
    )
}