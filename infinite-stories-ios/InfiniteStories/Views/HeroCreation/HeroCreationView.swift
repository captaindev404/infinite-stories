//
//  HeroCreationView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData

struct HeroCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let heroToEdit: Hero?
    var onSave: ((Hero) -> Void)?

    @State private var heroName: String = ""
    @State private var primaryTrait: CharacterTrait = .brave
    @State private var secondaryTrait: CharacterTrait = .kind
    @State private var appearance: String = ""
    @State private var specialAbility: String = ""
    @State private var currentStep = 0

    // Post-creation avatar generation
    @State private var showAvatarPrompt = false
    @State private var showingAvatarGeneration = false
    @State private var savedHero: Hero?

    private let totalSteps = 4
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 30) {
                        headerView
                        currentStepView
                            .id(currentStep)
                            .transition(.opacity)
                    }
                    .padding()
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
                }

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button(String(localized: "hero.creation.button.back")) {
                            currentStep -= 1
                        }
                        .buttonStyle(.bordered)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint(String(localized: "hero.creation.accessibility.back.hint"))
                    }

                    Spacer()

                    Button(currentStep == totalSteps - 1 ? (heroToEdit != nil ? String(localized: "hero.creation.button.update") : String(localized: "hero.creation.button.create")) : String(localized: "hero.creation.button.next")) {
                        if currentStep == totalSteps - 1 {
                            saveHero()
                        } else {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(!canProceed)
                    .accessibilityHint(currentStep == totalSteps - 1 ? String(localized: "hero.creation.accessibility.save.hint") : String(localized: "hero.creation.accessibility.next.hint"))
                }
                .padding()
            }
            .navigationTitle(heroToEdit != nil ? String(localized: "hero.creation.title.edit") : String(localized: "hero.creation.title.create"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "hero.creation.button.cancel")) {
                        dismiss()
                    }
                    .accessibilityLabel(String(localized: "hero.creation.button.cancel"))
                    .accessibilityHint(String(localized: "hero.creation.accessibility.cancel.hint"))
                }
            }
        }
        .sheet(isPresented: $showAvatarPrompt) {
            AvatarPromptView(
                hero: savedHero,
                showingAvatarGeneration: $showingAvatarGeneration,
                onDismiss: {
                    showAvatarPrompt = false
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showingAvatarGeneration) {
            if let hero = savedHero {
                AvatarGenerationView(hero: hero, isPresented: $showingAvatarGeneration)
                    .onDisappear {
                        // After avatar generation, dismiss the whole flow
                        dismiss()
                    }
            }
        }
        .onAppear {
            if let hero = heroToEdit {
                heroName = hero.name
                primaryTrait = hero.primaryTrait
                secondaryTrait = hero.secondaryTrait
                appearance = hero.appearance
                specialAbility = hero.specialAbility
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.star.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
                // BUG-26: decorative header icon; step text already
                // carries the meaningful label.
                .accessibilityHidden(true)

            Text(String(localized: "hero.creation.header.step", defaultValue: "Step \(currentStep + 1) of \(totalSteps)"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0:
            nameStep
        case 1:
            primaryTraitStep
        case 2:
            secondaryTraitStep
        case 3:
            customizationStep
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var nameStep: some View {
        VStack(spacing: 20) {
            Text(String(localized: "hero.creation.name.question"))
                .font(.title3)
                .fontWeight(.semibold)

            // BUG-24/30: hero name gets an explicit a11y label (the
            // question sitting above it) plus autocorrect disabled and
            // .words capitalization so `QA Hero` isn't silently rewritten
            // to `AQ Hero`.
            Group {
                if #available(iOS 18.0, *) {
                    TextField(String(localized: "hero.creation.name.placeholder"), text: $heroName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .writingToolsBehavior(.disabled)
                } else {
                    TextField(String(localized: "hero.creation.name.placeholder"), text: $heroName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                }
            }
            .accessibilityLabel(String(localized: "hero.creation.name.question"))
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.words)

            Text(String(localized: "hero.creation.name.hint"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var primaryTraitStep: some View {
        VStack(spacing: 20) {
            Text(String(localized: "hero.creation.primarytrait.question", defaultValue: "What's \(heroName)'s main personality?"))
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                ForEach(CharacterTrait.allCases, id: \.self) { trait in
                    TraitCard(
                        trait: trait,
                        isSelected: trait == primaryTrait
                    ) {
                        primaryTrait = trait
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var secondaryTraitStep: some View {
        VStack(spacing: 20) {
            Text(String(localized: "hero.creation.secondarytrait.question", defaultValue: "What's \(heroName)'s secondary trait?"))
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(String(localized: "hero.creation.secondarytrait.hint"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                ForEach(CharacterTrait.allCases.filter { $0 != primaryTrait }, id: \.self) { trait in
                    TraitCard(
                        trait: trait,
                        isSelected: trait == secondaryTrait
                    ) {
                        secondaryTrait = trait
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var customizationStep: some View {
        VStack(spacing: 25) {
            Text(String(localized: "hero.creation.customization.title"))
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "hero.creation.appearance.question", defaultValue: "How does \(heroName) look?"))
                        .font(.headline)

                    Group {
                        if #available(iOS 18.0, *) {
                            TextField(String(localized: "hero.creation.appearance.placeholder"), text: $appearance)
                                .textFieldStyle(.roundedBorder)
                                .writingToolsBehavior(.disabled)
                        } else {
                            TextField(String(localized: "hero.creation.appearance.placeholder"), text: $appearance)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    // BUG-24: match the visible question above the field.
                    .accessibilityLabel(String(localized: "hero.creation.appearance.question", defaultValue: "How does \(heroName) look?"))

                    Text(String(localized: "hero.creation.appearance.hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "hero.creation.specialability.question", defaultValue: "What's \(heroName)'s special ability?"))
                        .font(.headline)

                    Group {
                        if #available(iOS 18.0, *) {
                            TextField(String(localized: "hero.creation.specialability.placeholder"), text: $specialAbility)
                                .textFieldStyle(.roundedBorder)
                                .writingToolsBehavior(.disabled)
                        } else {
                            TextField(String(localized: "hero.creation.specialability.placeholder"), text: $specialAbility)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    // BUG-24: match the visible question above the field.
                    .accessibilityLabel(String(localized: "hero.creation.specialability.question", defaultValue: "What's \(heroName)'s special ability?"))

                    Text(String(localized: "hero.creation.specialability.hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Hero preview
            HeroPreviewCard(
                name: heroName,
                primaryTrait: primaryTrait,
                secondaryTrait: secondaryTrait,
                appearance: appearance,
                specialAbility: specialAbility
            )

            // Informational note about avatar
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.purple)
                    // BUG-26: decorative, label is provided by the
                    // adjacent Text.
                    .accessibilityHidden(true)
                Text(String(localized: "hero.creation.avatar.info"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return !heroName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    private func saveHero() {
        Task {
            await saveHeroAsync()
        }
    }

    private func saveHeroAsync() async {
        let repository = HeroRepository()
        let trimmedName = heroName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAppearance = appearance.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAbility = specialAbility.trimmingCharacters(in: .whitespacesAndNewlines)

        guard NetworkMonitor.shared.isConnected else {
            // Show network error
            print("No internet connection. Please connect and try again.")
            return
        }

        do {
            if let heroToEdit = heroToEdit {
                // Update existing hero via API
                guard let backendId = heroToEdit.backendId else {
                    throw APIError.unknown(NSError(domain: "HeroCreationView", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Hero has no backend ID"]))
                }

                let updatedHero = try await repository.updateHero(
                    id: backendId,
                    name: trimmedName,
                    traits: [primaryTrait, secondaryTrait],
                    specialAbility: trimmedAbility.isEmpty ? nil : trimmedAbility,
                    appearance: trimmedAppearance.isEmpty ? nil : trimmedAppearance
                )
                print("Hero updated successfully: \(updatedHero.name)")
                onSave?(updatedHero)
                dismiss()
            } else {
                // Create new hero via API
                let newHero = try await repository.createHero(
                    name: trimmedName,
                    age: 7, // Default age
                    traits: [primaryTrait, secondaryTrait],
                    specialAbility: trimmedAbility.isEmpty ? nil : trimmedAbility,
                    appearance: trimmedAppearance.isEmpty ? nil : trimmedAppearance
                )
                print("Hero created successfully: \(newHero.name)")

                // For new heroes, offer avatar generation
                savedHero = newHero
                showAvatarPrompt = true

                onSave?(newHero)
            }
        } catch {
            print("Failed to save hero: \(error.localizedDescription)")
            // TODO: Show error alert to user
        }
    }
}

struct AvatarPromptView: View {
    @Environment(\.colorScheme) private var colorScheme
    let hero: Hero?
    @Binding var showingAvatarGeneration: Bool
    let onDismiss: () -> Void

    @State private var showAvatarSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // Avatar icon
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)
                    // BUG-26: decorative — avatar prompt title/subtitle
                    // already describe the flow.
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(String(localized: "hero.avatar.prompt.title"))
                        .font(.title)
                        .fontWeight(.bold)

                    if let heroName = hero?.name {
                        Text(String(localized: "hero.avatar.prompt.subtitle", defaultValue: "Create an AI-generated avatar for \(heroName)"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                VStack(spacing: 16) {
                    Button {
                        showAvatarSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                // BUG-26: decorative — button carries a
                                // text label + explicit accessibilityLabel.
                                .accessibilityHidden(true)
                            Text(String(localized: "hero.avatar.prompt.button.generate"))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel(String(localized: "hero.avatar.prompt.button.generate"))
                    .accessibilityHint(String(localized: "hero.avatar.prompt.accessibility.hint"))

                    Button {
                        onDismiss()
                    } label: {
                        Text(String(localized: "hero.avatar.prompt.button.later"))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel(String(localized: "hero.avatar.prompt.accessibility.skip"))
                    .accessibilityHint(String(localized: "hero.avatar.prompt.accessibility.skip.hint"))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding()
            .navigationTitle(String(localized: "hero.avatar.prompt.ready"))
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showAvatarSheet) {
                if let hero = hero {
                    AvatarGenerationView(hero: hero, isPresented: $showAvatarSheet)
                        .onDisappear {
                            onDismiss()
                        }
                }
            }
        }
    }
}

struct TraitCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let trait: CharacterTrait
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // BUG-15: show localized trait name/description so FR users
                // stop seeing the English rawValue (e.g. "Brave" in a FR UI).
                Text(trait.localizedName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(trait.localizedDescription)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(isSelected ? Color.purple.opacity(colorScheme == .dark ? 0.2 : 0.1) : Color(.systemGray6).opacity(colorScheme == .dark ? 0.5 : 1.0))
            .foregroundColor(isSelected ? .purple : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(trait.localizedName)
        .accessibilityHint(trait.localizedDescription)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct HeroPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String
    let primaryTrait: CharacterTrait
    let secondaryTrait: CharacterTrait
    let appearance: String
    let specialAbility: String

    var body: some View {
        VStack(spacing: 15) {
            Text(String(localized: "hero.creation.preview.title"))
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.purple)
                        // BUG-26: decorative avatar stand-in in the hero
                        // preview; the hero name right next to it is the
                        // meaningful label.
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(String(localized: "hero.creation.preview.traits", defaultValue: "\(primaryTrait.rawValue) and \(secondaryTrait.rawValue)"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                if !appearance.isEmpty {
                    Text(String(localized: "hero.creation.preview.appearance", defaultValue: "Appearance: \(appearance)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if !specialAbility.isEmpty {
                    Text(String(localized: "hero.creation.preview.specialability", defaultValue: "Special Ability: \(specialAbility)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(colorScheme == .dark ? 0.5 : 1.0))
            .cornerRadius(12)
        }
    }
}


#Preview {
    HeroCreationView(heroToEdit: nil)
        .modelContainer(for: Hero.self, inMemory: true)
}