//
//  SongScorer.swift
//  Resonance
//
//  Calculates a composite score for each candidate song based on the current
//  user state, preferences, and historical effectiveness data.
//  Implements plan.md §5.2.1 (calculateSongScore) and §5.2.2 (calculateTargetBPM).
//

#if os(iOS)

import Foundation
import CoreData

// MARK: - Song Scorer

/// Scores candidate songs against the current user state and context.
/// Pure computation — no Core Data writes, no side effects.
final class SongScorer {

    // MARK: - Score Calculation (plan.md §5.2.1)

    /// Scores a single candidate song against the current decision context.
    ///
    /// - Parameters:
    ///   - arcPhase: Optional arc phase from SessionPlanner (WS-4).
    ///     When present, overrides target BPM and energy with the phase targets.
    ///   - workoutBPMRange: Optional workout-specific BPM range from WorkoutBPMAdvisor.
    ///     When present during workout context, overrides the generic need-based range.
    func scoreSong(
        _ song: Song,
        context: DecisionContext,
        arcPhase: ArcPhase? = nil,
        workoutBPMRange: WorkoutBPMRange? = nil
    ) -> SongScore? {
        guard let songId = song.id else { return nil }

        let weights = context.preferences
        let state = context.stateVector

        // Compute target values.
        // Arc phase (WS-4) overrides target BPM/energy when present.
        let targetBPM: Double
        let targetEnergy: Double
        if let phase = arcPhase {
            targetBPM = phase.targetBPM
            targetEnergy = phase.targetEnergy
        } else {
            targetBPM = calculateTargetBPM(state: state, context: context, workoutBPMRange: workoutBPMRange)
            targetEnergy = calculateTargetEnergy(state: state)
        }

        let songBPM = song.bpm
        let songEnergy = song.energyEstimate

        // Component 1: BPM Match
        let bpmMatchScore = calculateBPMMatchScore(songBPM: songBPM, targetBPM: targetBPM)

        // Component 2: Energy Match
        let energyMatchScore = calculateEnergyMatchScore(songEnergy: songEnergy, targetEnergy: targetEnergy)

        // Component 3: Familiarity
        let familiarityScore = calculateFamiliarityScore(
            song: song,
            state: state,
            preferences: weights
        )

        // Component 4: Historical Effect
        let historicalEffectScore = calculateHistoricalEffectScore(
            song: song,
            state: state
        )

        // Component 5: Context Alignment
        let contextAlignmentScore = calculateContextAlignmentScore(
            song: song,
            activityContext: state.context
        )

        // Component 6: Recency Penalty
        let recencyPenalty = calculateRecencyPenalty(
            songId: song.id,
            context: context
        )

        // Component 7: Time of Day
        let timeOfDayScore = calculateTimeOfDayScore(
            song: song,
            context: context
        )

        // Arc phase instrumental bonus (WS-4)
        var arcPhaseBonus = 0.0
        if let phase = arcPhase {
            if phase.preferInstrumental && song.instrumentalness >= 0.5 {
                arcPhaseBonus = 0.05
            } else if phase.preferInstrumental && song.instrumentalness < 0.5 {
                arcPhaseBonus = -0.05
            }
        }

        // Exploration bias weight adjustment:
        // When bias is high (Surprise Me), reduce familiarity and historical weights
        // and redistribute to context and energy for novel discovery.
        // When bias is low (Stay in Zone), boost familiarity and historical weights.
        //
        // At bias 0.0: familiarity/historical get +40% boost, context/energy get -20%
        // At bias 0.5: weights are unchanged (neutral)
        // At bias 1.0: familiarity/historical get -40% reduction, context/energy get +20%
        let bias = weights.explorationBias
        let exploitBoost = 1.0 + 0.8 * (0.5 - bias)     // 1.4 at 0.0, 1.0 at 0.5, 0.6 at 1.0
        let exploreBoost = 1.0 + 0.4 * (bias - 0.5)     // 0.8 at 0.0, 1.0 at 0.5, 1.2 at 1.0

        // Recency penalty is also modulated: lower bias = stronger penalty (don't repeat),
        // higher bias = weaker penalty (okay to revisit sooner for variety)
        let recencyMultiplier = 0.5 * exploitBoost       // 0.7 at 0.0, 0.5 at 0.5, 0.3 at 1.0

        // Final weighted score (plan.md §5.2.1) with exploration bias modulation
        var finalScore =
            (bpmMatchScore * weights.bpmWeight) +
            (energyMatchScore * weights.energyWeight * exploreBoost) +
            (familiarityScore * weights.familiarityWeight * exploitBoost) +
            (historicalEffectScore * weights.historicalWeight * exploitBoost) +
            (contextAlignmentScore * weights.contextWeight * exploreBoost) -
            (recencyPenalty * recencyMultiplier) +
            arcPhaseBonus

        // Time of day as multiplier
        finalScore = finalScore * (0.5 + timeOfDayScore * 0.5)

        // Clamp finalScore to non-negative
        finalScore = max(0.0, finalScore)

        // Confidence in this score
        let confidence = calculateConfidence(song: song, state: state)

        // Build explanation components
        var explanationComponents = buildExplanationComponents(
            bpmMatchScore: bpmMatchScore,
            energyMatchScore: energyMatchScore,
            familiarityScore: familiarityScore,
            historicalEffectScore: historicalEffectScore,
            contextAlignmentScore: contextAlignmentScore,
            state: state,
            songBPM: songBPM,
            targetBPM: targetBPM
        )
        // Arc phase explanation (WS-4)
        if let phase = arcPhase {
            explanationComponents.append(ExplanationComponent(
                factor: "Session Arc",
                contribution: arcPhaseBonus,
                description: "Phase: \(phase.phase.rawValue) (\(Int(phase.targetBPM)) BPM target)"
            ))
        }

        return SongScore(
            songId: songId,
            songTitle: song.title ?? "Unknown",
            artistName: song.artistName ?? "Unknown",
            albumName: song.albumName ?? "",
            bpm: songBPM,
            bpmMatchScore: bpmMatchScore,
            energyMatchScore: energyMatchScore,
            familiarityScore: familiarityScore,
            historicalEffectScore: historicalEffectScore,
            contextAlignmentScore: contextAlignmentScore,
            recencyPenalty: recencyPenalty,
            timeOfDayScore: timeOfDayScore,
            finalScore: finalScore,
            confidence: confidence,
            explanationComponents: explanationComponents
        )
    }

