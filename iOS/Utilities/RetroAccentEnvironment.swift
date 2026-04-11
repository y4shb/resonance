//
//  RetroAccentEnvironment.swift
//  Resonance
//
//  Custom SwiftUI environment key that propagates the dynamic accent color
//  (extracted from the current song's album artwork) to every view in the
//  hierarchy. Falls back to ResonanceColors.accent when no song is playing.
//

import SwiftUI

// MARK: - Environment Key

private struct RetroAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = ResonanceColors.accent
}

extension EnvironmentValues {
    /// The current retro accent color, derived from album artwork.
    /// Falls back to `ResonanceColors.accent` (periwinkle #5A8CFF).
    var retroAccentColor: Color {
        get { self[RetroAccentColorKey.self] }
        set { self[RetroAccentColorKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Injects the dynamic retro accent color into the environment.
    /// Call this at the root view (MainView) to propagate to all children.
    func retroAccentColor(_ color: Color?) -> some View {
        environment(\.retroAccentColor, color ?? ResonanceColors.accent)
    }
}
