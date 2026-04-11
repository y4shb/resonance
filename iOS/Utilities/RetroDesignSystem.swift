//
//  RetroDesignSystem.swift
//  Resonance
//
//  Shared animation constants and haptic patterns for retro-tech controls.
//  Every retro component references these values for consistent feel.
//

import SwiftUI

// MARK: - Retro Animations

enum RetroAnimation {
    /// VU meter needle overshoot-then-settle.
    static let needleBounce = Spring(response: 0.4, dampingRatio: 0.5)

    /// Rotary knob snap to detent.
    static let knobRotation = Spring(response: 0.2, dampingRatio: 0.8)

    /// Toggle switch throw.
    static let switchFlip = Spring(response: 0.15, dampingRatio: 0.7)

    /// Push button press/release travel.
    static let buttonPress = Spring(response: 0.1, dampingRatio: 0.6)

    /// Screen transition (cassette tray slide).
    static let traySlide = Spring(response: 0.35, dampingRatio: 0.85)

    /// LED on/off state change.
    static let ledFade = Animation.easeInOut(duration: 0.3)
}

// MARK: - Retro Dimensions

enum RetroDimensions {
    /// Standard button press depth in points.
    static let buttonPressDepth: CGFloat = 3

    /// Button proud height above surface.
    static let buttonProudHeight: CGFloat = 4

    /// Rocker switch rotation angle in degrees.
    static let switchRotationAngle: Double = 15

    /// Standard corner screw diameter.
    static let screwDiameter: CGFloat = 6

    /// Standard LED indicator diameter.
    static let ledDefaultSize: CGFloat = 8
}
