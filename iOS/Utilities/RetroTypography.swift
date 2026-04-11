//
//  RetroTypography.swift
//  Resonance
//
//  Monospaced font scale for retro-tech UI elements.
//  All retro text uses monospaced design. System fonts preserved
//  for accessibility-critical text (error messages, long descriptions).
//

import SwiftUI

// MARK: - Retro Typography

enum RetroTypography {
    /// Screen titles in LCD panels. 14pt semibold monospaced.
    static let lcdTitle: Font = .system(size: 14, weight: .semibold, design: .monospaced)

    /// Readout values, counters. 11pt medium monospaced.
    static let lcdBody: Font = .system(size: 11, weight: .medium, design: .monospaced)

    /// Labels, secondary info. 9pt regular monospaced.
    static let lcdCaption: Font = .system(size: 9, weight: .regular, design: .monospaced)

    /// Embossed panel labels. 8pt heavy monospaced with wide tracking.
    static let engraved: Font = .system(size: 8, weight: .heavy, design: .monospaced)

    /// Tracking value for engraved text (3pt).
    static let engravedTracking: CGFloat = 3

    /// Large numeric readouts. 16pt bold monospaced.
    static let ledDigit: Font = .system(size: 16, weight: .bold, design: .monospaced)
}

// MARK: - View Extension

extension View {
    /// Applies engraved label styling: heavy monospaced with wide tracking, secondary foreground.
    func retroEngravedLabel() -> some View {
        self
            .font(RetroTypography.engraved)
            .tracking(RetroTypography.engravedTracking)
            .foregroundStyle(.secondary)
    }
}
