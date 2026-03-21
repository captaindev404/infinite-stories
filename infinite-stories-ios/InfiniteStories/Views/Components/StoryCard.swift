//
//  StoryCard.swift
//  InfiniteStories
//
//  Unified story card component used across the app
//

import SwiftUI

// MARK: - Design System Tokens
struct StoryCardDesign {
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
        static let cardTitleCompact = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let cardBody = Font.system(size: 14, weight: .regular, design: .default)
        static let cardBodyCompact = Font.system(size: 13, weight: .regular, design: .default)
        static let metadata = Font.system(size: 12, weight: .medium, design: .rounded)
        static let metadataCompact = Font.system(size: 11, weight: .medium, design: .rounded)
        static let badge = Font.system(size: 11, weight: .bold, design: .rounded)
        static let badgeCompact = Font.system(size: 9, weight: .bold, design: .rounded)
    }

    // Spacing
    struct Spacing {
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
        static let elementSpacing: CGFloat = 8
        static let iconSpacing: CGFloat = 6
    }

    // Layout
    struct Layout {
        static let cardCornerRadius: CGFloat = 16
        static let cardCornerRadiusCompact: CGFloat = 14
        static let badgeCornerRadius: CGFloat = 8
        static let cardShadowRadius: CGFloat = 8
        static let cardShadowY: CGFloat = 4
        static let progressBarHeight: CGFloat = 4
    }
}

// MARK: - Story Card
/// Unified story card component used across home and library views
struct StoryCard: View {
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
    var variant: StoryCardVariant = .full

