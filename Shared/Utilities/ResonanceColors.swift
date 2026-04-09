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
}
