//
//  HeroListView.swift
//  InfiniteStories
//
//  Hero management view for creating, editing, and deleting heroes - API-only
//

import SwiftUI

struct HeroListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // API-only state management
    @State private var heroes: [Hero] = []
    @State private var isLoading = false
    @State private var error: Error?

    // UI state
    @State private var showingHeroCreation = false
    @State private var heroToEdit: Hero?
    @State private var heroToDelete: Hero?
    @State private var showingDeleteConfirmation = false

    // Repository
    private let heroRepository = HeroRepository()

    var body: some View {
        Group {
            if isLoading {
                ProgressView(String(localized: "hero.list.loading"))
                    .scaleEffect(1.2)
            } else if let error = error {
                ErrorView(error: error, retryAction: {
                    Task { await loadHeroes() }
                })
            } else if heroes.isEmpty {
                EmptyHeroStateView()
            } else {
                heroList
            }
        }
        .navigationTitle(String(localized: "hero.list.title"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingHeroCreation) {
            HeroCreationView(heroToEdit: nil, onSave: { _ in
                Task { await loadHeroes() }
            })
        }
        .sheet(item: $heroToEdit) { hero in
            HeroCreationView(heroToEdit: hero, onSave: { _ in
                Task { await loadHeroes() }
            })
        }
        .confirmationDialog(
            String(localized: "hero.list.delete.title"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: heroToDelete
        ) { hero in
            Button(String(localized: "hero.list.delete.button"), role: .destructive) {
                Task {
                    await deleteHero(hero)
                }
            }
            Button(String(localized: "hero.creation.button.cancel"), role: .cancel) { }
        } message: { hero in
            Text(String(localized: "hero.list.delete.message", defaultValue: "This will permanently delete \(hero.name)."))
        }
        .task {
            await loadHeroes()
        }
    }

    private var heroList: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Add Hero Button
                Button(action: { showingHeroCreation = true }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title2)
                        Text(String(localized: "hero.list.button.create"))
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                }
                .accessibilityLabel(String(localized: "hero.list.button.create"))
                .accessibilityHint(String(localized: "hero.list.accessibility.create.hint"))
                .padding(.horizontal)

                // Hero List
                LazyVStack(spacing: 15) {
                    ForEach(heroes, id: \.id) { hero in
                        HeroManagementCard(
                            hero: hero,
                            storyCount: hero.storyCount,
                            onEdit: {
                                heroToEdit = hero
                            },
                            onDelete: {
                                heroToDelete = hero
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .refreshable {
            await loadHeroes()
        }
    }

    // MARK: - API Operations

    private func loadHeroes() async {
        guard NetworkMonitor.shared.isConnected else {
            error = APIError.networkUnavailable
            return
        }

        isLoading = true
        error = nil

        do {
            heroes = try await heroRepository.fetchHeroes()
            Logger.ui.success("Loaded \(heroes.count) heroes")
        } catch {
            self.error = error
            Logger.ui.error("Failed to load heroes: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func deleteHero(_ hero: Hero) async {
        guard NetworkMonitor.shared.isConnected else {
            error = APIError.networkUnavailable
            return
        }

        guard let backendId = hero.backendId else {
            Logger.ui.error("Hero has no backend ID")
            return
        }

        do {
            try await heroRepository.deleteHero(id: backendId)

            // Remove from local state
            heroes.removeAll { $0.id == hero.id }

            Logger.ui.success("Deleted hero: \(hero.name)")
        } catch {
            self.error = error
            Logger.ui.error("Failed to delete hero: \(error.localizedDescription)")
        }
    }
}

struct HeroManagementCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let hero: Hero
    let storyCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isPressed = false
    @State private var showingAvatarGeneration = false

    var body: some View {
        VStack(spacing: 0) {
            // Hero Info Section
            HStack(spacing: 15) {
                // Hero Avatar with hint for missing avatars
                ZStack(alignment: .bottomTrailing) {
                    HeroAvatarImageView.medium(hero)

                    // Show "Add Avatar" indicator if no avatar
                    if !hero.hasAvatar {
                        Button(action: {
                            showingAvatarGeneration = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                                .background(
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 20, height: 20)
                                )
                        }
                        .accessibilityLabel("Add avatar for \(hero.name)")
                        .accessibilityHint("Generate an AI avatar for this hero")
                        .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(hero.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    HStack(spacing: 8) {
                        Text(hero.primaryTrait.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(5)

                        Text(hero.secondaryTrait.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.pink.opacity(0.2))
                            .foregroundColor(.pink)
                            .cornerRadius(5)
                    }

                    if !hero.specialAbility.isEmpty {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(hero.specialAbility)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }

                    // Add avatar hint text
                    if !hero.hasAvatar {
                        Button(action: {
                            showingAvatarGeneration = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.caption2)
                                Text("Add Avatar")
                                    .font(.caption)
                            }
                            .foregroundColor(.purple)
                            .frame(minHeight: 44)
                        }
                        .accessibilityLabel("Add avatar")
                        .accessibilityHint("Generate an AI avatar for \(hero.name)")
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Story Count Badge
                if storyCount > 0 {
                    VStack {
                        Text("\(storyCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text(storyCount == 1 ? String(localized: "hero.list.stat.story.singular") : String(localized: "hero.list.stat.story.plural"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(colorScheme == .dark ? 0.5 : 1.0))

            // Action Buttons
            HStack(spacing: 0) {
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text(String(localized: "hero.list.button.edit"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.vertical, 12)
                }
                .accessibilityLabel(String(localized: "hero.list.accessibility.edit", defaultValue: "Edit \(hero.name)"))
                .accessibilityHint(String(localized: "hero.list.accessibility.edit.hint"))

                Divider()
                    .frame(height: 20)

                // Show avatar button or delete button
                if !hero.hasAvatar {
                    Button(action: {
                        showingAvatarGeneration = true
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text(String(localized: "hero.list.button.avatar"))
                        }
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.vertical, 12)
                    }
                    .accessibilityLabel(String(localized: "hero.list.accessibility.avatar", defaultValue: "Generate avatar for \(hero.name)"))
                    .accessibilityHint(String(localized: "hero.list.accessibility.avatar.hint"))

                    Divider()
                        .frame(height: 20)
                }

                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text(String(localized: "hero.list.button.delete"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.vertical, 12)
                }
                .accessibilityLabel(String(localized: "hero.list.accessibility.delete", defaultValue: "Delete \(hero.name)"))
                .accessibilityHint(String(localized: "hero.list.accessibility.delete.hint"))
            }
            .background(Color(.systemGray6).opacity(colorScheme == .dark ? 0.3 : 0.5))
        }
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .sheet(isPresented: $showingAvatarGeneration) {
            AvatarGenerationView(hero: hero, isPresented: $showingAvatarGeneration)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }
    }
}

struct EmptyHeroStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 80))
                .foregroundColor(.purple.opacity(0.5))

            Text(String(localized: "hero.list.empty.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(localized: "hero.list.empty.message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 50)
    }
}

#Preview {
    HeroListView()
}