    /// Scores all candidate songs and returns them sorted by finalScore descending.
    ///
    /// - Parameters:
    ///   - arcPhase: Optional arc phase from SessionPlanner (WS-4).
    ///   - workoutBPMRange: Optional workout-specific BPM range from WorkoutBPMAdvisor.
    func scoreAllCandidates(
        _ songs: [Song],
        context: DecisionContext,
        arcPhase: ArcPhase? = nil,
        workoutBPMRange: WorkoutBPMRange? = nil
    ) -> [SongScore] {
        let scores = songs.compactMap { song in
            scoreSong(song, context: context, arcPhase: arcPhase, workoutBPMRange: workoutBPMRange)
        }
        return scores.sorted { $0.finalScore > $1.finalScore }
    }

    // MARK: - Target BPM Calculation (plan.md §5.2.2)

    /// Calculates the ideal target BPM based on user state and need.
    /// When a workout BPM range is provided (from WorkoutBPMAdvisor), it overrides
    /// the generic need-based range for more precise tempo targeting during exercise.
    func calculateTargetBPM(
        state: StateVector,
        context: DecisionContext,
        workoutBPMRange: WorkoutBPMRange? = nil
    ) -> Double {
        // Base BPM ranges by need
        let bpmRange: (min: Double, max: Double)

        // Workout BPM advisor override: use activity-specific ranges during workouts
        if let workoutRange = workoutBPMRange, state.context == .workout {
            bpmRange = (min: workoutRange.minBPM, max: workoutRange.maxBPM)
        } else {
            switch state.inferredNeed {
            case .energize:
                bpmRange = DecisionEngineConstants.BPMRange.energize
            case .calm:
                bpmRange = DecisionEngineConstants.BPMRange.calm
            case .focus:
                bpmRange = DecisionEngineConstants.BPMRange.focus
            case .maintain:
                bpmRange = DecisionEngineConstants.BPMRange.maintain
            case .transition:
                bpmRange = DecisionEngineConstants.BPMRange.transition
            }
        }

        // Interpolate within range based on energy level
        var targetBPM = bpmRange.min + (state.energy * (bpmRange.max - bpmRange.min))

        // If already high arousal but need to calm, target lower BPM
        if state.inferredNeed == .calm && state.arousal > 0.6 {
            targetBPM -= 10
        }

        // Time of day caps
        let hour = context.currentHour
        if hour >= context.preferences.nightStartHour || hour < 6 {
            targetBPM = min(targetBPM, context.preferences.nightMaxBPM)
        } else if hour < context.preferences.morningEndHour {
            targetBPM = min(targetBPM, context.preferences.morningMaxBPM)
        }

        return clamp(targetBPM, DecisionEngineConstants.absoluteMinBPM, DecisionEngineConstants.absoluteMaxBPM)
    }

