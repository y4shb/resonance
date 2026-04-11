//
//  ResonanceColors.swift
//  Resonance
//
//  Cross-platform color definitions shared across iOS, macOS, watchOS, and widgets.
//  Platform-specific extensions (UIColor-based dark mode helpers) live in
//  iOS/Utilities/ColorTheme.swift.
//

import SwiftUI

// MARK: - Resonance Color Palette (Cross-Platform)

/// Centralized color definitions available on every platform target.
/// iOS-only helpers that depend on UIColor live in iOS/Utilities/ColorTheme.swift
/// and extend this enum via conditional compilation.
enum ResonanceColors {
    // MARK: - Accent Color

    /// App accent color, consistent across light and dark modes.
    /// Custom periwinkle-blue for brand identity.
    static let accent = Color(red: 0.35, green: 0.55, blue: 1.0)

    // MARK: - Glass Surface Helpers

    /// Subtle tint overlay for glass card backgrounds
    static let glassTint = Color.white.opacity(0.06)

    /// Divider color for use on glass/material surfaces
    static let glassDivider = Color.white.opacity(0.12)

    /// Secondary accent for subtle highlights on glass surfaces
    static let accentSubtle = Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.6)

    // MARK: - LED Colors

    /// Warm amber LED for pause state, warning indicators.
    static let ledAmber = Color(red: 1.0, green: 0.702, blue: 0.278) // #FFB347

    /// Green LED for active/on state, signal present.
    static let ledGreen = Color(red: 0.290, green: 0.871, blue: 0.502) // #4ADE80

    /// Red LED for peak/clip indicators, errors.
    static let ledRed = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444

    // MARK: - Metal Surface Colors

    /// Brushed aluminum highlight.
    static let metalLight = Color(red: 0.753, green: 0.753, blue: 0.784) // #C0C0C8

    /// Metal surface mid-tone.
    static let metalMid = Color(red: 0.541, green: 0.541, blue: 0.580) // #8A8A94

    /// Panel recesses, button wells.
    static let metalDark = Color(red: 0.227, green: 0.227, blue: 0.259) // #3A3A42

    /// Corner screws, bezels.
    static let screwChrome = Color(red: 0.831, green: 0.831, blue: 0.863) // #D4D4DC

    /// Recessed panel interiors.
    static let panelBg = Color(red: 0.102, green: 0.102, blue: 0.133) // #1A1A22

    /// Horizontal grain texture overlay on metal surfaces.
    static let grainOverlay = Color.white.opacity(0.03)
}
