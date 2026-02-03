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
    let storyDuration: TimeInterval? // Optional actual story duration

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
        onSeekToIllustration: ((TimeInterval) -> Void)? = nil,
        storyDuration: TimeInterval? = nil
    ) {
        self.illustrations = illustrations
        self._currentTime = currentTime
        self.onRetryIllustration = onRetryIllustration
        self.onSeekToIllustration = onSeekToIllustration
        self.storyDuration = storyDuration
    }

    /// Calculate the effective duration for timeline display
    /// Uses actual story duration if provided, otherwise estimates from illustrations
    private var effectiveDuration: TimeInterval {
        // Use provided story duration if available
        if let duration = storyDuration, duration > 0 {
            return duration
        }

        // Fallback: estimate based on last illustration timestamp + buffer
        if let lastIllustration = illustrations.max(by: { $0.timestamp < $1.timestamp }) {
            // Add 30 seconds buffer after last illustration
            return lastIllustration.timestamp + 30
        }

        // Default fallback (5 minutes)
        return 300
    }

    private var currentIllustration: StoryIllustration? {
        guard selectedIndex < illustrations.count else { return nil }
        return illustrations[selectedIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // System background
                Color(.systemBackground)
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

                // Tap to seek hint overlay with glass styling
                if showTapToSeekHint {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "hand.tap.fill")
                                .font(.title2)
                            Text("illustration.carousel.tapToSeek")
                                .font(.subheadline)
                        }
                        .foregroundColor(.primary)
                        .padding()
                        .liquidGlassCard(cornerRadius: 12)
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
                                // Semi-transparent overlay for text readability
                                Color.black.opacity(showingDescription ? 0.4 : 0.15)
                                    .allowsHitTesting(false)
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
            // Seek feedback overlay with glass styling
            ZStack {
                if showSeekFeedback {
                    VStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("illustration.carousel.jumpingTo \(illustration.formattedTimestamp)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .liquidGlassCard(cornerRadius: 12, variant: .tinted(.orange))
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
            Text("illustration.carousel.scene \(illustration.displayOrder + 1)")
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
        .background(Color.black.opacity(0.7))
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
                                x: CGFloat(illustration.timestamp / effectiveDuration) * geometry.size.width,
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
                            x: CGFloat(min(currentTime, effectiveDuration) / effectiveDuration) * geometry.size.width,
                            y: geometry.size.height / 2
                        )
                        .shadow(color: .purple.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 20)

            if let current = currentIllustration {
                Text("illustration.carousel.scene \(current.displayOrder + 1) • \(current.formattedTimestamp)")
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
            // System secondary background
            Color(.secondarySystemBackground)

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("illustration.carousel.generating")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("illustration.carousel.scene \(illustration.displayOrder + 1)")
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

            Text("illustration.carousel.noIllustrations")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("illustration.carousel.willAppear")
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
        // Don't start animation if there are no valid illustrations
        guard hasValidIllustrations else { return }

        // Stop any existing timer first
        stopKenBurnsAnimation()

        kenBurnsTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [self] _ in
            // Only animate if current illustration is valid and loaded
            guard selectedIndex < illustrations.count,
                  illustrations[selectedIndex].isGenerated,
                  !failedIllustrations.contains(illustrations[selectedIndex].id) else {
                return
            }

            withAnimation(.linear(duration: 20)) {
                kenBurnsScale = kenBurnsScale == 1.0 ? 1.1 : 1.0
                kenBurnsOffset = CGSize(
                    width: CGFloat.random(in: -20...20),
                    height: CGFloat.random(in: -20...20)
                )
            }
        }
    }

    /// Check if there are any valid (generated and not failed) illustrations
    private var hasValidIllustrations: Bool {
        illustrations.contains { $0.isGenerated && !failedIllustrations.contains($0.id) }
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
        onRetryIllustration: nil,
        onSeekToIllustration: nil,
        storyDuration: 300
    )
}