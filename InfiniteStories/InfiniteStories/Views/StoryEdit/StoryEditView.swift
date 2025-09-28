//
//  StoryEditView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData

struct StoryEditView: View {
    @Bindable var story: Story
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var editedTitle: String = ""
    @State private var editedContent: String = ""
    @State private var showingDiscardAlert = false
    @State private var hasChanges = false
    @State private var characterCount = 0
    @State private var wordCount = 0
    @State private var showingSaveConfirmation = false
    @State private var isSaving = false
    @State private var showingRegenerationView = false
    @State private var shouldRegenerateAudio = false
    
    @FocusState private var isTextEditorFocused: Bool
    
    private let maxCharacters = 10000
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Story Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TextField("Enter story title", text: $editedTitle)
                        .font(.title3.bold())
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .onChange(of: editedTitle) { _, _ in
                            hasChanges = true
                        }
                }
                .padding(.top)
                
                // Content editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Story Content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Character and word count
                        HStack(spacing: 12) {
                            Label("\(wordCount) words", systemImage: "text.word.spacing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Label("\(characterCount)/\(maxCharacters)", systemImage: "character.cursor.ibeam")
                                .font(.caption)
                                .foregroundColor(characterCount > maxCharacters ? .red : .secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Text editor with enhanced UI
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $editedContent)
                            .font(.system(.body, design: .serif))
                            .lineSpacing(4)
                            .padding(8)
                            .focused($isTextEditorFocused)
                            .scrollContentBackground(.hidden)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isTextEditorFocused ? Color.purple : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: editedContent) { _, newValue in
                                hasChanges = true
                                updateCounts()
                                
                                // Limit characters
                                if newValue.count > maxCharacters {
                                    editedContent = String(newValue.prefix(maxCharacters))
                                }
                            }
                        
                        // Placeholder text
                        if editedContent.isEmpty {
                            Text("Write your magical story here...")
                                .font(.system(.body, design: .serif))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Bottom toolbar with formatting hints
                VStack(spacing: 12) {
                    // Formatting tips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FormatTip(icon: "quote.opening", text: "Use quotes for dialogue")
                            FormatTip(icon: "paragraphsign", text: "Separate paragraphs")
                            FormatTip(icon: "sparkles", text: "Add descriptive details")
                            FormatTip(icon: "face.smiling", text: "Keep it engaging")
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 30)
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        // Auto-format button
                        Button(action: autoFormatContent) {
                            Label("Auto-Format", systemImage: "wand.and.stars")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        // Reading time estimate
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("\(estimatedReadingTime) min read")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Edit Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasChanges {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { saveChanges(regenerateAudio: false) }) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        Button(action: { saveChanges(regenerateAudio: true) }) {
                            Label("Save & Regenerate Audio", systemImage: "waveform")
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!hasChanges || isSaving || editedTitle.isEmpty || editedContent.isEmpty)
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Story Updated", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    if shouldRegenerateAudio {
                        showingRegenerationView = true
                    } else {
                        dismiss()
                    }
                }
            } message: {
                Text(shouldRegenerateAudio ?
                     "Your story has been saved. Audio generation will begin now." :
                     "Your story has been updated successfully. The audio will be regenerated using OpenAI when you play the story.")
            }
            .fullScreenCover(isPresented: $showingRegenerationView) {
                AudioRegenerationView(story: story) {
                    // On completion, dismiss both views
                    showingRegenerationView = false
                    dismiss()
                }
            }
            .onAppear {
                editedTitle = story.title
                editedContent = story.content
                updateCounts()
            }
            // Keyboard toolbar
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Done") {
                        isTextEditorFocused = false
                    }
                }
            }
        }
    }
    
    private func updateCounts() {
        characterCount = editedContent.count
        wordCount = editedContent.split(whereSeparator: \.isWhitespace).count
    }
    
    private var estimatedReadingTime: Int {
        // Average reading speed: 200 words per minute
        max(1, (wordCount + 199) / 200)
    }
    
    private func autoFormatContent() {
        // Add proper paragraph breaks
        var formatted = editedContent
        
        // Ensure dialogue has proper spacing
        formatted = formatted.replacingOccurrences(of: ".", with: ".\n\n")
            .replacingOccurrences(of: "!", with: "!\n\n")
            .replacingOccurrences(of: "?", with: "?\n\n")
        
        // Remove excessive line breaks
        while formatted.contains("\n\n\n") {
            formatted = formatted.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        // Trim whitespace
        formatted = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        
        editedContent = formatted
        updateCounts()
    }
    
    private func saveChanges(regenerateAudio: Bool = false) {
        isSaving = true
        shouldRegenerateAudio = regenerateAudio
        
        // Update story properties
        // The Story model will automatically mark audio for regeneration and delete old audio
        // when content or title changes (via didSet observers)
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only update if there are actual changes to trigger audio regeneration
        if story.title != trimmedTitle {
            story.title = trimmedTitle
        }
        if story.content != trimmedContent {
            story.content = trimmedContent
        }
        
        // Update last modified date
        story.lastModified = Date()
        
        // Save to database
        do {
            try modelContext.save()
            
            // Show confirmation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
                showingSaveConfirmation = true
            }
        } catch {
            print("Failed to save story edits: \(error)")
            isSaving = false
        }
    }
}

struct FormatTip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }
}

#Preview {
    let story = Story(
        title: "Luna's Magical Adventure",
        content: "Once upon a time in a magical forest, Luna the brave and magical hero discovered a secret that would change everything...",
        event: .bedtime,
        hero: Hero(name: "Luna", primaryTrait: .brave, secondaryTrait: .magical)
    )
    
    return StoryEditView(story: story)
        .modelContainer(for: Story.self, inMemory: true)
}