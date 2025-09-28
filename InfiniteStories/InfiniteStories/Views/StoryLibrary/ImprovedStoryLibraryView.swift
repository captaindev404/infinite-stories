//
//  ImprovedStoryLibraryView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//
//  Enhanced Story Library with improved UX/UI design
//

import SwiftUI
import SwiftData

// MARK: - Design System Tokens
struct StoryLibraryDesign {
    // Color Palette
    struct Colors {
        // Primary Colors (use adaptive colors)
        static let primaryPurple = Color.purple
        static let primaryOrange = Color.orange
        static let primaryBlue = Color.blue
        
        // Background Colors (adaptive)
        static let cardBackground = Color(.systemBackground)
        static let newStoryGradientStart = Color.purple.opacity(0.1)
        static let newStoryGradientEnd = Color.blue.opacity(0.1)
        
        // Status Colors
        static let newBadge = Color.mint
        static let inProgressBadge = Color.orange
        static let completedBadge = Color.green
        
        // Event Colors (for category badges)
        static let bedtimeColor = Color.purple
        static let schoolColor = Color.yellow
        static let birthdayColor = Color.pink
        static let weekendColor = Color.green
        static let rainyDayColor = Color.blue
        static let familyColor = Color.orange
        
        // Text Colors (adaptive)
        static let titleText = Color.primary
        static let bodyText = Color.secondary
        static let captionText = Color.secondary.opacity(0.8)
    }
    
    // Typography
    struct Typography {
        static let cardTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let cardBody = Font.system(size: 14, weight: .regular, design: .default)
        static let metadata = Font.system(size: 12, weight: .medium, design: .rounded)
        static let badge = Font.system(size: 11, weight: .bold, design: .rounded)
        static let sectionHeader = Font.system(size: 22, weight: .bold, design: .rounded)
    }
    
    // Spacing
    struct Spacing {
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 24
        static let elementSpacing: CGFloat = 8
        static let iconSpacing: CGFloat = 6
    }
    
    // Layout
    struct Layout {
        static let cardCornerRadius: CGFloat = 16
        static let badgeCornerRadius: CGFloat = 8
        static let cardShadowRadius: CGFloat = 8
        static let cardShadowY: CGFloat = 4
        static let progressBarHeight: CGFloat = 4
    }
}

// MARK: - Improved Story Library View
struct ImprovedStoryLibraryView: View {
    @Query(sort: \Story.createdAt, order: .reverse) private var stories: [Story]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStory: Story?
    @State private var searchText = ""
    @State private var selectedFilter: StoryFilter = .all
    @State private var showingFilters = false
    @State private var showDeleteConfirmation = false
    @State private var storyToDelete: Story?
    @State private var visibleStoryCount = 20 // Initial load
    @State private var isLoadingMore = false
    @State private var showingAudioRegeneration = false
    @State private var storyToRegenerate: Story?
    @State private var regeneratingStories: Set<PersistentIdentifier> = []
    @State private var isEditMode = false
    @State private var selectedStories: Set<PersistentIdentifier> = []
    @State private var showBulkDeleteConfirmation = false
    @StateObject private var viewModel = StoryViewModel()
    
    // Group stories by status
    private var newStories: [Story] {
        stories.filter { $0.playCount == 0 }
    }
    
    private var inProgressStories: [Story] {
        stories.filter { $0.playCount > 0 && $0.playCount < 3 } // Assume < 3 plays means in progress
    }
    
    private var completedStories: [Story] {
        stories.filter { $0.playCount >= 3 }
    }
    
    private var filteredStories: [Story] {
        let searchFiltered = searchText.isEmpty ? stories : 
            stories.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        
        switch selectedFilter {
        case .all:
            return searchFiltered
        case .new:
            return searchFiltered.filter { $0.playCount == 0 }
        case .favorites:
            return searchFiltered.filter { $0.isFavorite }
        case .recent:
            return Array(searchFiltered.prefix(10))
        }
    }
    
