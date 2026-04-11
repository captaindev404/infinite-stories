//
//  CustomEventManagementView.swift
//  InfiniteStories
//
//  Complete management interface for custom events (API-based)
//

import SwiftUI

struct CustomEventManagementView: View {
    @Environment(\.dismiss) private var dismiss

    // API-based state management
    @State private var customEvents: [CustomStoryEvent] = []
    @State private var isLoading = true
    @State private var error: Error?

    private let repository = CustomEventRepository()

    @State private var searchText = ""
    @State private var selectedCategory: EventCategory?
    @State private var sortOption: SortOption = .newest
    @State private var viewMode: ViewMode = .grid
    @State private var isInSelectionMode = false
    @State private var selectedEvents: Set<String> = []
    @State private var showingCreationSheet = false
    @State private var showingDeleteConfirmation = false

    enum ViewMode {
        case list, grid
    }

    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case oldest = "Oldest"
        case mostUsed = "Most Used"
        case alphabetical = "Alphabetical"
        case favorites = "Favorites First"

        var localizedName: String {
            switch self {
            case .newest: return String(localized: "customEvent.management.sort.newest")
            case .oldest: return String(localized: "customEvent.management.sort.oldest")
            case .mostUsed: return String(localized: "customEvent.management.sort.mostUsed")
            case .alphabetical: return String(localized: "customEvent.management.sort.alphabetical")
            case .favorites: return String(localized: "customEvent.management.sort.favorites")
            }
        }
    }

    private var filteredEvents: [CustomStoryEvent] {
        var events = customEvents

        // Search filter
        if !searchText.isEmpty {
            events = events.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                event.description.localizedCaseInsensitiveContains(searchText) ||
                event.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Category filter
        if let category = selectedCategory {
            events = events.filter { $0.eventCategory == category }
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
                // System background
                Color(.systemBackground)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("customEvent.management.loading")
                } else if let error = error {
                    ErrorView(
                        error: error,
                        retryAction: {
                            Task {
                                await loadEvents()
                            }
                        }
                    )
                } else if customEvents.isEmpty {
                    emptyStateView
                } else {
                    mainContentView
                }
            }
            .navigationTitle("customEvent.management.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            // BUG-01 fix: pin search field to a dedicated drawer so it cannot
            // collapse onto the navigation bar after a child sheet is dismissed.
            // Previously, after dismissing CustomEventCreationView via "Annuler",
            // the search bar would go into an "active" state and the entire
            // navigation chrome (close button, title) would be hidden, trapping
            // the user. Forcing `.navigationBarDrawer(displayMode: .always)`
            // keeps the search bar separate from the toolbar so the close button
            // and title remain visible at all times.
            //
            // Manual verification checklist (BUG-01):
            //   1. Tap purple grid FAB on Home → management sheet opens with title + close button.
            //   2. Tap "+" → creation sheet opens.
            //   3. Tap "Annuler" → returns to management sheet; close button + title still visible.
            //   4. Tap close button → returns to Home.
            //   5. Repeat with swipe-to-dismiss instead of close button.
            //   6. Repeat with a category filter pill selected before opening creation.
            //   7. Repeat after typing into the search field before opening creation.
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "customEvent.management.search"
            )
            .sheet(isPresented: $showingCreationSheet) {
                CustomEventCreationView(onEventCreated: { newEvent in
                    customEvents.insert(newEvent, at: 0)
                })
            }
            .alert("customEvent.management.deleteAlert.title", isPresented: $showingDeleteConfirmation) {
                Button("customEvent.management.deleteAlert.cancel", role: .cancel) { }
                Button("customEvent.management.deleteAlert.delete", role: .destructive) {
                    Task {
                        await deleteSelectedEvents()
                    }
                }
            } message: {
                Text(String(localized: "customEvent.management.deleteAlert.message \(selectedEvents.count)"))
            }
        }
        .task {
            await loadEvents()
        }
    }

    // MARK: - Load Events

    private func loadEvents() async {
        isLoading = true
        error = nil

        do {
            customEvents = try await repository.fetchCustomEvents()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
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
                    title: String(localized: "customEvent.management.filter.all"),
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
                        title: category.displayName,
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
                label: String(localized: "customEvent.management.stats.events")
            )

            StatItem(
                icon: "sparkles",
                value: "\(filteredEvents.filter { $0.aiEnhanced }.count)",
                label: String(localized: "customEvent.management.stats.aiEnhanced")
            )

            StatItem(
                icon: "star.fill",
                value: "\(filteredEvents.filter { $0.isFavorite }.count)",
                label: String(localized: "customEvent.management.stats.favorites")
            )

            Spacer()

            // View mode toggle
            Picker("customEvent.management.viewMode", selection: $viewMode) {
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
        .refreshable {
            await loadEvents()
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
                        Task {
                            await deleteEvent(event)
                        }
                    } label: {
                        Label("customEvent.management.swipe.delete", systemImage: "trash")
                    }

                    Button {
                        Task {
                            await toggleFavorite(for: event)
                        }
                    } label: {
                        Label(
                            event.isFavorite ? String(localized: "customEvent.management.swipe.unfavorite") : String(localized: "customEvent.management.swipe.favorite"),
                            systemImage: event.isFavorite ? "star.fill" : "star"
                        )
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .leading) {
                    NavigationLink(destination: CustomEventDetailView(
                        event: event,
                        onEventUpdated: { updatedEvent in
                            if let index = customEvents.firstIndex(where: { $0.id == updatedEvent.id }) {
                                customEvents[index] = updatedEvent
                            }
                        }
                    )) {
                        Label("customEvent.management.swipe.details", systemImage: "info.circle")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await loadEvents()
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func eventContextMenu(for event: CustomStoryEvent) -> some View {
        NavigationLink(destination: CustomEventDetailView(
            event: event,
            onEventUpdated: { updatedEvent in
                if let index = customEvents.firstIndex(where: { $0.id == updatedEvent.id }) {
                    customEvents[index] = updatedEvent
                }
            }
        )) {
            Label("customEvent.management.context.viewDetails", systemImage: "info.circle")
        }

        if !event.aiEnhanced {
            Button {
                Task {
                    await enhanceEvent(event)
                }
            } label: {
                Label("customEvent.management.context.enhance", systemImage: "sparkles")
            }
        }

        Button {
            Task {
                await toggleFavorite(for: event)
            }
        } label: {
            Label(
                event.isFavorite ? String(localized: "customEvent.management.context.unfavorite") : String(localized: "customEvent.management.context.favorite"),
                systemImage: event.isFavorite ? "star.slash" : "star"
            )
        }

        Divider()

        Button(role: .destructive) {
            Task {
                await deleteEvent(event)
            }
        } label: {
            Label("customEvent.management.context.delete", systemImage: "trash")
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
                Text("customEvent.management.empty.title")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("customEvent.management.empty.message")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showingCreationSheet = true
            } label: {
                Label("customEvent.management.empty.createFirst", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
        }
        .padding()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if isInSelectionMode {
                Button("customEvent.management.toolbar.cancel") {
                    withAnimation {
                        isInSelectionMode = false
                        selectedEvents.removeAll()
                    }
                }
            } else {
                Button("customEvent.management.toolbar.close") {
                    dismiss()
                }
            }
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isInSelectionMode {
                // Selection mode actions
                Menu {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("customEvent.management.toolbar.deleteSelected", systemImage: "trash")
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
                                    Text(option.localizedName)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("customEvent.management.toolbar.sort", systemImage: "arrow.up.arrow.down")
                    }

                    Button {
                        withAnimation {
                            isInSelectionMode = true
                        }
                    } label: {
                        Label("customEvent.management.toolbar.select", systemImage: "checkmark.circle")
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

    private func deleteEvent(_ event: CustomStoryEvent) async {
        do {
            try await repository.deleteCustomEvent(event)
            withAnimation {
                customEvents.removeAll { $0.id == event.id }
            }
        } catch {
            Logger.api.error("Failed to delete event: \(error.localizedDescription)")
        }
    }

    private func deleteSelectedEvents() async {
        for eventID in selectedEvents {
            if let event = customEvents.first(where: { $0.id == eventID }) {
                await deleteEvent(event)
            }
        }
        selectedEvents.removeAll()
        isInSelectionMode = false
    }

    private func toggleFavorite(for event: CustomStoryEvent) async {
        var updatedEvent = event
        updatedEvent.isFavorite.toggle()

        do {
            let result = try await repository.updateCustomEvent(updatedEvent)
            if let index = customEvents.firstIndex(where: { $0.id == event.id }) {
                customEvents[index] = result
            }
        } catch {
            Logger.api.error("Failed to update favorite: \(error.localizedDescription)")
        }
    }

    private func enhanceEvent(_ event: CustomStoryEvent) async {
        do {
            let enhancedEvent = try await repository.enhanceEvent(event)
            if let index = customEvents.firstIndex(where: { $0.id == event.id }) {
                customEvents[index] = enhancedEvent
            }
        } catch {
            Logger.api.error("Failed to enhance event: \(error.localizedDescription)")
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
                // BUG-16: longer FR/EN labels like "Apprendre"/"Learning"
                // must stay on a single line inside the pill. Limit to one
                // line and allow shrinking to 75% before truncation.
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: true, vertical: false)
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
                // BUG-16: FR label "Événements" was wrapping mid-word in the
                // stats bar. Keep on a single line and shrink before truncating.
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: event.colorHex).opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: event.iconName)
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: event.colorHex))
                        )

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

                    // AI Enhanced indicator
                    if event.aiEnhanced {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .position(x: 10, y: 70)
                    }
                }

                VStack(spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 4) {
                        Image(systemName: event.eventCategory.icon)
                            .font(.caption2)
                        Text(event.eventCategory.displayName)
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

            // Icon
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: event.colorHex).opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: event.iconName)
                        .font(.title2)
                        .foregroundColor(Color(hex: event.colorHex))
                )

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

                    if event.aiEnhanced {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }

                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(event.eventCategory.displayName, systemImage: event.eventCategory.icon)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("*")
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
}
