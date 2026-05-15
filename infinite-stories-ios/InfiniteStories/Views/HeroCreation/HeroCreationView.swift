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
                // BUG-A30: Announce step count ("Step 1 of 4") instead of
                // "0 %" which VoiceOver would speak as the raw progress value.
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                    .padding(.horizontal)
                    .accessibilityLabel(String(
                        // NOTE: catalog state is `new` — EN fallback kept until the
                        // key is translated. See Task #86 report.
                        format: String(localized: "hero.creation.progress.a11y",
                                       defaultValue: "Step %1$d of %2$d",
                                       comment: "VoiceOver label describing hero creation progress. %1$d is current step, %2$d is total steps."),
                        currentStep + 1, totalSteps
                    ))
                    .accessibilityValue("")
                
                ScrollView {
                    VStack(spacing: 30) {
                        headerView
                        currentStepView
                            .id(currentStep)
                            .transition(.opacity)
                    }
                    .padding()
                    .padding(.bottom, 40)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
                }

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button(String(localized: "hero.creation.button.back",
                                      comment: "Hero creation: Back button")) {
                            currentStep -= 1
                        }
                        .buttonStyle(.bordered)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint(String(localized: "hero.creation.accessibility.back.hint",
                                                  comment: "Hero creation: Back button accessibility hint"))
                    }

                    Spacer()

                    Button(currentStep == totalSteps - 1
                           ? (heroToEdit != nil
                              ? String(localized: "hero.creation.button.update",
                                       comment: "Hero creation: Update hero button")
                              : String(localized: "hero.creation.button.create",
                                       comment: "Hero creation: Create hero button"))
                           : String(localized: "hero.creation.button.next",
                                    comment: "Hero creation: Next button")) {
                        if currentStep == totalSteps - 1 {
                            saveHero()
                        } else {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(!canProceed)
                    .accessibilityHint(currentStep == totalSteps - 1
                                       ? String(localized: "hero.creation.accessibility.save.hint",
                                                comment: "Hero creation: Save hint")
                                       : String(localized: "hero.creation.accessibility.next.hint",
                                                comment: "Hero creation: Next hint"))
                }
                .padding()
            }
            .navigationTitle(heroToEdit != nil
                             ? String(localized: "hero.creation.title.edit",
                                      comment: "Hero creation: Edit title")
                             : String(localized: "hero.creation.title.create",
                                      comment: "Hero creation: Create title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "hero.creation.button.cancel",
                                  comment: "Hero creation: Cancel button")) {
                        dismiss()
                    }
                    .accessibilityLabel(String(localized: "hero.creation.button.cancel",
                                               comment: "Hero creation: Cancel button"))
                    .accessibilityHint(String(localized: "hero.creation.accessibility.cancel.hint",
                                              comment: "Hero creation: Cancel hint"))
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

            Text(String(format: String(localized: "hero.creation.header.step",
                                       comment: "Hero creation: Step indicator. %1$lld is current step, %2$lld is total steps."),
                        currentStep + 1, totalSteps))
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
            Text(String(localized: "hero.creation.name.question",
                        comment: "Hero creation: Name question"))
                .font(.title3)
                .fontWeight(.semibold)

            // BUG-24/30: hero name gets an explicit a11y label (the
            // question sitting above it) plus autocorrect disabled and
            // .words capitalization so `QA Hero` isn't silently rewritten
            // to `AQ Hero`.
            Group {
                if #available(iOS 18.0, *) {
                    TextField(String(localized: "hero.creation.name.placeholder",
                                     comment: "Hero creation: Name placeholder"), text: $heroName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .writingToolsBehavior(.disabled)
                } else {
                    TextField(String(localized: "hero.creation.name.placeholder",
                                     comment: "Hero creation: Name placeholder"), text: $heroName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                }
            }
            .accessibilityLabel(String(localized: "hero.creation.name.question",
                                       comment: "Hero creation: Name question"))
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.words)

            Text(String(localized: "hero.creation.name.hint",
                        comment: "Hero creation: Name hint"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var primaryTraitStep: some View {
        VStack(spacing: 20) {
            Text(String(format: String(localized: "hero.creation.primarytrait.question",
                                       comment: "Hero creation: Primary trait question. %@ is the hero name."),
                        heroName))
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
            Text(String(format: String(localized: "hero.creation.secondarytrait.question",
                                       comment: "Hero creation: Secondary trait question. %@ is the hero name."),
                        heroName))
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(String(localized: "hero.creation.secondarytrait.hint",
                        comment: "Hero creation: Secondary trait hint"))
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
            Text(String(localized: "hero.creation.customization.title",
                        comment: "Hero creation: Customization title"))
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    let appearanceQuestion = String(format: String(localized: "hero.creation.appearance.question",
                                                                   comment: "Hero creation: Appearance question. %@ is the hero name."),
                                                    heroName)
                    Text(appearanceQuestion)
                        .font(.headline)

                    Group {
                        if #available(iOS 18.0, *) {
                            TextField(String(localized: "hero.creation.appearance.placeholder",
                                             comment: "Hero creation: Appearance placeholder"), text: $appearance)
                                .textFieldStyle(.roundedBorder)
                                .writingToolsBehavior(.disabled)
                        } else {
                            TextField(String(localized: "hero.creation.appearance.placeholder",
                                             comment: "Hero creation: Appearance placeholder"), text: $appearance)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    // BUG-24: match the visible question above the field.
                    .accessibilityLabel(appearanceQuestion)

                    Text(String(localized: "hero.creation.appearance.hint",
                                comment: "Hero creation: Appearance hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    let specialAbilityQuestion = String(format: String(localized: "hero.creation.specialability.question",
                                                                       comment: "Hero creation: Special ability question. %@ is the hero name."),
                                                        heroName)
                    Text(specialAbilityQuestion)
                        .font(.headline)

                    Group {
                        if #available(iOS 18.0, *) {
                            TextField(String(localized: "hero.creation.specialability.placeholder",
                                             comment: "Hero creation: Special ability placeholder"), text: $specialAbility)
                                .textFieldStyle(.roundedBorder)
                                .writingToolsBehavior(.disabled)
                        } else {
                            TextField(String(localized: "hero.creation.specialability.placeholder",
                                             comment: "Hero creation: Special ability placeholder"), text: $specialAbility)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    // BUG-24: match the visible question above the field.
                    .accessibilityLabel(specialAbilityQuestion)

                    Text(String(localized: "hero.creation.specialability.hint",
                                comment: "Hero creation: Special ability hint"))
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
                Text(String(localized: "hero.creation.avatar.info",
                            comment: "Hero creation: Avatar info"))
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
                    Text(String(localized: "hero.avatar.prompt.title",
                                comment: "Avatar prompt: Title"))
                        .font(.title)
                        .fontWeight(.bold)

                    if let heroName = hero?.name {
                        Text(String(format: String(localized: "hero.avatar.prompt.subtitle",
                                                   comment: "Avatar prompt: Subtitle. %@ is the hero name."),
                                    heroName))
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
                            Text(String(localized: "hero.avatar.prompt.button.generate",
                                        comment: "Avatar prompt: Generate button"))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel(String(localized: "hero.avatar.prompt.button.generate",
                                               comment: "Avatar prompt: Generate button"))
                    .accessibilityHint(String(localized: "hero.avatar.prompt.accessibility.hint",
                                              comment: "Avatar prompt: Accessibility hint"))

                    Button {
                        onDismiss()
                    } label: {
                        Text(String(localized: "hero.avatar.prompt.button.later",
                                    comment: "Avatar prompt: Maybe later button"))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel(String(localized: "hero.avatar.prompt.accessibility.skip",
                                               comment: "Avatar prompt: Skip accessibility label"))
                    .accessibilityHint(String(localized: "hero.avatar.prompt.accessibility.skip.hint",
                                              comment: "Avatar prompt: Skip hint"))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding()
            .navigationTitle(String(localized: "hero.avatar.prompt.ready",
                                    comment: "Avatar prompt: Ready title"))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

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
            Text(String(localized: "hero.creation.preview.title",
                        comment: "Hero creation: Preview title"))
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

                        Text({
                            // BUG-15: use format string + localizedName instead of
                            // interpolating English rawValue into the lookup key.
                            let format = String(localized: "hero.creation.preview.traits",
                                                defaultValue: "%@ and %@",
                                                comment: "Hero creation: Preview traits")
                            return String(format: format, primaryTrait.localizedName, secondaryTrait.localizedName)
                        }())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                if !appearance.isEmpty {
                    Text(String(format: String(localized: "hero.creation.preview.appearance",
                                               comment: "Hero creation: Preview appearance. %@ is the appearance description."),
                                appearance))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if !specialAbility.isEmpty {
                    Text(String(format: String(localized: "hero.creation.preview.specialability",
                                               comment: "Hero creation: Preview special ability. %@ is the special ability."),
                                specialAbility))
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