    var body: some View {
        ZStack {
            // Magical background gradient (adaptive)
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: StoryLibraryDesign.Spacing.sectionSpacing) {
                    // Header with search and filters
                    headerSection
                    
                    // Quick stats
                    if !stories.isEmpty {
                        statsSection
                    }
                    
                    // Filter pills
                    filterSection
                    
                    // Stories grid/list
                    if filteredStories.isEmpty {
                        emptyStateView
                    } else {
                        storiesSection
                    }
                }
                .padding()

                // Edit mode toolbar at bottom
                if isEditMode && !stories.isEmpty {
                    EditModeToolbar(
                        selectedStories: $selectedStories,
                        totalStories: filteredStories.count,
                        onDelete: {
                            if !selectedStories.isEmpty {
                                showBulkDeleteConfirmation = true
                            }
                        },
                        onSelectAll: {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                if selectedStories.count == filteredStories.count {
                                    selectedStories.removeAll()
                                } else {
                                    selectedStories = Set(filteredStories.map { $0.id })
                                }
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Story Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditMode ? "Done" : "Edit") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedStories.removeAll()
                        }
                    }
                }
                .fontWeight(.medium)
                .disabled(stories.isEmpty)
            }
        }
        .sheet(item: $selectedStory) { story in
            NavigationStack {
                // Find the index of the selected story in the filtered list
                let storyIndex = filteredStories.firstIndex(where: { $0.id == story.id }) ?? 0
                AudioPlayerView(
                    story: story,
                    allStories: filteredStories,
                    storyIndex: storyIndex
                )
            }
        }
        .sheet(item: $storyToRegenerate) { story in
            AudioRegenerationView(story: story) {
                // On completion, play the story
                selectedStory = story
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .alert("Delete Story?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let story = storyToDelete {
                    deleteStory(story)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Delete \(selectedStories.count) Stories?", isPresented: $showBulkDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteSelectedStories()
            }
        } message: {
            Text("This will permanently delete \(selectedStories.count) stories. This action cannot be undone.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: StoryLibraryDesign.Spacing.elementSpacing) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(StoryLibraryDesign.Colors.captionText)
                
                TextField("Search stories...", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search stories")
                    .accessibilityHint("Enter text to search through your story library")
                
                if !searchText.isEmpty {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(StoryLibraryDesign.Colors.captionText)
                            .scaleEffect(searchText.isEmpty ? 0 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searchText)
                            .accessibilityLabel("Clear search")
                            .accessibilityHint("Tap to clear the search text")
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.primary.opacity(0.05), radius: 4, y: 2)
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: StoryLibraryDesign.Spacing.cardSpacing) {
            StatCard(
                icon: "sparkles",
                value: "\(newStories.count)",
                label: "New",
                color: StoryLibraryDesign.Colors.newBadge
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(newStories.count) new stories")
            
            StatCard(
                icon: "book.fill",
                value: "\(inProgressStories.count)",
                label: "Reading",
                color: StoryLibraryDesign.Colors.inProgressBadge
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(inProgressStories.count) stories in progress")
            
            StatCard(
                icon: "checkmark.circle.fill",
                value: "\(completedStories.count)",
                label: "Completed",
                color: StoryLibraryDesign.Colors.completedBadge
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(completedStories.count) completed stories")
            
            StatCard(
                icon: "heart.fill",
                value: "\(stories.filter { $0.isFavorite }.count)",
                label: "Favorites",
                color: Color.red
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(stories.filter { $0.isFavorite }.count) favorite stories")
        }
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StoryFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.title,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
        }
    }
    
    // MARK: - Stories Section
    private var storiesSection: some View {
        LazyVStack(spacing: StoryLibraryDesign.Spacing.cardSpacing) {
            // Show limited number of stories for performance
            ForEach(Array(filteredStories.prefix(visibleStoryCount)), id: \.id) { story in
                HStack(spacing: 12) {
                    // Selection indicator in edit mode
                    if isEditMode {
                        SelectionCircle(isSelected: selectedStories.contains(story.id))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    if selectedStories.contains(story.id) {
                                        selectedStories.remove(story.id)
                                    } else {
                                        selectedStories.insert(story.id)
                                    }
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.5).combined(with: .opacity),
                                removal: .scale(scale: 0.5).combined(with: .opacity)
                            ))
                    }

                    storyCardView(for: story)
                        .opacity(isEditMode && !selectedStories.contains(story.id) ? 0.6 : 1.0)
                        .allowsHitTesting(!isEditMode || selectedStories.contains(story.id))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditMode)
            }

            // Load more button/indicator
            if visibleStoryCount < filteredStories.count {
                LoadMoreView(isLoading: $isLoadingMore) {
                    loadMoreStories()
                }
                .padding(.top, 10)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(StoryLibraryDesign.Colors.primaryPurple.opacity(0.5))
            
            Text("No stories found")
                .font(StoryLibraryDesign.Typography.sectionHeader)
                .foregroundColor(StoryLibraryDesign.Colors.titleText)
            
            Text("Try adjusting your filters or search")
                .font(StoryLibraryDesign.Typography.cardBody)
                .foregroundColor(StoryLibraryDesign.Colors.captionText)
        }
        .padding(40)
    }
    
    // MARK: - Helper Functions
    private func deleteStory(_ story: Story) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.deleteStoryWithCleanup(story)
        }
    }

    private func deleteSelectedStories() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            for storyId in selectedStories {
                if let story = stories.first(where: { $0.id == storyId }) {
                    viewModel.deleteStoryWithCleanup(story)
                }
            }
            selectedStories.removeAll()
            isEditMode = false
        }
    }
    
    private func toggleFavorite(_ story: Story) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            story.isFavorite.toggle()
            try? modelContext.save()
        }
    }
    
    private func shareStory(_ story: Story) {
        // Implementation for sharing
        let activityVC = UIActivityViewController(
            activityItems: [story.title, story.content],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func loadMoreStoriesIfNeeded() {
        // Auto-load when scrolling near the bottom
        let remainingStories = filteredStories.count - visibleStoryCount
        if remainingStories > 0 && !isLoadingMore {
            loadMoreStories()
        }
    }
    
    private func loadMoreStories() {
        guard !isLoadingMore else { return }

        isLoadingMore = true

        // Simulate loading delay for smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.visibleStoryCount = min(self.visibleStoryCount + 20, self.filteredStories.count)
                self.isLoadingMore = false
            }
        }
    }

    // MARK: - Story Card View Builder
    @ViewBuilder
    private func storyCardView(for story: Story) -> some View {
        let isRegenerating = regeneratingStories.contains(story.id)

        ImprovedStoryCard(
            story: story,
            onTap: {
                selectedStory = story
            },
            onToggleFavorite: {
                toggleFavorite(story)
            },
            onShare: {
                shareStory(story)
            },
            onDelete: {
                storyToDelete = story
                showDeleteConfirmation = true
            },
            onEdit: {
                // Show edit view
                selectedStory = story
            },
            onRegenerateAudio: {
                // Show inline regeneration progress
                regeneratingStories.insert(story.id)
                Task {
                    await viewModel.regenerateAudioForStory(story)
                    regeneratingStories.remove(story.id)
                }
            },
            onRetryFailedIllustrations: {
                Task {
                    await viewModel.retryAllFailedIllustrations(for: story)
                }
            },
            isRegenerating: isRegenerating,
            hasFailedIllustrations: viewModel.hasRetryableFailedIllustrations(story),
            failedIllustrationCount: viewModel.failedIllustrationCount(for: story)
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: filteredStories.count)
        .onAppear {
            // Load more when reaching the last few items
            let visibleStories = Array(filteredStories.prefix(visibleStoryCount))
            if story.id == visibleStories.last?.id {
                loadMoreStoriesIfNeeded()
            }
        }
    }
}

