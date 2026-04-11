//
//  GlassNavigationStyle.swift
//  InfiniteStories
//
//  Navigation styling for Liquid Glass design system.
//  Provides glass effects for tab bars, toolbars, and navigation bars on iOS 26+.
//

import SwiftUI

// MARK: - Glass Navigation Modifier

/// Applies glass styling to navigation elements on iOS 26+
struct GlassNavigationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
                .toolbarBackgroundVisibility(.visible, for: .tabBar)
        } else {
            content
        }
    }
}

// MARK: - Glass Tab Bar Modifier

/// Ensures tab bar uses glass styling on iOS 26+
struct GlassTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .toolbarBackgroundVisibility(.visible, for: .tabBar)
        } else {
            content
        }
    }
}

// MARK: - Glass Tab Morphing Modifier

/// Adds smooth morphing transitions between tab selections on iOS 26+.
///
/// NOTE (BUG-06/BUG-27): Previously this modifier applied an implicit
/// `.animation(.smooth(duration: 0.3), value: selectedTab)` to the entire
/// `TabView`. That caused SwiftUI to cross-fade the outgoing and incoming tab
/// hierarchies for ~0.3s, bleeding the previous tab's content on top of the
/// new tab (two headers, two sets of cards, and garbled accessibility trees).
/// The system `TabView` already handles its own selection transition, so this
/// modifier is intentionally a pass-through until a proper morph effect is
/// designed. Keeping the type preserves source compatibility with existing
/// call sites in `MainTabView`.
struct GlassTabMorphingModifier<Tab: Hashable>: ViewModifier {
    let namespace: Namespace.ID
    let selectedTab: Tab

    func body(content: Content) -> some View {
        content
    }
}

// MARK: - Glass Toolbar Modifier

/// Ensures navigation bar uses glass styling on iOS 26+
struct GlassToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        } else {
            content
        }
    }
}

// MARK: - Glass Sheet Modifier

/// Applies glass background to sheets and modals on iOS 26+
/// Ensures sheets fill the full width while respecting safe areas
struct GlassSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .presentationBackground(.regularMaterial)
        } else {
            content
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Glass Floating Button Style

/// A button style that applies floating glass appearance on iOS 26+
struct GlassFloatingButtonStyle: ButtonStyle {
    let size: CGFloat
    let tintColor: Color?

    init(size: CGFloat = 56, tintColor: Color? = nil) {
        self.size = size
        self.tintColor = tintColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .modifier(GlassFloatingButtonModifier(tintColor: tintColor))
    }
}

/// Internal modifier for floating button glass effect
private struct GlassFloatingButtonModifier: ViewModifier {
    let tintColor: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if let color = tintColor {
                content
                    .glassEffect(.regular.tint(color).interactive(), in: .circle)
            } else {
                content
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
            }
        } else {
            content
                .background(
                    Circle()
                        .fill(tintColor ?? .accentColor)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
                .foregroundStyle(.white)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies glass styling to navigation bars and tab bars on iOS 26+
    func glassNavigation() -> some View {
        modifier(GlassNavigationModifier())
    }

    /// Ensures tab bar uses glass styling on iOS 26+
    func glassTabBar() -> some View {
        modifier(GlassTabBarModifier())
    }

    /// Adds smooth morphing transitions between tab selections on iOS 26+
    func glassTabMorphing<Tab: Hashable>(namespace: Namespace.ID, selectedTab: Tab) -> some View {
        modifier(GlassTabMorphingModifier(namespace: namespace, selectedTab: selectedTab))
    }

    /// Ensures navigation bar uses glass styling on iOS 26+
    func glassToolbar() -> some View {
        modifier(GlassToolbarModifier())
    }

    /// Applies glass background to sheets on iOS 26+
    func glassSheet() -> some View {
        modifier(GlassSheetModifier())
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == GlassFloatingButtonStyle {
    /// A floating action button style with glass effect on iOS 26+
    static var glassFloating: GlassFloatingButtonStyle {
        GlassFloatingButtonStyle()
    }

    /// A floating action button style with custom size and tint
    static func glassFloating(size: CGFloat = 56, tintColor: Color? = nil) -> GlassFloatingButtonStyle {
        GlassFloatingButtonStyle(size: size, tintColor: tintColor)
    }
}

// MARK: - Preview

#if DEBUG
struct GlassNavigationStyle_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ZStack {
                // Background content
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Glass Navigation Demo")
                        .font(.title)

                    Text("The navigation bar and toolbar should have glass effects on iOS 26+")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()

                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            // Action
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                        }
                        .buttonStyle(.glassFloating)
                        .padding()
                    }
                }
            }
            .navigationTitle("Glass Demo")
            .glassNavigation()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Action") { }
                }
            }
        }
    }
}
#endif
