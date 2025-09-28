//
//  CustomEventManagementView.swift
//  InfiniteStories
//
//  Complete management interface for custom events with pictogram support
//

import SwiftUI
import SwiftData

struct CustomEventManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomStoryEvent.createdAt, order: .reverse) private var customEvents: [CustomStoryEvent]

    @StateObject private var pictogramGenerator = EventPictogramGenerator()
    @StateObject private var cacheManager = PictogramCacheManager.shared

    @State private var searchText = ""
    @State private var selectedCategory: EventCategory?
    @State private var sortOption: SortOption = .newest
    @State private var viewMode: ViewMode = .grid
    @State private var isInSelectionMode = false
    @State private var selectedEvents: Set<UUID> = []
    @State private var showingCreationSheet = false
    @State private var showingBatchGenerationAlert = false
    @State private var batchGenerationProgress = 0.0
    @State private var batchGenerationStatus = ""

    enum ViewMode {
        case list, grid
    }

    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case oldest = "Oldest"
        case mostUsed = "Most Used"
        case alphabetical = "Alphabetical"
        case favorites = "Favorites First"
    }

    private var filteredEvents: [CustomStoryEvent] {
        var events = customEvents

        // Search filter
        if !searchText.isEmpty {
            events = events.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                event.eventDescription.localizedCaseInsensitiveContains(searchText) ||
                event.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Category filter
        if let category = selectedCategory {
            events = events.filter { $0.category == category }
        }

        // Sorting
        switch sortOption {
        case .newest:
            events.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            events.sort { $0.createdAt < $1.createdAt }
        case .mostUsed:
            events.sort { $0.usageCount > $1.usageCount }
        case .alphabetical:
            events.sort { $0.title < $1.title }
        case .favorites:
            events.sort { event1, event2 in
                if event1.isFavorite != event2.isFavorite {
                    return event1.isFavorite
                }
                return event1.createdAt > event2.createdAt
            }
        }

        return events
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if customEvents.isEmpty {
                    emptyStateView
                } else {
                    mainContentView
                }
            }
            .navigationTitle("Custom Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .searchable(text: $searchText, prompt: "Search events...")
            .sheet(isPresented: $showingCreationSheet) {
                CustomEventCreationView()
            }
            .alert("Generate Pictograms", isPresented: $showingBatchGenerationAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Generate") {
                    Task {
                        await generatePictogramsForSelected()
                    }
                }
            } message: {
                Text("Generate pictograms for \(selectedEvents.count) selected events?")
            }
        }
        .task {
            await cacheManager.warmCache(with: customEvents)
        }
    }

    // MARK: - Main Content View

    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Category filter
            categoryFilterView

            // Stats bar
            statsBar

            // Content based on view mode
            Group {
                if viewMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All categories
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    color: .blue
                ) {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedCategory = nil
                    }
                }

                ForEach(EventCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        color: Color(hex: category.defaultColor)
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            StatItem(
                icon: "square.stack.3d.up",
                value: "\(filteredEvents.count)",
                label: "Events"
            )

            StatItem(
                icon: "photo",
                value: "\(filteredEvents.filter { $0.hasPictogram }.count)",
                label: "With Pictograms"
            )

            StatItem(
                icon: "star.fill",
                value: "\(filteredEvents.filter { $0.isFavorite }.count)",
                label: "Favorites"
            )

            Spacer()

            // View mode toggle
            Picker("View Mode", selection: $viewMode) {
                Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                Image(systemName: "list.bullet").tag(ViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredEvents) { event in
                    CustomEventGridCard(
                        event: event,
                        isSelected: selectedEvents.contains(event.id),
                        isInSelectionMode: isInSelectionMode,
                        onTap: {
                            if isInSelectionMode {
                                toggleSelection(for: event)
                            }
                        }
                    )
                    .contextMenu {
                        eventContextMenu(for: event)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(filteredEvents) { event in
                CustomEventListRow(
                    event: event,
                    isSelected: selectedEvents.contains(event.id),
                    isInSelectionMode: isInSelectionMode,
                    onTap: {
                        if isInSelectionMode {
                            toggleSelection(for: event)
                        }
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteEvent(event)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        event.toggleFavorite()
                    } label: {
                        Label(
                            event.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: event.isFavorite ? "star.fill" : "star"
                        )
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .leading) {
                    NavigationLink(destination: CustomEventDetailView(event: event)) {
                        Label("Details", systemImage: "info.circle")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func eventContextMenu(for event: CustomStoryEvent) -> some View {
        NavigationLink(destination: CustomEventDetailView(event: event)) {
            Label("View Details", systemImage: "info.circle")
        }

        NavigationLink(destination: PictogramGenerationView(event: event)) {
            Label(
                event.hasPictogram ? "Regenerate Pictogram" : "Generate Pictogram",
                systemImage: "photo.badge.plus"
            )
        }

        Button {
            event.toggleFavorite()
        } label: {
            Label(
                event.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: event.isFavorite ? "star.slash" : "star"
            )
        }

        Divider()

        Button(role: .destructive) {
            deleteEvent(event)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 80))
                .foregroundColor(.purple.opacity(0.6))
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("No Custom Events Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create personalized story scenarios for your little ones")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showingCreationSheet = true
            } label: {
                Label("Create Your First Event", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
        }
        .padding()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if isInSelectionMode {
                Button("Cancel") {
                    withAnimation {
                        isInSelectionMode = false
                        selectedEvents.removeAll()
                    }
                }
            } else {
                Button("Close") {
                    dismiss()
                }
            }
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isInSelectionMode {
                // Selection mode actions
                Menu {
                    Button {
                        showingBatchGenerationAlert = true
                    } label: {
                        Label("Generate Pictograms", systemImage: "photo.badge.plus")
                    }
                    .disabled(selectedEvents.isEmpty)

                    Button(role: .destructive) {
                        deleteSelectedEvents()
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                    .disabled(selectedEvents.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            } else {
                // Normal mode actions
                Menu {
                    // Sort options
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }

                    Button {
                        withAnimation {
                            isInSelectionMode = true
                        }
                    } label: {
                        Label("Select", systemImage: "checkmark.circle")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                }

                Button {
                    showingCreationSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleSelection(for event: CustomStoryEvent) {
        if selectedEvents.contains(event.id) {
            selectedEvents.remove(event.id)
        } else {
            selectedEvents.insert(event.id)
        }
    }

    private func deleteEvent(_ event: CustomStoryEvent) {
        withAnimation {
            // Delete pictogram if exists
            Task {
                await pictogramGenerator.deletePictogram(for: event)
            }
            modelContext.delete(event)
        }
    }

    private func deleteSelectedEvents() {
        for eventID in selectedEvents {
            if let event = customEvents.first(where: { $0.id == eventID }) {
                deleteEvent(event)
            }
        }
        selectedEvents.removeAll()
        isInSelectionMode = false
    }

    private func generatePictogramsForSelected() async {
        let eventsToGenerate = customEvents.filter { selectedEvents.contains($0.id) && !$0.hasPictogram }

        await pictogramGenerator.generatePictogramsInBatch(
            for: eventsToGenerate,
            style: .playful
        ) { progress, status in
            Task { @MainActor in
                batchGenerationProgress = progress
                batchGenerationStatus = status
            }
        }

        await MainActor.run {
            selectedEvents.removeAll()
            isInSelectionMode = false
        }
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Grid Card

struct CustomEventGridCard: View {
    let event: CustomStoryEvent
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onTap: () -> Void

    var body: some View {
        NavigationLink(destination: CustomEventDetailView(event: event)) {
            VStack(spacing: 12) {
                // Pictogram or Icon
                ZStack {
                    if event.hasPictogram {
                        CachedPictogramImage(event: event)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: event.colorHex).opacity(0.3),
                                        Color(hex: event.colorHex).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: event.iconName)
                                    .font(.system(size: 36))
                                    .foregroundColor(Color(hex: event.colorHex))
                            )
                    }

                    // Selection indicator
                    if isInSelectionMode {
                        Circle()
                            .fill(isSelected ? Color.blue : Color.white)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray, lineWidth: 2)
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .opacity(isSelected ? 1 : 0)
                            )
                            .position(x: 70, y: 10)
                    }

                    // Favorite indicator
                    if event.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .position(x: 10, y: 10)
                    }
                }

                VStack(spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 4) {
                        Image(systemName: event.category.icon)
                            .font(.caption2)
                        Text(event.category.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)

                    Text(event.formattedUsageCount)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .onTapGesture {
            if isInSelectionMode {
                onTap()
            }
        }
    }
}

// MARK: - List Row

struct CustomEventListRow: View {
    let event: CustomStoryEvent
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            if isInSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .onTapGesture {
                        onTap()
                    }
            }

            // Pictogram
            if event.hasPictogram {
                CachedPictogramImage(event: event)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: event.colorHex).opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: event.iconName)
                            .font(.title2)
                            .foregroundColor(Color(hex: event.colorHex))
                    )
            }

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(1)

                    if event.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                Text(event.eventDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(event.category.rawValue, systemImage: event.category.icon)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(event.formattedUsageCount)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Chevron for navigation
            if !isInSelectionMode {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CustomEventManagementView()
        .modelContainer(for: [CustomStoryEvent.self], inMemory: true)
}