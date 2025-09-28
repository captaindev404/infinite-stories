//
//  ImprovedContentView.swift
//  InfiniteStories
//
//  Production-ready enhanced home screen with magical UI
//

import SwiftUI
import SwiftData

// MARK: - Main Improved Content View
struct ImprovedContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeSettings: ThemeSettings
    @Query private var heroes: [Hero]
    @Query(sort: \Story.createdAt, order: .reverse) private var stories: [Story]
    
    @State private var showingHeroCreation = false
    @State private var showingStoryGeneration = false
    @State private var showingSettings = false
    @State private var selectedStory: Story?
    @State private var selectedHeroForStory: Hero?
    @State private var animateHero = false
    @State private var sparkleAnimation = false
    @State private var cloudOffset: CGFloat = -100
    @State private var starRotation: Double = 0
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingFullJourney = false
    @State private var showingCustomEventManagement = false
    
    // Performance optimization: Limit floating elements on older devices
    private var shouldShowFloatingElements: Bool {
        ProcessInfo.processInfo.processorCount >= 4
    }
    
    // Computed properties for stats
    private var totalStoriesRead: Int {
        stories.reduce(0) { $0 + $1.playCount }
    }
    
    private var currentStreak: Int {
        calculateReadingStreak()
    }
    
    private var recentStories: [Story] {
        Array(stories.prefix(6))  // Increased from 3 to 6 since we have more space
    }
    
    private var favoriteStories: [Story] {
        stories.filter { $0.isFavorite }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Magical Background
                MagicalBackgroundView()
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Section
                        HeroSectionView(
                            heroes: heroes,
                            animateHero: $animateHero,
                            sparkleAnimation: $sparkleAnimation,
                            showingHeroCreation: $showingHeroCreation,
                            selectedHeroForStory: $selectedHeroForStory,
                            showingStoryGeneration: $showingStoryGeneration
                        )
                        .padding(.top, 20)

                        // Recent Stories - Now with more space
                        if !recentStories.isEmpty {
                            RecentStoriesView(
                                stories: Array(stories.prefix(6)),  // Show more stories now
                                selectedStory: $selectedStory
                            )
                            .padding(.top, 25)
                        }

                        // Empty State
                        if heroes.isEmpty {
                            EmptyStateView(showingHeroCreation: $showingHeroCreation)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Extra padding for floating button
                }
                .refreshable {
                    await refreshData()
                }

                // Floating Elements (performance optimized)
                if shouldShowFloatingElements {
                    FloatingElementsView(
                        cloudOffset: $cloudOffset,
                        starRotation: $starRotation
                    )
                    .allowsHitTesting(false)
                }

                // Floating Create Story Button
                if !heroes.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FloatingCreateStoryButton(
                                showingStoryGeneration: $showingStoryGeneration
                            )
                            .padding(.trailing, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }

                // Floating Custom Event Management Button
                VStack {
                    Spacer()
                    HStack {
                        FloatingCustomEventButton(
                            showingCustomEventManagement: $showingCustomEventManagement
                        )
                        .padding(.leading, 20)
                        .padding(.bottom, 30)
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    MagicalLogoView()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        // Reading Journey Button (replaced Story Library button)
                        if !stories.isEmpty {
                            Button(action: {
                                showingFullJourney = true
                            }) {
                                ReadingJourneyTopButton(
                                    totalStories: stories.count,
                                    streak: currentStreak
                                )
                            }
                            .accessibilityLabel("Reading Journey")
                            .accessibilityHint("View your reading statistics and progress")
                        }

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(MagicalColors.primary)
                                .font(.system(size: 20))
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Open app settings")
                    }
                }
            }
            .sheet(isPresented: $showingHeroCreation) {
                HeroCreationView(heroToEdit: nil)
            }
            .sheet(isPresented: $showingStoryGeneration) {
                if heroes.count > 1 {
                    HeroSelectionForStoryView(selectedHero: $selectedHeroForStory, showingStoryGeneration: $showingStoryGeneration)
                } else if let hero = selectedHeroForStory ?? heroes.first {
                    StoryGenerationView(hero: hero)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(themeSettings)
            }
            .sheet(item: $selectedStory) { story in
                NavigationStack {
                    // Find the index of the selected story in the stories list
                    let storyIndex = stories.firstIndex(where: { $0.id == story.id }) ?? 0
                    AudioPlayerView(
                        story: story,
                        allStories: stories,
                        storyIndex: storyIndex
                    )
                        .onDisappear {
                            // Update play count when audio player closes
                            handleStoryPlayed(story)
                        }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An unexpected error occurred")
            }
            .fullScreenCover(isPresented: $showingFullJourney) {
                ReadingJourneyView()
            }
            .sheet(isPresented: $showingCustomEventManagement) {
                CustomEventManagementView()
            }
            .onAppear {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        // Stagger animations for better performance
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            animateHero = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                sparkleAnimation = true
            }
        }
        
        if shouldShowFloatingElements {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    cloudOffset = UIScreen.main.bounds.width + 100
                }
                
                withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                    starRotation = 360
                }
            }
        }
    }
    
    private func calculateReadingStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        for _ in 0..<30 {
            let dayStories = stories.filter {
                calendar.isDate($0.createdAt, inSameDayAs: currentDate)
            }
            
            if !dayStories.isEmpty {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    @MainActor
    private func refreshData() async {
        isRefreshing = true
        
        do {
            // Simulate refresh delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // In production, this would reload data from server
            // For now, we just refresh the UI
            
        } catch {
            errorMessage = "Failed to refresh: \(error.localizedDescription)"
            showingError = true
        }
        
        isRefreshing = false
    }
    
    private func handleStoryPlayed(_ story: Story) {
        do {
            // Save the updated play count
            try modelContext.save()
        } catch {
            print("Failed to update story play count: \(error)")
        }
    }
}

// MARK: - Magical Background View
struct MagicalBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: colorScheme == .dark ? 
                    [Color.black.opacity(0.9), Color.black.opacity(0.7)] :
                    [Color.purple.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle Pattern Overlay - Performance optimized
            GeometryReader { geometry in
                ForEach(0..<10, id: \.self) { index in // Reduced from 20 to 10 for performance
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.08), // Reduced opacity
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .position(
                            x: CGFloat(index % 3) * geometry.size.width / 3 + 50,
                            y: CGFloat(index / 3) * geometry.size.height / 4 + 50
                        )
                        .blur(radius: 3)
                }
            }
            .opacity(0.3)
        }
    }
}

