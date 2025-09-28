//
//  IllustrationPlaceholderView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 17/09/2025.
//

import SwiftUI

/// Types of illustration failures
enum IllustrationErrorType: String {
    case network = "Network Error"
    case invalidPrompt = "Invalid Content"
    case rateLimit = "Rate Limited"
    case apiError = "Service Error"
    case timeout = "Timeout"
    case fileSystem = "Storage Error"
    case unknown = "Unknown Error"

    var icon: String {
        switch self {
        case .network:
            return "wifi.slash"
        case .invalidPrompt:
            return "exclamationmark.bubble"
        case .rateLimit:
            return "hourglass.tophalf.filled"
        case .apiError:
            return "exclamationmark.triangle"
        case .timeout:
            return "clock.badge.exclamationmark"
        case .fileSystem:
            return "folder.badge.questionmark"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .network:
            return .blue
        case .invalidPrompt:
            return .orange
        case .rateLimit:
            return .yellow
        case .apiError:
            return .red
        case .timeout:
            return .purple
        case .fileSystem:
            return .gray
        case .unknown:
            return .secondary
        }
    }

    var userFriendlyMessage: String {
        switch self {
        case .network:
            return "Connection issue. Check your internet and try again."
        case .invalidPrompt:
            return "Content couldn't be illustrated. We'll improve this."
        case .rateLimit:
            return "Too many requests. Please wait a moment."
        case .apiError:
            return "Service temporarily unavailable. Try again later."
        case .timeout:
            return "Taking too long. Please try again."
        case .fileSystem:
            return "Couldn't save illustration. Check storage space."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    var shortMessage: String {
        switch self {
        case .network:
            return "No Connection"
        case .invalidPrompt:
            return "Content Issue"
        case .rateLimit:
            return "Please Wait"
        case .apiError:
            return "Service Issue"
        case .timeout:
            return "Timed Out"
        case .fileSystem:
            return "Storage Issue"
        case .unknown:
            return "Error"
        }
    }
}

/// Beautiful placeholder view for failed illustrations
struct IllustrationPlaceholderView: View {
    let sceneNumber: Int
    let errorType: IllustrationErrorType
    let onRetry: (() -> Void)?

    @State private var isAnimating = false
    @State private var pulseAnimation = false
    @State private var shimmerAnimation = false
    @AppStorage("showIllustrationErrors") private var showDetailedErrors = false

    init(
        sceneNumber: Int,
        errorType: IllustrationErrorType = .unknown,
        onRetry: (() -> Void)? = nil
    ) {
        self.sceneNumber = sceneNumber
        self.errorType = errorType
        self.onRetry = onRetry
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Beautiful gradient background
                backgroundGradient

                // Content
                VStack(spacing: 20) {
                    Spacer()

                    // Animated icon
                    animatedIcon

                    // Scene indicator
                    sceneIndicator

                    // Error message (if enabled)
                    if showDetailedErrors {
                        errorMessage
                    }

                    // Retry button (if available)
                    if onRetry != nil {
                        retryButton
                    }

                    Spacer()
                }
                .padding()

                // Subtle pattern overlay
                patternOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                errorType.color.opacity(0.3),
                                errorType.color.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: errorType.color.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Components

    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.95, green: 0.95, blue: 0.98),
                Color(red: 0.92, green: 0.92, blue: 0.96),
                errorType.color.opacity(0.05)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // Shimmer effect
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(shimmerAnimation ? 0.3 : 0),
                    Color.white.opacity(0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .animation(
                Animation.easeInOut(duration: 2.5)
                    .repeatForever(autoreverses: false),
                value: shimmerAnimation
            )
        )
    }

    @ViewBuilder
    private var animatedIcon: some View {
        ZStack {
            // Pulsing background circle
            Circle()
                .fill(errorType.color.opacity(0.1))
                .frame(width: 100, height: 100)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                .opacity(pulseAnimation ? 0.3 : 0.5)
                .animation(
                    Animation.easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )

            // Secondary circle
            Circle()
                .fill(errorType.color.opacity(0.15))
                .frame(width: 80, height: 80)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2)
                        .delay(0.2)
                        .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )

            // Main icon
            Image(systemName: errorType.icon)
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .foregroundColor(errorType.color)
                .rotationEffect(.degrees(isAnimating ? 5 : -5))
                .animation(
                    Animation.easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // Decorative sparkles
            ForEach(0..<3) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundColor(errorType.color.opacity(0.6))
                    .offset(
                        x: cos(Double(index) * 2 * .pi / 3) * 45,
                        y: sin(Double(index) * 2 * .pi / 3) * 45
                    )
                    .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 2)
                            .delay(Double(index) * 0.3)
                            .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
            }
        }
    }

    @ViewBuilder
    private var sceneIndicator: some View {
        VStack(spacing: 8) {
            Text("Scene \(sceneNumber)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary.opacity(0.9))

            Text("Illustration Placeholder")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        VStack(spacing: 4) {
            Text(errorType.shortMessage)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(errorType.color)

            Text(errorType.userFriendlyMessage)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var retryButton: some View {
        Button(action: {
            onRetry?()
            hapticFeedback()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))

                Text("Try Again")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                errorType.color,
                                errorType.color.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: errorType.color.opacity(0.3), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var patternOverlay: some View {
        GeometryReader { geometry in
            Path { path in
                let size: CGFloat = 30
                let rows = Int(geometry.size.height / size)
                let cols = Int(geometry.size.width / size)

                for row in 0...rows {
                    for col in 0...cols {
                        let x = CGFloat(col) * size + (row % 2 == 0 ? 0 : size/2)
                        let y = CGFloat(row) * size

                        path.addEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                    }
                }
            }
            .fill(Color.gray.opacity(0.05))
        }
    }

    // MARK: - Helper Methods

    private func startAnimations() {
        withAnimation {
            isAnimating = true
            pulseAnimation = true
            shimmerAnimation = true
        }
    }

    private func hapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Compact Placeholder (for thumbnails)

struct CompactIllustrationPlaceholder: View {
    let sceneNumber: Int
    let errorType: IllustrationErrorType

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(0.1),
                            errorType.color.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 4) {
                Image(systemName: errorType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(errorType.color.opacity(0.6))
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Text("Scene \(sceneNumber)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Custom Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Placeholder Gallery") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach([
                IllustrationErrorType.network,
                .invalidPrompt,
                .rateLimit,
                .apiError,
                .timeout,
                .fileSystem,
                .unknown
            ], id: \.self) { errorType in
                IllustrationPlaceholderView(
                    sceneNumber: Int.random(in: 1...5),
                    errorType: errorType,
                    onRetry: {}
                )
                .frame(height: 300)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

#Preview("Compact Placeholders") {
    HStack(spacing: 10) {
        ForEach([
            IllustrationErrorType.network,
            .rateLimit,
            .apiError
        ], id: \.self) { errorType in
            CompactIllustrationPlaceholder(
                sceneNumber: Int.random(in: 1...5),
                errorType: errorType
            )
            .frame(width: 80, height: 80)
        }
    }
    .padding()
}