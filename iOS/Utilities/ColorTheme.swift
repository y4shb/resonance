//
//  ColorTheme.swift
//  Resonance
//
//  Defines the app-wide color palette with dark mode refinements.
//  Uses dark gray (#121212) instead of pure black to prevent OLED smearing,
//  and applies a blue undertone for a night-sky quality in dark mode.
//
//  P2-20: Dark Mode Palette Refinement
//

import SwiftUI

// MARK: - Resonance Color Palette

/// Centralized color definitions that adapt to light and dark mode.
/// Dark mode uses carefully chosen grays with blue undertones rather than pure
/// black, preventing OLED pixel smearing and reducing visual harshness.
enum ResonanceColors {
    // MARK: - Background Colors

    /// Primary background: #121212 in dark mode (soft dark gray), system background in light mode.
    static let background = Color("ResonanceBackground", bundle: nil)

    /// Secondary background: #1E1E2E in dark mode (dark with blue undertone), secondary system in light.
    static let secondaryBackground = Color("ResonanceSecondaryBackground", bundle: nil)

    /// Tertiary background: #2A2A3C in dark mode (lighter with blue undertone), tertiary system in light.
    static let tertiaryBackground = Color("ResonanceTertiaryBackground", bundle: nil)

    // MARK: - Adaptive Background Colors (Programmatic Fallback)

    /// Primary background that adapts to the current color scheme.
    /// Use this when asset catalog colors are not available.
    static func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x12 / 255.0) // #121212
        case .light:
            return Color(.systemBackground)
        @unknown default:
            return Color(.systemBackground)
        }
    }

    /// Secondary background with blue undertone in dark mode.
    static func adaptiveSecondaryBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0x1E / 255.0, green: 0x1E / 255.0, blue: 0x2E / 255.0) // #1E1E2E
        case .light:
            return Color(.secondarySystemBackground)
        @unknown default:
            return Color(.secondarySystemBackground)
        }
    }

    /// Tertiary background with blue undertone in dark mode.
    static func adaptiveTertiaryBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0x2A / 255.0, green: 0x2A / 255.0, blue: 0x3C / 255.0) // #2A2A3C
        case .light:
            return Color(.tertiarySystemBackground)
        @unknown default:
            return Color(.tertiarySystemBackground)
        }
    }

    // MARK: - Card Background

    /// Card background: a subtle translucent fill for glass-style containers.
    /// Uses secondary system grouped background in light mode, and a dark
    /// blue-tinted gray in dark mode for consistency with the app palette.
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    /// Card background that adapts to the current color scheme.
    /// Dark mode uses a blue-tinted dark gray; light mode uses the system grouped background.
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x2E / 255.0)
        case .light:
            return Color(.secondarySystemGroupedBackground)
        @unknown default:
            return Color(.secondarySystemGroupedBackground)
        }
    }

    // MARK: - Accent Color

    /// App accent color, consistent across light and dark modes.
    /// Custom periwinkle-blue for brand identity.
    static let accent = Color(red: 0.35, green: 0.55, blue: 1.0)

    // MARK: - Saturation Adjustment

    /// The saturation reduction factor applied to album art gradients in dark mode (15-20%).
    static let darkModeSaturationReduction = 0.17

    /// Adjusts the saturation of a Color by the given amount.
    ///
    /// A positive `amount` increases saturation; a negative `amount` decreases it.
    /// The resulting saturation is clamped to [0, 1].
    ///
    /// - Parameters:
    ///   - color: The input SwiftUI `Color`.
    ///   - amount: The adjustment delta (e.g., -0.17 reduces saturation by 17%).
    /// - Returns: A new `Color` with adjusted saturation.
    static func adjustSaturation(_ color: Color, by amount: Double) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return color
        }

        let adjustedSaturation = min(max(saturation + CGFloat(amount), 0), 1)
        return Color(UIColor(hue: hue, saturation: adjustedSaturation, brightness: brightness, alpha: alpha))
    }

    /// Reduces the saturation of a color for dark mode display.
    /// Applies a 15-20% reduction to prevent oversaturated gradients on dark backgrounds.
    ///
    /// - Parameters:
    ///   - color: The input color (typically extracted from album art).
    ///   - colorScheme: The current color scheme; reduction is only applied in dark mode.
    /// - Returns: The original color in light mode, or a desaturated variant in dark mode.
    static func darkModeAdjusted(_ color: Color, for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return adjustSaturation(color, by: -darkModeSaturationReduction)
        case .light:
            return color
        @unknown default:
            return color
        }
    }
}
