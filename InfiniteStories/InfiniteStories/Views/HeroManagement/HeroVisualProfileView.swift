//
//  HeroVisualProfileView.swift
//  InfiniteStories
//
//  View for managing hero visual consistency profiles
//

import SwiftUI
import SwiftData

struct HeroVisualProfileView: View {
    let hero: Hero
    @State private var visualProfile: HeroVisualProfile?
    @State private var isLoading = false
    @State private var showingEditor = false
    @State private var showingExtractor = false
    @State private var errorMessage: String?

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Visual Profile Status
                profileStatusSection

                if let profile = visualProfile {
                    // Visual Characteristics
                    characteristicsSection(profile)

                    // Art Style Settings
                    artStyleSection(profile)

                    // Prompts
                    promptsSection(profile)

                    // Actions
                    actionsSection(profile)
                } else {
                    // Create Profile
                    createProfileSection
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Visual Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            visualProfile = hero.visualProfile
        }
        .sheet(isPresented: $showingEditor) {
            VisualProfileEditorView(
                profile: visualProfile ?? HeroVisualProfile(
                    canonicalPrompt: hero.avatarPrompt ?? ""
                ),
                hero: hero
            ) { updatedProfile in
                visualProfile = updatedProfile
                hero.visualProfile = updatedProfile
                try? modelContext.save()
            }
        }
    }

    // MARK: - View Sections

    private var headerSection: some View {
        HStack {
            HeroAvatarImageView(hero: hero, size: 80)

            VStack(alignment: .leading) {
                Text(hero.name)
                    .font(.title2)
                    .bold()

                Text(hero.appearance)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var profileStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Visual Consistency Status", systemImage: "eye.circle.fill")
                .font(.headline)

            HStack {
                Image(systemName: visualProfile != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(visualProfile != nil ? .green : .orange)

                Text(visualProfile != nil ? "Profile Active" : "No Profile")
                    .font(.subheadline)

                Spacer()

                if let profile = visualProfile {
                    Text(profile.extractionMethod.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func characteristicsSection(_ profile: HeroVisualProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Visual Characteristics", systemImage: "person.text.rectangle")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                characteristicItem("Hair", value: combineHair(profile))
                characteristicItem("Eyes", value: profile.eyeColor)
                characteristicItem("Skin", value: profile.skinTone)
                characteristicItem("Age", value: profile.ageAppearance)
                characteristicItem("Clothing", value: profile.clothingStyle)
                characteristicItem("Colors", value: profile.clothingColors)
            }

            if let distinctive = profile.distinctiveFeatures {
                VStack(alignment: .leading) {
                    Text("Distinctive Features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(distinctive)
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func artStyleSection(_ profile: HeroVisualProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Art Style", systemImage: "paintbrush.pointed.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Style:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(profile.artStyle)
                        .font(.subheadline)
                }

                if let palette = profile.colorPalette {
                    HStack {
                        Text("Colors:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(palette)
                            .font(.subheadline)
                    }
                }

                if let lighting = profile.lightingPreference {
                    HStack {
                        Text("Lighting:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(lighting)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func promptsSection(_ profile: HeroVisualProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Consistency Prompts", systemImage: "text.alignleft")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Canonical Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(profile.canonicalPrompt)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading) {
                    Text("Simplified for Scenes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(profile.simplifiedPrompt)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func actionsSection(_ profile: HeroVisualProfile) -> some View {
        VStack(spacing: 12) {
            Button(action: {
                showingEditor = true
            }) {
                Label("Edit Profile", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: {
                Task {
                    await extractProfileWithAI()
                }
            }) {
                Label("Re-Extract with AI", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)

            Button(action: {
                resetProfile()
            }) {
                Label("Reset Profile", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var createProfileSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("No Visual Profile")
                .font(.headline)

            Text("Create a visual consistency profile to ensure \(hero.name) looks the same in all illustrations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                Task {
                    await createProfile()
                }
            }) {
                Label("Create Profile", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            if isLoading {
                ProgressView()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Helper Views

    private func characteristicItem(_ label: String, value: String?) -> some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value ?? "Not specified")
                .font(.subheadline)
                .foregroundColor(value != nil ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func combineHair(_ profile: HeroVisualProfile) -> String? {
        if let color = profile.hairColor, let style = profile.hairStyle {
            return "\(color) \(style)"
        }
        return profile.hairColor ?? profile.hairStyle
    }

    // MARK: - Actions

    private func createProfile() async {
        isLoading = true
        errorMessage = nil

        // For now, create a basic profile manually
        // In production, this would be triggered from a view that has access to the AI service
        let profile = HeroVisualProfile(
            canonicalPrompt: hero.avatarPrompt ?? hero.appearance,
            artStyle: "warm watercolor children's book illustration"
        )

        // Set basic attributes from hero
        profile.distinctiveFeatures = hero.appearance
        profile.ageAppearance = "young child character"
        profile.extractionMethod = "manual"

        // Link to hero and save
        hero.visualProfile = profile
        modelContext.insert(profile)

        do {
            try modelContext.save()
            visualProfile = profile
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func extractProfileWithAI() async {
        isLoading = true
        errorMessage = nil

        // This would need to be implemented in a view with AI service access
        // For now, just show a message
        errorMessage = "AI extraction requires access to the AI service. Please use the story generation flow to extract visual profiles."

        isLoading = false
    }

    private func resetProfile() {
        if let profile = visualProfile {
            modelContext.delete(profile)
            hero.visualProfile = nil
            try? modelContext.save()
            visualProfile = nil
        }
    }
}

// MARK: - Visual Profile Editor

struct VisualProfileEditorView: View {
    @State var profile: HeroVisualProfile
    let hero: Hero
    let onSave: (HeroVisualProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Appearance") {
                    TextField("Hair Color", text: Binding(
                        get: { profile.hairColor ?? "" },
                        set: { profile.hairColor = $0.isEmpty ? nil : $0 }
                    ))

                    TextField("Hair Style", text: Binding(
                        get: { profile.hairStyle ?? "" },
                        set: { profile.hairStyle = $0.isEmpty ? nil : $0 }
                    ))

                    TextField("Eye Color", text: Binding(
                        get: { profile.eyeColor ?? "" },
                        set: { profile.eyeColor = $0.isEmpty ? nil : $0 }
                    ))

                    TextField("Skin Tone", text: Binding(
                        get: { profile.skinTone ?? "" },
                        set: { profile.skinTone = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Clothing") {
                    TextField("Clothing Style", text: Binding(
                        get: { profile.clothingStyle ?? "" },
                        set: { profile.clothingStyle = $0.isEmpty ? nil : $0 }
                    ))

                    TextField("Clothing Colors", text: Binding(
                        get: { profile.clothingColors ?? "" },
                        set: { profile.clothingColors = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Art Style") {
                    TextField("Art Style", text: $profile.artStyle)

                    TextField("Color Palette", text: Binding(
                        get: { profile.colorPalette ?? "" },
                        set: { profile.colorPalette = $0.isEmpty ? nil : $0 }
                    ))

                    TextField("Lighting", text: Binding(
                        get: { profile.lightingPreference ?? "" },
                        set: { profile.lightingPreference = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Distinctive Features") {
                    TextEditor(text: Binding(
                        get: { profile.distinctiveFeatures ?? "" },
                        set: { profile.distinctiveFeatures = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Visual Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        profile.lastUpdated = Date()
                        onSave(profile)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        HeroVisualProfileView(
            hero: Hero(
                name: "Luna",
                primaryTrait: .brave,
                secondaryTrait: .kind,
                appearance: "Young girl with curly brown hair and bright green eyes",
                specialAbility: "Can talk to animals"
            )
        )
    }
}