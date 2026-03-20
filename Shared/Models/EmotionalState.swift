//
//  EmotionalState.swift
//  Resonance
//
//  Emotional state types detected by the Watch emotion classifier.
//  Shared between Watch (classification) and iPhone (refinement).
//

import Foundation

// MARK: - Emotional State

/// The five emotional states detected by Watch-side fuzzy classification.
///
/// Each state carries a display name for UI presentation and a valence
/// adjustment factor used by `EmotionRefinementEngine` on the iPhone side
/// to refine the biometric mood estimate.
public enum EmotionalState: String, Codable, CaseIterable, Sendable {
    case calm
    case excited
    case stressed
    case fatigued
    case focused

    // MARK: - Display

    /// Human-readable name for UI presentation.
    public var displayName: String {
        switch self {
        case .calm:     return "Calm"
        case .excited:  return "Excited"
        case .stressed: return "Stressed"
        case .fatigued: return "Fatigued"
        case .focused:  return "Focused"
        }
    }

    // MARK: - Valence Adjustment

    /// Suggested valence adjustment when this emotion is detected.
    ///
    /// Applied by `EmotionRefinementEngine` on the iPhone side.
    /// Positive values improve mood, negative values depress it.
    public var valenceAdjustment: Double {
        switch self {
        case .calm:     return 0.05
        case .excited:  return 0.15
        case .stressed: return -0.10
        case .fatigued: return -0.05
        case .focused:  return 0.0
        }
    }
}

// MARK: - Watch Capability Tier

/// Describes the sensor capability tier of the connected Apple Watch.
///
/// Used to determine which emotion detection features are available
/// and which biometric signals can be collected.
public enum WatchCapabilityTier: String, Codable, Sendable {
    /// Full capability: HR, HRV, motion, temperature.
    case full
    /// Motion tier: HR, HRV, motion (no temperature).
    case motion
    /// Basic tier: HR, HRV only (no motion or temperature).
    case basic
}
