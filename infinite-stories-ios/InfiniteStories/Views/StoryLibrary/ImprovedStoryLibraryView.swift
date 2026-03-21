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

        // Text Colors (adaptive - designed for liquid glass backgrounds)
        static let titleText = Color.primary
        static let bodyText = Color.primary.opacity(0.75)
        static let captionText = Color.primary.opacity(0.6)
        static let searchPlaceholder = Color.primary.opacity(0.5)
        static let iconTint = Color.primary.opacity(0.7)
        static let selectedText = Color.white
        static let badgeText = Color.white
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
    // API-only state management
    @State private var stories: [Story] = []
    @State private var heroes: [Hero] = []
    @State private var isLoadingData = false
    @State private var loadError: Error?

    @Environment(\.dismiss) private var dismiss

    // Repositories
    private let storyRepository = StoryRepository()
    private let heroRepository = HeroRepository()

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
    @State private var regeneratingStories: Set<UUID> = []
    @State private var isEditMode = false
    @State private var selectedStories: Set<UUID> = []
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
        .navigationTitle(String(localized: "library.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditMode ? String(localized: "library.button.done") : String(localized: "library.button.edit")) {
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
            // Find the index of the selected story in the filtered list
            let storyIndex = filteredStories.firstIndex(where: { $0.id == story.id }) ?? 0
            AudioPlayerView(
                story: story,
                allStories: filteredStories,
                storyIndex: storyIndex
            )
            .glassSheet()
        }
        .sheet(item: $storyToRegenerate) { story in
            AudioRegenerationView(story: story) {
                // On completion, play the story
                selectedStory = story
            }
        }
        .alert(String(localized: "library.alert.delete.title"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "library.button.cancel"), role: .cancel) { }
            Button(String(localized: "library.button.delete"), role: .destructive) {
                if let story = storyToDelete {
                    deleteStory(story)
                }
            }
        } message: {
            Text(String(localized: "library.alert.delete.message"))
        }
        .alert(String(localized: "library.alert.bulk.delete.title.\(selectedStories.count)"), isPresented: $showBulkDeleteConfirmation) {
            Button(String(localized: "library.button.cancel"), role: .cancel) { }
            Button(String(localized: "library.button.delete.all"), role: .destructive) {
                deleteSelectedStories()
            }
        } message: {
            Text(String(localized: "library.alert.bulk.delete.message.\(selectedStories.count)"))
        }
        .task {
            await loadStories()
        }
    }

    // MARK: - API Operations

    private func loadStories() async {
        guard NetworkMonitor.shared.isConnected else {
            loadError = APIError.networkUnavailable
            return
        }

        isLoadingData = true
        loadError = nil

        do {
            // Fetch heroes first to match with stories
            heroes = try await heroRepository.fetchHeroes()
            Logger.ui.info("Loaded \(heroes.count) heroes for story matching")

            // Fetch stories and pass heroes for proper hero assignment
            stories = try await storyRepository.fetchStories(heroId: nil, limit: 100, offset: 0, heroes: heroes)
            Logger.ui.success("Loaded \(stories.count) stories")
        } catch {
            loadError = error
            Logger.ui.error("Failed to load stories: \(error.localizedDescription)")
        }

        isLoadingData = false
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: StoryLibraryDesign.Spacing.elementSpacing) {
            // Search bar with liquid glass styling
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(StoryLibraryDesign.Colors.iconTint)
                    .font(.system(size: 16))

                TextField(String(localized: "library.search.placeholder"), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(StoryLibraryDesign.Colors.titleText)
                    .font(.system(size: 16))
                    .accessibilityLabel(String(localized: "library.search.accessibility.label"))
                    .accessibilityHint(String(localized: "library.search.accessibility.hint"))

                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(StoryLibraryDesign.Colors.iconTint)
                            .font(.system(size: 16))
                            .scaleEffect(searchText.isEmpty ? 0 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searchText)
                            .accessibilityLabel(String(localized: "library.search.clear.accessibility.label"))
                            .accessibilityHint(String(localized: "library.search.clear.accessibility.hint"))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 12)
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: StoryLibraryDesign.Spacing.cardSpacing) {
            StatCard(
                icon: "sparkles",
                value: "\(newStories.count)",
                label: String(localized: "library.stats.new"),
                color: StoryLibraryDesign.Colors.newBadge
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "library.stats.new.accessibility.\(newStories.count)"))

            StatCard(
                icon: "book.fill",
                value: "\(inProgressStories.count)",
                label: String(localized: "library.stats.reading"),
                color: StoryLibraryDesign.Colors.inProgressBadge
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "library.stats.reading.accessibility.\(inProgressStories.count)"))

            StatCard(
                icon: "checkmark.circle.fill",
                value: "\(completedStories.count)",
                label: String(localized: "library.stats.completed"),
                color: StoryLibraryDesign.Colors.completedBadge
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "library.stats.completed.accessibility.\(completedStories.count)"))

            StatCard(
                icon: "heart.fill",
                value: "\(stories.filter { $0.isFavorite }.count)",
                label: String(localized: "library.stats.favorites"),
                color: Color.red
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "library.stats.favorites.accessibility.\(stories.filter { $0.isFavorite }.count)"))
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
            
            Text(String(localized: "library.empty.title"))
                .font(StoryLibraryDesign.Typography.sectionHeader)
                .foregroundColor(StoryLibraryDesign.Colors.titleText)

            Text(String(localized: "library.empty.message"))
                .font(StoryLibraryDesign.Typography.cardBody)
                .foregroundColor(StoryLibraryDesign.Colors.captionText)
        }
        .padding(40)
    }
    
    // MARK: - Helper Functions
    private func deleteStory(_ story: Story) {
        Task {
            do {
                guard let backendId = story.backendId else {
                    Logger.ui.error("Story has no backend ID")
                    return
                }
                try await storyRepository.deleteStory(id: backendId)
                withAnimation {
                    stories.removeAll { $0.id == story.id }
                }
                Logger.ui.success("Deleted story: \(story.title)")
            } catch {
                loadError = error
                Logger.ui.error("Failed to delete story: \(error.localizedDescription)")
            }
        }
    }

    private func deleteSelectedStories() {
        Task {
            for storyId in selectedStories {
                if let story = stories.first(where: { $0.id == storyId }) {
                    if let backendId = story.backendId {
                        try? await storyRepository.deleteStory(id: backendId)
                        withAnimation {
                            stories.removeAll { $0.id == story.id }
                        }
                    }
                }
            }
            selectedStories.removeAll()
            isEditMode = false
        }
    }

    private func toggleFavorite(_ story: Story) {
        Task {
            do {
                guard let backendId = story.backendId else {
                    Logger.ui.error("Story has no backend ID")
                    return
                }
                let newFavoriteState = !story.isFavorite
                _ = try await storyRepository.updateStory(id: backendId, title: nil, content: nil, isFavorite: newFavoriteState)
                withAnimation {
                    if let index = stories.firstIndex(where: { $0.id == story.id }) {
                        stories[index].isFavorite = newFavoriteState
                    }
                }
                Logger.ui.success("Updated favorite status")
            } catch {
                loadError = error
                Logger.ui.error("Failed to update favorite: \(error.localizedDescription)")
            }
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

        StoryCard(
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
            failedIllustrationCount: viewModel.failedIllustrationCount(for: story),
            variant: .full
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


// MARK: - Supporting Components

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .liquidGlassCard(cornerRadius: 12, variant: .tinted(color))
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : StoryLibraryDesign.Colors.titleText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .liquidGlassCapsule(variant: isSelected ? .tinted(.purple) : .regular)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel(String(localized: "library.filter.accessibility.label.\(title)"))
        .accessibilityHint(isSelected ? String(localized: "library.filter.selected.accessibility.hint") : String(localized: "library.filter.accessibility.hint.\(title.lowercased())"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct EventBadge: View {
    let eventTitle: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(eventTitle)
            .font(StoryLibraryDesign.Typography.badge)
            .foregroundColor(colorScheme == .dark ? color.opacity(0.9) : color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .liquidGlassCapsule(variant: .tinted(color))
    }
}

struct MetadataItem: View {
    let icon: String
    let text: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(StoryLibraryDesign.Typography.metadata)
        }
        .foregroundColor(color == StoryLibraryDesign.Colors.captionText ?
            StoryLibraryDesign.Colors.captionText :
            (colorScheme == .dark ? color.opacity(0.85) : color))
    }
}

// MARK: - Supporting Types

enum StoryFilter: String, CaseIterable {
    case all = "all"
    case new = "new"
    case favorites = "favorites"
    case recent = "recent"

    var title: String {
        switch self {
        case .all: return String(localized: "library.filter.all")
        case .new: return String(localized: "library.filter.new")
        case .favorites: return String(localized: "library.filter.favorites")
        case .recent: return String(localized: "library.filter.recent")
        }
    }
}

// MARK: - Load More View
struct LoadMoreView: View {
    @Binding var isLoading: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ?
                            StoryLibraryDesign.Colors.primaryPurple.opacity(0.9) :
                            StoryLibraryDesign.Colors.primaryPurple))
                    Text(String(localized: "library.loading.more"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(StoryLibraryDesign.Colors.bodyText)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(colorScheme == .dark ?
                            StoryLibraryDesign.Colors.primaryPurple.opacity(0.9) :
                            StoryLibraryDesign.Colors.primaryPurple)
                    Text(String(localized: "library.button.load.more"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ?
                            StoryLibraryDesign.Colors.primaryPurple.opacity(0.9) :
                            StoryLibraryDesign.Colors.primaryPurple)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .liquidGlassCapsule(variant: .tinted(.purple))
        }
        .disabled(isLoading)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isLoading)
        .accessibilityLabel(isLoading ? String(localized: "library.loading.accessibility.label") : String(localized: "library.load.more.accessibility.label"))
        .accessibilityHint(isLoading ? String(localized: "library.loading.accessibility.hint") : String(localized: "library.load.more.accessibility.hint"))
    }
}

// MARK: - Selection Circle
struct SelectionCircle: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Subtle glass background for the entire circle frame
            Circle()
                .fill(Color.clear)
                .frame(width: 32, height: 32)
                .liquidGlassCard(cornerRadius: 16, variant: isSelected ? .tinted(.accentColor) : .clear)

            // Selection indicator
            Circle()
                .strokeBorder(isSelected ? Color.clear : Color.accentColor.opacity(0.3), lineWidth: 2)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
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
        .foregroundColor(StoryLibraryDesign.Colors.badgeText)
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
        .accessibilityLabel(String(localized: "library.illustrations.accessibility.\(generatedCount).\(count)"))
    }
}

