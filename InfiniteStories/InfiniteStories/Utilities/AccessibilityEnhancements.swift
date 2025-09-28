//
//  AccessibilityEnhancements.swift
//  InfiniteStories
//
//  Core accessibility utilities and enhancements for better user experience
//

import SwiftUI

// MARK: - Accessible Colors with WCAG AA Compliance
struct AccessibleColors {
    // Primary text: minimum 7:1 contrast ratio
    static let primaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark 
            ? UIColor(white: 0.95, alpha: 1.0)  // #F2F2F2
            : UIColor(white: 0.15, alpha: 1.0)  // #262626
    })
    
    // Secondary text: minimum 4.5:1 contrast ratio
    static let secondaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.75, alpha: 1.0)  // #BFBFBF
            : UIColor(white: 0.35, alpha: 1.0)  // #595959
    })
    
    // Card shadows for better separation
    static let cardShadow = Color.black.opacity(0.15) // Increased from 0.08
    static let cardBorder = Color.primary.opacity(0.12) // Add subtle border
    
    // Accent colors with proper contrast
    static let accessibleAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0)  // Lighter purple
            : UIColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 1.0)  // Darker purple
    })
}

// MARK: - Accessible Sizes
struct AccessibleSizes {
    // Touch targets for different user groups
    static let minTouchTarget: CGFloat = 44  // iOS minimum
    static let childTouchTarget: CGFloat = 56  // Better for children
    static let comfortableTouchTarget: CGFloat = 48  // Recommended default
    
    // Card dimensions
    static let miniCardMinHeight: CGFloat = 88  // Increased from current
    static let cardSpacing: CGFloat = 16  // Increased from 12pt
    static let cardPadding: CGFloat = 20  // Increased from 15pt
    
    // Interactive elements
    static let iconContainerSize: CGFloat = 56  // Up from 45pt
    static let actionButtonSize: CGFloat = 48
}

// MARK: - Accessible Card Style
struct AccessibleCardStyle {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    static func cardBackground(for colorScheme: ColorScheme, reduceTransparency: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(reduceTransparency ? Color(.systemBackground) : Color(.systemBackground).opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        colorScheme == .dark 
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.3)
                    : Color.black.opacity(0.12),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

// MARK: - Accessible Interaction Modifier
struct AccessibleInteractionModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    @State private var isPressed: Bool = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : (isFocused ? 1.02 : 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isFocused ? Color.blue : Color.clear,
                        lineWidth: 3
                    )
            )
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
            .focusable()
            .focused($isFocused)
            .onTapGesture {
                // Haptic feedback with intensity based on action
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            }
            .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }, perform: {})
    }
}

// MARK: - Accessibility Label Provider
struct AccessibilityLabelProvider {
    static func storyCardLabel(for story: Story) -> String {
        var components: [String] = [story.title]
        
        if story.isFavorite {
            components.append("Favorite")
        }
        
        components.append("Event: \(story.eventTitle)")
        components.append(story.hasAudio ? "Has audio" : "Text only")
        
        if story.hasAudio {
            let minutes = Int(story.estimatedDuration / 60)
            components.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        
        if story.playCount > 0 {
            components.append("Played \(story.playCount) time\(story.playCount == 1 ? "" : "s")")
        }
        
        return components.joined(separator: ", ")
    }
    
    static func storyCardHint(for story: Story) -> String {
        if story.hasAudio {
            return "Double tap to play audio. Actions available in rotor."
        } else {
            return "Double tap to read story. Actions available in rotor."
        }
    }
    
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}

// MARK: - Dynamic Type Support
struct AccessibleTypography {
    // Use semantic font styles that scale with Dynamic Type
    static let cardTitle = Font.headline  // Scales automatically
    static let cardBody = Font.subheadline
    static let metadata = Font.caption
    
    // For custom sizes, use scaledValue
    static func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: UIFontMetrics.default.scaledValue(for: size))
            .weight(weight)
    }
}

// MARK: - Motion Aware Modifier
struct MotionAwareModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let value: V
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.7), value: value)
    }
}

// MARK: - Accessible Card Button Style
struct AccessibleCardButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Voice Control Extensions
extension View {
    func voiceControlOptimized(label: String, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityInputLabels([label, createShortLabel(from: label)])
            .onTapGesture(perform: action)
    }
}

private func createShortLabel(from label: String) -> String {
    // Create a shorter version for voice control
    let words = label.components(separatedBy: " ")
    if words.count > 2 {
        return words.prefix(2).joined(separator: " ")
    }
    return label
}

// MARK: - High Contrast Mode Detector
struct HighContrastKey: EnvironmentKey {
    static let defaultValue: Bool = UIAccessibility.isDarkerSystemColorsEnabled
}

extension EnvironmentValues {
    var isHighContrastEnabled: Bool {
        get { self[HighContrastKey.self] }
        set { self[HighContrastKey.self] = newValue }
    }
}

// MARK: - Focus Management Helper
struct FocusableCard: ViewModifier {
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isFocused ? Color.blue : Color.clear,
                        lineWidth: 3
                    )
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            )
    }
}

extension View {
    func accessibleCard() -> some View {
        modifier(FocusableCard())
    }
    
    func accessibleInteraction(action: @escaping () -> Void) -> some View {
        modifier(AccessibleInteractionModifier(action: action))
    }
    
    func motionAware<V: Equatable>(value: V) -> some View {
        modifier(MotionAwareModifier(value: value))
    }
}