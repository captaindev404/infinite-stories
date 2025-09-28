//
//  AdaptiveHeroGridView.swift
//  InfiniteStories
//
//  Adaptive hero display system with dynamic layout based on hero count
//

import SwiftUI
import SwiftData

// MARK: - Adaptive Hero Grid View
struct AdaptiveHeroGridView: View {
    let heroes: [Hero]
    @Binding var showingHeroCreation: Bool
    @Binding var selectedHeroForStory: Hero?
    @Binding var showingStoryGeneration: Bool
    @State private var selectedHeroForEdit: Hero?
    @State private var animationTrigger = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Computed layout properties
    private var gridColumns: [GridItem] {
        if heroes.count <= 2 {
            // Single column for 1-2 heroes (expanded view)
            return [GridItem(.flexible())]
        } else if heroes.count <= 4 {
            // Two columns for 3-4 heroes
            return Array(repeating: GridItem(.flexible(), spacing: 15), count: 2)
        } else {
            // Three columns for 5+ heroes on iPad, 2 on iPhone
            let columns = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
            return Array(repeating: GridItem(.flexible(), spacing: 15), count: columns)
        }
    }
    
    private var shouldShowExpandedCards: Bool {
        heroes.count <= 2
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header Section
            HeroGridHeaderView(
                heroCount: heroes.count,
                showingHeroCreation: $showingHeroCreation
            )
            
            if heroes.isEmpty {
                // Empty State
                HeroEmptyStateView(showingHeroCreation: $showingHeroCreation)
            } else {
                // Adaptive Grid Layout
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 15) {
                        ForEach(heroes) { hero in
                            if shouldShowExpandedCards {
                                ExpandedHeroCard(
                                    hero: hero,
                                    onGenerateStory: {
                                        handleStoryGeneration(for: hero)
                                    },
                                    onEdit: {
                                        handleHeroEdit(hero)
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            } else {
                                CompactHeroCard(
                                    hero: hero,
                                    onTap: {
                                        handleStoryGeneration(for: hero)
                                    },
                                    onEdit: {
                                        handleHeroEdit(hero)
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                        }
                        
                        // Add Hero Card
                        AddHeroCard(showingHeroCreation: $showingHeroCreation)
                            .transition(.scale.combined(with: .opacity))
                    }
                    .padding(.horizontal)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: heroes.count)
                }
            }
        }
        .sheet(item: $selectedHeroForEdit) { hero in
            HeroCreationView(heroToEdit: hero)
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.5)) {
                    animationTrigger = true
                }
            }
        }
    }
    
    private func handleStoryGeneration(for hero: Hero) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        selectedHeroForStory = hero
        showingStoryGeneration = true
    }
    
    private func handleHeroEdit(_ hero: Hero) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        selectedHeroForEdit = hero
    }
}

