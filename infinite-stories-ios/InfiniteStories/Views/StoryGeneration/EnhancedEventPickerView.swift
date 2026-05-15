//
//  EnhancedEventPickerView.swift
//  InfiniteStories
//
//  Created on 2025-09-14.
//

import SwiftUI

struct EnhancedEventPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedBuiltInEvent: StoryEvent?
    @Binding var selectedCustomEvent: CustomStoryEvent?

    // API-based state management
    @State private var customEvents: [CustomStoryEvent] = []
    @State private var isLoading = true
    @State private var loadError: Error?

    private let repository = CustomEventRepository()

    @State private var showingCustomEventCreation = false
    @State private var showingCustomEventManagement = false
    @State private var searchText = ""
    @State private var selectedCategory: EventCategory? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(String(localized: "story.event.search.placeholder",
                                         comment: "Event Picker: Search placeholder"), text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Create Custom Event Button
                    Button(action: { showingCustomEventCreation = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("story.event.custom.create")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("story.event.custom.subtitle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .opacity(0.1)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Category filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            CategoryFilterChip(
                                title: String(localized: "story.event.category.all",
                                              comment: "Event Picker: All categories filter"),
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )

                            ForEach(EventCategory.allCases, id: \.self) { category in
                                CategoryFilterChip(
                                    title: category.displayName,
                                    icon: category.icon,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Loading state
                    if isLoading {
                        ProgressView(String(localized: "story.event.loading",
                                            comment: "Event Picker: Loading custom events"))
                            .padding(.vertical, 20)
                    } else if let error = loadError {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundColor(.orange)
                            Text("story.event.error.title")
                                .font(.headline)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("common.retry") {
                                Task {
                                    await loadCustomEvents()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 20)
                    } else {
                        // Custom Events Section
                        if !filteredCustomEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("story.event.custom.section")
                                        .font(.headline)

                                    Spacer()

                                    // Manage button
                                    Button(action: { showingCustomEventManagement = true }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.grid.2x2")
                                                .font(.caption)
                                            Text("common.manage")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.purple.opacity(0.15))
                                        .foregroundColor(.purple)
                                        .cornerRadius(8)
                                    }

                                    Text("\(filteredCustomEvents.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal)

                                ForEach(filteredCustomEvents) { event in
                                    CustomEventCard(
                                        event: event,
                                        isSelected: selectedCustomEvent?.id == event.id,
                                        action: {
                                            selectedCustomEvent = event
                                            selectedBuiltInEvent = nil
                                            dismiss()
                                        },
                                        onDelete: {
                                            Task {
                                                await deleteCustomEvent(event)
                                            }
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }

                    // Built-in Events Section
                    if !filteredBuiltInEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("story.event.suggested")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(filteredBuiltInEvents, id: \.self) { event in
                                BuiltInEventCard(
                                    event: event,
                                    isSelected: selectedBuiltInEvent == event,
                                    action: {
                                        selectedBuiltInEvent = event
                                        selectedCustomEvent = nil
                                        dismiss()
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Empty state
                    if filteredBuiltInEvents.isEmpty && filteredCustomEvents.isEmpty && !isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)

                            Text("story.event.empty.title")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            if !searchText.isEmpty {
                                Text("story.event.empty.search")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 50)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("story.event.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCustomEventCreation) {
                CustomEventCreationView(onEventCreated: { newEvent in
                    customEvents.insert(newEvent, at: 0)
                })
            }
            .sheet(isPresented: $showingCustomEventManagement) {
                CustomEventManagementView()
            }
            .refreshable {
                await loadCustomEvents()
            }
        }
        .task {
            await loadCustomEvents()
        }
    }

    // MARK: - Load Custom Events

    private func loadCustomEvents() async {
        isLoading = true
        loadError = nil

        do {
            customEvents = try await repository.fetchCustomEvents()
            isLoading = false
        } catch {
            loadError = error
            isLoading = false
        }
    }

    // MARK: - Filtering

    private var filteredBuiltInEvents: [StoryEvent] {
        let events = StoryEvent.allCases

        guard !searchText.isEmpty else {
            return selectedCategory == nil ? events : []
        }

        return events.filter { event in
            let matchesSearch = searchText.isEmpty ||
                event.localizedName.localizedCaseInsensitiveContains(searchText) ||
                event.rawValue.localizedCaseInsensitiveContains(searchText) ||
                event.localizedDescription.localizedCaseInsensitiveContains(searchText)

            return matchesSearch
        }
    }

    private var filteredCustomEvents: [CustomStoryEvent] {
        customEvents.filter { event in
            let matchesSearch = searchText.isEmpty ||
                event.title.localizedCaseInsensitiveContains(searchText) ||
                event.description.localizedCaseInsensitiveContains(searchText) ||
                event.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }

            let matchesCategory = selectedCategory == nil || event.eventCategory == selectedCategory

            return matchesSearch && matchesCategory
        }
    }

    // MARK: - Actions

    private func deleteCustomEvent(_ event: CustomStoryEvent) async {
        do {
            try await repository.deleteCustomEvent(event)
            customEvents.removeAll { $0.id == event.id }
        } catch {
            Logger.api.error("Failed to delete custom event: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Views

struct CategoryFilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? .orange : .primary)
            .liquidGlassCapsule(variant: isSelected ? .tinted(.orange) : .regular)
        }
        .buttonStyle(.plain)
    }
}

struct BuiltInEventCard: View {
    let event: StoryEvent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: event.icon)
                    .font(.title2)
                    .foregroundColor(.orange)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    // L10N-05: localized event name + localized description
                    // (promptSeed stays English because it feeds the AI prompt).
                    Text(event.localizedName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(event.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .liquidGlassCard(cornerRadius: 12, variant: isSelected ? .tinted(.orange) : .regular)
        }
        .buttonStyle(.plain)
    }
}

struct CustomEventCard: View {
    let event: CustomStoryEvent
    let isSelected: Bool
    let action: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false
    @State private var showingDetailView = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Icon
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: event.colorHex).opacity(0.15))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: event.iconName)
                                .font(.title2)
                                .foregroundColor(Color(hex: event.colorHex))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.title)
                                .font(.headline)
                                .foregroundColor(.primary)

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
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }

                HStack(spacing: 12) {
                    // Category badge
                    HStack(spacing: 4) {
                        Image(systemName: event.eventCategory.icon)
                            .font(.caption2)
                        Text(event.eventCategory.displayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: event.colorHex).opacity(0.2))
                    .cornerRadius(6)

                    // Age range badge — route through AgeRange.localizedName so
                    // FR users see "Tous âges" instead of the raw English
                    // rawValue ("All Ages"). See Task #81 for the pending raw/id
                    // split on AgeRange.
                    if let ageRange = event.eventAgeRange {
                        Text(ageRange.localizedName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                    }

                    // Tone badge
                    Text(event.storyTone.localizedName)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)

                    Spacer()

                    // Usage count
                    Text(event.formattedUsageCount)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .liquidGlassCard(cornerRadius: 12, variant: isSelected ? .tinted(.orange) : .regular)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: {
                showingDetailView = true
            }) {
                Label("common.view.details", systemImage: "info.circle")
            }

            Divider()

            Button(role: .destructive, action: {
                showingDeleteConfirmation = true
            }) {
                Label("common.delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingDetailView) {
            NavigationStack {
                CustomEventDetailView(event: event)
            }
        }
        .confirmationDialog(
            String(localized: "story.event.delete.title",
                   comment: "Event Picker: Delete confirmation title"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("common.delete", role: .destructive) {
                onDelete()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "story.event.delete.message",
                                       comment: "Event Picker: Delete confirmation message. %@ is the event title."),
                        event.title))
        }
    }
}


// MARK: - Preview

struct EnhancedEventPickerView_Previews: PreviewProvider {
    @State static var selectedBuiltIn: StoryEvent? = nil
    @State static var selectedCustom: CustomStoryEvent? = nil

    static var previews: some View {
        EnhancedEventPickerView(
            selectedBuiltInEvent: $selectedBuiltIn,
            selectedCustomEvent: $selectedCustom
        )
    }
}
