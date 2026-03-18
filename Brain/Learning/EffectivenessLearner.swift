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

    /// Motion intensity during playback (0.0 = stationary, 1.0 = vigorous).
    /// Workstream 2.2: Used for motion-aware reward gating.
    let motionIntensity: Double

    /// HRV sensor quality (0.0 - 1.0). Workstream 2.4.
    let hrvQuality: Double

    /// Session quality score (0.0 - 1.0). Workstream 2.5.
    let sessionScore: Double

    /// Arc adherence score (0.0 - 1.0). Workstream 2.5.
    let arcAdherence: Double

    /// User's total interaction count (for weight selection). Workstream 2.1.
    let interactionCount: Int

    /// Personal HRV baseline for normalization. Workstream 2.3.
    let personalHRVBaseline: Double?

    init(
        hrvDelta: Double? = nil,
        hrDelta: Double? = nil,
        listenPercentage: Double = 0.0,
        wasSkipped: Bool = false,
        explicitFeedback: Double? = nil,
        motionIntensity: Double = 0.0,
        hrvQuality: Double = 1.0,
        sessionScore: Double = 0.5,
        arcAdherence: Double = 0.5,
        interactionCount: Int = 0,
        personalHRVBaseline: Double? = nil
    ) {
        self.hrvDelta = hrvDelta
        self.hrDelta = hrDelta
        self.listenPercentage = listenPercentage
        self.wasSkipped = wasSkipped
        self.explicitFeedback = explicitFeedback
        self.motionIntensity = motionIntensity
        self.hrvQuality = hrvQuality
        self.sessionScore = sessionScore
        self.arcAdherence = arcAdherence
        self.interactionCount = interactionCount
        self.personalHRVBaseline = personalHRVBaseline
    }

    /// Computes the composite reward signal (0.0 - 1.0) using the
    /// multi-component reward function (Workstream 2.1).
    ///
    /// Integrates:
    /// - Moving-window normalization (2.3)
    /// - Motion-aware reward gating (2.2)
    /// - Sensor confidence scoring (2.4)
    /// - Session arc reward (2.5)
    func computeReward(forNeed need: MusicNeed) -> Double {
        // Compute HRV reward component with personal baseline normalization (2.3)
        let hrvComponent = MultiComponentRewardCalculator.computeHRVReward(
            hrvDelta: hrvDelta,
            personalBaseline: personalHRVBaseline ?? PersonalBaseline.populationDefault,
            musicNeed: need
        )

        // Compute HR reward component
        let hrComponent = MultiComponentRewardCalculator.computeHRReward(
            hrDelta: hrDelta,
            musicNeed: need
        )

        // Compute behavioral reward component
        let behavioralComponent = MultiComponentRewardCalculator.computeBehavioralReward(
            wasSkipped: wasSkipped,
            listenPercentage: listenPercentage,
            explicitFeedback: explicitFeedback
        )

        // Compute session arc reward component (2.5)
        let sessionComponent = MultiComponentRewardCalculator.computeSessionReward(
            sessionScore: sessionScore,
            arcAdherence: arcAdherence
        )

        // Compute composite reward with motion gating (2.2) and HRV quality (2.4)
        return MultiComponentRewardCalculator.computeCompositeReward(
            hrvComponent: hrvComponent,
            hrComponent: hrComponent,
            behavioralComponent: behavioralComponent,
            sessionComponent: sessionComponent,
            interactionCount: interactionCount,
            motionIntensity: motionIntensity,
            hrvQuality: hrvQuality
        )
    }
}

// MARK: - Effectiveness Learner

/// RL-based song effectiveness learner using contextual bandits.
/// Replaces static EMA with an explore-exploit approach.
final class EffectivenessLearner {

    private let persistence: PersistenceController

    // MARK: - Exploration State Persistence Keys

    private enum Keys {
        static let explorationWeight = "com.y4sh.resonance.effectivenessLearner.explorationWeight"
        static let totalEventsProcessed = "com.y4sh.resonance.effectivenessLearner.totalEventsProcessed"
    }

