//
//  SettingsView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @StateObject private var settings = AppSettings()
    @EnvironmentObject private var themeSettings: ThemeSettings
    
    @State private var showingAPIKeyInfo = false
    @State private var tempAPIKey: String = ""
    @State private var showingSuccess = false
    @State private var showingEraseConfirmation = false
    @State private var showingEraseComplete = false
    @State private var showingRemoveAPIKeyConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "gear.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("InfiniteStories Settings")
                                .font(.headline)
                            Text("Configure AI story generation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Theme Settings Section
                Section {
                    HStack {
                        Label("Appearance", systemImage: "moon.circle.fill")
                            .foregroundColor(.purple)
                        
                        Spacer()
                        
                        Picker("", selection: $themeSettings.themePreferenceString) {
                            ForEach(["system", "light", "dark"], id: \.self) { theme in
                                HStack {
                                    Image(systemName: themeIcon(for: theme))
                                    Text(theme.capitalized)
                                }
                                .tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.purple)
                    }
                    
                    // Visual indicator showing current theme
                    HStack {
                        Text("Current Mode:")
                        Spacer()
                        Text(colorScheme == .dark ? "Dark" : "Light")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Theme")
                } footer: {
                    Text("Choose your preferred appearance or let it follow your system settings.")
                        .font(.caption)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("OpenAI API Key")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: { showingAPIKeyInfo = true }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if settings.hasValidAPIKey {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API key configured")
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Button("Update") {
                                    tempAPIKey = settings.openAIAPIKey
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("AI story generation disabled")
                                        .foregroundColor(.orange)
                                        .font(.subheadline)
                                }
                                
                                SecureField("sk-...", text: $tempAPIKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                
                                Button(action: saveAPIKey) {
                                    Text("Save API Key")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(tempAPIKey.isEmpty ? Color.gray : Color.green)
                                        .cornerRadius(10)
                                }
                                .disabled(tempAPIKey.isEmpty)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("AI Configuration")
                } footer: {
                    Text("An OpenAI API key is required to generate new stories. Without it, the app will use sample stories only.")
                        .font(.caption)
                }
                
                if settings.hasValidAPIKey {
                    Section {
                        HStack {
                            Picker("Story Length", selection: $settings.defaultStoryLength) {
                                Text("5 minutes").tag(5)
                                Text("7 minutes").tag(7)
                                Text("10 minutes").tag(10)
                            }
                            .pickerStyle(.menu)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Picker("Voice", selection: $settings.preferredVoice) {
                                    ForEach(AppSettings.availableVoices, id: \.id) { voice in
                                        Text(voice.name).tag(voice.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            if let selectedVoice = AppSettings.availableVoices.first(where: { $0.id == settings.preferredVoice }) {
                                Text(selectedVoice.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Picker("Language", selection: $settings.preferredLanguage) {
                                    ForEach(AppSettings.availableLanguages, id: \.id) { language in
                                        HStack {
                                            Text(language.name)
                                            Text(language.nativeName)
                                                .foregroundColor(.secondary)
                                        }
                                        .tag(language.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Text("Stories will be generated in the selected language")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Story Preferences")
                    } footer: {
                        Text("Voice selection uses OpenAI's enhanced text-to-speech with storytelling instructions. Coral and Fable are recommended for bedtime stories.")
                            .font(.caption)
                    }
                    
                    Section {
                        Toggle("Auto-Generate Illustrations", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "autoGenerateIllustrations") },
                            set: { UserDefaults.standard.set($0, forKey: "autoGenerateIllustrations") }
                        ))

                        Toggle("Continue on Illustration Failures", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "allowIllustrationFailures") },
                            set: { UserDefaults.standard.set($0, forKey: "allowIllustrationFailures") }
                        ))

                        Toggle("Show Error Details", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "showIllustrationErrors") },
                            set: { UserDefaults.standard.set($0, forKey: "showIllustrationErrors") }
                        ))

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Max Retry Attempts")
                                Spacer()
                                Picker("Retries", selection: Binding(
                                    get: {
                                        let value = UserDefaults.standard.integer(forKey: "maxIllustrationRetries")
                                        return value > 0 ? value : 3
                                    },
                                    set: { UserDefaults.standard.set($0, forKey: "maxIllustrationRetries") }
                                )) {
                                    Text("1").tag(1)
                                    Text("2").tag(2)
                                    Text("3").tag(3)
                                    Text("5").tag(5)
                                }
                                .pickerStyle(.menu)
                            }

                            Text("Number of automatic retry attempts for failed illustrations")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Max Illustrations Per Story")
                            Spacer()
                            Picker("Max", selection: Binding(
                                get: {
                                    let value = UserDefaults.standard.integer(forKey: "maxIllustrationsPerStory")
                                    return value > 0 ? value : 6
                                },
                                set: { UserDefaults.standard.set($0, forKey: "maxIllustrationsPerStory") }
                            )) {
                                Text("5").tag(5)
                                Text("6").tag(6)
                                Text("7").tag(7)
                                Text("8").tag(8)
                            }
                            .pickerStyle(.menu)
                        }
                    } header: {
                        Text("Illustrations")
                    } footer: {
                        Text("Illustrations enhance stories with AI-generated visuals. If generation fails, placeholders will be shown. You can retry failed illustrations later.")
                            .font(.caption)
                    }

                    Section {
                        Button(action: { showingRemoveAPIKeyConfirmation = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove API Key")
                            }
                            .foregroundColor(.red)
                        }

                        Button(action: { showingEraseConfirmation = true }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Erase All Data")
                            }
                            .foregroundColor(.red)
                        }
                    } header: {
                        Text("Advanced")
                    } footer: {
                        Text("Removing the API key will disable AI story generation. Erasing all data will permanently delete all heroes and stories.")
                            .font(.caption)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("About InfiniteStories")
                            .font(.headline)
                        
                        Text("Generate personalized bedtime stories for children using AI. Create heroes with unique traits and enjoy magical adventures every night.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("App Info")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAPIKeyInfo) {
                APIKeyInfoView()
            }
            .alert("API Key Saved!", isPresented: $showingSuccess) {
                Button("OK") { }
            } message: {
                Text("Your OpenAI API key has been saved securely. You can now generate AI-powered stories!")
            }
            .confirmationDialog("Remove API Key?", isPresented: $showingRemoveAPIKeyConfirmation, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    clearAPIKey()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will disable AI story generation. You can add a new API key anytime.")
            }
            .confirmationDialog("Erase All Data?", isPresented: $showingEraseConfirmation, titleVisibility: .visible) {
                Button("Erase Everything", role: .destructive) {
                    eraseAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all heroes, stories, and audio files. This action cannot be undone.")
            }
            .alert("Data Erased", isPresented: $showingEraseComplete) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("All heroes, stories, and audio files have been permanently deleted.")
            }
        }
        .onAppear {
            tempAPIKey = settings.openAIAPIKey
        }
    }
    
    private func saveAPIKey() {
        settings.openAIAPIKey = tempAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        showingSuccess = true
        tempAPIKey = ""
    }
    
    private func clearAPIKey() {
        settings.openAIAPIKey = ""
        tempAPIKey = ""
    }
    
    private func eraseAllData() {
        do {
            // Delete all Hero objects
            try modelContext.delete(model: Hero.self)
            
            // Delete all Story objects
            try modelContext.delete(model: Story.self)
            
            // Save the deletion
            try modelContext.save()
            
            // Delete all audio files from Documents directory
            let fileManager = FileManager.default
            if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let audioPath = documentsPath.appendingPathComponent("AudioStories")
                if fileManager.fileExists(atPath: audioPath.path) {
                    try fileManager.removeItem(at: audioPath)
                }
                
                // Also check for any MP3 files in the root documents directory
                let contents = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                for file in contents {
                    if file.pathExtension == "mp3" {
                        try fileManager.removeItem(at: file)
                    }
                }
            }
            
            // Clear API key and settings
            settings.openAIAPIKey = ""
            tempAPIKey = ""
            
            // Reset theme to system default
            themeSettings.themePreferenceString = "system"
            
            // Show completion
            showingEraseComplete = true
            
        } catch {
            print("Failed to erase all data: \(error)")
        }
    }
    
    private func themeIcon(for theme: String) -> String {
        switch theme {
        case "system":
            return "circle.lefthalf.filled"
        case "light":
            return "sun.max.fill"
        case "dark":
            return "moon.fill"
        default:
            return "circle.lefthalf.filled"
        }
    }

}

struct APIKeyInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How to get your OpenAI API Key")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Follow these steps to get your API key:")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        APIKeyStep(
                            number: "1",
                            title: "Visit OpenAI",
                            description: "Go to platform.openai.com and sign up or log in to your account."
                        )
                        
                        APIKeyStep(
                            number: "2", 
                            title: "Navigate to API Keys",
                            description: "In your dashboard, go to the API section and click on 'API Keys'."
                        )
                        
                        APIKeyStep(
                            number: "3",
                            title: "Create New Key",
                            description: "Click 'Create new secret key' and give it a name like 'InfiniteStories'."
                        )
                        
                        APIKeyStep(
                            number: "4",
                            title: "Copy and Paste",
                            description: "Copy the generated key (starts with 'sk-') and paste it in the settings above."
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Important Notes:")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("• Your API key is stored securely on your device only")
                        Text("• OpenAI charges per story generated (usually $0.01-0.05)")
                        Text("• Keep your API key private - don't share it with others")
                        Text("• You can revoke or regenerate keys anytime on OpenAI's website")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("API Key Help")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct APIKeyStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.purple)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeSettings.shared)
}
