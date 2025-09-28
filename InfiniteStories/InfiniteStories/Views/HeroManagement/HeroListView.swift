//
//  HeroListView.swift
//  InfiniteStories
//
//  Hero management view for creating, editing, and deleting heroes
//

import SwiftUI
import SwiftData

struct HeroListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Hero.createdAt, order: .reverse) private var heroes: [Hero]
    @Query private var stories: [Story]
    
    @State private var showingHeroCreation = false
    @State private var heroToEdit: Hero?
    @State private var heroToDelete: Hero?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Add Hero Button
                    Button(action: { showingHeroCreation = true }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title2)
                            Text("Create New Hero")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
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
                    .padding(.horizontal)
                    
                    if heroes.isEmpty {
                        EmptyHeroStateView()
                            .padding(.top, 50)
                    } else {
                        // Hero List
                        LazyVStack(spacing: 15) {
                            ForEach(heroes) { hero in
                                HeroManagementCard(
                                    hero: hero,
                                    storyCount: storiesCount(for: hero),
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
                }
                .padding(.vertical)
            }
            .navigationTitle("Manage Heroes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingHeroCreation) {
                HeroCreationView(heroToEdit: nil)
            }
            .sheet(item: $heroToEdit) { hero in
                HeroCreationView(heroToEdit: hero)
            }
            .confirmationDialog(
                "Delete Hero?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible,
                presenting: heroToDelete
            ) { hero in
                Button("Delete Hero", role: .destructive) {
                    deleteHero(hero)
                }
                Button("Cancel", role: .cancel) { }
            } message: { hero in
                let count = storiesCount(for: hero)
                if count > 0 {
                    Text("This will delete \(hero.name). The \(count) \(count == 1 ? "story" : "stories") created for this hero will be kept in your library.")
                } else {
                    Text("This will permanently delete \(hero.name).")
                }
            }
        }
    }
    
    private func storiesCount(for hero: Hero) -> Int {
        stories.filter { $0.hero == hero }.count
    }
    
    private func deleteHero(_ hero: Hero) {
        modelContext.delete(hero)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete hero: \(error)")
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Hero Info Section
            HStack(spacing: 15) {
                // Hero Avatar
                HeroAvatarImageView.medium(hero)
                
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
                }
                
                Spacer()
                
                // Story Count Badge
                VStack {
                    Text("\(storyCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text(storyCount == 1 ? "Story" : "Stories")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(colorScheme == .dark ? 0.5 : 1.0))
            
            // Action Buttons
            HStack(spacing: 0) {
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                
                Divider()
                    .frame(height: 20)
                
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.systemGray6).opacity(colorScheme == .dark ? 0.3 : 0.5))
        }
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
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
            
            Text("No Heroes Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first hero to start generating magical stories!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    HeroListView()
        .modelContainer(for: Hero.self, inMemory: true)
}