// MARK: - Improved Story Card (Enhanced Accessibility)
struct ImprovedStoryCard: View {
    let story: Story
    let onTap: () -> Void
    var onToggleFavorite: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onRegenerateAudio: (() -> Void)? = nil
    var onRetryFailedIllustrations: (() -> Void)? = nil
    var isRegenerating: Bool = false
    var hasFailedIllustrations: Bool = false
    var failedIllustrationCount: Int = 0
    
    @State private var isPressed = false
    @State private var showingActions = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    private var storyStatus: StoryStatus {
        if story.playCount == 0 {
            return .new
        } else if story.playCount < 3 {
            return .inProgress
        } else {
            return .completed
        }
    }
    
    private var progressPercentage: Double {
        // Assume 3 plays = completed
        return min(Double(story.playCount) / 3.0, 1.0)
    }
    
    private var eventColor: Color {
        if let builtInEvent = story.builtInEvent {
            switch builtInEvent {
            case .bedtime: return StoryLibraryDesign.Colors.bedtimeColor
            case .schoolDay: return StoryLibraryDesign.Colors.schoolColor
            case .birthday: return StoryLibraryDesign.Colors.birthdayColor
            case .weekend: return StoryLibraryDesign.Colors.weekendColor
            case .rainyDay: return StoryLibraryDesign.Colors.rainyDayColor
            case .family: return StoryLibraryDesign.Colors.familyColor
            default: return StoryLibraryDesign.Colors.primaryPurple
            }
        } else if let customEvent = story.customEvent {
            return Color(hex: customEvent.colorHex)
        } else {
            return StoryLibraryDesign.Colors.primaryPurple
        }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            HStack(alignment: .top, spacing: StoryLibraryDesign.Spacing.cardPadding) {
                // Thumbnail
                thumbnailView
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    titleRow
                    contentPreview
                    Spacer(minLength: 8)
                    metadataRow
                }
            }
            .padding(StoryLibraryDesign.Spacing.cardPadding)
            
