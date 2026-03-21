//
//  MagicalTextField.swift
//  InfiniteStories
//
//  Reusable magical text field component with animated gradient borders
//

import SwiftUI

struct MagicalTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType

    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isEditing ? .accentColor : .secondary)
                .frame(width: 25)

            if isSecure {
                if #available(iOS 18.0, *) {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .writingToolsBehavior(.disabled)
                        .onTapGesture {
                            isEditing = true
                        }
                } else {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onTapGesture {
                            isEditing = true
                        }
                }
            } else {
                if #available(iOS 18.0, *) {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(keyboardType)
                        .writingToolsBehavior(.disabled)
                        .onTapGesture {
                            isEditing = true
                        }
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(keyboardType)
                        .onTapGesture {
                            isEditing = true
                        }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isEditing ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
            isEditing = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
            isEditing = false
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    VStack(spacing: 16) {
        MagicalTextField(icon: "envelope", placeholder: "Email", text: $text, isSecure: false, keyboardType: .emailAddress)
        MagicalTextField(icon: "lock", placeholder: "Password", text: $text, isSecure: true, keyboardType: .default)
    }
    .padding()
}
