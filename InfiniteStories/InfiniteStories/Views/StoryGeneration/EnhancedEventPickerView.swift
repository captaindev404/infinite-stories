//
//  EnhancedEventPickerView.swift
//  InfiniteStories
//
//  Created on 2025-09-14.
//

import SwiftUI
import SwiftData

struct EnhancedEventPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomStoryEvent.createdAt, order: .reverse) private var customEvents: [CustomStoryEvent]
    
    @Binding var selectedBuiltInEvent: StoryEvent?
    @Binding var selectedCustomEvent: CustomStoryEvent?
    
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
                        TextField("Search events...", text: $searchText)
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
                                Text("Create Custom Event")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Design your own story scenario")
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
                                title: "All",
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )
                            
                            ForEach(EventCategory.allCases, id: \.self) { category in
                                CategoryFilterChip(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Custom Events Section
                    if !filteredCustomEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Your Custom Events")
                                    .font(.headline)

                                Spacer()

                                // Manage button
                                Button(action: { showingCustomEventManagement = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "square.grid.2x2")
                                            .font(.caption)
                                        Text("Manage")
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
                                        event.incrementUsage()
                                        dismiss()
                                    },
                                    onDelete: {
                                        deleteCustomEvent(event)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Built-in Events Section
                    if !filteredBuiltInEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested Events")
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
                    if filteredBuiltInEvents.isEmpty && filteredCustomEvents.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            
                            Text("No events found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            if !searchText.isEmpty {
                                Text("Try a different search term")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 50)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Choose Adventure")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCustomEventCreation) {
                CustomEventCreationView()
            }
            .sheet(isPresented: $showingCustomEventManagement) {
                CustomEventManagementView()
            }
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
                event.rawValue.localizedCaseInsensitiveContains(searchText) ||
                event.promptSeed.localizedCaseInsensitiveContains(searchText)
            
            return matchesSearch
        }
    }
    
    private var filteredCustomEvents: [CustomStoryEvent] {
        customEvents.filter { event in
            let matchesSearch = searchText.isEmpty ||
                event.title.localizedCaseInsensitiveContains(searchText) ||
                event.eventDescription.localizedCaseInsensitiveContains(searchText) ||
                event.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            
            let matchesCategory = selectedCategory == nil || event.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }
    }
    
    // MARK: - Actions
    
    private func deleteCustomEvent(_ event: CustomStoryEvent) {
        modelContext.delete(event)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete custom event: \(error)")
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
            .background(isSelected ? Color.orange : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(15)
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
                    Text(event.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(event.promptSeed.capitalized)
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
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
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
    @State private var showingManagementView = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Display pictogram if available, otherwise show icon
                    if event.hasPictogram {
                        CachedPictogramImage(event: event)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: event.colorHex).opacity(0.15))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: event.iconName)
                                    .font(.title2)
                                    .foregroundColor(Color(hex: event.colorHex))
                            )
                    }

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

                            if event.isAIEnhanced {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }

                            if event.hasPictogram {
                                Image(systemName: "photo")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Text(event.eventDescription)
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
                        Image(systemName: event.category.icon)
                            .font(.caption2)
                        Text(event.category.rawValue)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: event.colorHex).opacity(0.2))
                    .cornerRadius(6)
                    
                    // Age range badge
                    Text(event.ageRange.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                    
                    // Tone badge
                    Text(event.tone.rawValue)
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
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: {
                event.toggleFavorite()
            }) {
                Label(
                    event.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: event.isFavorite ? "star.slash" : "star"
                )
            }

            Button(action: {
                showingManagementView = true
            }) {
                Label(
                    event.hasPictogram ? "Regenerate Pictogram" : "Generate Pictogram",
                    systemImage: "photo.badge.plus"
                )
            }

            Button(action: {
                showingManagementView = true
            }) {
                Label("View Details", systemImage: "info.circle")
            }

            Divider()

            Button(role: .destructive, action: {
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingManagementView) {
            NavigationStack {
                CustomEventDetailView(event: event)
            }
        }
        .confirmationDialog(
            "Delete Custom Event",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(event.title)'? This action cannot be undone.")
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
        .modelContainer(for: CustomStoryEvent.self, inMemory: true)
    }
}