            // Progress bar or regeneration indicator
            if isRegenerating {
                regenerationProgressBar
            } else if storyStatus == .inProgress {
                progressBar
            }
        }
        .background(cardBackground)
        .overlay(cardOverlay)
        .shadow(
            color: Color.primary.opacity(isPressed ? 0.15 : 0.1),
            radius: isPressed ? 4 : StoryLibraryDesign.Layout.cardShadowRadius,
            y: isPressed ? 2 : StoryLibraryDesign.Layout.cardShadowY
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            if let hero = story.hero {
                // Show hero avatar
                HeroAvatarImageView(hero: hero, size: 60)
            } else {
                // Fallback to event icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [eventColor.opacity(0.3), eventColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: story.eventIcon)
                        .font(.system(size: 24))
                        .foregroundColor(eventColor)
                }
            }

            // Show first illustration as preview thumbnail if available
            if let firstIllustration = story.illustrations.first {
                AsyncImage(url: firstIllustration.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        )
                } placeholder: {
                    // Keep showing hero/event icon while loading
                    EmptyView()
                }
                .transition(.opacity)
            }
        }
    }
    
    @ViewBuilder
    private var titleRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(StoryLibraryDesign.Typography.cardTitle)
                    .foregroundColor(StoryLibraryDesign.Colors.titleText)
                    .lineLimit(2)

                if let hero = story.hero {
                    Text("Hero: \(hero.name)")
                        .font(.caption)
                        .foregroundColor(StoryLibraryDesign.Colors.primaryPurple)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            if storyStatus == .new {
                StatusBadge(status: .new)
            }
            
            if story.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
            }
        }
    }
    
    @ViewBuilder
    private var contentPreview: some View {
        Text(story.shortContent)
            .font(StoryLibraryDesign.Typography.cardBody)
            .foregroundColor(StoryLibraryDesign.Colors.bodyText)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: 12) {
            EventBadge(eventTitle: story.eventTitle, color: eventColor)

            Spacer()

            // Illustration indicator
            if !story.illustrations.isEmpty {
                IllustrationBadge(
                    count: story.illustrations.count,
                    generatedCount: story.generatedIllustrations.count
                )
            }

            // Regenerate audio button
            if !isRegenerating && story.audioFileName != nil {
                Button(action: { onRegenerateAudio?() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            if story.hasAudio && !isRegenerating {
                MetadataItem(
                    icon: "speaker.wave.2.fill",
                    text: "\(Int(story.estimatedDuration / 60))m",
                    color: StoryLibraryDesign.Colors.primaryOrange
                )
            }

            if story.playCount > 0 {
                MetadataItem(
                    icon: "play.circle.fill",
                    text: "\(story.playCount)",
                    color: StoryLibraryDesign.Colors.primaryBlue
                )
            }

            MetadataItem(
                icon: "calendar",
                text: formatSmartDate(story.createdAt),
                color: StoryLibraryDesign.Colors.captionText
            )
        }
    }
    
    @ViewBuilder
    private var regenerationProgressBar: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.7)
            Text("Regenerating audio...")
                .font(.caption)
                .foregroundColor(.purple)
            Spacer()
        }
        .padding(.horizontal, StoryLibraryDesign.Spacing.cardPadding)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.1))
    }

    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: StoryLibraryDesign.Layout.progressBarHeight)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                StoryLibraryDesign.Colors.inProgressBadge,
                                StoryLibraryDesign.Colors.inProgressBadge.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * progressPercentage,
                        height: StoryLibraryDesign.Layout.progressBarHeight
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progressPercentage)
            }
        }
        .frame(height: StoryLibraryDesign.Layout.progressBarHeight)
        .cornerRadius(StoryLibraryDesign.Layout.progressBarHeight / 2, corners: [.bottomLeft, .bottomRight])
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: StoryLibraryDesign.Layout.cardCornerRadius)
            .fill(
                storyStatus == .new ?
                LinearGradient(
                    colors: [
                        StoryLibraryDesign.Colors.newStoryGradientStart,
                        StoryLibraryDesign.Colors.newStoryGradientEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [StoryLibraryDesign.Colors.cardBackground, StoryLibraryDesign.Colors.cardBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    @ViewBuilder
    private var cardOverlay: some View {
        RoundedRectangle(cornerRadius: StoryLibraryDesign.Layout.cardCornerRadius)
            .stroke(
                storyStatus == .new ?
                StoryLibraryDesign.Colors.newBadge.opacity(0.3) :
                Color.clear,
                lineWidth: 1
            )
    }
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        }) {
            cardContent
        }
        .buttonStyle(AccessibleCardButtonStyle())
        .scaleEffect(isPressed ? 0.95 : (isFocused ? 1.02 : 1.0))
        .overlay(
            RoundedRectangle(cornerRadius: StoryLibraryDesign.Layout.cardCornerRadius)
                .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 3)
        )
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .focusable()
        .focused($isFocused)
        .onLongPressGesture(minimumDuration: 0.5) {
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showingActions = true
        } onPressingChanged: { pressing in
            withAnimation(reduceMotion ? nil : .spring()) {
                isPressed = pressing
            }
        }
        .contextMenu {
            Button(action: { onToggleFavorite?() }) {
                Label(
                    story.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: story.isFavorite ? "heart.slash" : "heart"
                )
            }

            Button(action: { onShare?() }) {
                Label("Share Story", systemImage: "square.and.arrow.up")
            }

            if story.hasAudio {
                Button(action: { /* Download functionality can be added later */ }) {
                    Label("Download Audio", systemImage: "arrow.down.circle")
                }
            }

            // Add retry failed illustrations option
            if hasFailedIllustrations {
                Button(action: { onRetryFailedIllustrations?() }) {
                    Label(
                        "Retry Failed Illustrations (\(failedIllustrationCount))",
                        systemImage: "arrow.clockwise.circle"
                    )
                }
            }
            
            if story.audioNeedsRegeneration {
                Button(action: { onRegenerateAudio?() }) {
                    Label("Regenerate Audio", systemImage: "arrow.clockwise")
                }
            }
            
            Button(action: { onEdit?() }) {
                Label("Edit Story", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: { onDelete?() }) {
                Label("Delete Story", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityLabelProvider.storyCardLabel(for: story))
        .accessibilityHint(AccessibilityLabelProvider.storyCardHint(for: story))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(story.isFavorite ? "Favorite" : "")
        .accessibilityActions {
            if let onToggleFavorite = onToggleFavorite {
                Button(story.isFavorite ? "Remove from favorites" : "Add to favorites") {
                    onToggleFavorite()
                }
            }
            
            if let onShare = onShare {
                Button("Share story") {
                    onShare()
                }
            }
            
            if story.hasAudio {
                Button("Download audio") {
                    // Download action
                }
            }
            
            if let onDelete = onDelete {
                Button("Delete story") {
                    onDelete()
                }
            }
        }
    }
    
    private func iconForEvent(_ event: StoryEvent) -> String {
        switch event {
        case .bedtime: return "moon.stars.fill"
        case .schoolDay: return "backpack.fill"
        case .birthday: return "birthday.cake.fill"
        case .weekend: return "sun.max.fill"
        case .rainyDay: return "cloud.rain.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .friendship: return "person.2.fill"
        case .learning: return "lightbulb.fill"
        case .helping: return "hands.sparkles.fill"
        case .holiday: return "gift.fill"
        }
    }
    
    private func formatSmartDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days < 7 {
                return "\(days)d ago"
            } else if days < 30 {
                return "\(days / 7)w ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
    }
}

// MARK: - Supporting Components

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(StoryLibraryDesign.Colors.captionText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.primary.opacity(0.05), radius: 4, y: 2)
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : StoryLibraryDesign.Colors.bodyText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? 
                        StoryLibraryDesign.Colors.primaryPurple : 
                        Color(.secondarySystemBackground)
                )
                .cornerRadius(20)
                .shadow(
                    color: Color.primary.opacity(isSelected ? 0.15 : 0.05),
                    radius: isSelected ? 6 : 3,
                    y: isSelected ? 3 : 1
                )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct StatusBadge: View {
    let status: StoryStatus
    
    var body: some View {
        Text(status.title)
            .font(StoryLibraryDesign.Typography.badge)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .cornerRadius(StoryLibraryDesign.Layout.badgeCornerRadius)
    }
}

struct EventBadge: View {
    let eventTitle: String
    let color: Color
    
    var body: some View {
        Text(eventTitle)
            .font(StoryLibraryDesign.Typography.badge)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(StoryLibraryDesign.Layout.badgeCornerRadius)
    }
}

struct MetadataItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(StoryLibraryDesign.Typography.metadata)
        }
        .foregroundColor(color)
    }
}

