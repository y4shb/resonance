//
//  ResonanceScoreCalculator.swift
//  Resonance
//
//  Post-session biometric-music correlation scoring engine.
//  Computes a 0-100 "Resonance Score" measuring how well music
//  aligned with the user's biometric state and engagement signals.
//
//  Score formula:
//    overallScore = biometricScore * 0.6 + engagementScore * 0.4
//
//  Biometric score: weighted average of per-track HR direction alignment.
//  Engagement score: (1 - skipRate) * avgCompletion * durationBonus.
//

#if os(iOS)

import Foundation
import SwiftUI

// MARK: - Track Resonance Data

/// Per-track biometric alignment and engagement data for the resonance score.
struct TrackResonanceData: Codable, Sendable {
    let songTitle: String
    let artistName: String
    let songAppleMusicId: String
    /// Biometric alignment for this track (0.0-1.0)
    let alignment: Double
    /// Did heart rate move in the expected direction for the session intent?
    let hrDirectionMatch: Bool
    /// Fraction of the track that was played (0.0-1.0)
    let completionRatio: Double
    /// Whether the user skipped this track
    let wasSkipped: Bool
}

// MARK: - Resonance Score Result

/// Complete result of the post-session resonance scoring computation.
struct ResonanceScoreResult: Sendable {
    /// Overall resonance score (0-100)
    let overallScore: Int
    /// Biometric alignment sub-score (0-100)
    let biometricScore: Int
    /// Engagement sub-score (0-100)
    let engagementScore: Int
    /// Per-track breakdown data
    let perTrackData: [TrackResonanceData]
    /// Total session duration
    let sessionDuration: TimeInterval
    /// Number of tracks played
    let tracksPlayed: Int
    /// The track with highest alignment, if any
    let bestTrack: TrackResonanceData?

    /// Grade derived from the overall score.
    var grade: ResonanceGrade {
        switch overallScore {
        case 85...100: return .excellent
        case 70...84: return .good
        case 50...69: return .fair
        default: return .low
        }
    }
}

// MARK: - Resonance Grade

/// Qualitative grade for a resonance score.
enum ResonanceGrade: String, CaseIterable, Sendable {
    case excellent
    case good
    case fair
    case low

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .low: return "Low"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return ResonanceColors.accent
        case .fair: return .orange
        case .low: return .red
        }
    }
}

// MARK: - Resonance Score Calculator

/// Computes a post-session Resonance Score (0-100) from per-track
/// biometric alignment and engagement signals.
///
/// Scoring algorithm:
/// 1. Per-track biometric alignment based on session intent:
///    - energize: rising HR = good alignment
///    - calm: falling HR = good alignment
///    - focus: stable HR = good alignment
/// 2. Per-track engagement: completion ratio with skip penalty
/// 3. Overall biometric score = weighted average of per-track alignment
/// 4. Overall engagement = (1 - skipRate) * avgCompletion * durationBonus
/// 5. Overall score = biometricScore * 0.6 + engagementScore * 0.4
final class ResonanceScoreCalculator {

    // MARK: - Scoring Weights

    /// Weight of biometric alignment in the overall score.
    static let biometricWeight = 0.6
    /// Weight of engagement in the overall score.
    static let engagementWeight = 0.4

    /// Minimum session duration (seconds) for a valid resonance score.
    static let minimumSessionDuration: TimeInterval = 300 // 5 minutes

    /// Session duration at which the full duration bonus is awarded (seconds).
    static let fullDurationBonusThreshold: TimeInterval = 1800 // 30 minutes

    // MARK: - Compute Score

    /// Computes the resonance score for a completed listening session.
    ///
    /// - Parameters:
    ///   - tracks: Per-track resonance data collected during the session.
    ///   - sessionIntent: The session's music need (energize, calm, focus, etc.).
    ///   - sessionDuration: Total duration of the listening session.
    ///   - biometricAvailable: Whether biometric data was available during the session.
    /// - Returns: A `ResonanceScoreResult` with overall and component scores.
    func computeScore(
        tracks: [TrackResonanceData],
        sessionIntent: MusicNeed,
        sessionDuration: TimeInterval,
        biometricAvailable: Bool
    ) -> ResonanceScoreResult {
        guard !tracks.isEmpty else {
            return emptyResult(sessionDuration: sessionDuration)
        }

        // 1. Compute biometric score
        let bioScore = computeBiometricScore(
            tracks: tracks,
            biometricAvailable: biometricAvailable
        )

        // 2. Compute engagement score
        let engScore = computeEngagementScore(
            tracks: tracks,
            sessionDuration: sessionDuration
        )

        // 3. Combine into overall score
        let rawOverall = bioScore * Self.biometricWeight + engScore * Self.engagementWeight
        let overallScore = Int(round(clamp(rawOverall, 0.0, 1.0) * 100))

        // 4. Find best track by alignment
        let bestTrack = tracks
            .filter { !$0.wasSkipped }
            .max(by: { $0.alignment < $1.alignment })

        return ResonanceScoreResult(
            overallScore: overallScore,
            biometricScore: Int(round(clamp(bioScore, 0.0, 1.0) * 100)),
            engagementScore: Int(round(clamp(engScore, 0.0, 1.0) * 100)),
            perTrackData: tracks,
            sessionDuration: sessionDuration,
            tracksPlayed: tracks.count,
            bestTrack: bestTrack
        )
    }

