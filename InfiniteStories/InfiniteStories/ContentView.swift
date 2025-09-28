//
//  ContentView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeSettings: ThemeSettings
    @Query private var heroes: [Hero]
    @Query private var stories: [Story]
    
    @State private var showingHeroCreation = false
    @State private var showingStoryGeneration = false
    @State private var showingSettings = false
    @State private var showingHeroManagement = false
    @State private var selectedHeroForStory: Hero?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                
                // Compact Header - only show when heroes exist
                if !heroes.isEmpty {
                    HStack {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.purple)
                        
                        Text("Your Heroes")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: { showingHeroManagement = true }) {
                            Text("Manage heroes")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                // Main Content
                if heroes.isEmpty {
                    // First time user - create hero
                    VStack(spacing: 20) {
                        Text("Welcome! Let's create your story hero")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showingHeroCreation = true }) {
                            Label("Create Your First Hero", systemImage: "person.crop.circle.badge.plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                } else {
                    // Quick Actions Section
                    VStack(spacing: 15) {
                        Button(action: { showingStoryGeneration = true }) {
                            Label("Generate New Story", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: Color.orange.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        
                        if !stories.isEmpty {
                            NavigationLink(destination: ImprovedStoryLibraryView()) {
                                HStack {
                                    Image(systemName: "books.vertical.fill")
                                        .font(.system(size: 20))
                                    Text("View Story Library")
                                    Spacer()
                                    Text("\(stories.count)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .font(.headline)
                                .foregroundColor(.purple)
                                .padding()
                                .background(Color(.systemGray6).opacity(colorScheme == .dark ? 0.5 : 1.0))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(false)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingHeroCreation) {
                HeroCreationView(heroToEdit: nil)
            }
            .sheet(isPresented: $showingHeroManagement) {
                HeroListView()
            }
            .sheet(isPresented: $showingStoryGeneration) {
                if let hero = selectedHeroForStory ?? heroes.first {
                    StoryGenerationView(hero: hero)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(themeSettings)
            }
        }
    }
}

// Note: This is the original StoryLibraryView
// For the improved version, use ImprovedStoryLibraryView
struct StoryLibraryView: View {
    @Query(sort: \Story.createdAt, order: .reverse) private var stories: [Story]
    @State private var selectedStory: Story?
    
    var body: some View {
        List(stories) { story in
            StoryRow(story: story) {
                selectedStory = story
            }
        }
        .navigationTitle("Story Library")
        .sheet(item: $selectedStory) { story in
            NavigationStack {
                // Find the index of the selected story in the stories list
                let storyIndex = stories.firstIndex(where: { $0.id == story.id }) ?? 0
                AudioPlayerView(
                    story: story,
                    allStories: stories,
                    storyIndex: storyIndex
                )
                    .onAppear {
                        print("📚 Opening AudioPlayerView for story: \(story.title)")
                        print("📚 Story queue has \(stories.count) stories, starting at index \(storyIndex)")
                    }
            }
        }
    }
}

struct StoryRow: View {
    let story: Story
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Hero Avatar
                if let hero = story.hero {
                    HeroAvatarImageView.medium(hero)
                } else {
                    // Fallback if no hero
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 60, height: 60)
                        Image(systemName: "book.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(story.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if story.isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    Text(story.shortContent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if let hero = story.hero {
                            Text(hero.name)
                                .font(.caption)
                                .foregroundColor(.purple)
                                .fontWeight(.medium)
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(story.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                        
                        HStack(spacing: 15) {
                            if story.hasAudio {
                                Label("\(Int(story.estimatedDuration / 60))min", systemImage: "speaker.wave.2")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            if story.playCount > 0 {
                                Label("\(story.playCount)", systemImage: "play")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Label(story.eventTitle, systemImage: "sparkles")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    ContentView()
        .modelContainer(for: Hero.self, inMemory: true)
}