// MARK: - Hero Section View
struct HeroSectionView: View {
    let heroes: [Hero]
    @Binding var animateHero: Bool
    @Binding var sparkleAnimation: Bool
    @Binding var showingHeroCreation: Bool
    @Binding var selectedHeroForStory: Hero?
    @Binding var showingStoryGeneration: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            // Heroes Title Bar
            HStack {
                Text("Your Heroes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(MagicalColors.primary)
                
                Spacer()
                
                if !heroes.isEmpty {
                    NavigationLink(destination: HeroListView()) {
                        Text("Manage heroes")
                            .font(.subheadline)
                            .foregroundColor(MagicalColors.primary)
                    }
                }
            }
            
            // Heroes Avatar Row
            if !heroes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                 
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(heroes) { hero in
                                VStack(spacing: 4) {
                                    HeroAvatarImageView(hero: hero, size: 40)

                                    Text(hero.name)
                                        .font(.caption2)
                                        .foregroundColor(MagicalColors.primary)
                                        .lineLimit(1)
                                        .frame(minWidth: 60, maxWidth: 80)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 5)
            }
        }
    }
}


// MARK: - Floating Create Story Button
struct FloatingCreateStoryButton: View {
    @Binding var showingStoryGeneration: Bool
    @State private var isPressed = false
    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            showingStoryGeneration = true
        }) {
            ZStack {
                // Shadow layer
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 72, height: 72)
                    .blur(radius: 10)
                    .offset(y: 4)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange,
                                Color.orange.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                // Icon
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isAnimating ? 90 : 0))
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .accessibilityLabel("Create new story")
        .accessibilityHint("Generate a new magical story")
    }
}

// MARK: - Floating Custom Event Button
struct FloatingCustomEventButton: View {
    @Binding var showingCustomEventManagement: Bool
    @State private var isPressed = false
    @State private var isPulsing = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            showingCustomEventManagement = true
        }) {
            ZStack {
                // Shadow layer
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .blur(radius: 8)
                    .offset(y: 3)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple,
                                Color.purple.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                // Icon
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityLabel("Manage custom events")
        .accessibilityHint("Open custom event management screen")
    }
}