    // MARK: - Biometric Score

    /// Weighted average of per-track biometric alignment.
    /// Tracks played longer contribute more to the score.
    private func computeBiometricScore(
        tracks: [TrackResonanceData],
        biometricAvailable: Bool
    ) -> Double {
        guard biometricAvailable else {
            // Without biometrics, use a neutral score based on engagement cues
            return 0.5
        }

        let totalCompletion = tracks.reduce(0.0) { $0 + $1.completionRatio }
        guard totalCompletion > 0 else { return 0.5 }

        // Weighted average: tracks with higher completion ratio contribute more
        let weightedSum = tracks.reduce(0.0) { sum, track in
            sum + track.alignment * track.completionRatio
        }

        return weightedSum / totalCompletion
    }

    // MARK: - Engagement Score

    /// Engagement score based on skip rate, average completion, and duration bonus.
    private func computeEngagementScore(
        tracks: [TrackResonanceData],
        sessionDuration: TimeInterval
    ) -> Double {
        guard !tracks.isEmpty else { return 0.0 }

        // Skip rate: fraction of tracks that were skipped
        let skippedCount = tracks.filter { $0.wasSkipped }.count
        let skipRate = Double(skippedCount) / Double(tracks.count)
        let skipFactor = 1.0 - skipRate

        // Average completion ratio across all tracks
        let avgCompletion = tracks.reduce(0.0) { $0 + $1.completionRatio } / Double(tracks.count)

        // Duration bonus: longer sessions get a small boost (up to 1.2x)
        let durationRatio = min(sessionDuration / Self.fullDurationBonusThreshold, 1.0)
        let durationBonus = 1.0 + (durationRatio * 0.2) // 1.0 to 1.2

        let rawEngagement = skipFactor * avgCompletion * durationBonus
        return clamp(rawEngagement, 0.0, 1.0)
    }

    // MARK: - Track Alignment Helpers

    /// Computes alignment for a single track based on heart rate direction and session intent.
    ///
    /// - Parameters:
    ///   - hrDelta: Change in heart rate during the track (positive = rising).
    ///   - sessionIntent: The session's music need.
    ///   - completionRatio: How much of the track was played.
    ///   - wasSkipped: Whether the track was skipped.
    /// - Returns: Alignment value (0.0-1.0) and whether HR direction matched.
    static func computeTrackAlignment(
        hrDelta: Double,
        sessionIntent: MusicNeed,
        completionRatio: Double,
        wasSkipped: Bool
    ) -> (alignment: Double, hrDirectionMatch: Bool) {
        // Determine expected HR direction based on intent
        let hrDirectionMatch: Bool
        let directionScore: Double

        switch sessionIntent {
        case .energize:
            // Rising HR = good alignment
            hrDirectionMatch = hrDelta > 0
            directionScore = 0.5 + clamp(hrDelta / 20.0, -0.5, 0.5)
        case .calm:
            // Falling HR = good alignment
            hrDirectionMatch = hrDelta < 0
            directionScore = 0.5 - clamp(hrDelta / 20.0, -0.5, 0.5)
        case .focus:
            // Stable HR = good alignment (small absolute change is best)
            let stability = 1.0 - clamp(abs(hrDelta) / 10.0, 0.0, 1.0)
            hrDirectionMatch = abs(hrDelta) < 5.0
            directionScore = stability
        case .maintain, .transition:
            // Neutral: moderate alignment regardless of direction
            hrDirectionMatch = true
            directionScore = 0.6
        }

        // Blend HR alignment with completion signal
        // Completed tracks with matching HR direction get highest alignment
        let completionBonus = wasSkipped ? -0.15 : (completionRatio > 0.9 ? 0.1 : 0.0)
        let alignment = clamp(directionScore + completionBonus, 0.0, 1.0)

        return (alignment, hrDirectionMatch)
    }

    // MARK: - Helpers

    private func emptyResult(sessionDuration: TimeInterval) -> ResonanceScoreResult {
        ResonanceScoreResult(
            overallScore: 0,
            biometricScore: 0,
            engagementScore: 0,
            perTrackData: [],
            sessionDuration: sessionDuration,
            tracksPlayed: 0,
            bestTrack: nil
        )
    }

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        Self.clamp(value, low, high)
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}

#endif