// MARK: - Edit Mode Toolbar
struct EditModeToolbar: View {
    @Binding var selectedStories: Set<UUID>
    let totalStories: Int
    let onDelete: () -> Void
    let onSelectAll: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 20) {
                // Selection info
                Text(String(localized: "library.selection.count.\(selectedStories.count)"))
                    .font(.subheadline)
                    .foregroundColor(StoryLibraryDesign.Colors.bodyText)
                    .accessibilityLabel(String(localized: "library.selection.accessibility.\(selectedStories.count)"))

                Spacer()

                // Select All/None button with glass styling
                Button(action: onSelectAll) {
                    Text(selectedStories.count == totalStories ? String(localized: "library.button.deselect.all") : String(localized: "library.button.select.all"))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(colorScheme == .dark ?
                            Color.accentColor.opacity(0.9) :
                            Color.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .liquidGlassCapsule(variant: .tinted(.accentColor))
                }
                .accessibilityLabel(selectedStories.count == totalStories ? String(localized: "library.deselect.all.accessibility.label") : String(localized: "library.select.all.accessibility.label"))
                .accessibilityHint(selectedStories.count == totalStories ? String(localized: "library.deselect.all.accessibility.hint") : String(localized: "library.select.all.accessibility.hint"))

                // Delete button with glass styling
                Button(action: onDelete) {
                    Label(String(localized: "library.button.delete"), systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(selectedStories.isEmpty ?
                            Color.red.opacity(0.5) :
                            (colorScheme == .dark ? Color.red.opacity(0.9) : Color.red))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .liquidGlassCapsule(variant: .tintedInteractive(.red))
                }
                .disabled(selectedStories.isEmpty)
                .accessibilityLabel(String(localized: "library.delete.accessibility.label"))
                .accessibilityHint(selectedStories.isEmpty ? String(localized: "library.delete.empty.accessibility.hint") : String(localized: "library.delete.selected.accessibility.hint.\(selectedStories.count)"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .liquidGlassBackground()
        }
    }
}

#Preview {
    ImprovedStoryLibraryView()
}