// MARK: - Reading Journey Top Button
struct ReadingJourneyTopButton: View {
    let totalStories: Int
    let streak: Int
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 6) {
            // Icon with animation
            ZStack {
                Circle()
                    .fill(MagicalColors.primary.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MagicalColors.primary)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }

            // Compact stats
            VStack(alignment: .leading, spacing: 1) {
                Text("Journey")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(MagicalColors.primary)

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("\(streak)d")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(MagicalColors.primary.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(MagicalColors.primary.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}


// MARK: - Recent Stories View - Enhanced with more content
struct RecentStoriesView: View {
    let stories: [Story]
    @Binding var selectedStory: Story?

    private let headerFont = Font.system(size: 18, weight: .bold, design: .rounded)
    private let linkFont = Font.system(size: 14, weight: .medium, design: .rounded)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("Recent Adventures")
                        .font(headerFont)
                        .foregroundColor(MagicalColors.primary)

                    // Story count badge
                    if stories.count > 3 {
                        Text("\(stories.count) new")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(MagicalColors.accent.opacity(0.2))
                            )
                            .foregroundColor(MagicalColors.accent)
                    }
                }

                Spacer()

                NavigationLink(destination: ImprovedStoryLibraryView()) {
                    HStack(spacing: 4) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 14))
                        Text("Library")
                            .font(linkFont)
                    }
                    .foregroundColor(MagicalColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(MagicalColors.accent.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(MagicalColors.accent.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }

            VStack(spacing: 10) {
                ForEach(stories) { story in
                    MiniStoryCard(story: story) {
                        selectedStory = story
                    }
                }
            }
        }
    }
}

// MARK: - Mini Story Card (Enhanced Accessibility)
struct MiniStoryCard: View {
    let story: Story
    let onTap: () -> Void
    @State private var isPressed = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    // Dynamic type aware fonts
    private var titleFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .title3 : AccessibleTypography.cardTitle
    }
    
    private var contentFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .body : AccessibleTypography.cardBody
    }
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        }) {
            ZStack {
                // Accessible card background with better contrast
                AccessibleCardStyle.cardBackground(for: colorScheme)
                
                HStack(spacing: AccessibleSizes.cardSpacing) {
                    // Hero Avatar or story icon
                    if let hero = story.hero {
                        HeroAvatarImageView(hero: hero, size: AccessibleSizes.iconContainerSize)
                    } else {
                        // Fallback to story icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AccessibleColors.accessibleAccent.opacity(0.3),
                                            AccessibleColors.accessibleAccent.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: AccessibleSizes.iconContainerSize,
                                       height: AccessibleSizes.iconContainerSize)

                            Image(systemName: "book.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AccessibleColors.accessibleAccent)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(story.title)
                                .font(titleFont)
                                .foregroundColor(AccessibleColors.primaryText)
                                .lineLimit(1)
                            
                            if story.isFavorite {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .accessibilityLabel("Favorite")
                            }
                        }
                        
                        Text(story.shortContent)
                            .font(contentFont)
                            .foregroundColor(AccessibleColors.secondaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .multilineTextAlignment(.leading)
                        
                        HStack {
                            if let hero = story.hero {
                                Text(hero.name)
                                    .font(AccessibleTypography.metadata)
                                    .foregroundColor(AccessibleColors.accessibleAccent)
                                    .fontWeight(.medium)
                            }

                            if story.hasAudio {
                                Label("\(Int(story.estimatedDuration / 60))m",
                                      systemImage: "speaker.wave.2.fill")
                                    .font(AccessibleTypography.metadata)
                                    .foregroundColor(.orange)
                            }

                            Spacer()
                            
                            Text(story.formattedDate)
                                .font(AccessibleTypography.metadata)
                                .foregroundColor(AccessibleColors.secondaryText)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AccessibleColors.secondaryText)
                }
                .padding(AccessibleSizes.cardPadding)
            }
            .frame(minHeight: AccessibleSizes.miniCardMinHeight)
        }
        .buttonStyle(AccessibleCardButtonStyle())
        .scaleEffect(isPressed ? 0.95 : (isFocused ? 1.02 : 1.0))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 3)
        )
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .focusable()
        .focused($isFocused)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(reduceMotion ? nil : .spring()) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityLabelProvider.storyCardLabel(for: story))
        .accessibilityHint(AccessibilityLabelProvider.storyCardHint(for: story))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(story.isFavorite ? "Favorite" : "")
        .accessibilityActions {
            if story.isFavorite {
                Button("Remove from favorites") {
                    // Toggle favorite action
                }
            } else {
                Button("Add to favorites") {
                    // Toggle favorite action
                }
            }
            
            Button("Share story") {
                // Share action
            }
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @Binding var showingHeroCreation: Bool
    @State private var bounce = false
    
    private let titleFont = Font.system(size: 24, weight: .bold, design: .rounded)
    private let bodyFont = Font.system(size: 16, weight: .light, design: .rounded)
    private let buttonFont = Font.system(size: 18, weight: .bold, design: .rounded)
    
    var body: some View {
        VStack(spacing: 25) {
            // Animated Illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                MagicalColors.accent.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 10)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundColor(MagicalColors.accent)
                    .rotationEffect(.degrees(bounce ? 10 : -10))
                    .scaleEffect(bounce ? 1.1 : 0.9)
            }
            
            VStack(spacing: 12) {
                Text("Begin Your Magical Journey")
                    .font(titleFont)
                    .foregroundColor(MagicalColors.primary)
                
                Text("Create your first hero and start\nexploring wonderful stories!")
                    .font(bodyFont)
                    .foregroundColor(MagicalColors.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                showingHeroCreation = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title3)
                    Text("Create Your Hero")
                        .font(buttonFont)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [MagicalColors.primary, MagicalColors.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: MagicalColors.primary.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            .scaleEffect(bounce ? 1.05 : 1.0)
            .accessibilityLabel("Create Your Hero")
            .accessibilityHint("Start your magical journey by creating your first hero")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}

// MARK: - Floating Elements View (Performance Optimized)
struct FloatingElementsView: View {
    @Binding var cloudOffset: CGFloat
    @Binding var starRotation: Double
    
    var body: some View {
        ZStack {
            // Floating Clouds
            Cloud()
                .fill(Color.white.opacity(0.15))
                .frame(width: 80, height: 40)
                .offset(x: cloudOffset, y: 100)
            
            Cloud()
                .fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 30)
                .offset(x: cloudOffset - 150, y: 200)
            
            // Rotating Stars - Reduced for performance
            ForEach(0..<2, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: CGFloat(15 + index * 5)))
                    .foregroundColor(Color.yellow.opacity(0.3))
                    .position(
                        x: CGFloat(100 + index * 150),
                        y: CGFloat(150 + index * 100)
                    )
                    .rotationEffect(.degrees(starRotation))
            }
        }
    }
}

