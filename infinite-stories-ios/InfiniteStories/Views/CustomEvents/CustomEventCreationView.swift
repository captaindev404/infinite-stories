//
//  CustomEventCreationView.swift
//  InfiniteStories
//
//  Created on 2025-09-14.
//

import SwiftUI

struct CustomEventCreationView: View {
    @Environment(\.dismiss) private var dismiss

    // Callback for when event is created
    var onEventCreated: ((CustomStoryEvent) -> Void)?

    // Repository for API calls
    private let repository = CustomEventRepository()

    // Form state
    @State private var currentStep = 0
    @State private var eventTitle = ""
    @State private var eventDescription = ""
    @State private var selectedCategory: EventCategory = .custom
    @State private var selectedAgeRange: AgeRange = .all
    @State private var selectedTone: StoryTone = .cheerful
    @State private var keywords: [String] = []
    @State private var newKeyword = ""
    @State private var promptSeed = ""
    @State private var isEnhancingWithAI = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""

    @StateObject private var aiAssistant = CustomEventAIAssistant()

    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding()

                // Step content
                TabView(selection: $currentStep) {
                    BasicInfoStepView(
                        title: $eventTitle,
                        description: $eventDescription,
                        onSuggestTitle: suggestTitleWithAI
                    )
                    .tag(0)

                    CategorizationStepView(
                        category: $selectedCategory,
                        ageRange: $selectedAgeRange,
                        tone: $selectedTone
                    )
                    .tag(1)

                    AIEnhancementStepView(
                        promptSeed: $promptSeed,
                        keywords: $keywords,
                        newKeyword: $newKeyword,
                        isEnhancing: isEnhancingWithAI,
                        onEnhance: enhanceWithAI,
                        onGenerateKeywords: generateKeywordsWithAI
                    )
                    .tag(2)

                    PreviewStepView(
                        event: buildPreviewEvent(),
                        pictogramImage: nil,
                        onSave: saveCustomEvent
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation { currentStep -= 1 }
                        }) {
                            Label("customEvent.creation.navigation.previous", systemImage: "chevron.left")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSaving)
                    }

                    if currentStep < totalSteps - 1 {
                        Button(action: {
                            withAnimation { currentStep += 1 }
                        }) {
                            Label("customEvent.creation.navigation.next", systemImage: "chevron.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isStepValid(currentStep))
                    }

                    if currentStep == totalSteps - 1 {
                        Button(action: saveCustomEvent) {
                            if isSaving {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("customEvent.creation.navigation.save", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isFormValid() || isSaving)
                    }
                }
                .padding()
            }
            .navigationTitle("customEvent.creation.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("customEvent.creation.cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("customEvent.creation.error.title", isPresented: $showingError) {
                Button("customEvent.creation.error.ok") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Validation

    private func isStepValid(_ step: Int) -> Bool {
        switch step {
        case 0:
            return !eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !eventDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            return true // Category, age, and tone all have defaults
        case 2:
            return !promptSeed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    private func isFormValid() -> Bool {
        return !eventTitle.isEmpty && !eventDescription.isEmpty && !promptSeed.isEmpty
    }

    // MARK: - AI Integration

    private func suggestTitleWithAI() {
        guard !eventDescription.isEmpty else { return }

        Task {
            if let suggestedTitle = await aiAssistant.generateTitle(from: eventDescription) {
                await MainActor.run {
                    withAnimation {
                        eventTitle = suggestedTitle
                    }
                }
            }
        }
    }

    private func enhanceWithAI() {
        guard !eventTitle.isEmpty && !eventDescription.isEmpty else { return }

        isEnhancingWithAI = true

        Task {
            let enhanced = await aiAssistant.enhancePromptSeed(
                title: eventTitle,
                description: eventDescription,
                category: selectedCategory,
                ageRange: selectedAgeRange,
                tone: selectedTone
            )

            await MainActor.run {
                withAnimation {
                    promptSeed = enhanced
                    isEnhancingWithAI = false
                }
            }
        }
    }

    private func generateKeywordsWithAI() {
        guard !eventTitle.isEmpty && !eventDescription.isEmpty else { return }

        Task {
            let generatedKeywords = await aiAssistant.generateKeywords(
                for: eventTitle,
                description: eventDescription
            )

            await MainActor.run {
                withAnimation {
                    keywords = generatedKeywords
                }
            }
        }
    }

    // MARK: - Data Operations

    private func buildPreviewEvent() -> CustomStoryEvent {
        CustomStoryEvent(
            title: eventTitle.isEmpty
                   ? String(localized: "customEvent.creation.preview.newEvent",
                            comment: "Custom Event creation: Placeholder title shown in the live preview when no title has been entered.")
                   : eventTitle,
            description: eventDescription.isEmpty
                         ? String(localized: "customEvent.creation.preview.description",
                                  comment: "Custom Event creation: Placeholder description shown in the live preview when no description has been entered.")
                         : eventDescription,
            promptSeed: promptSeed.isEmpty ? eventDescription : promptSeed,
            category: selectedCategory,
            ageRange: selectedAgeRange,
            tone: selectedTone
        )
    }

    private func saveCustomEvent() {
        guard NetworkMonitor.shared.isConnected else {
            errorMessage = String(localized: "customEvent.creation.error.noNetwork",
                                  comment: "Custom Event creation: Error message shown when saving requires a network connection.")
            showingError = true
            return
        }

        isSaving = true

        let newEvent = CustomStoryEvent(
            title: eventTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            description: eventDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            promptSeed: promptSeed.isEmpty ? eventDescription : promptSeed,
            category: selectedCategory,
            ageRange: selectedAgeRange,
            tone: selectedTone
        )

        Task {
            do {
                let createdEvent = try await repository.createCustomEvent(newEvent)

                await MainActor.run {
                    isSaving = false
                    onEventCreated?(createdEvent)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = String(localized: "customEvent.creation.error.saveFailed",
                                          comment: "Custom Event creation: Error message shown when saving the event fails.") + ": \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Step Views

struct BasicInfoStepView: View {
    @Binding var title: String
    @Binding var description: String
    let onSuggestTitle: () -> Void

    private var exampleDescriptions: [String] {
        [
            String(localized: "customEvent.creation.step1.example1",
                   comment: "Custom Event creation step 1: Example description 1."),
            String(localized: "customEvent.creation.step1.example2",
                   comment: "Custom Event creation step 1: Example description 2."),
            String(localized: "customEvent.creation.step1.example3",
                   comment: "Custom Event creation step 1: Example description 3."),
            String(localized: "customEvent.creation.step1.example4",
                   comment: "Custom Event creation step 1: Example description 4.")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                        // BUG-26: decorative step-header icon.
                        .accessibilityHidden(true)

                    Text("customEvent.creation.step1.title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Title input
                VStack(alignment: .leading, spacing: 8) {
                    Label("customEvent.creation.step1.eventTitle", systemImage: "textformat")
                        .font(.headline)

                    HStack {
                        // BUG-24/30: title field gets the visible Label
                        // above it as its a11y label + autocorrect off so
                        // short identifier-style titles aren't mangled.
                        Group {
                            if #available(iOS 18.0, *) {
                                TextField("customEvent.creation.step1.eventTitlePlaceholder", text: $title)
                                    .textFieldStyle(.roundedBorder)
                                    .writingToolsBehavior(.disabled)
                            } else {
                                TextField("customEvent.creation.step1.eventTitlePlaceholder", text: $title)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .accessibilityLabel(Text("customEvent.creation.step1.eventTitle"))
                        .autocorrectionDisabled(true)

                        Button(action: onSuggestTitle) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                                // BUG-26: decorative — button carries an
                                // explicit accessibility label below.
                                .accessibilityHidden(true)
                        }
                        .buttonStyle(.bordered)
                        .disabled(description.isEmpty)
                        // BUG-26: replace the SF-symbol-name leak with a
                        // meaningful FR label. TODO: move to xcstrings.
                        .accessibilityLabel(Text(verbatim: "Suggérer un titre"))
                    }

                    Text("customEvent.creation.step1.eventTitleHint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Description input
                VStack(alignment: .leading, spacing: 8) {
                    Label("customEvent.creation.step1.description", systemImage: "text.alignleft")
                        .font(.headline)

                    if #available(iOS 18.0, *) {
                        TextEditor(text: $description)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .writingToolsBehavior(.complete)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    } else {
                        TextEditor(text: $description)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }

                    Text("customEvent.creation.step1.descriptionHint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Example prompts
                VStack(alignment: .leading, spacing: 8) {
                    Text("customEvent.creation.step1.inspiration")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(exampleDescriptions, id: \.self) { example in
                        Button(action: {
                            withAnimation {
                                description = example
                            }
                        }) {
                            HStack {
                                Image(systemName: "lightbulb")
                                    .font(.caption)
                                Text(example)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}

struct CategorizationStepView: View {
    @Binding var category: EventCategory
    @Binding var ageRange: AgeRange
    @Binding var tone: StoryTone

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "tag.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                        // BUG-26: decorative step-header icon.
                        .accessibilityHidden(true)

                    Text("customEvent.creation.step2.title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Category selection
                VStack(alignment: .leading, spacing: 12) {
                    Label("customEvent.creation.step2.category", systemImage: "folder")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(EventCategory.allCases, id: \.self) { cat in
                            CategoryButton(
                                category: cat,
                                isSelected: category == cat,
                                action: { category = cat }
                            )
                        }
                    }
                }

                // Age range selection
                VStack(alignment: .leading, spacing: 12) {
                    Label("customEvent.creation.step2.ageRange", systemImage: "person.2")
                        .font(.headline)

                    ForEach(AgeRange.allCases, id: \.self) { age in
                        AgeRangeButton(
                            ageRange: age,
                            isSelected: ageRange == age,
                            action: { ageRange = age }
                        )
                    }
                }

                // Tone selection
                VStack(alignment: .leading, spacing: 12) {
                    Label("customEvent.creation.step2.tone", systemImage: "waveform")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(StoryTone.allCases, id: \.self) { t in
                                ToneChip(
                                    tone: t,
                                    isSelected: tone == t,
                                    action: { tone = t }
                                )
                            }
                        }
                    }

                    Text(tone.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding()
        }
    }
}

struct AIEnhancementStepView: View {
    @Binding var promptSeed: String
    @Binding var keywords: [String]
    @Binding var newKeyword: String
    let isEnhancing: Bool
    let onEnhance: () -> Void
    let onGenerateKeywords: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                        // BUG-26: decorative step-header icon.
                        .accessibilityHidden(true)

                    Text("customEvent.creation.step3.title")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("customEvent.creation.step3.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Prompt seed
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("customEvent.creation.step3.prompt", systemImage: "text.bubble")
                            .font(.headline)

                        Spacer()

                        Button(action: onEnhance) {
                            if isEnhancing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Label("customEvent.creation.step3.enhance", systemImage: "sparkles")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isEnhancing)
                    }

                    if #available(iOS 18.0, *) {
                        TextEditor(text: $promptSeed)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .writingToolsBehavior(.complete)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    } else {
                        TextEditor(text: $promptSeed)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }

                    Text("customEvent.creation.step3.promptHint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Keywords
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("customEvent.creation.step3.keywords", systemImage: "tag")
                            .font(.headline)

                        Spacer()

                        Button(action: onGenerateKeywords) {
                            Label("customEvent.creation.step3.generate", systemImage: "sparkles")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    // Keyword input
                    HStack {
                        if #available(iOS 18.0, *) {
                            TextField("customEvent.creation.step3.addKeyword", text: $newKeyword)
                                .textFieldStyle(.roundedBorder)
                                .writingToolsBehavior(.disabled)
                                .onSubmit {
                                    if !newKeyword.isEmpty {
                                        withAnimation {
                                            keywords.append(newKeyword)
                                            newKeyword = ""
                                        }
                                    }
                                }
                        } else {
                            TextField("customEvent.creation.step3.addKeyword", text: $newKeyword)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !newKeyword.isEmpty {
                                        withAnimation {
                                            keywords.append(newKeyword)
                                            newKeyword = ""
                                        }
                                    }
                                }
                        }

                        Button(action: {
                            if !newKeyword.isEmpty {
                                withAnimation {
                                    keywords.append(newKeyword)
                                    newKeyword = ""
                                }
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange)
                                // BUG-26: decorative — button has label below.
                                .accessibilityHidden(true)
                        }
                        .disabled(newKeyword.isEmpty)
                        // BUG-26: replace SF-symbol leak with FR label.
                        // TODO: move to xcstrings.
                        .accessibilityLabel(Text(verbatim: "Ajouter le mot-clé"))
                    }

                    // Keyword chips
                    if !keywords.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(keywords, id: \.self) { keyword in
                                    CreationKeywordChip(
                                        keyword: keyword,
                                        onDelete: {
                                            withAnimation {
                                                keywords.removeAll { $0 == keyword }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    } else {
                        Text("customEvent.creation.step3.noKeywords")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding()
        }
    }
}

struct PreviewStepView: View {
    let event: CustomStoryEvent
    let pictogramImage: UIImage?
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        // BUG-26: decorative step-header icon.
                        .accessibilityHidden(true)

                    Text("customEvent.creation.step4.title")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top)

                // Event preview card
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    HStack {
                        Image(systemName: event.iconName)
                            .font(.title2)
                            .foregroundColor(.orange)

                        Text(event.title)
                            .font(.title3)
                            .fontWeight(.bold)

                        Spacer()
                    }

                    Divider()

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        CreationDetailRow(
                            icon: "text.alignleft",
                            label: String(localized: "customEvent.creation.step4.description",
                                          comment: "Custom Event creation step 4 (review): Description field label."),
                            value: event.description
                        )

                        CreationDetailRow(
                            icon: "folder",
                            label: String(localized: "customEvent.creation.step4.category",
                                          comment: "Custom Event creation step 4 (review): Category field label."),
                            value: event.eventCategory.displayName
                        )

                        CreationDetailRow(
                            icon: "person.2",
                            label: String(localized: "customEvent.creation.step4.ageRange",
                                          comment: "Custom Event creation step 4 (review): Age range field label."),
                            // Route through the enum's localizedName so the
                            // review step shows "Tous âges" in FR rather than
                            // the raw English rawValue. See Task #81.
                            value: event.eventAgeRange?.localizedName
                                ?? String(localized: "customEvent.creation.step4.allAges",
                                          comment: "Custom Event creation step 4 (review): Fallback value shown when no age range is selected.")
                        )

                        CreationDetailRow(
                            icon: "waveform",
                            label: String(localized: "customEvent.creation.step4.tone",
                                          comment: "Custom Event creation step 4 (review): Story tone field label."),
                            value: event.storyTone.localizedName
                        )

                        if !event.keywords.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("customEvent.creation.step4.keywords", systemImage: "tag")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(event.keywords.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    // Prompt preview
                    VStack(alignment: .leading, spacing: 8) {
                        Label("customEvent.creation.step4.prompt", systemImage: "text.bubble")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(event.promptSeed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

                // Ready message
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundColor(.orange)

                    Text("customEvent.creation.step4.ready")
                        .font(.headline)

                    Text("customEvent.creation.step4.readyMessage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .padding()
        }
    }
}

// MARK: - Supporting Views

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                RoundedRectangle(cornerRadius: 4)
                    .fill(step <= currentStep ? Color.orange : Color(.systemGray4))
                    .frame(height: 6)
                    .animation(.easeInOut, value: currentStep)
            }
        }
    }
}

struct CategoryButton: View {
    let category: EventCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.orange.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AgeRangeButton: View {
    let ageRange: AgeRange
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .orange : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    // BUG-L10N-82: rawValue is the English API identifier
                    // ("All Ages"). Use localizedName so the creation picker
                    // renders "Tous âges" in FR instead of leaking English.
                    Text(ageRange.localizedName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .medium : .regular)

                    Text(String(format: String(localized: "customEvent.creation.step2.ages %lld %lld",
                                               comment: "Custom Event creation step 2: Ages range caption. %1$lld is min age, %2$lld is max age."),
                                ageRange.minAge, ageRange.maxAge))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? Color.orange.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ToneChip: View {
    let tone: StoryTone
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tone.localizedName)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

struct CreationKeywordChip: View {
    let keyword: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(keyword)
                .font(.caption)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(15)
    }
}

struct CreationDetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.subheadline)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

struct CustomEventCreationView_Previews: PreviewProvider {
    static var previews: some View {
        CustomEventCreationView()
    }
}
