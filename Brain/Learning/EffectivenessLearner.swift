//
//  EffectivenessLearner.swift
//  Resonance
//
//  Reinforcement learning-based song effectiveness model.
//  Replaces static EMA with a contextual bandit approach that learns
//  per-user song effectiveness from biometric reward signals.
//
//  Reward signal: HRV delta (primary) + skip penalty (secondary) + explicit feedback
//  Features: (song features, context, time-of-day, previous song features, session duration)
//
//  Uses Thompson Sampling / Upper Confidence Bound (UCB) for exploration vs exploitation.
//

#if os(iOS)

import Foundation
import CoreData

// MARK: - Song Effectiveness Score

/// A learned effectiveness score for a (song, context) pair.
struct EffectivenessScore {
    /// Mean estimated effectiveness (0.0 - 1.0)
    let mean: Double

    /// Uncertainty in the estimate (higher = less data, more exploration)
    let uncertainty: Double

    /// Number of observations (plays in this context)
    let observations: Int

    /// UCB score = mean + exploration_weight * uncertainty
    func ucbScore(explorationWeight: Double = 1.0) -> Double {
        mean + explorationWeight * uncertainty
    }

    /// Thompson sample: draw from beta distribution approximated by normal
    func thompsonSample() -> Double {
        guard observations > 0 else { return 0.5 }

        // Approximate beta distribution with normal(mean, uncertainty)
        let sample = mean + uncertainty * Self.gaussianRandom()
        return min(1.0, max(0.0, sample))
    }

    /// Box-Muller transform for Gaussian random numbers
    private static func gaussianRandom() -> Double {
        let u1 = Double.random(in: 0.0001...0.9999)
        let u2 = Double.random(in: 0.0001...0.9999)
        return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }
}

// MARK: - Reward Signal

/// A reward signal from a completed playback event.
struct PlaybackReward {
    /// HRV delta during playback (positive = relaxation/recovery)
    let hrvDelta: Double?

    /// Heart rate delta during playback
    let hrDelta: Double?

    /// Listen percentage (0.0 - 1.0)
    let listenPercentage: Double

    /// Whether the song was skipped
    let wasSkipped: Bool

    /// Explicit user feedback (nil if not provided)
    let explicitFeedback: Double?  // 0.0 - 1.0

    /// Computes the composite reward signal (0.0 - 1.0).
    func computeReward(forNeed need: MusicNeed) -> Double {
        var reward = 0.5  // Neutral starting point

        // Skip penalty (most reliable signal)
        if wasSkipped {
            if listenPercentage < 0.15 {
                reward -= 0.30  // Early skip = strong negative signal
            } else if listenPercentage < 0.30 {
                reward -= 0.15  // Late skip = moderate negative signal
            } else {
                reward -= 0.075
            }
        } else {
            // Completion bonus
            if listenPercentage > 0.90 {
                reward += 0.10
            }
        }

        // Biometric signal (context-dependent)
        if let hrvDelta = hrvDelta {
            let normalizedHRV = hrvDelta / LearningConstants.hrvNormalizationFactor

            switch need {
            case .calm, .focus:
                // For calm/focus: positive HRV delta = good (relaxation)
                reward += normalizedHRV * 0.20
            case .energize:
                // For energize: negative HRV delta is expected (activation)
                reward -= normalizedHRV * 0.10
            case .maintain, .transition:
                // For maintain: minimal change is ideal
                reward -= abs(normalizedHRV) * 0.05
            }
        }

        if let hrDelta = hrDelta {
            let normalizedHR = hrDelta / LearningConstants.hrNormalizationFactor

            switch need {
            case .energize:
                reward += normalizedHR * 0.10  // Rising HR during energize = good
            case .calm:
                reward -= normalizedHR * 0.10  // Rising HR during calm = bad
            default:
                break
            }
        }

        // Explicit feedback override (strongest signal when available)
        if let feedback = explicitFeedback {
            reward = reward * 0.4 + feedback * 0.6
        }

        return min(1.0, max(0.0, reward))
    }
}

// MARK: - Effectiveness Learner

/// RL-based song effectiveness learner using contextual bandits.
/// Replaces static EMA with an explore-exploit approach.
final class EffectivenessLearner {

    private let persistence: PersistenceController

    /// Controls exploration vs exploitation (decays over time)
    private var explorationWeight: Double = 1.5

    /// Minimum exploration weight (never stop exploring completely)
    private let minExplorationWeight: Double = 0.3

    /// Exploration decay rate per processed event
    private let explorationDecayRate: Double = 0.995

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Score Retrieval

