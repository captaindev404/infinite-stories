//
//  HeroSelectionForStoryView.swift
//  InfiniteStories
//
//  Allows user to select a hero before generating a story
//

import SwiftUI
import SwiftData

struct HeroSelectionForStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Hero.createdAt, order: .reverse) private var heroes: [Hero]
    @Query private var stories: [Story]
    
    @Binding var selectedHero: Hero?
    @Binding var showingStoryGeneration: Bool
    
    @State private var showingActualStoryGeneration = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)
                        
                        Text("Choose Your Hero")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Select which hero will star in this story")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Heroes Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 15) {
                        ForEach(heroes) { hero in
                            HeroSelectionCard(
                                hero: hero,
                                storyCount: storiesCount(for: hero),
                                isSelected: selectedHero == hero,
                                onSelect: {
                                    selectedHero = hero
                                    showingActualStoryGeneration = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Select Hero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingActualStoryGeneration) {
                if let hero = selectedHero {
                    StoryGenerationView(hero: hero)
                        .onDisappear {
                            showingStoryGeneration = false
                        }
                }
            }
        }
    }
    
    private func storiesCount(for hero: Hero) -> Int {
        stories.filter { $0.hero == hero }.count
    }
}

struct HeroSelectionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let hero: Hero
    let storyCount: Int
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Hero Avatar
                HeroAvatarImageView.large(hero)
                
                VStack(spacing: 6) {
                    Text(hero.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(hero.primaryTrait.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                        
                        Text(hero.secondaryTrait.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pink.opacity(0.2))
                            .foregroundColor(.pink)
                            .cornerRadius(4)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.caption2)
                        Text("\(storyCount) \(storyCount == 1 ? "story" : "stories")")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 0.5 : 1.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    HeroSelectionForStoryView(
        selectedHero: .constant(nil),
        showingStoryGeneration: .constant(true)
    )
    .modelContainer(for: Hero.self, inMemory: true)
}