//
//  TestThemeView.swift
//  InfiniteStories
//
//  Test view to verify theme switching works correctly
//

import SwiftUI

struct TestThemeView: View {
    @EnvironmentObject var themeSettings: ThemeSettings
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Theme Test View")
                .font(.largeTitle)
                .padding()
            
            Text("Current Theme Preference: \(themeSettings.themePreferenceString)")
                .font(.headline)
            
            Text("Current Color Scheme: \(colorScheme == .dark ? "Dark" : "Light")")
                .font(.headline)
            
            HStack(spacing: 20) {
                Button("System") {
                    themeSettings.themePreferenceString = "system"
                }
                .buttonStyle(.borderedProminent)
                
                Button("Light") {
                    themeSettings.themePreferenceString = "light"
                }
                .buttonStyle(.borderedProminent)
                
                Button("Dark") {
                    themeSettings.themePreferenceString = "dark"
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 10) {
                HStack {
                    Text("Background Color:")
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .frame(width: 50, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                
                HStack {
                    Text("Secondary Background:")
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 50, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                
                HStack {
                    Text("Label Color:")
                    Spacer()
                    Text("Sample Text")
                        .foregroundColor(Color(.label))
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    TestThemeView()
        .environmentObject(ThemeSettings.shared)
}