    /// Gets the effectiveness score for a song in a given context.
    func getEffectivenessScore(
        songId: UUID,
        contextType: String
    ) -> EffectivenessScore {
        let context = persistence.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SongEffect")
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "song.id == %@", songId as CVarArg),
            NSPredicate(format: "contextType == %@", contextType),
        ])
        fetchRequest.fetchLimit = 1

        guard let effect = try? context.fetch(fetchRequest).first else {
            // No data: high uncertainty encourages exploration
            return EffectivenessScore(mean: 0.5, uncertainty: 0.5, observations: 0)
        }

        let sampleCount = effect.value(forKey: "sampleCount") as? Int ?? 0
        let calmScore = effect.value(forKey: "calmScore") as? Double ?? 0.5
        let energyScore = effect.value(forKey: "energyScore") as? Double ?? 0.5
        let focusScore = effect.value(forKey: "focusScore") as? Double ?? 0.5

        // Composite mean
        let mean = (calmScore + energyScore + focusScore) / 3.0

        // Uncertainty decreases with observations (1/sqrt(n) rule)
        let uncertainty = sampleCount > 0 ? 1.0 / sqrt(Double(sampleCount)) : 0.5

        return EffectivenessScore(
            mean: mean,
            uncertainty: min(0.5, uncertainty),
            observations: sampleCount
        )
    }

    // MARK: - Score All Candidates

    /// Scores all candidate songs using Thompson Sampling for exploration.
    func scoreWithExploration(
        candidates: [(songId: UUID, baseScore: Double)],
        contextType: String,
        useThompsonSampling: Bool = true
    ) -> [(songId: UUID, adjustedScore: Double)] {
        candidates.map { candidate in
            let effectiveness = getEffectivenessScore(
                songId: candidate.songId,
                contextType: contextType
            )

            let rlBonus: Double
            if useThompsonSampling {
                rlBonus = effectiveness.thompsonSample()
            } else {
                rlBonus = effectiveness.ucbScore(explorationWeight: explorationWeight)
            }

            // Blend base score with RL score (30% RL influence)
            let adjustedScore = candidate.baseScore * 0.7 + rlBonus * 0.3

            return (songId: candidate.songId, adjustedScore: adjustedScore)
        }
        .sorted { $0.adjustedScore > $1.adjustedScore }
    }

    // MARK: - Process Reward

    /// Processes a reward signal from a completed playback event.
    /// Updates the effectiveness model for the (song, context) pair.
    func processReward(
        songId: UUID,
        contextType: String,
        reward: PlaybackReward,
        musicNeed: MusicNeed
    ) async {
        let rewardValue = reward.computeReward(forNeed: musicNeed)

        await persistence.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            // Find or create SongEffect
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SongEffect")
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "song.id == %@", songId as CVarArg),
                NSPredicate(format: "contextType == %@", contextType),
            ])
            fetchRequest.fetchLimit = 1

            let effect: NSManagedObject
            if let existing = try? context.fetch(fetchRequest).first {
                effect = existing
            } else {
                // Create new effect entity
                guard let entity = NSEntityDescription.entity(forEntityName: "SongEffect", in: context) else { return }
                effect = NSManagedObject(entity: entity, insertInto: context)
                effect.setValue(contextType, forKey: "contextType")
                effect.setValue(0.5, forKey: "calmScore")
                effect.setValue(0.5, forKey: "energyScore")
                effect.setValue(0.5, forKey: "focusScore")
                effect.setValue(0.5, forKey: "moodLiftScore")
                effect.setValue(0, forKey: "sampleCount")
                effect.setValue(0.0, forKey: "confidence")
            }

            let sampleCount = (effect.value(forKey: "sampleCount") as? Int ?? 0) + 1

            // Two-tier learning rate: faster for new songs, slower for established
            let alpha = sampleCount <= BackfillConstants.coldStartThreshold
                ? BackfillConstants.coldStartLearningRate  // 0.4
                : LearningConstants.defaultLearningRate     // 0.2

            // Update scores using EMA with RL reward
            let dimensions = ["calmScore", "energyScore", "focusScore", "moodLiftScore"]
            for dimension in dimensions {
                let current = effect.value(forKey: dimension) as? Double ?? 0.5
                let updated = (1.0 - alpha) * current + alpha * rewardValue
                effect.setValue(updated, forKey: dimension)
            }

            effect.setValue(sampleCount, forKey: "sampleCount")

            // Update confidence based on sample count
            let confidence = min(1.0, Double(sampleCount) / Double(DecisionEngineConstants.fullConfidenceSampleCount))
            effect.setValue(confidence, forKey: "confidence")

            if context.hasChanges {
                try? context.save()
            }

            logDebug(
                "RL reward processed: songId=\(songId), context=\(contextType), reward=\(String(format: "%.3f", rewardValue)), samples=\(sampleCount)",
                category: .learning
            )
        }

        // Decay exploration weight
        explorationWeight = max(minExplorationWeight, explorationWeight * explorationDecayRate)
    }
}

#endif
