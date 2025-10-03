//
//  SettingsView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 10/09/2025.
//

import SwiftUI
import SwiftData

extension Notification.Name {
    static let aiServiceChanged = Notification.Name("aiServiceChanged")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @StateObject private var settings = AppSettings()
    @EnvironmentObject private var themeSettings: ThemeSettings
    
    @State private var showingSuccess = false
    @State private var showingEraseConfirmation = false
    @State private var showingEraseComplete = false
    
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
                            Text("Configure app settings")
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
                
                // Story Preferences Section
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
                        Text("Voice selection uses enhanced text-to-speech with storytelling instructions. Coral and Fable are recommended for bedtime stories.")
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
                        // Backend Selection Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Use Firebase Backend", isOn: Binding(
                                get: { AIServiceFactory.useFirebaseBackend },
                                set: { newValue in
                                    AIServiceFactory.enableFirebaseBackend(newValue)
                                    // Post notification for any active services to refresh
                                    NotificationCenter.default.post(name: .aiServiceChanged, object: nil)
                                }
                            ))

                            Text("Current: \(AIServiceFactory.currentServiceName)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Switch between Supabase Edge Functions and Firebase Cloud Functions. This is for migration testing purposes.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)

                        Divider()

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
                        Text("Backend selection allows gradual migration testing. Erasing all data will permanently delete all heroes and stories.")
                            .font(.caption)
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
            
            // Clear settings
            
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

#Preview {
    SettingsView()
        .environmentObject(ThemeSettings.shared)
}