// MARK: - Cloud Shape
struct Cloud: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Create cloud shape with circles
        path.addEllipse(in: CGRect(x: rect.minX, y: rect.midY - rect.height/4, 
                                   width: rect.width * 0.5, height: rect.height * 0.6))
        path.addEllipse(in: CGRect(x: rect.midX - rect.width * 0.25, y: rect.minY, 
                                   width: rect.width * 0.5, height: rect.height * 0.7))
        path.addEllipse(in: CGRect(x: rect.midX, y: rect.midY - rect.height/4, 
                                   width: rect.width * 0.5, height: rect.height * 0.6))
        
        return path
    }
}

// MARK: - Sparkle View (Performance Optimized)
struct SparkleView: View {
    @Binding var animate: Bool
    
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in // Reduced from 4 to 3
                Image(systemName: "sparkle")
                    .foregroundColor(Color.yellow)
                    .scaleEffect(animate ? 1.0 : 0.3)
                    .opacity(animate ? 0.8 : 0.3)
                    .rotationEffect(.degrees(Double(index) * 120))
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animate
                    )
            }
        }
    }
}

// MARK: - Magical Logo View
struct MagicalLogoView: View {
    @State private var isAnimating = false
    
    private let logoFont = Font.system(size: 20, weight: .bold, design: .rounded)
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.pages.fill")
                .font(.title2)
                .foregroundColor(MagicalColors.primary)
                .rotationEffect(.degrees(isAnimating ? 5 : -5))
            
            Text("Infinite")
                .font(logoFont)
                .foregroundColor(MagicalColors.primary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Magical Colors (Adaptive)
struct MagicalColors {
    static let primary = Color.purple
    static let secondary = Color.gray
    static let accent = Color.orange
    static let text = Color.primary
    static let heroCardStart = Color.purple.opacity(0.8)
    static let heroCardEnd = Color.purple
}


// MARK: - Preview
#Preview {
    ImprovedContentView()
        .modelContainer(for: Hero.self, inMemory: true)
}
