//
//  CustomEventDetailView.swift
//  InfiniteStories
//
//  Detailed view for a custom event with full information and actions (API-based)
//

import SwiftUI

struct CustomEventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let event: CustomStoryEvent
    var onEventUpdated: ((CustomStoryEvent) -> Void)?

    private let repository = CustomEventRepository()

    @State private var currentEvent: CustomStoryEvent
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var isDeleting = false
    @State private var isUpdating = false
    @State private var isEnhancing = false
    @State private var error: Error?

    init(event: CustomStoryEvent, onEventUpdated: ((CustomStoryEvent) -> Void)? = nil) {
        self.event = event
        self.onEventUpdated = onEventUpdated
        self._currentEvent = State(initialValue: event)
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
                if !currentEvent.keywords.isEmpty {
                    keywordsSection
                }

                // Prompt Seed
                promptSeedSection

                // Danger Zone
                dangerZone
            }
            .padding()
        }
        .navigationTitle(currentEvent.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .alert("customEvent.detail.deleteAlert.title", isPresented: $showingDeleteAlert) {
            Button("customEvent.detail.deleteAlert.cancel", role: .cancel) { }
            Button("customEvent.detail.deleteAlert.delete", role: .destructive) {
                Task {
                    await deleteEvent()
                }
            }
        } message: {
            Text("customEvent.detail.deleteAlert.message")
        }
        .overlay {
            if isDeleting || isEnhancing {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(isDeleting
                             ? String(localized: "customEvent.detail.deleting",
                                      comment: "Overlay label shown while a custom event is being deleted.")
                             : String(localized: "customEvent.detail.enhancing",
                                      comment: "Overlay label shown while a custom event is being AI-enhanced."))
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color(.systemGray6).opacity(0.95))
                    .cornerRadius(16)
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: currentEvent.colorHex).opacity(0.3),
                                Color(hex: currentEvent.colorHex).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                    .overlay(
                        Image(systemName: currentEvent.iconName)
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: currentEvent.colorHex))
                    )

                // Favorite badge
                if currentEvent.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundColor(.yellow)
                        .padding(8)
                        .background(Circle().fill(.white))
                        .shadow(radius: 3)
                        .position(x: 130, y: 20)
                }

                // AI Enhanced badge
                if currentEvent.aiEnhanced {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundColor(.purple)
                        .padding(8)
                        .background(Circle().fill(.white))
                        .shadow(radius: 3)
                        .position(x: 20, y: 20)
                }
            }
            .frame(width: 150, height: 150)

            // Description
            Text(currentEvent.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Category and Tone badges
            HStack(spacing: 12) {
                BadgeView(
                    text: currentEvent.eventCategory.displayName,
                    icon: currentEvent.eventCategory.icon,
                    color: Color(hex: currentEvent.colorHex)
                )

                BadgeView(
                    text: currentEvent.storyTone.localizedName,
                    icon: "waveform",
                    color: .blue
                )

                if let ageRange = currentEvent.eventAgeRange {
                    // BUG-L10N-08: was rendering the English rawValue
                    // ("All Ages"). Route through localizedName so FR users
                    // see "Tous âges", DE "Alle Altersgruppen", etc.
                    BadgeView(
                        text: ageRange.localizedName,
                        icon: "person.2",
                        color: .green
                    )
                }
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
            if !currentEvent.aiEnhanced {
                ActionButton(
                    title: String(localized: "customEvent.detail.actions.enhance",
                                  comment: "Custom Event detail: AI Enhance action button title."),
                    icon: "sparkles",
                    color: .purple
                ) {
                    Task {
                        await enhanceEvent()
                    }
                }
            }

            ActionButton(
                title: currentEvent.isFavorite
                       ? String(localized: "customEvent.detail.actions.unfavorite",
                                comment: "Custom Event detail: Remove favorite action button title.")
                       : String(localized: "customEvent.detail.actions.favorite",
                                comment: "Custom Event detail: Add favorite action button title."),
                icon: currentEvent.isFavorite ? "star.slash" : "star",
                color: .yellow
            ) {
                Task {
                    await toggleFavorite()
                }
            }
        }
    }

    // MARK: - Event Details

    private var eventDetailsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: String(localized: "customEvent.detail.section.eventDetails",
                                        comment: "Custom Event detail: Event Details section header."),
                          icon: "info.circle")

            VStack(spacing: 12) {
                DetailRow(
                    label: String(localized: "customEvent.detail.field.created",
                                  comment: "Custom Event detail: Created timestamp field label."),
                    value: currentEvent.createdAt.formatted(date: .abbreviated, time: .shortened)
                )

                if let lastUsed = currentEvent.lastUsedAt {
                    DetailRow(
                        label: String(localized: "customEvent.detail.field.lastUsed",
                                      comment: "Custom Event detail: Last used timestamp field label."),
                        value: lastUsed.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                DetailRow(
                    label: String(localized: "customEvent.detail.field.aiEnhanced",
                                  comment: "Custom Event detail: AI enhanced status field label."),
                    value: currentEvent.aiEnhanced
                           ? String(localized: "customEvent.detail.field.yes",
                                    comment: "Custom Event detail: Yes value for AI enhanced flag.")
                           : String(localized: "customEvent.detail.field.no",
                                    comment: "Custom Event detail: No value for AI enhanced flag."),
                    valueColor: currentEvent.aiEnhanced ? .green : .secondary
                )

                DetailRow(
                    label: String(localized: "customEvent.detail.field.lastUpdated",
                                  comment: "Custom Event detail: Last updated timestamp field label."),
                    value: currentEvent.updatedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: String(localized: "customEvent.detail.section.statistics",
                                        comment: "Custom Event detail: Statistics section header."),
                          icon: "chart.bar")

            HStack(spacing: 16) {
                EventStatCard(
                    value: "\(currentEvent.usageCount)",
                    label: String(localized: "customEvent.detail.stats.timesUsed",
                                  comment: "Custom Event detail: Times used stat label."),
                    icon: "book.pages",
                    color: .blue
                )

                EventStatCard(
                    value: currentEvent.timeSinceCreation,
                    label: String(localized: "customEvent.detail.stats.age",
                                  comment: "Custom Event detail: Age/time-since-creation stat label."),
                    icon: "clock",
                    color: .green
                )
            }
        }
    }

    // MARK: - Keywords

    private var keywordsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: String(localized: "customEvent.detail.section.keywords",
                                        comment: "Custom Event detail: Keywords section header."),
                          icon: "tag")

            FlowLayout(spacing: 8) {
                ForEach(currentEvent.keywords, id: \.self) { keyword in
                    KeywordChip(text: keyword)
                }
            }
        }
    }

    // MARK: - Prompt Seed

    private var promptSeedSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: String(localized: "customEvent.detail.section.prompt",
                                        comment: "Custom Event detail: Prompt seed section header."),
                          icon: "text.bubble")

            Text(currentEvent.promptSeed)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: 12) {
            SectionHeader(title: String(localized: "customEvent.detail.section.dangerZone",
                                        comment: "Custom Event detail: Danger Zone section header."),
                          icon: "exclamationmark.triangle")
                .foregroundColor(.red)

            Button {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("customEvent.detail.actions.deleteEvent")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isDeleting)
        }
        .padding(.top, 24)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showingShareSheet = true
                } label: {
                    Label("customEvent.detail.toolbar.share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Methods

    private func deleteEvent() async {
        isDeleting = true

        do {
            try await repository.deleteCustomEvent(currentEvent)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error
                isDeleting = false
            }
        }
    }

    private func toggleFavorite() async {
        var updatedEvent = currentEvent
        updatedEvent.isFavorite.toggle()

        isUpdating = true

        do {
            let result = try await repository.updateCustomEvent(updatedEvent)
            await MainActor.run {
                currentEvent = result
                onEventUpdated?(result)
                isUpdating = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                isUpdating = false
            }
        }
    }

    private func enhanceEvent() async {
        guard !currentEvent.aiEnhanced else { return }

        isEnhancing = true

        do {
            let enhancedEvent = try await repository.enhanceEvent(currentEvent)
            await MainActor.run {
                currentEvent = enhancedEvent
                onEventUpdated?(enhancedEvent)
                isEnhancing = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                isEnhancing = false
            }
        }
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
            event: CustomStoryEvent.previewData[0]
        )
    }
}