    // MARK: - Target Energy Calculation

    /// Calculates the ideal target energy based on user state and need.
    func calculateTargetEnergy(state: StateVector) -> Double {
        switch state.inferredNeed {
        case .energize:
            // Want high energy music to activate
            return clamp(0.7 + state.arousal * 0.2, 0.0, 1.0)
        case .calm:
            // Want low energy music to relax
            return clamp(0.3 - state.stress * 0.1, 0.0, 1.0)
        case .focus:
            // Want moderate energy — not too stimulating, not too sleepy
            return clamp(0.4 + state.focus * 0.1, 0.0, 1.0)
        case .maintain:
            // Match current energy level
            return state.energy
        case .transition:
            // Middle ground
            return 0.5
        }
    }

    // MARK: - Component Score Calculations

    /// BPM match using Gaussian kernel for smoother, perceptually accurate scoring.
    /// Unlike linear decay which has a sharp discontinuity at the tolerance boundary,
    /// the Gaussian kernel provides gradual falloff: songs 5 BPM off score much higher
    /// than songs 30 BPM off, without a hard cutoff.
    /// sigma is set to tolerance/2.5 so that the tolerance boundary maps to ~0.08 score.
    private func calculateBPMMatchScore(songBPM: Double, targetBPM: Double) -> Double {
        guard songBPM > 0 else { return 0.5 } // Unknown BPM → neutral score
        let bpmDelta = abs(songBPM - targetBPM)
        let sigma = DecisionEngineConstants.bpmTolerance / 2.5
        return exp(-0.5 * (bpmDelta * bpmDelta) / (sigma * sigma))
    }

    /// Energy match using Gaussian kernel for smoother scoring.
    /// sigma = 0.4 gives graceful falloff: 0.1 difference ≈ 0.97, 0.3 difference ≈ 0.57.
    private func calculateEnergyMatchScore(songEnergy: Double, targetEnergy: Double) -> Double {
        let energyDelta = abs(songEnergy - targetEnergy)
        let sigma = 0.4
        return exp(-0.5 * (energyDelta * energyDelta) / (sigma * sigma))
    }

    /// Familiarity: base familiarity score with contextual boosts.
    private func calculateFamiliarityScore(
        song: Song,
        state: StateVector,
        preferences: UserPreferences
    ) -> Double {
        var boost: Double = 1.0

        // Higher familiarity preferred when stressed
        if state.stress > 0.6 && preferences.preferFamiliarInStress {
            boost = 1.3
        }

        // Higher familiarity preferred for focus
        if state.inferredNeed == .focus {
            boost = max(boost, 1.2)
        }

        return clamp(song.familiarityScore * boost, 0.0, 1.0)
    }

