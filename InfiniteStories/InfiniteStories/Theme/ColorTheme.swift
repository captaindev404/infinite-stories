//
//  ColorTheme.swift
//  InfiniteStories
//
//  Theme colors that adapt to light/dark mode
//

import SwiftUI

struct ColorTheme {
    @Environment(\.colorScheme) private var colorScheme
    
    static let shared = ColorTheme()
    
    // MARK: - Primary Colors
    static let primary = Color("PrimaryColor")
    static let secondary = Color("SecondaryColor")
    static let accent = Color("AccentColor")
    
    // MARK: - Background Colors
    static let background = Color("BackgroundColor")
    static let secondaryBackground = Color("SecondaryBackgroundColor")
    static let cardBackground = Color("CardBackgroundColor")
    
    // MARK: - Text Colors
    static let primaryText = Color("PrimaryTextColor")
    static let secondaryText = Color("SecondaryTextColor")
    static let tertiaryText = Color("TertiaryTextColor")
    
    // MARK: - Semantic Colors
    static let success = Color("SuccessColor")
    static let warning = Color("WarningColor")
    static let error = Color("ErrorColor")
    static let info = Color("InfoColor")
    
    // MARK: - Special Colors for Magical UI
    static let magicalPrimary = Color("MagicalPrimaryColor")
    static let magicalSecondary = Color("MagicalSecondaryColor")
    static let heroCardStart = Color("HeroCardStartColor")
    static let heroCardEnd = Color("HeroCardEndColor")
    static let sparkle = Color("SparkleColor")
}
