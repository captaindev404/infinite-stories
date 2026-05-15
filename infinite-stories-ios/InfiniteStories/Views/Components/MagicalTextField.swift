//
//  MagicalTextField.swift
//  InfiniteStories
//
//  Reusable magical text field component with animated gradient borders
//

import SwiftUI

/// BUG-24/26/29/30: Centralized text input so every call site gets
/// accessibility labels, correct text content type, autocorrect disabled
/// where needed, autocapitalization, and the decorative icon hidden from
/// VoiceOver — fixing SF-symbol-names-leak-as-a11y-label, password-manager
/// hijack and identifier autocorrect issues in one place.
struct MagicalTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType

    /// Explicit VoiceOver label. When nil, we fall back to the placeholder
    /// so at least something readable is announced (still better than the
    /// raw SF Symbol name iOS auto-translates into French nonsense).
    var accessibilityLabel: String? = nil

    /// Maps to `.textContentType(_:)`. Use `.password` for sign-in, `.newPassword`
    /// for sign-up so iOS doesn't hijack the field with a strong-password prompt
    /// on existing accounts (BUG-29).
    var textContentType: UITextContentType? = nil

    /// When true, the field disables autocorrection. Required on emails,
    /// passwords and identifier-like fields where autocorrect mangles input
    /// (BUG-30: `test@example.com` -> `test2exq,plz:co,`).
    var autocorrectionDisabled: Bool = false

    /// Autocapitalization behavior. `.never` for emails/passwords, `.words`
    /// for names (hero name capitalizes each word like a proper noun).
    var textInputAutocapitalization: TextInputAutocapitalization? = nil

    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isEditing ? .accentColor : .secondary)
                .frame(width: 25)
                // BUG-26: icon is purely decorative — never let VoiceOver
                // announce the raw SF Symbol name.
                .accessibilityHidden(true)

            if isSecure {
                secureFieldView
            } else {
                plainFieldView
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

    // MARK: - Inner field builders

    @ViewBuilder
    private var secureFieldView: some View {
        Group {
            if #available(iOS 18.0, *) {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .writingToolsBehavior(.disabled)
                    .onTapGesture { isEditing = true }
            } else {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onTapGesture { isEditing = true }
            }
        }
        .modifier(
            SharedTextFieldModifiers(
                accessibilityLabel: accessibilityLabel ?? placeholder,
                // BUG-A20: SecureField must never announce its content to
                // VoiceOver. Force an empty AXValue so the placeholder does
                // not leak as the spoken value.
                accessibilityValue: "",
                textContentType: textContentType,
                autocorrectionDisabled: autocorrectionDisabled,
                textInputAutocapitalization: textInputAutocapitalization
            )
        )
    }

    @ViewBuilder
    private var plainFieldView: some View {
        Group {
            if #available(iOS 18.0, *) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .keyboardType(keyboardType)
                    .writingToolsBehavior(.disabled)
                    .onTapGesture { isEditing = true }
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .keyboardType(keyboardType)
                    .onTapGesture { isEditing = true }
            }
        }
        .modifier(
            SharedTextFieldModifiers(
                accessibilityLabel: accessibilityLabel ?? placeholder,
                // BUG-A20: Explicit AXValue that reflects actual text (empty
                // when nothing typed) instead of letting SwiftUI fall back to
                // the placeholder string.
                accessibilityValue: text,
                textContentType: textContentType,
                autocorrectionDisabled: autocorrectionDisabled,
                textInputAutocapitalization: textInputAutocapitalization
            )
        )
    }
}

/// Shared suite of modifiers so TextField and SecureField branches stay in
/// lockstep without duplicating every single `.textContentType` /
/// `.autocorrectionDisabled` / `.accessibilityLabel` line.
private struct SharedTextFieldModifiers: ViewModifier {
    let accessibilityLabel: String
    let accessibilityValue: String
    let textContentType: UITextContentType?
    let autocorrectionDisabled: Bool
    let textInputAutocapitalization: TextInputAutocapitalization?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .textContentType(textContentType)
            .autocorrectionDisabled(autocorrectionDisabled)
            .textInputAutocapitalization(textInputAutocapitalization)
    }
}

#Preview {
    @Previewable @State var text = ""
    VStack(spacing: 16) {
        MagicalTextField(
            icon: "envelope",
            placeholder: "Email",
            text: $text,
            isSecure: false,
            keyboardType: .emailAddress,
            accessibilityLabel: "E-mail",
            textContentType: .emailAddress,
            autocorrectionDisabled: true,
            textInputAutocapitalization: .never
        )
        MagicalTextField(
            icon: "lock",
            placeholder: "Password",
            text: $text,
            isSecure: true,
            keyboardType: .default,
            accessibilityLabel: "Mot de passe",
            textContentType: .password,
            autocorrectionDisabled: true,
            textInputAutocapitalization: .never
        )
    }
    .padding()
}