    /// Historical effect: looks up SongEffect for the current context, maps to need.
    private func calculateHistoricalEffectScore(
        song: Song,
        state: StateVector
    ) -> Double {
        guard let effect = getEffectForContext(song: song, context: state.context) else {
            return DecisionEngineConstants.defaultHistoricalScore
        }

        // Map effect scores to the current need
        let rawScore: Double
        switch state.inferredNeed {
        case .calm:
            rawScore = effect.calmScore
        case .focus:
            rawScore = effect.focusScore
        case .energize:
            rawScore = effect.energyScore
        case .maintain:
            rawScore = (effect.calmScore + effect.energyScore) / 2.0
        case .transition:
            rawScore = effect.moodLiftScore
        }

        // Blend with default based on confidence
        let confidence = effect.confidenceLevel
        return blend(DecisionEngineConstants.defaultHistoricalScore, rawScore, weight: confidence)
    }

    /// Looks up the SongEffect for a song in the given activity context.
    /// Falls back to "any" context if no specific match exists.
    private func getEffectForContext(song: Song, context: ActivityContext) -> SongEffect? {
        guard let effectsSet = song.effects,
              let effects = effectsSet.allObjects as? [SongEffect],
              !effects.isEmpty else {
            return nil
        }

        let contextString = context.rawValue

        // Try specific context first
        if let specific = effects.first(where: { $0.contextType == contextString }) {
            return specific
        }

        // Fall back to "any" context
        if let any = effects.first(where: { $0.contextType == "any" }) {
            return any
        }

        // Fall back to highest confidence effect
        return effects.max(by: { $0.confidenceLevel < $1.confidenceLevel })
    }

    /// Context alignment: how well the song's audio profile matches the activity context.
    private func calculateContextAlignmentScore(
        song: Song,
        activityContext: ActivityContext
    ) -> Double {
        let energy = song.energyEstimate
        let bpm = song.bpm
        let instrumentalness = song.instrumentalness

        switch activityContext {
        case .workout:
            // High energy, high BPM preferred
            let energyFit = energy > 0.6 ? 1.0 : energy / 0.6
            let bpmFit = bpm > 120 ? 1.0 : (bpm > 0 ? bpm / 120.0 : 0.5)
            return (energyFit * 0.6 + bpmFit * 0.4)

        case .deepWork:
            // Instrumental, moderate energy, steady BPM
            let instrumentalFit = instrumentalness
            let energyFit = 1.0 - abs(energy - 0.4)
            return (instrumentalFit * 0.5 + energyFit * 0.5)

        case .work:
            // Moderate energy, not too distracting
            let energyFit = 1.0 - abs(energy - 0.5)
            return energyFit

        case .relaxation:
            // Low energy, calming
            let energyFit = energy < 0.4 ? 1.0 : max(0.0, 1.0 - (energy - 0.4) / 0.6)
            let bpmFit = bpm < 100 ? 1.0 : (bpm > 0 ? max(0.0, 1.0 - (bpm - 100) / 60.0) : 0.5)
            return (energyFit * 0.6 + bpmFit * 0.4)

        case .preSleep:
            // Very low energy, slow, instrumental
            let energyFit = max(0.0, 1.0 - energy * 1.5)
            let bpmFit = bpm < 80 ? 1.0 : (bpm > 0 ? max(0.0, 1.0 - (bpm - 80) / 60.0) : 0.5)
            let instrumentalFit = instrumentalness * 0.8
            return (energyFit * 0.4 + bpmFit * 0.3 + instrumentalFit * 0.3)

        case .morning:
            // Moderate to moderately high energy, positive valence
            let energyFit = 1.0 - abs(energy - 0.5)
            let valenceFit = song.valence
            return (energyFit * 0.6 + valenceFit * 0.4)

        case .commute:
            // Upbeat, moderate-high energy (continuous curve peaking at energy ~0.7+)
            let energyFit = min(1.0, energy / 0.7)
            return energyFit

        case .social:
            // Popular, positive valence, moderate energy
            let valenceFit = song.valence
            let energyFit = 1.0 - abs(energy - 0.6)
            return (valenceFit * 0.5 + energyFit * 0.5)

        case .postWorkout:
            // Moderate energy, calming down
            let energyFit = 1.0 - abs(energy - 0.4)
            return energyFit

        case .unknown:
            return 0.5
        }
    }