    init(
        story: Story,
        onTap: @escaping () -> Void,
        onToggleFavorite: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onRegenerateAudio: (() -> Void)? = nil,
        onRetryFailedIllustrations: (() -> Void)? = nil,
        isRegenerating: Bool = false,
        hasFailedIllustrations: Bool = false,
        failedIllustrationCount: Int = 0,
        variant: StoryCardVariant = .full
    ) {
        self.story = story
        self.onTap = onTap
        self.onToggleFavorite = onToggleFavorite
        self.onShare = onShare
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.onRegenerateAudio = onRegenerateAudio
        self.onRetryFailedIllustrations = onRetryFailedIllustrations
        self.isRegenerating = isRegenerating
        self.hasFailedIllustrations = hasFailedIllustrations
        self.failedIllustrationCount = failedIllustrationCount
        self.variant = variant
    }

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
            case .bedtime: return StoryCardDesign.Colors.bedtimeColor
            case .schoolDay: return StoryCardDesign.Colors.schoolColor
            case .birthday: return StoryCardDesign.Colors.birthdayColor
            case .weekend: return StoryCardDesign.Colors.weekendColor
            case .rainyDay: return StoryCardDesign.Colors.rainyDayColor
            case .family: return StoryCardDesign.Colors.familyColor
            default: return StoryCardDesign.Colors.primaryPurple
            }
        } else if let customEvent = story.customEvent {
            return Color(hex: customEvent.colorHex)
        } else {
            return StoryCardDesign.Colors.primaryPurple
        }
    }

    private var cornerRadius: CGFloat {
        variant == .compact ? StoryCardDesign.Layout.cardCornerRadiusCompact : StoryCardDesign.Layout.cardCornerRadius
    }

    private var titleFont: Font {
        variant == .compact ? StoryCardDesign.Typography.cardTitleCompact : StoryCardDesign.Typography.cardTitle
    }

    private var bodyFont: Font {
        variant == .compact ? StoryCardDesign.Typography.cardBodyCompact : StoryCardDesign.Typography.cardBody
    }

    private var metadataFont: Font {
        variant == .compact ? StoryCardDesign.Typography.metadataCompact : StoryCardDesign.Typography.metadata
    }

    private var badgeFont: Font {
        variant == .compact ? StoryCardDesign.Typography.badgeCompact : StoryCardDesign.Typography.badge
    }

    private var thumbnailSize: CGFloat {
        variant == .compact ? 50 : 60
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
            RoundedRectangle(cornerRadius: cornerRadius)
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
            if let onToggleFavorite = onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Label(
                        story.isFavorite ? String(localized: "story.action.removeFromFavorites") : String(localized: "story.action.addToFavorites"),
                        systemImage: story.isFavorite ? "heart.slash" : "heart"
                    )
                }
            }

            if let onShare = onShare {
                Button(action: onShare) {
                    Label(String(localized: "story.action.share"), systemImage: "square.and.arrow.up")
                }
            }

            if story.hasAudio {
                Button(action: { /* Download functionality can be added later */ }) {
                    Label(String(localized: "story.action.downloadAudio"), systemImage: "arrow.down.circle")
                }
            }

            // Add retry failed illustrations option
            if hasFailedIllustrations, let onRetryFailedIllustrations = onRetryFailedIllustrations {
                Button(action: onRetryFailedIllustrations) {
                    Label(
                        String(localized: "story.action.retryIllustrations \(failedIllustrationCount)"),
                        systemImage: "arrow.clockwise.circle"
                    )
                }
            }

            if story.audioNeedsRegeneration, let onRegenerateAudio = onRegenerateAudio {
                Button(action: onRegenerateAudio) {
                    Label(String(localized: "story.action.regenerateAudio"), systemImage: "arrow.clockwise")
                }
            }

            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label(String(localized: "story.action.edit"), systemImage: "pencil")
                }
            }

            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label(String(localized: "story.action.delete"), systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityLabelProvider.storyCardLabel(for: story))
        .accessibilityHint(AccessibilityLabelProvider.storyCardHint(for: story))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(story.isFavorite ? String(localized: "common.favorite") : "")
        .accessibilityActions {
            if let onToggleFavorite = onToggleFavorite {
                Button(story.isFavorite ? String(localized: "story.action.removeFromFavorites") : String(localized: "story.action.addToFavorites")) {
                    onToggleFavorite()
                }
            }

            if let onShare = onShare {
                Button(String(localized: "story.action.share")) {
                    onShare()
                }
            }

            if story.hasAudio {
                Button(String(localized: "story.action.downloadAudio")) {
                    // Download action
                }
            }

            if let onDelete = onDelete {
                Button(String(localized: "story.action.delete")) {
                    onDelete()
                }
            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            HStack(alignment: .top, spacing: StoryCardDesign.Spacing.cardSpacing) {
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
            .padding(StoryCardDesign.Spacing.cardPadding)

            // Progress bar or regeneration indicator
            if isRegenerating {
                regenerationProgressBar
            } else if storyStatus == .inProgress && variant == .full {
                progressBar
            }
        }
        .frame(minHeight: variant == .compact ? 90 : 120)
        .background(cardBackground)
        .overlay(cardOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(isPressed ? 0.15 : 0.1),
            radius: isPressed ? 4 : StoryCardDesign.Layout.cardShadowRadius,
            y: isPressed ? 2 : StoryCardDesign.Layout.cardShadowY
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            if let hero = story.hero {
                // Show hero avatar
                HeroAvatarImageView(hero: hero, size: thumbnailSize)
            } else {
                // Fallback to event icon
                ZStack {
                    RoundedRectangle(cornerRadius: variant == .compact ? 10 : 12)
                        .fill(
                            LinearGradient(
                                colors: [eventColor.opacity(0.3), eventColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: thumbnailSize, height: thumbnailSize)

                    Image(systemName: story.eventIcon)
                        .font(.system(size: variant == .compact ? 20 : 24))
                        .foregroundColor(eventColor)
                }
            }

            // Show first illustration as preview thumbnail if available
            if let firstIllustration = story.illustrations.first {
                AsyncImage(url: firstIllustration.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: variant == .compact ? 10 : 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: variant == .compact ? 10 : 12)
                                .stroke(eventColor.opacity(0.3), lineWidth: variant == .compact ? 1 : 2)
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
            VStack(alignment: .leading, spacing: variant == .compact ? 2 : 4) {
                Text(story.title)
                    .font(titleFont)
                    .foregroundColor(StoryCardDesign.Colors.titleText)
                    .lineLimit(variant == .compact ? 1 : 2)

                if let hero = story.hero {
                    Text("story.hero.label \(hero.name)")
                        .font(.caption)
                        .foregroundColor(variant == .compact ? .accentColor : StoryCardDesign.Colors.primaryPurple)
                        .fontWeight(.medium)
                }
            }

            Spacer()

            // Right side badges
            VStack(alignment: .trailing, spacing: 4) {
                if storyStatus == .new {
                    Text("story.badge.new")
                        .font(badgeFont)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(StoryCardDesign.Colors.newBadge)
                        )
                }

                if story.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        Text(story.shortContent)
            .font(bodyFont)
            .foregroundColor(StoryCardDesign.Colors.bodyText)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: 8) {
            // Event badge
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: variant == .compact ? 10 : 11))
                Text(story.eventTitle)
                    .font(metadataFont)
                    .lineLimit(1)
            }
            .foregroundColor(eventColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(eventColor.opacity(0.15))
            )
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)

            Spacer(minLength: 4)

            // Illustration indicator
            if !story.illustrations.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: variant == .compact ? 10 : 11))
                    Text("\(story.illustrations.count)")
                        .font(metadataFont)
                }
                .foregroundColor(.purple)
            }

            // Regenerate audio button (full variant only)
            if variant == .full && !isRegenerating && story.audioFileName != nil, let onRegenerateAudio = onRegenerateAudio {
                Button(action: onRegenerateAudio) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(String(localized: "story.action.regenerateAudio"))
                .accessibilityHint(String(localized: "story.accessibility.regenerateAudioHint"))
            }

            if story.hasAudio && !isRegenerating {
                HStack(spacing: 2) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: variant == .compact ? 10 : 11))
                    Text("\(Int(story.estimatedDuration / 60))m")
                        .font(metadataFont)
                }
                .foregroundColor(.orange)
            }

            if story.playCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: variant == .compact ? 10 : 11))
                    Text("\(story.playCount)")
                        .font(metadataFont)
                }
                .foregroundColor(.blue)
            }

            Text(formatSmartDate(story.createdAt))
                .font(.system(size: variant == .compact ? 10 : 11))
                .foregroundColor(StoryCardDesign.Colors.captionText)
        }
    }

    @ViewBuilder
    private var regenerationProgressBar: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.7)
            Text("story.regenerating.audio")
                .font(.caption)
                .foregroundColor(.purple)
            Spacer()
        }
        .padding(.horizontal, StoryCardDesign.Spacing.cardPadding)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.1))
    }

    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: StoryCardDesign.Layout.progressBarHeight)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                StoryCardDesign.Colors.inProgressBadge,
                                StoryCardDesign.Colors.inProgressBadge.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * progressPercentage,
                        height: StoryCardDesign.Layout.progressBarHeight
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progressPercentage)
            }
        }
        .frame(height: StoryCardDesign.Layout.progressBarHeight)
        .cornerRadius(StoryCardDesign.Layout.progressBarHeight / 2, corners: [.bottomLeft, .bottomRight])
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                storyStatus == .new ?
                LinearGradient(
                    colors: [
                        StoryCardDesign.Colors.newStoryGradientStart,
                        StoryCardDesign.Colors.newStoryGradientEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    private var cardOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                storyStatus == .new ?
                StoryCardDesign.Colors.newBadge.opacity(0.3) :
                Color.clear,
                lineWidth: 1
            )
    }

    private func formatSmartDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            if variant == .compact {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return String(localized: "date.today") + ", \(formatter.string(from: date))"
            } else {
                return String(localized: "date.today")
            }
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "date.yesterday")
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days < 7 {
                return String(localized: "date.daysAgo \(days)")
            } else if days < 30 && variant == .full {
                return String(localized: "date.weeksAgo \(days / 7)")
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
    }
}

// MARK: - Story Card Variant
enum StoryCardVariant {
    case compact  // Used in home view
    case full     // Used in library view
}

// MARK: - Story Status
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
        case .new: return StoryCardDesign.Colors.newBadge
        case .inProgress: return StoryCardDesign.Colors.inProgressBadge
        case .completed: return StoryCardDesign.Colors.completedBadge
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

// MARK: - Previews

#Preview("Full Variant") {
    let story = Story(
        title: "Luna's Magical Adventure",
        content: "Once upon a time in a magical forest, Luna the brave hero discovered a secret that would change everything...",
        event: .bedtime,
        hero: Hero(name: "Luna", primaryTrait: .brave, secondaryTrait: .magical)
    )
    StoryCard(story: story, onTap: {})
        .padding()
}

#Preview("Compact Variant") {
    let story = Story(
        title: "Luna's Magical Adventure",
        content: "Once upon a time in a magical forest...",
        event: .bedtime,
        hero: Hero(name: "Luna", primaryTrait: .brave, secondaryTrait: .magical)
    )
    StoryCard(story: story, onTap: {}, variant: .compact)
        .padding()
}
