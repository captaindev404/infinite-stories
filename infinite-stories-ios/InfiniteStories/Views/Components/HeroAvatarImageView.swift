//
//  HeroAvatarImageView.swift
//  InfiniteStories
//
//  Component for displaying hero avatars with fallback to icon
//

import SwiftUI
import UIKit

/// Shared in-memory cache for hero avatar images keyed by URL.
///
/// SwiftUI's built-in `AsyncImage` does NOT use `URLSession.shared` or
/// `URLCache.shared`, so every time the view is re-instantiated (e.g. pushing
/// `StoryGenerationView` while the Home grid already loaded the same avatar)
/// it transitions through `.empty` and refetches, producing a ~1s spinner.
///
/// `HeroAvatarCache` gives us a warm in-process hit: the first successful load
/// is kept in memory, and every subsequent `HeroAvatarImageView` for the same
/// URL renders synchronously with no spinner. The underlying `URLSession.shared`
/// request still benefits from `URLCache.shared` (configured in
/// `InfiniteStoriesApp`) when the cache entry is evicted.
final class HeroAvatarCache {
    static let shared = HeroAvatarCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 64
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct HeroAvatarImageView: View {
    let hero: Hero
    let size: CGFloat
    let showEditButton: Bool
    let onEdit: (() -> Void)?

    @State private var showingAvatarGeneration = false
    @State private var imageLoadError = false
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var currentURL: URL?

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
        Group {
            if let image = loadedImage ?? HeroAvatarCache.shared.image(for: url) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                    )
            } else if imageLoadError {
                fallbackAvatarView
            } else {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: size, height: size)

                    ProgressView()
                        .scaleEffect(size > 60 ? 1.2 : 0.8)
                }
            }
        }
        .task(id: url) {
            await loadImage(from: url)
        }
    }

    /// Loads the avatar image, preferring the in-memory cache for an instant
    /// hit. Falls back to a `URLSession.shared` request which itself is backed
    /// by `URLCache.shared` for warm-disk hits.
    @MainActor
    private func loadImage(from url: URL) async {
        // Hot path: memory cache hit — render synchronously, no spinner.
        if let cached = HeroAvatarCache.shared.image(for: url) {
            if currentURL != url || loadedImage == nil {
                loadedImage = cached
                imageLoadError = false
                currentURL = url
            }
            return
        }

        // Avoid re-triggering an in-flight load for the same URL.
        guard currentURL != url || (loadedImage == nil && !isLoading) else { return }
        currentURL = url
        isLoading = true
        defer { isLoading = false }

        // Local file URLs (legacy avatar storage) — load directly.
        if url.isFileURL {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                HeroAvatarCache.shared.set(image, for: url)
                loadedImage = image
                imageLoadError = false
            } else {
                imageLoadError = true
            }
            return
        }

        // Remote URL: use URLSession.shared so URLCache.shared (configured in
        // InfiniteStoriesApp) serves warm responses from disk cache.
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard currentURL == url else { return } // Stale response; ignore.
            if let image = UIImage(data: data) {
                HeroAvatarCache.shared.set(image, for: url)
                loadedImage = image
                imageLoadError = false
            } else {
                imageLoadError = true
            }
        } catch {
            guard currentURL == url else { return }
            imageLoadError = true
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
                .overlay(
                    // Dashed border hint for missing avatars
                    Circle()
                        .stroke(
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap: .round,
                                dash: [5, 5]
                            )
                        )
                        .foregroundColor(Color.purple.opacity(0.4))
                )

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