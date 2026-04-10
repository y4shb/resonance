//
//  VinylConstants.swift
//  Resonance
//
//  Central configuration for all vinyl record player UI constants.
//  Sizing, angles, speeds, colors, and animation parameters.
//

import SwiftUI

enum VinylConstants {
    // MARK: - Record Sizing

    /// Full turntable record diameter on Now Playing screen
    static let recordDiameterLarge: CGFloat = 300

    /// Mini player spinning record diameter
    static let recordDiameterMini: CGFloat = 36

    /// Carousel record sleeve card size
    static let recordDiameterCarousel: CGFloat = 200

    /// Album art label diameter as ratio of record diameter
    static let labelRatio: CGFloat = 0.40

    /// Center spindle diameter as ratio of record diameter
    static let spindleRatio: CGFloat = 0.025

    // MARK: - Groove Rendering

    /// Number of concentric groove rings rendered via Canvas
    static let grooveCount: Int = 80

    /// Stroke width of each groove ring
    static let grooveStrokeWidth: CGFloat = 0.5

    /// Base opacity for even-numbered groove rings
    static let grooveBaseOpacity: Double = 0.03

    /// Slightly brighter opacity for odd-numbered groove rings
    static let grooveAlternateOpacity: Double = 0.06

    /// Additional opacity boost on the upper-left specular highlight arc
    static let specularBoost: Double = 0.02

    /// Simplified groove count for mini player (fewer rings at small size)
    static let grooveCountMini: Int = 12

    // MARK: - Tonearm Angles (degrees)

    /// Tonearm resting position (parked outside the record)
    static let tonearmRestingAngle: Double = -27

    /// Tonearm angle at the outer groove (start of track, progress = 0)
    static let tonearmOuterGrooveAngle: Double = 0

    /// Tonearm angle at the inner groove (end of track, progress = 1)
    static let tonearmInnerGrooveAngle: Double = 22

    /// Pivot anchor point for tonearm rotation (upper-right bearing)
    static let tonearmPivot = UnitPoint(x: 0.85, y: 0.08)

    // MARK: - Animation

    /// Spring animation for tonearm play/pause sweep
    static let tonearmSpring = Animation.spring(response: 0.8, dampingFraction: 0.7)

    /// Vinyl rotation speed in RPM (33 1/3 standard)
    static let rpm: Double = 33.333

    /// Degrees per second derived from RPM (33.333 * 6 = 200)
    static let degreesPerSecond: Double = 200.0

    /// Button press scale-down factor
    static let buttonPressScale: CGFloat = 0.92

    /// Button press spring animation
    static let buttonPressSpring = Animation.spring(response: 0.25, dampingFraction: 0.6)

    // MARK: - Colors

    /// Base vinyl disc color (near-black)
    static let vinylBlack = Color(white: 0.08)

    /// Chrome highlight for tonearm bearing and arm tube
    static let chromeLight = Color(white: 0.85)

    /// Chrome shadow for tonearm darker regions
    static let chromeDark = Color(white: 0.45)

    /// Specular groove highlight color
    static let grooveHighlight = Color.white.opacity(0.08)

    /// Turntable platter base color
    static let platterBase = Color(white: 0.12)

    /// Label border ring color
    static let labelBorder = Color(white: 0.2)

    /// Spindle metallic gradient start (dark center)
    static let spindleDark = Color(white: 0.15)

    /// Spindle metallic gradient end (chrome edge)
    static let spindleChrome = Color(white: 0.7)

    // MARK: - Shadows

    /// Record disc drop shadow
    static let recordShadowColor = Color.black.opacity(0.5)
    static let recordShadowRadius: CGFloat = 16
    static let recordShadowY: CGFloat = 10

    /// Tonearm drop shadow
    static let tonearmShadowColor = Color.black.opacity(0.3)
    static let tonearmShadowRadius: CGFloat = 4

    /// Spindle shadow
    static let spindleShadowColor = Color.black.opacity(0.3)
    static let spindleShadowRadius: CGFloat = 2

    // MARK: - Sound Effects

    /// Volume for ambient vinyl crackle loop
    static let crackleVolume: Float = 0.12

    /// Crackle loop duration in seconds (for audio file)
    static let crackleDuration: TimeInterval = 5.0
}