    /// Recency penalty: returns 0.0 for songs that passed the guard filter
    /// (not played recently) to avoid double-penalizing with GuardFilters.
    /// Only applies a mild penalty for songs in the twilight zone between
    /// having been played and fully re-entering rotation, which can occur
    /// in fallback mode when guard filters are bypassed.
    private func calculateRecencyPenalty(songId: UUID?, context: DecisionContext) -> Double {
        guard let songId = songId,
              let minutesSince = context.minutesSinceLastPlayed(songId) else {
            return 0.0  // Never played recently -- no penalty
        }

        let avoidMinutes = Double(context.preferences.avoidRecentMinutes)
        guard avoidMinutes > 0, minutesSince < avoidMinutes else {
            return 0.0
        }

        // In normal operation, GuardFilters already removes songs within
        // avoidRecentMinutes. This penalty only activates in fallback mode
        // (when all candidates were filtered). Apply a reduced penalty
        // (halved) to let songs re-enter rotation sooner.
        let rawPenalty = 1.0 - (minutesSince / avoidMinutes)
        return rawPenalty * 0.5
    }

    /// Time of day score: penalizes songs whose BPM exceeds the time slot's suggested max.
    private func calculateTimeOfDayScore(song: Song, context: DecisionContext) -> Double {
        let songBPM = song.bpm
        guard songBPM > 0 else { return 1.0 } // Unknown BPM → no penalty

        let maxBPM = context.timeSlot.suggestedMaxBPM
        if songBPM <= maxBPM {
            return 1.0
        }

        // Gradual penalty for exceeding max BPM
        let excess = songBPM - maxBPM
        return max(0.3, 1.0 - (excess / 60.0))
    }

    // MARK: - Confidence Calculation

    private func calculateConfidence(song: Song, state: StateVector) -> Double {
        var confidence = 0.0
        if song.bpm > 0 { confidence += 0.2 }
        if let effects = song.effects, effects.count > 0 { confidence += 0.3 * song.confidenceLevel }
        confidence += 0.3 * state.confidence
        if song.totalPlayCount > 0 {
            confidence += 0.2 * min(1.0, Double(song.totalPlayCount) / 10.0)
        }
        return confidence
    }

    // MARK: - Explanation Component Building

    private func buildExplanationComponents(
        bpmMatchScore: Double, energyMatchScore: Double, familiarityScore: Double,
        historicalEffectScore: Double, contextAlignmentScore: Double,
        state: StateVector, songBPM: Double, targetBPM: Double
    ) -> [ExplanationComponent] {
        var c: [ExplanationComponent] = []
        if songBPM > 0 {
            let delta = abs(songBPM - targetBPM)
            let desc = delta < 10
                ? "Tempo closely matches target (\(Int(targetBPM)) BPM)"
                : "Tempo is \(Int(songBPM)) BPM (target: \(Int(targetBPM)))"
            c.append(ExplanationComponent(factor: "Tempo", contribution: bpmMatchScore, description: desc))
        }
        c.append(ExplanationComponent(
            factor: "Energy", contribution: energyMatchScore,
            description: energyMatchScore > 0.7 ? "Energy level is a great fit" : "Energy level matches well"))
        if historicalEffectScore != 0.5 {
            c.append(ExplanationComponent(
                factor: "History", contribution: historicalEffectScore,
                description: historicalEffectScore > 0.6
                    ? "Proven effective for \(state.inferredNeed.displayName.lowercased())"
                    : "Has historical playback data"))
        }
        c.append(ExplanationComponent(
            factor: "Context", contribution: contextAlignmentScore,
            description: "Fits \(state.context.displayName.lowercased()) context"))
        if familiarityScore > 0.3 {
            c.append(ExplanationComponent(
                factor: "Familiarity", contribution: familiarityScore,
                description: state.stress > 0.6 ? "Familiar track (comforting)" : "Known track in your library"))
        }
        return c.sorted { $0.contribution > $1.contribution }
    }

    // MARK: - Helpers

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    private func blend(_ a: Double, _ b: Double, weight: Double) -> Double {
        a * (1.0 - weight) + b * weight
    }
}

#endif