// MARK: - Supporting Types

enum StoryFilter: String, CaseIterable {
    case all = "All"
    case new = "New"
    case favorites = "Favorites"
    case recent = "Recent"
    
    var title: String { rawValue }
}

enum StoryStatus {
    case new, inProgress, completed
    
    var title: String {
        switch self {
        case .new: return "NEW"
        case .inProgress: return "READING"
        case .completed: return "COMPLETED"
        }
    }
    
    var color: Color {
        switch self {
        case .new: return StoryLibraryDesign.Colors.newBadge
        case .inProgress: return StoryLibraryDesign.Colors.inProgressBadge
        case .completed: return StoryLibraryDesign.Colors.completedBadge
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Load More View
struct LoadMoreView: View {
    @Binding var isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: StoryLibraryDesign.Colors.primaryPurple))
                    Text("Loading more stories...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(StoryLibraryDesign.Colors.bodyText)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(StoryLibraryDesign.Colors.primaryPurple)
                    Text("Load More Stories")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(StoryLibraryDesign.Colors.primaryPurple)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            )
        }
        .disabled(isLoading)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isLoading)
    }
}

// MARK: - Selection Circle
struct SelectionCircle: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.clear : Color.gray.opacity(0.4), lineWidth: 2)
                .background(
                    Circle()
                        .fill(isSelected ? Color.purple : Color.clear)
                )
                .frame(width: 24, height: 24)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 44, height: 44) // Larger tap target
        .contentShape(Circle())
    }
}

