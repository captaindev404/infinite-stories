//
//  IllustrationThumbnailStrip.swift
//  InfiniteStories
//
//  Created by Captain Dev on 16/09/2025.
//

import SwiftUI

struct IllustrationThumbnailStrip: View {
    let illustrations: [StoryIllustration]
    @Binding var selectedIndex: Int
    let onThumbnailTap: (Int) -> Void

    @State private var scrollViewProxy: ScrollViewProxy?
    @Namespace private var thumbnailNamespace

    // Visual constants
    private let thumbnailSize: CGFloat = 60
    private let selectedScale: CGFloat = 1.15
    private let spacing: CGFloat = 12

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(Array(illustrations.enumerated()), id: \.element.id) { index, illustration in
                        thumbnailView(for: illustration, at: index)
                            .id(index)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(
                // Subtle background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.05),
                                Color.gray.opacity(0.05)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .onAppear {
                scrollViewProxy = proxy
            }
            .onChange(of: selectedIndex) { newIndex in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnailView(for illustration: StoryIllustration, at index: Int) -> some View {
        let isSelected = selectedIndex == index

        Button(action: {
            onThumbnailTap(index)
        }) {
            ZStack {
                // Thumbnail container
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .overlay(
                        thumbnailContent(for: illustration, isSelected: isSelected)
                    )
                    .overlay(
                        // Selection ring
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isSelected ? Color.orange : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
                    .scaleEffect(isSelected ? selectedScale : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                // Badge for scene number
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            sceneBadge(number: index + 1)
                                .offset(x: 5, y: -5)
                        }
                        Spacer()
                    }
                }

                // Loading indicator overlay (only for pending, not failed)
                if !illustration.isGenerated && !illustration.isPlaceholder {
                    loadingOverlay
                }
            }
            .frame(width: thumbnailSize * 1.2, height: thumbnailSize * 1.2)
        }
        .buttonStyle(ThumbnailButtonStyle())
        .accessibilityLabel("Scene \(index + 1)")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to view")
    }

    @ViewBuilder
    private func thumbnailContent(for illustration: StoryIllustration, isSelected: Bool) -> some View {
        if illustration.isPlaceholder {
            // Show compact placeholder for failed illustrations
            CompactIllustrationPlaceholder(
                sceneNumber: illustration.displayOrder + 1,
                errorType: convertToGlobalErrorType(illustration.typedError)
            )
            .frame(width: thumbnailSize, height: thumbnailSize)
        } else if illustration.isGenerated, let imageURL = illustration.imageURL {
            // Actual thumbnail image
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    thumbnailPlaceholder(systemName: "photo", isAnimating: true)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            // Subtle gradient for depth
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.black.opacity(isSelected ? 0.1 : 0.2)
                                ]),
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        )
                case .failure:
                    // Show compact placeholder for loading failure
                    CompactIllustrationPlaceholder(
                        sceneNumber: illustration.displayOrder + 1,
                        errorType: .fileSystem
                    )
                    .frame(width: thumbnailSize, height: thumbnailSize)
                @unknown default:
                    thumbnailPlaceholder(systemName: "photo")
                }
            }
        } else {
            // Placeholder for pending illustrations (not yet generated)
            thumbnailPlaceholder(
                systemName: "sparkles",
                gradient: LinearGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.3),
                        Color.orange.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    @ViewBuilder
    private func thumbnailPlaceholder(
        systemName: String,
        gradient: LinearGradient? = nil,
        isAnimating: Bool = false
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(gradient ?? LinearGradient(
                    gradient: Gradient(colors: [Color.gray.opacity(0.2)]),
                    startPoint: .top,
                    endPoint: .bottom
                ))

            Image(systemName: systemName)
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.7))
                .rotationEffect(isAnimating ? .degrees(360) : .zero)
                .animation(
                    isAnimating ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                    value: isAnimating
                )
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.7)
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
    }

    @ViewBuilder
    private func sceneBadge(number: Int) -> some View {
        Text("\(number)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(Color.orange)
                    .shadow(color: .orange.opacity(0.3), radius: 2, x: 0, y: 1)
            )
    }

    // MARK: - Helper Functions

    private func convertToGlobalErrorType(_ storyError: StoryIllustration.IllustrationErrorType?) -> IllustrationErrorType {
        guard let storyError = storyError else { return .unknown }

        switch storyError {
        case .network:
            return .network
        case .invalidPrompt:
            return .invalidPrompt
        case .rateLimit:
            return .rateLimit
        case .apiError:
            return .apiError
        case .timeout:
            return .timeout
        case .fileSystem:
            return .fileSystem
        case .unknown:
            return .unknown
        }
    }
}

// MARK: - Custom Button Style

struct ThumbnailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        IllustrationThumbnailStrip(
            illustrations: [],
            selectedIndex: .constant(0),
            onThumbnailTap: { _ in }
        )
        .frame(height: 100)
        .padding()

        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}