//
//  ReadingJourneyDemo.swift
//  InfiniteStories
//
//  Demo view to test the new Reading Journey feature
//

import SwiftUI
import SwiftData

struct ReadingJourneyDemo: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stories: [Story]
    @Query private var heroes: [Hero]

    @State private var showingJourney = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Summary Info
                VStack(spacing: 10) {
                    Text("Reading Journey Feature")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Moved from main screen to dedicated view")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)

                // Stats Preview
                VStack(spacing: 15) {
                    HStack {
                        Label("\(stories.count) Stories", systemImage: "book.closed.fill")
                        Spacer()
                        Label("\(heroes.count) Heroes", systemImage: "person.2.fill")
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                // Main Screen Button
                NavigationLink(destination: ImprovedContentView()) {
                    Label("View Main Screen", systemImage: "house.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // Journey View Button
                Button(action: {
                    showingJourney = true
                }) {
                    Label("Open Reading Journey", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // Features List
                VStack(alignment: .leading, spacing: 10) {
                    Text("New Features:")
                        .font(.headline)

                    FeatureRow(icon: "chart.bar.fill", text: "Comprehensive listening statistics")
                    FeatureRow(icon: "calendar", text: "Reading streak tracking")
                    FeatureRow(icon: "trophy.fill", text: "Milestones and achievements")
                    FeatureRow(icon: "clock.fill", text: "Listening time analytics")
                    FeatureRow(icon: "person.3.fill", text: "Hero performance metrics")
                    FeatureRow(icon: "heart.fill", text: "Favorite stories collection")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // Benefit Note
                Text("More space for recent stories on main screen!")
                    .font(.footnote)
                    .foregroundColor(.green)
                    .padding()
            }
            .navigationTitle("Feature Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showingJourney) {
            ReadingJourneyView()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 25)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    ReadingJourneyDemo()
        .modelContainer(for: [Hero.self, Story.self], inMemory: true)
}