// MARK: - Illustration Badge
struct IllustrationBadge: View {
    let count: Int
    let generatedCount: Int
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: generatedCount == count ? "photo.stack.fill" : "photo.stack")
                .font(.system(size: 12))
                .rotationEffect(.degrees(isAnimating ? 5 : -5))
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            if generatedCount == count {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            } else {
                Text("\(generatedCount)/\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: generatedCount == count ?
                    [Color.purple, Color.pink] :
                    [Color.orange, Color.yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: generatedCount == count ?
            Color.purple.opacity(0.3) :
            Color.orange.opacity(0.3), radius: 4, y: 2)
        .onAppear {
            isAnimating = true
        }
        .accessibilityLabel("\(generatedCount) of \(count) illustrations generated")
    }
}

// MARK: - Edit Mode Toolbar
struct EditModeToolbar: View {
    @Binding var selectedStories: Set<PersistentIdentifier>
    let totalStories: Int
    let onDelete: () -> Void
    let onSelectAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 20) {
                // Selection info
                Text("\(selectedStories.count) selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // Select All/None button
                Button(action: onSelectAll) {
                    Text(selectedStories.count == totalStories ? "Deselect All" : "Select All")
                        .font(.subheadline.weight(.medium))
                }

                // Delete button
                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Color.red
                                .opacity(selectedStories.isEmpty ? 0.5 : 1.0)
                        )
                        .cornerRadius(20)
                }
                .disabled(selectedStories.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(.ultraThinMaterial)
        }
    }
}