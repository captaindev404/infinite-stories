//
//  HeroAvatarImageView.swift
//  InfiniteStories
//
//  Component for displaying hero avatars with fallback to icon
//

import SwiftUI

struct HeroAvatarImageView: View {
    let hero: Hero
    let size: CGFloat
    let showEditButton: Bool
    let onEdit: (() -> Void)?

    @State private var showingAvatarGeneration = false
    @State private var imageLoadError = false

    init(hero: Hero, size: CGFloat, showEditButton: Bool = false, onEdit: (() -> Void)? = nil) {
        self.hero = hero
        self.size = size
        self.showEditButton = showEditButton
        self.onEdit = onEdit
    }

    var body: some View {
        ZStack {
            // Main avatar content
            if hero.hasAvatar, let avatarURL = hero.avatarURL {
                avatarImageView(url: avatarURL)
            } else {
                fallbackAvatarView
            }

            // Edit button overlay
            if showEditButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        editButton
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .sheet(isPresented: $showingAvatarGeneration) {
            AvatarGenerationView(hero: hero, isPresented: $showingAvatarGeneration)
        }
    }

    @ViewBuilder
    private func avatarImageView(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                    )

            case .failure(_):
                // Show fallback on load error
                fallbackAvatarView
                    .onAppear {
                        imageLoadError = true
                    }

            case .empty:
                // Loading state
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: size, height: size)

                    ProgressView()
                        .scaleEffect(size > 60 ? 1.2 : 0.8)
                }

            @unknown default:
                fallbackAvatarView
            }
        }
    }

    private var fallbackAvatarView: some View {
        ZStack {
            // Background Circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.3),
                            Color.purple.opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)

            // Icon or initials
            if hero.name.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.purple)
            } else {
                // Show first letter of name
                Text(String(hero.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
            }

            // Error indicator if image failed to load
            if imageLoadError {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 16, height: 16)
                            )
                    }
                }
            }
        }
    }

    private var editButton: some View {
        Button(action: {
            if let onEdit = onEdit {
                onEdit()
            } else {
                showingAvatarGeneration = true
            }
        }) {
            Image(systemName: hero.hasAvatar ? "pencil.circle.fill" : "plus.circle.fill")
                .font(.system(size: size * 0.25))
                .foregroundColor(.white)
                .background(
                    Circle()
                        .fill(Color.purple)
                        .frame(width: size * 0.3, height: size * 0.3)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .offset(x: -size * 0.05, y: -size * 0.05)
    }
}

// MARK: - Convenience Initializers
extension HeroAvatarImageView {
    static func small(_ hero: Hero) -> HeroAvatarImageView {
        HeroAvatarImageView(hero: hero, size: 40)
    }

    static func medium(_ hero: Hero) -> HeroAvatarImageView {
        HeroAvatarImageView(hero: hero, size: 60)
    }

    static func large(_ hero: Hero) -> HeroAvatarImageView {
        HeroAvatarImageView(hero: hero, size: 80)
    }

    static func extraLarge(_ hero: Hero) -> HeroAvatarImageView {
        HeroAvatarImageView(hero: hero, size: 120)
    }

    func withEditButton(_ onEdit: @escaping () -> Void) -> HeroAvatarImageView {
        HeroAvatarImageView(hero: hero, size: size, showEditButton: true, onEdit: onEdit)
    }

    func withGenerateButton() -> HeroAvatarImageView {
        HeroAvatarImageView(hero: hero, size: size, showEditButton: true, onEdit: nil)
    }
}

// MARK: - Legacy Support
// For backwards compatibility with existing HeroAvatarView
typealias HeroAvatarView = HeroAvatarImageView

// MARK: - Preview
#Preview {
    let hero = Hero(name: "Alex", primaryTrait: .brave, secondaryTrait: .kind, appearance: "curly hair", specialAbility: "talk to animals")

    return VStack(spacing: 20) {
        HeroAvatarImageView.small(hero)
        HeroAvatarImageView.medium(hero)
        HeroAvatarImageView.large(hero).withGenerateButton()
        HeroAvatarImageView.extraLarge(hero).withEditButton { print("Edit tapped") }
    }
    .padding()
}