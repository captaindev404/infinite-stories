//
//  CustomEventDetailView.swift
//  InfiniteStories
//
//  Detailed view for a custom event with full information and actions
//

import SwiftUI
import SwiftData

struct CustomEventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var stories: [Story]

    let event: CustomStoryEvent
    @StateObject private var pictogramGenerator = EventPictogramGenerator()

    @State private var showingEditSheet = false
    @State private var showingPictogramGenerator = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false

    private var relatedStories: [Story] {
        stories.filter { $0.customEvent?.id == event.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Section
                heroSection

                // Quick Actions
                quickActionsSection

                // Event Details
                eventDetailsSection

                // Statistics
                statisticsSection

                // Keywords
                if !event.keywords.isEmpty {
                    keywordsSection
                }

                // Related Stories
                if !relatedStories.isEmpty {
                    relatedStoriesSection
                }

                // Danger Zone
                dangerZone
            }
            .padding()
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingPictogramGenerator) {
            PictogramGenerationView(event: event)
        }
        .alert("Delete Event", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete this custom event? This action cannot be undone.")
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Pictogram
            ZStack {
                if event.hasPictogram {
                    CachedPictogramImage(event: event)
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                } else {
                    RoundedRectangle(cornerRadius: 24)
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
                        .frame(width: 150, height: 150)
                        .overlay(
                            Image(systemName: event.iconName)
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: event.colorHex))
                        )
                }

                // Favorite badge
                if event.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundColor(.yellow)
                        .padding(8)
                        .background(Circle().fill(.white))
                        .shadow(radius: 3)
                        .position(x: 130, y: 20)
                }
            }
            .frame(width: 150, height: 150)

            // Description
            Text(event.eventDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Category and Tone badges
            HStack(spacing: 12) {
                BadgeView(
                    text: event.category.rawValue,
                    icon: event.category.icon,
                    color: Color(hex: event.colorHex)
                )

                BadgeView(
                    text: event.tone.rawValue,
                    icon: "waveform",
                    color: .blue
                )

                BadgeView(
                    text: event.ageRange.rawValue,
                    icon: "person.2",
                    color: .green
                )
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            ActionButton(
                title: "Use in Story",
                icon: "book.fill",
                color: .purple
            ) {
                // Navigate to story generation with this event
                // This would need to be implemented with proper navigation
            }

            ActionButton(
                title: event.hasPictogram ? "Regenerate" : "Generate",
                icon: "photo.badge.plus",
                color: .blue
            ) {
                showingPictogramGenerator = true
            }

            ActionButton(
                title: event.isFavorite ? "Unfavorite" : "Favorite",
                icon: event.isFavorite ? "star.slash" : "star",
                color: .yellow
            ) {
                withAnimation {
                    event.toggleFavorite()
                }
            }
        }
    }

    // MARK: - Event Details

    private var eventDetailsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Event Details", icon: "info.circle")

            VStack(spacing: 12) {
                DetailRow(
                    label: "Created",
                    value: event.createdAt.formatted(date: .abbreviated, time: .shortened)
                )

                if let lastUsed = event.lastUsed {
                    DetailRow(
                        label: "Last Used",
                        value: lastUsed.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                DetailRow(
                    label: "AI Enhanced",
                    value: event.isAIEnhanced ? "Yes" : "No",
                    valueColor: event.isAIEnhanced ? .green : .secondary
                )

                if let pictogramGeneratedAt = event.pictogramGeneratedAt {
                    DetailRow(
                        label: "Pictogram Created",
                        value: pictogramGeneratedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                if let style = event.pictogramStyle {
                    DetailRow(
                        label: "Pictogram Style",
                        value: style.displayName
                    )
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Usage Statistics", icon: "chart.bar")

            HStack(spacing: 16) {
                EventStatCard(
                    value: "\(event.usageCount)",
                    label: "Times Used",
                    icon: "book.pages",
                    color: .blue
                )

                EventStatCard(
                    value: "\(relatedStories.count)",
                    label: "Stories Created",
                    icon: "text.book.closed",
                    color: .purple
                )

                EventStatCard(
                    value: event.timeSinceCreation,
                    label: "Age",
                    icon: "clock",
                    color: .green
                )
            }
        }
    }

    // MARK: - Keywords

    private var keywordsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Keywords", icon: "tag")

            FlowLayout(spacing: 8) {
                ForEach(event.keywords, id: \.self) { keyword in
                    KeywordChip(text: keyword)
                }
            }
        }
    }

    // MARK: - Related Stories

    private var relatedStoriesSection: some View {
        VStack(spacing: 12) {
            HStack {
                SectionHeader(title: "Related Stories", icon: "book.pages")
                Spacer()
                Text("\(relatedStories.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.gray.opacity(0.2)))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(relatedStories.prefix(5)) { story in
                        RelatedStoryCard(story: story)
                    }
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Danger Zone", icon: "exclamationmark.triangle")
                .foregroundColor(.red)

            Button {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Event")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    showingShareSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Methods

    private func deleteEvent() {
        Task {
            await pictogramGenerator.deletePictogram(for: event)
        }
        modelContext.delete(event)
        dismiss()
    }
}

// MARK: - Supporting Views

struct BadgeView: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

struct EventStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct KeywordChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
}

struct RelatedStoryCard: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(story.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            if let hero = story.hero {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text(hero.name)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Text(story.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 150)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    private struct FlowResult {
        let size: CGSize
        let positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentY += rowHeight + spacing
                    currentX = 0
                    rowHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }

            self.positions = positions
            self.size = CGSize(width: maxWidth, height: currentY + rowHeight)
        }
    }
}

#Preview {
    NavigationStack {
        CustomEventDetailView(
            event: CustomStoryEvent(
                title: "First Day at School",
                description: "A story about overcoming nervousness and making new friends",
                promptSeed: "Starting school adventure",
                category: .learning,
                ageRange: .preschool,
                tone: .inspiring
            )
        )
    }
    .modelContainer(for: [CustomStoryEvent.self, Story.self], inMemory: true)
}