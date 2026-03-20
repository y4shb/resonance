//
//  WatchEmotionClassifier.swift
//  Resonance Watch
//
//  Fuzzy membership emotion classifier that detects 5 states:
//  calm, excited, stressed, fatigued, focused.
//  Uses hysteresis (60-second hold, 3 consecutive agreements)
//  to prevent rapid state switching.
//

import Foundation

// MARK: - Classification Result

struct EmotionClassification: Sendable {
    let state: EmotionalState
    let confidence: Double
    let memberships: [EmotionalState: Double]
    let timestamp: Date
}

// MARK: - WatchEmotionClassifier

final class WatchEmotionClassifier {

    // MARK: - Hysteresis Configuration

    /// Minimum hold time before switching emotion state (seconds).
    private let holdDurationSeconds: TimeInterval = 60.0

    /// Number of consecutive agreements required before switching.
    private let consecutiveAgreementsRequired = 3

    // MARK: - Hysteresis State

    private var committedState: EmotionalState = .calm
    private var lastStateChangeTimestamp: Date?
    private var candidateHistory: [EmotionalState] = []

    // MARK: - Classification

    /// Classifies the current emotional state from extracted features.
    func classify(features: EmotionFeatures) -> EmotionClassification {
        let memberships = computeMemberships(features: features)

        // Select raw winner (highest membership)
        let rawState = memberships.max(by: { $0.value < $1.value })?.key ?? .calm

        // Apply hysteresis
        let finalState = applyHysteresis(rawState)

        // Compute confidence
        let confidence = computeConfidence(
            memberships: memberships,
            winner: finalState,
            features: features
        )

        return EmotionClassification(
            state: finalState,
            confidence: confidence,
            memberships: memberships,
            timestamp: Date()
        )
    }

    /// Resets the classifier's hysteresis state.
    func reset() {
        committedState = .calm
        lastStateChangeTimestamp = nil
        candidateHistory.removeAll()
    }

    // MARK: - Fuzzy Membership Functions

    private func computeMemberships(features: EmotionFeatures) -> [EmotionalState: Double] {
        let f = features

        // calm = (1-arousal)*0.3 + (1-stress)*0.3 + motorCalm*0.2 + (1-sympathetic)*0.2
        let calm = (1.0 - f.arousal) * 0.3
            + (1.0 - f.stress) * 0.3
            + f.motorCalm * 0.2
            + (1.0 - f.sympatheticActivation) * 0.2

        // excited = arousal*0.25 + (1-stress)*0.2 + valence*0.2 + moveMag*0.2 + gestureFreq*0.15
        let excited = f.arousal * 0.25
            + (1.0 - f.stress) * 0.2
            + f.valence * 0.2
            + clamp(f.movementMagnitude, 0.0, 1.0) * 0.2
            + clamp(f.gestureFrequency / 2.0, 0.0, 1.0) * 0.15

        // stressed = stress*0.3 + sympathetic*0.25 + moveVar*0.2 + (1-valence)*0.15 + moveEntropy*0.1
        let stressed = f.stress * 0.3
            + f.sympatheticActivation * 0.25
            + clamp(f.movementVariability * 2.0, 0.0, 1.0) * 0.2
            + (1.0 - f.valence) * 0.15
            + clamp(f.movementEntropy / 3.0, 0.0, 1.0) * 0.1

        // fatigued = (1-energy)*0.35 + (1-arousal)*0.25 + (1-moveMag)*0.2 + (1-valence)*0.2
        let fatigued = (1.0 - f.energy) * 0.35
            + (1.0 - f.arousal) * 0.25
            + (1.0 - clamp(f.movementMagnitude, 0.0, 1.0)) * 0.2
            + (1.0 - f.valence) * 0.2

        // focused = (1-moveVar)*0.3 + (1-stress)*0.2 + focus*0.25 + motorCalm*0.15 + (1-gestureFreq)*0.1
        let focused = (1.0 - clamp(f.movementVariability * 2.0, 0.0, 1.0)) * 0.3
            + (1.0 - f.stress) * 0.2
            + f.focus * 0.25
            + f.motorCalm * 0.15
            + clamp(1.0 - f.gestureFrequency / 2.0, 0.0, 1.0) * 0.1

        return [
            .calm: clamp(calm, 0.0, 1.0),
            .excited: clamp(excited, 0.0, 1.0),
            .stressed: clamp(stressed, 0.0, 1.0),
            .fatigued: clamp(fatigued, 0.0, 1.0),
            .focused: clamp(focused, 0.0, 1.0)
        ]
    }

    // MARK: - Hysteresis (matches MusicNeed pattern)

    private func applyHysteresis(_ rawState: EmotionalState) -> EmotionalState {
        // If raw state matches committed, clear candidate history
        if rawState == committedState {
            candidateHistory.removeAll()
            return committedState
        }

        // Accumulate candidate, capping at 20 entries
        candidateHistory.append(rawState)
        if candidateHistory.count > 20 {
            candidateHistory.removeFirst(candidateHistory.count - 20)
        }

        // Check for consecutive agreement
        let recent = candidateHistory.suffix(consecutiveAgreementsRequired)
        let allAgree = recent.count >= consecutiveAgreementsRequired
            && recent.allSatisfy { $0 == rawState }
        guard allAgree else { return committedState }

        // Check hold time
        if let lastChange = lastStateChangeTimestamp,
           Date().timeIntervalSince(lastChange) < holdDurationSeconds {
            return committedState
        }

        // Commit the new state
        committedState = rawState
        lastStateChangeTimestamp = Date()
        candidateHistory.removeAll()
        logInfo(
            "Emotion state changed to \(rawState.rawValue) (hysteresis passed)",
            category: .general
        )
        return committedState
    }

    // MARK: - Confidence Calculation

    private func computeConfidence(
        memberships: [EmotionalState: Double],
        winner: EmotionalState,
        features: EmotionFeatures
    ) -> Double {
        guard let winnerScore = memberships[winner] else { return 0.0 }

        // Separation: how far ahead is the winner vs second place
        let sortedScores = memberships.values.sorted(by: >)
        let secondScore = sortedScores.count > 1 ? sortedScores[1] : 0.0
        let separation = winnerScore - secondScore

        // Source contribution: more sources = higher confidence
        let sourceBonus = min(0.3, Double(features.sourceCount) * 0.1)

        // Quality contribution
        let qualityFactor = features.qualityAverage

        // Temporal stability: winning state matching committed state
        let stabilityBonus: Double = (winner == committedState) ? 0.1 : 0.0

        let confidence = clamp(
            separation * 0.4 + qualityFactor * 0.3 + sourceBonus + stabilityBonus,
            0.0, 1.0
        )

        return confidence
    }

    // MARK: - Helpers

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}