// MARK: - Hero Grid Header
struct HeroGridHeaderView: View {
    let heroCount: Int
    @Binding var showingHeroCreation: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Heroes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if heroCount > 0 {
                    Text("\(heroCount) \(heroCount == 1 ? "hero" : "heroes") created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if heroCount > 0 {
                NavigationLink(destination: HeroListView()) {
                    Label("Manage", systemImage: "person.3.fill")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Expanded Hero Card (1-2 heroes)
struct ExpandedHeroCard: View {
    let hero: Hero
    let onGenerateStory: () -> Void
    let onEdit: () -> Void
    
    @Query private var stories: [Story]
    @State private var isPressed = false
    @State private var showingDetails = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var heroStories: [Story] {
        stories.filter { $0.hero == hero }
    }
    
    private var latestStory: Story? {
        heroStories.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Card Content
            ZStack {
                // Background Gradient
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.8),
                                Color.purple
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Content
                VStack(spacing: 16) {
                    // Hero Header
                    HStack(spacing: 16) {
                        // Avatar
                        HeroAvatarImageView.large(hero).withEditButton {
                            onEdit()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(hero.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            // Traits
                            HStack(spacing: 8) {
                                TraitPill(trait: hero.primaryTrait, color: .orange)
                                TraitPill(trait: hero.secondaryTrait, color: .pink)
                            }
                            
                            // Special Ability
                            if !hero.specialAbility.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                    Text(hero.specialAbility)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Stats Row
                    HStack(spacing: 20) {
                        StatPill(
                            icon: "book.closed.fill",
                            value: "\(heroStories.count)",
                            label: "Stories"
                        )
                        
                        StatPill(
                            icon: "clock.fill",
                            value: formatDuration(heroStories),
                            label: "Total Time"
                        )
                        
                        StatPill(
                            icon: "star.fill",
                            value: "\(heroStories.filter { $0.isFavorite }.count)",
                            label: "Favorites"
                        )
                    }
                    
                    // Latest Story Preview (if exists)
                    if let latestStory = latestStory {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Latest Story")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Spacer()
                                
                                Text(latestStory.formattedDate)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Text(latestStory.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: onGenerateStory) {
                            Label("New Story", systemImage: "sparkles")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: onEdit) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
            }
            .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .rotation3DEffect(
            .degrees(isPressed ? 2 : 0),
            axis: (x: 1, y: 0, z: 0)
        )
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hero.name), \(hero.traitsDescription)")
        .accessibilityHint("Tap to view options")
    }
    
    private func formatDuration(_ stories: [Story]) -> String {
        let totalMinutes = stories.reduce(0) { $0 + Int($1.estimatedDuration / 60) }
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Compact Hero Card (3+ heroes)
struct CompactHeroCard: View {
    let hero: Hero
    let onTap: () -> Void
    let onEdit: () -> Void
    
    @Query private var stories: [Story]
    @State private var isPressed = false
    @State private var showingMenu = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var heroStoryCount: Int {
        stories.filter { $0.hero == hero }.count
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Avatar
                HeroAvatarImageView.medium(hero)
                
                // Name
                Text(hero.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Primary Trait
                Text(hero.primaryTrait.rawValue)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.8))
                    .cornerRadius(6)
                
                // Story Count
                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.caption2)
                    Text("\(heroStoryCount)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                // Quick Actions
                HStack(spacing: 8) {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onTap()
                    }) {
                        Image(systemName: "sparkles.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onEdit()
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.purple)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hero.name), \(hero.primaryTrait.rawValue), \(heroStoryCount) stories")
        .accessibilityHint("Tap to create a new story")
    }
}

// MARK: - Add Hero Card
struct AddHeroCard: View {
    @Binding var showingHeroCreation: Bool
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            showingHeroCreation = true
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.purple)
                }
                
                Text("Add Hero")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                
                Text("Create new")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.purple.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                            .foregroundColor(.purple.opacity(0.3))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityLabel("Add new hero")
        .accessibilityHint("Tap to create a new hero character")
    }
}

// Note: HeroAvatarView is now handled by HeroAvatarImageView in Components folder

// MARK: - Trait Pill
struct TraitPill: View {
    let trait: CharacterTrait
    let color: Color
    
    var body: some View {
        Text(trait.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.8))
            .cornerRadius(6)
    }
}

// MARK: - Stat Pill
struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Hero Empty State
struct HeroEmptyStateView: View {
    @Binding var showingHeroCreation: Bool
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)
                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
            }
            
            VStack(spacing: 12) {
                Text("Create Your First Hero")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Start your magical journey by creating\na hero for your stories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                showingHeroCreation = true
            }) {
                Label("Create Hero", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
        .padding(.vertical, 40)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        AdaptiveHeroGridView(
            heroes: [],
            showingHeroCreation: .constant(false),
            selectedHeroForStory: .constant(nil),
            showingStoryGeneration: .constant(false)
        )
    }
    .modelContainer(for: Hero.self, inMemory: true)
}