//
//  AdaptiveHeroGridDemo.swift
//  InfiniteStories
//
//  Demo and test file for the adaptive hero grid display system
//

import SwiftUI
import SwiftData

// MARK: - Demo View
struct AdaptiveHeroGridDemo: View {
    @State private var heroCount = 1
    @State private var showingHeroCreation = false
    @State private var selectedHeroForStory: Hero?
    @State private var showingStoryGeneration = false
    
    // Create mock heroes for demo
    private var mockHeroes: [Hero] {
        (0..<heroCount).map { index in
            let hero = Hero(
                name: "Hero \(index + 1)",
                primaryTrait: CharacterTrait.allCases[index % CharacterTrait.allCases.count],
                secondaryTrait: CharacterTrait.allCases[(index + 1) % CharacterTrait.allCases.count],
                appearance: "A brave warrior with a kind heart",
                specialAbility: "Can fly and has super strength"
            )
            return hero
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Control Panel
                VStack(spacing: 16) {
                    Text("Adaptive Grid Demo")
                        .font(.headline)
                        .foregroundColor(.purple)
                    
                    HStack {
                        Text("Heroes: \(heroCount)")
                            .font(.subheadline)
                            .frame(width: 100, alignment: .leading)
                        
                        Slider(value: Binding(
                            get: { Double(heroCount) },
                            set: { heroCount = Int($0) }
                        ), in: 0...10, step: 1)
                        .accentColor(.purple)
                    }
                    
                    Text(layoutDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                
                Divider()
                
                // Adaptive Hero Grid
                ScrollView {
                    AdaptiveHeroGridView(
                        heroes: mockHeroes,
                        showingHeroCreation: $showingHeroCreation,
                        selectedHeroForStory: $selectedHeroForStory,
                        showingStoryGeneration: $showingStoryGeneration
                    )
                    .padding(.vertical)
                }
            }
            .navigationTitle("Hero Grid Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("0 Heroes (Empty State)") { heroCount = 0 }
                        Button("1 Hero (Expanded)") { heroCount = 1 }
                        Button("2 Heroes (Expanded)") { heroCount = 2 }
                        Button("3 Heroes (2 Column Grid)") { heroCount = 3 }
                        Button("4 Heroes (2 Column Grid)") { heroCount = 4 }
                        Button("5+ Heroes (Compact Grid)") { heroCount = 5 }
                        Button("10 Heroes (Max Grid)") { heroCount = 10 }
                    } label: {
                        Label("Presets", systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
        .sheet(isPresented: $showingHeroCreation) {
            Text("Hero Creation View")
                .font(.title)
                .padding()
        }
        .sheet(isPresented: $showingStoryGeneration) {
            if let hero = selectedHeroForStory {
                VStack(spacing: 20) {
                    Text("Story Generation")
                        .font(.title)
                    Text("Selected Hero: \(hero.name)")
                        .font(.headline)
                    Button("Close") {
                        showingStoryGeneration = false
                        selectedHeroForStory = nil
                    }
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
        }
    }
    
    private var layoutDescription: String {
        switch heroCount {
        case 0:
            return "Empty state with call-to-action"
        case 1...2:
            return "Expanded cards with full details and stats"
        case 3...4:
            return "2-column grid layout"
        case 5...:
            return "Compact grid (2 columns on iPhone, 3 on iPad)"
        default:
            return ""
        }
    }
}

// MARK: - Layout Comparison View
struct LayoutComparisonView: View {
    var body: some View {
        TabView {
            // Empty State
            NavigationView {
                AdaptiveHeroGridView(
                    heroes: [],
                    showingHeroCreation: .constant(false),
                    selectedHeroForStory: .constant(nil),
                    showingStoryGeneration: .constant(false)
                )
                .navigationTitle("Empty State")
            }
            .tabItem {
                Label("Empty", systemImage: "person.crop.circle.badge.questionmark")
            }
            
            // Single Hero
            NavigationView {
                AdaptiveHeroGridView(
                    heroes: [createMockHero(name: "Luna", primary: .brave, secondary: .kind)],
                    showingHeroCreation: .constant(false),
                    selectedHeroForStory: .constant(nil),
                    showingStoryGeneration: .constant(false)
                )
                .navigationTitle("Single Hero")
            }
            .tabItem {
                Label("Single", systemImage: "person.fill")
            }
            
            // Two Heroes
            NavigationView {
                AdaptiveHeroGridView(
                    heroes: [
                        createMockHero(name: "Luna", primary: .brave, secondary: .kind),
                        createMockHero(name: "Max", primary: .curious, secondary: .funny)
                    ],
                    showingHeroCreation: .constant(false),
                    selectedHeroForStory: .constant(nil),
                    showingStoryGeneration: .constant(false)
                )
                .navigationTitle("Two Heroes")
            }
            .tabItem {
                Label("Two", systemImage: "person.2.fill")
            }
            
            // Grid Layout
            NavigationView {
                AdaptiveHeroGridView(
                    heroes: [
                        createMockHero(name: "Luna", primary: .brave, secondary: .kind),
                        createMockHero(name: "Max", primary: .curious, secondary: .funny),
                        createMockHero(name: "Aria", primary: .smart, secondary: .gentle),
                        createMockHero(name: "Leo", primary: .adventurous, secondary: .creative)
                    ],
                    showingHeroCreation: .constant(false),
                    selectedHeroForStory: .constant(nil),
                    showingStoryGeneration: .constant(false)
                )
                .navigationTitle("Grid Layout")
            }
            .tabItem {
                Label("Grid", systemImage: "square.grid.2x2.fill")
            }
        }
    }
    
    private func createMockHero(name: String, primary: CharacterTrait, secondary: CharacterTrait) -> Hero {
        Hero(
            name: name,
            primaryTrait: primary,
            secondaryTrait: secondary,
            appearance: "A magical character with sparkling eyes",
            specialAbility: "Can create beautiful stories"
        )
    }
}

// MARK: - Performance Test View
struct PerformanceTestView: View {
    @State private var heroes: [Hero] = []
    @State private var isLoading = false
    @State private var testResults = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Performance Testing")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 10) {
                    Button("Test 10 Heroes") { runTest(count: 10) }
                    Button("Test 25 Heroes") { runTest(count: 25) }
                    Button("Test 50 Heroes") { runTest(count: 50) }
                    Button("Test 100 Heroes") { runTest(count: 100) }
                    Button("Clear") { 
                        heroes = []
                        testResults = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                
                if !testResults.isEmpty {
                    Text(testResults)
                        .font(.caption)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                if isLoading {
                    ProgressView("Loading heroes...")
                        .padding()
                }
                
                ScrollView {
                    AdaptiveHeroGridView(
                        heroes: heroes,
                        showingHeroCreation: .constant(false),
                        selectedHeroForStory: .constant(nil),
                        showingStoryGeneration: .constant(false)
                    )
                }
            }
            .padding()
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func runTest(count: Int) {
        isLoading = true
        let startTime = Date()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            heroes = (0..<count).map { index in
                Hero(
                    name: "Hero \(index + 1)",
                    primaryTrait: CharacterTrait.allCases.randomElement()!,
                    secondaryTrait: CharacterTrait.allCases.randomElement()!,
                    appearance: "Test appearance \(index)",
                    specialAbility: "Test ability \(index)"
                )
            }
            
            let loadTime = Date().timeIntervalSince(startTime)
            testResults = "Loaded \(count) heroes in \(String(format: "%.3f", loadTime)) seconds"
            isLoading = false
        }
    }
}

// MARK: - Accessibility Test View
struct AccessibilityTestView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Accessibility Features")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Enable VoiceOver to test:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("Hero names are announced", systemImage: "checkmark.circle.fill")
                    Label("Traits are described", systemImage: "checkmark.circle.fill")
                    Label("Story counts are included", systemImage: "checkmark.circle.fill")
                    Label("Actions have clear hints", systemImage: "checkmark.circle.fill")
                    Label("Focus states are visible", systemImage: "checkmark.circle.fill")
                    Label("Reduce motion is respected", systemImage: "checkmark.circle.fill")
                }
                .foregroundColor(.green)
                
                Divider()
                
                AdaptiveHeroGridView(
                    heroes: [
                        Hero(name: "Accessible Hero", 
                             primaryTrait: .brave, 
                             secondaryTrait: .kind,
                             specialAbility: "Creates inclusive stories")
                    ],
                    showingHeroCreation: .constant(false),
                    selectedHeroForStory: .constant(nil),
                    showingStoryGeneration: .constant(false)
                )
            }
            .padding()
            .navigationTitle("Accessibility")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Main Demo Container
struct HeroGridDemoContainer: View {
    var body: some View {
        TabView {
            AdaptiveHeroGridDemo()
                .tabItem {
                    Label("Interactive", systemImage: "hand.tap.fill")
                }
            
            LayoutComparisonView()
                .tabItem {
                    Label("Layouts", systemImage: "rectangle.3.group.fill")
                }
            
            PerformanceTestView()
                .tabItem {
                    Label("Performance", systemImage: "speedometer")
                }
            
            AccessibilityTestView()
                .tabItem {
                    Label("Accessibility", systemImage: "person.wave.2.fill")
                }
        }
    }
}

// MARK: - Preview
#Preview("Demo Container") {
    HeroGridDemoContainer()
        .modelContainer(for: Hero.self, inMemory: true)
}

#Preview("Adaptive Grid") {
    AdaptiveHeroGridDemo()
        .modelContainer(for: Hero.self, inMemory: true)
}

#Preview("Empty State") {
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

#Preview("Single Hero") {
    NavigationView {
        AdaptiveHeroGridView(
            heroes: [
                Hero(name: "Luna the Brave", 
                     primaryTrait: .brave, 
                     secondaryTrait: .kind,
                     appearance: "A courageous warrior with flowing silver hair",
                     specialAbility: "Can light up the darkest nights")
            ],
            showingHeroCreation: .constant(false),
            selectedHeroForStory: .constant(nil),
            showingStoryGeneration: .constant(false)
        )
    }
    .modelContainer(for: Hero.self, inMemory: true)
}