    /// Lock protecting mutable exploration state accessed from multiple threads.
    private let lock = NSLock()

    /// Controls exploration vs exploitation (decays over time)
    /// - Note: Access must be protected by `lock`.
    private var _explorationWeight: Double

    /// Minimum exploration weight (never stop exploring completely)
    private let minExplorationWeight: Double = 0.3

    /// Exploration decay rate per processed event
    private let explorationDecayRate: Double = 0.995

    /// Total events processed (persisted for continuity)
    /// - Note: Access must be protected by `lock`.
    private var _totalEventsProcessed: Int

    private let defaults: UserDefaults

    init(
        persistence: PersistenceController = .shared,
        defaults: UserDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
    ) {
        self.persistence = persistence
        self.defaults = defaults

        // Restore persisted exploration state
        let storedWeight = defaults.double(forKey: Keys.explorationWeight)
        self._explorationWeight = storedWeight > 0 ? storedWeight : 1.5
        self._totalEventsProcessed = defaults.integer(forKey: Keys.totalEventsProcessed)

        logDebug(
            "EffectivenessLearner restored: explorationWeight=\(String(format: "%.3f", _explorationWeight)), "
            + "events=\(_totalEventsProcessed)",
            category: .learning
        )
    }

    // MARK: - State Persistence

    /// Saves exploration parameters to UserDefaults.
    /// Call on app backgrounding or termination.
    func saveExplorationState() {
        lock.lock()
        let weight = _explorationWeight
        let events = _totalEventsProcessed
        lock.unlock()

        defaults.set(weight, forKey: Keys.explorationWeight)
        defaults.set(events, forKey: Keys.totalEventsProcessed)
        logDebug(
            "EffectivenessLearner state saved: explorationWeight=\(String(format: "%.3f", weight))",
            category: .learning
        )
    }

    /// Restores exploration parameters from UserDefaults.
    /// Called automatically during init; can also be called on app foregrounding.
    func restoreExplorationState() {
        let storedWeight = defaults.double(forKey: Keys.explorationWeight)
        let storedEvents = defaults.integer(forKey: Keys.totalEventsProcessed)

        lock.lock()
        if storedWeight > 0 {
            _explorationWeight = storedWeight
        }
        _totalEventsProcessed = storedEvents
        lock.unlock()
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
            NSPredicate(format: "song.id == %@", songId as NSUUID),
            NSPredicate(format: "contextType == %@", contextType),
        ])
        fetchRequest.fetchLimit = 1

        // Thread-safe Core Data access via performAndWait
        var fetchedEffect: NSManagedObject?
        context.performAndWait {
            fetchedEffect = try? context.fetch(fetchRequest).first
        }
        guard let effect = fetchedEffect else {
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
                lock.lock()
                let weight = _explorationWeight
                lock.unlock()
                rlBonus = effectiveness.ucbScore(explorationWeight: weight)
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

        try? await persistence.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            // Find or create SongEffect
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SongEffect")
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "song.id == %@", songId as NSUUID),
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

            // Update only the dimension relevant to the current music need
            // to avoid cross-context contamination
            let targetDimension: String
            switch musicNeed {
            case .calm: targetDimension = "calmScore"
            case .energize: targetDimension = "energyScore"
            case .focus: targetDimension = "focusScore"
            case .maintain, .transition: targetDimension = "moodLiftScore"
            }

            let current = effect.value(forKey: targetDimension) as? Double ?? 0.5
            let updated = (1.0 - alpha) * current + alpha * rewardValue
            effect.setValue(updated, forKey: targetDimension)

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

        // Decay exploration weight (thread-safe)
        lock.lock()
        _explorationWeight = max(minExplorationWeight, _explorationWeight * explorationDecayRate)
        _totalEventsProcessed += 1
        let shouldPersist = _totalEventsProcessed % 10 == 0
        lock.unlock()

        // Persist every 10 events to avoid excessive writes
        if shouldPersist {
            saveExplorationState()
        }
    }
}

#endif
