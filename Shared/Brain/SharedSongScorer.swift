//
//  SongScorer.swift
//  Resonance
//
//  Scores candidate songs against the current DecisionContext.
//  Implements circadian-aware energy targeting (6.1), cognitive load
//  context detection (6.2), sleep preparation scoring (6.4), and
//  session arc phase targeting (WS-4).
//

import Foundation

// MARK: - SharedSongScorer

/// Scores candidate songs against the current state, context, and physiological needs.
///
/// When an `ArcPhase` is provided (from the SessionPlanner), the phase's
/// target BPM and energy ranges override the standard need-based targets.
/// This enables session-level arc planning (WS-4).
public struct SharedSongScorer: Sendable {

    public init() {}

    // MARK: - Public API

    /// Scores a single candidate song against the current decision context.
    ///
    /// - Parameter arcPhase: Optional arc phase from SessionPlanner (WS-4).
    ///   When present, overrides the standard target BPM and provides an
    ///   instrumental preference bonus.
    public func score(
        songId: UUID,
        songTitle: String,
        artistName: String,
        albumName: String,
        features: SongFeatures,
        playCount: Int,
        context: DecisionContext,
        arousalState: ArousalState = .optimal,
        isSleepPrepActive: Bool = false,
        arousalBPMAdjustment: Double = 0.0,
        isoModeActive: Bool = false,
        isoTargetBPM: Double? = nil,
        arcPhase: ArcPhase? = nil
    ) -> SongScore {
        let preferences = context.preferences

        // Calculate component scores.
        // Arc phase (WS-4) overrides target BPM when present.
        let targetBPM: Double
        if let phase = arcPhase {
            targetBPM = phase.targetBPM
        } else {
            targetBPM = calculateTargetBPM(
                context: context,
                arousalBPMAdjustment: arousalBPMAdjustment,
                isoModeActive: isoModeActive,
                isoTargetBPM: isoTargetBPM,
                isSleepPrep: isSleepPrepActive
            )
        }
        let bpmScore = calculateBPMMatchScore(songBPM: features.bpm, targetBPM: targetBPM)

        // Arc phase (WS-4) overrides energy target when present.
        let energyScore: Double
        if let phase = arcPhase {
            energyScore = calculateArcPhaseEnergyScore(
                songEnergy: features.energy,
                phase: phase
            )
        } else {
            energyScore = calculateEnergyMatchScore(
                songEnergy: features.energy,
                context: context,
                isSleepPrep: isSleepPrepActive
            )
        }
        let familiarityScore = calculateFamiliarityScore(
            playCount: playCount,
            context: context
        )
        let historicalScore = DecisionEngineConstants.defaultHistoricalScore
        let contextScore = calculateContextAlignmentScore(
            features: features,
            context: context,
            isSleepPrep: isSleepPrepActive,
            arousalState: arousalState
        )
        let recencyPenalty = calculateRecencyPenalty(
            songId: songId,
            context: context
        )
        let timeScore = calculateTimeOfDayScore(
            features: features,
            context: context
        )

        // Arc phase instrumental preference bonus (WS-4)
        var arcPhaseBonus = 0.0
        if let phase = arcPhase {
            if phase.preferInstrumental && features.instrumentalness >= 0.5 {
                arcPhaseBonus = 0.05
            } else if phase.preferInstrumental && features.instrumentalness < 0.5 {
                arcPhaseBonus = -0.05
            }
        }

        // Weighted combination
        let weightedScore =
            bpmScore * preferences.bpmWeight
            + energyScore * preferences.energyWeight
            + familiarityScore * preferences.familiarityWeight
            + historicalScore * preferences.historicalWeight
            + contextScore * preferences.contextWeight

        // Apply recency penalty, time-of-day, and arc phase bonus (WS-4)
        let finalScore = max(0.0, min(1.0,
            (weightedScore + arcPhaseBonus) * (1.0 - recencyPenalty) * timeScore))

        // Build explanation
        var explanations: [ExplanationComponent] = []
        explanations.append(ExplanationComponent(
            factor: "BPM Match",
            contribution: bpmScore * preferences.bpmWeight,
            description: "Tempo \(Int(features.bpm)) BPM vs target \(Int(targetBPM))"
        ))
        explanations.append(ExplanationComponent(
            factor: "Energy Match",
            contribution: energyScore * preferences.energyWeight,
            description: "Energy level matches current need"
        ))
        explanations.append(ExplanationComponent(
            factor: "Context",
            contribution: contextScore * preferences.contextWeight,
            description: "Fits \(context.stateVector.context.displayName) context"
        ))
        if recencyPenalty > 0 {
            explanations.append(ExplanationComponent(
                factor: "Recency",
                contribution: -recencyPenalty,
                description: "Recently played penalty"
            ))
        }
        if isSleepPrepActive {
            explanations.append(ExplanationComponent(
                factor: "Sleep Prep",
                contribution: contextScore * 0.1,
                description: "Optimized for sleep preparation"
            ))
        }
        // Arc phase explanation (WS-4)
        if let phase = arcPhase {
            explanations.append(ExplanationComponent(
                factor: "Session Arc",
                contribution: arcPhaseBonus,
                description: "Phase: \(phase.phase.rawValue) (\(Int(phase.targetBPM)) BPM target)"
            ))
        }

        // Use graduated confidence from the feature extraction pipeline:
        // 0.4 genre-only / 0.45 enhanced heuristic / 0.65 ML / 0.85 audio-analyzed.
        // Falls back to the binary check only when confidence was never set.
        let confidence = features.confidence > 0.0 ? features.confidence : (features.isAnalyzed ? 0.8 : 0.4)

        return SongScore(
            songId: songId,
            songTitle: songTitle,
            artistName: artistName,
            albumName: albumName,
            bpm: features.bpm,
            bpmMatchScore: bpmScore,
            energyMatchScore: energyScore,
            familiarityScore: familiarityScore,
            historicalEffectScore: historicalScore,
            contextAlignmentScore: contextScore,
            recencyPenalty: recencyPenalty,
            timeOfDayScore: timeScore,
            finalScore: finalScore,
            confidence: confidence,
            explanationComponents: explanations
        )
    }

    // MARK: - Circadian Energy Curve (6.1)

    /// Returns the circadian-based target energy for a given hour (0-23).
    public func circadianEnergyTarget(for hour: Int) -> Double {
        let h = ((hour % 24) + 24) % 24
        switch h {
        case 6..<10:  return 0.3 + Double(h - 6) / 4.0 * 0.3   // Morning ramp
        case 10..<14: return 0.6 + Double(h - 10) / 4.0 * 0.2  // Midday peak
        case 14..<18: return 0.7 - Double(h - 14) / 4.0 * 0.1  // Afternoon decline
        case 18..<22: return 0.6 - Double(h - 18) / 4.0 * 0.3  // Evening wind-down
        default:                                                 // Night: 22-6
            let nightHour = h >= 22 ? h - 22 : h + 2
            return 0.3 - Double(nightHour) / 8.0 * 0.2
        }
    }

    /// Returns the blended energy target: 30% circadian + 70% need-based.
    public func blendedEnergyTarget(for hour: Int, needBased: Double) -> Double {
        let circadian = circadianEnergyTarget(for: hour)
        return circadian * 0.3 + needBased * 0.7
    }

    // MARK: - BPM Scoring

    /// Calculates target BPM based on context, iso-principle, and sleep prep.
    private func calculateTargetBPM(
        context: DecisionContext,
        arousalBPMAdjustment: Double,
        isoModeActive: Bool,
        isoTargetBPM: Double?,
        isSleepPrep: Bool
    ) -> Double {
        // Iso-principle override (6.3): during iso mode, match current arousal BPM
        if isoModeActive, let isoBPM = isoTargetBPM {
            return isoBPM
        }

        // Sleep preparation trajectory (6.4): BPM 80 -> 60
        if isSleepPrep {
            let sessionProgress = Double(context.sessionSongCount) / 6.0 // ~6 songs in prep
            let targetBPM = 80.0 - (sessionProgress * 20.0)
            return max(60.0, targetBPM)
        }

        // Standard need-based BPM target
        let range: (min: Double, max: Double)
        switch context.stateVector.inferredNeed {
        case .energize: range = DecisionEngineConstants.BPMRange.energize
        case .calm: range = DecisionEngineConstants.BPMRange.calm
        case .focus: range = DecisionEngineConstants.BPMRange.focus
        case .maintain: range = DecisionEngineConstants.BPMRange.maintain
        case .transition: range = DecisionEngineConstants.BPMRange.transition
        }

        let midpoint = (range.min + range.max) / 2.0
        let adjusted = midpoint + arousalBPMAdjustment
        return max(DecisionEngineConstants.absoluteMinBPM,
                   min(DecisionEngineConstants.absoluteMaxBPM, adjusted))
    }

    /// Scores how well a song's BPM matches the target.
    private func calculateBPMMatchScore(songBPM: Double, targetBPM: Double) -> Double {
        guard songBPM > 0 else { return 0.5 } // Unknown BPM gets neutral score
        let difference = abs(songBPM - targetBPM)
        let tolerance = DecisionEngineConstants.bpmTolerance
        let score = max(0.0, 1.0 - (difference / tolerance))
        return score
    }

    // MARK: - Energy Scoring

    /// Calculates energy match score using circadian blending (6.1).
    private func calculateEnergyMatchScore(
        songEnergy: Double,
        context: DecisionContext,
        isSleepPrep: Bool
    ) -> Double {
        // Sleep prep targets very low energy
        if isSleepPrep {
            return max(0.0, 1.0 - songEnergy * 2.0) // Strongly prefer low energy
        }

        let needBasedTarget: Double
        switch context.stateVector.inferredNeed {
        case .energize: needBasedTarget = 0.8
        case .calm: needBasedTarget = 0.3
        case .focus: needBasedTarget = 0.4
        case .maintain: needBasedTarget = context.stateVector.energy
        case .transition: needBasedTarget = 0.5
        }

        // Blend with circadian curve (6.1): 30% circadian + 70% need-based
        let blendedTarget = blendedEnergyTarget(
            for: context.currentHour,
            needBased: needBasedTarget
        )

        let difference = abs(songEnergy - blendedTarget)
        return max(0.0, 1.0 - difference * 2.0)
    }

    // MARK: - Familiarity Scoring (6.2 enhancement)

    /// Calculates familiarity bonus.
    /// During focus contexts (6.2), familiarity bonus is increased from 1.2 to 1.5
    /// because familiar songs reduce cognitive load during concentration.
    private func calculateFamiliarityScore(
        playCount: Int,
        context: DecisionContext
    ) -> Double {
        let baseFamiliarity: Double
        switch playCount {
        case 0: baseFamiliarity = 0.3        // Unknown song
        case 1...3: baseFamiliarity = 0.5    // Somewhat familiar
        case 4...10: baseFamiliarity = 0.7   // Familiar
        default: baseFamiliarity = 0.85      // Very familiar
        }

        // Focus context boost (6.2): increase familiarity importance
        let isFocusContext = context.stateVector.context == .deepWork
            || context.stateVector.context == .work

        if isFocusContext {
            // Boost from 1.2x to 1.5x for focus contexts
            return min(1.0, baseFamiliarity * 1.5)
        }

        // Stress-based familiarity preference
        if context.preferences.preferFamiliarInStress && context.stateVector.stress > 0.6 {
            return min(1.0, baseFamiliarity * 1.3)
        }

        return baseFamiliarity
    }

    // MARK: - Context Alignment Scoring (6.2 cognitive load + 6.4 sleep prep)

    /// Calculates context alignment. Enhanced for cognitive load (6.2) and sleep prep (6.4).
    private func calculateContextAlignmentScore(
        features: SongFeatures,
        context: DecisionContext,
        isSleepPrep: Bool,
        arousalState: ArousalState
    ) -> Double {
        var score = 0.5 // Neutral baseline

        let activityContext = context.stateVector.context

        switch activityContext {

        // Deep Work (6.2): cognitive load optimization
        case .deepWork:
            score = calculateFocusContextScore(features: features)

        // Work (6.2): similar to deep work but slightly more relaxed
        case .work:
            score = calculateWorkContextScore(features: features)

        case .workout:
            if features.energy > 0.7 { score += 0.3 }
            if features.bpm > 120 { score += 0.2 }
            score = min(1.0, score)
        case .postWorkout:
            if features.energy >= 0.3 && features.energy <= 0.6 { score += 0.25 }
            if features.bpm >= 80 && features.bpm <= 110 { score += 0.2 }
            score = min(1.0, score)
        case .relaxation:
            if features.energy < 0.5 { score += 0.2 }
            if features.valence > 0.5 { score += 0.15 }
            score = min(1.0, score)
        case .commute:
            if features.energy >= 0.4 && features.energy <= 0.7 { score += 0.2 }
            if features.valence > 0.5 { score += 0.15 }
            score = min(1.0, score)
        case .morning:
            if features.energy >= 0.3 && features.energy <= 0.6 { score += 0.2 }
            if features.valence > 0.5 { score += 0.2 }
            score = min(1.0, score)
        case .social:
            if features.energy > 0.5 { score += 0.15 }
            if features.valence > 0.5 { score += 0.2 }
            score = min(1.0, score)
        case .preSleep:
            score = calculateSleepPrepScore(features: features, context: context)
        case .unknown:
            score = 0.5
        }

        // Override with sleep prep scoring if flag is set
        if isSleepPrep && activityContext != .preSleep {
            score = calculateSleepPrepScore(features: features, context: context)
        }

        return score
    }

    // MARK: - Focus Context Scoring (6.2)

    /// Deep work scoring: penalizes vocals, prefers moderate energy (0.3-0.5), stable dynamics.
    private func calculateFocusContextScore(features: SongFeatures) -> Double {
        var score = 0.5
        let hasVocals = features.instrumentalness < 0.5
        if hasVocals { score -= 0.25 } else { score += 0.2 }
        // Complexity filter: prefer moderate energy (0.3-0.5)
        if features.energy >= 0.3 && features.energy <= 0.5 { score += 0.2 }
        else if features.energy < 0.2 { score -= 0.05 }
        else if features.energy > 0.6 { score -= 0.15 }
        // Stable dynamics: moderate acoustic density
        if features.acousticDensity >= 0.3 && features.acousticDensity <= 0.6 { score += 0.15 }
        else if features.acousticDensity > 0.8 { score -= 0.1 }
        if features.bpm >= 80 && features.bpm <= 110 { score += 0.1 }
        return max(0.0, min(1.0, score))
    }

    /// General work scoring (less strict than deep work).
    private func calculateWorkContextScore(features: SongFeatures) -> Double {
        var score = 0.5
        let hasVocals = features.instrumentalness < 0.5
        if hasVocals { score -= 0.1 } else { score += 0.1 }
        if features.energy >= 0.3 && features.energy <= 0.6 { score += 0.15 }
        if features.acousticDensity >= 0.3 && features.acousticDensity <= 0.7 { score += 0.1 }
        return max(0.0, min(1.0, score))
    }

    // MARK: - Sleep Preparation Scoring (6.4)

    /// Sleep prep: instrumental only, low dynamics, BPM 80->60 trajectory, no sudden changes.
    private func calculateSleepPrepScore(
        features: SongFeatures,
        context: DecisionContext
    ) -> Double {
        var score = 0.5
        let hasVocals = features.instrumentalness < 0.5
        if hasVocals { score -= 0.3 } else { score += 0.25 }
        if features.energy <= 0.3 { score += 0.2 }
        else if features.energy <= 0.5 { score += 0.05 }
        else { score -= 0.2 }
        if features.acousticDensity <= 0.3 { score += 0.15 }
        else if features.acousticDensity > 0.6 { score -= 0.15 }
        if features.bpm > 0 && features.bpm <= 80 { score += 0.15 }
        else if features.bpm > 100 { score -= 0.2 }
        if features.valence >= 0.4 && features.valence <= 0.7 { score += 0.1 }
        return max(0.0, min(1.0, score))
    }

    // MARK: - Recency Penalty

    private func calculateRecencyPenalty(songId: UUID, context: DecisionContext) -> Double {
        guard let minutesSince = context.minutesSinceLastPlayed(songId) else {
            return 0.0 // Never played, no penalty
        }

        let avoidMinutes = Double(context.preferences.avoidRecentMinutes)
        if minutesSince >= avoidMinutes {
            return 0.0
        }

        // Linear decay: full penalty at 0 minutes, zero at avoidMinutes
        return max(0.0, 1.0 - (minutesSince / avoidMinutes))
    }

    // MARK: - Time-of-Day Scoring

    /// Scores time-of-day appropriateness using circadian energy curve.
    private func calculateTimeOfDayScore(
        features: SongFeatures,
        context: DecisionContext
    ) -> Double {
        let timeSlot = context.timeSlot

        // Check BPM against time slot limits
        if features.bpm > 0 && features.bpm > timeSlot.suggestedMaxBPM {
            // Penalize songs that exceed the time slot's max BPM
            let excess = features.bpm - timeSlot.suggestedMaxBPM
            let penalty = min(0.4, excess / 100.0)
            return max(0.6, 1.0 - penalty)
        }

        // Check energy against circadian target
        let circadianTarget = circadianEnergyTarget(for: context.currentHour)
        let energyDiff = abs(features.energy - circadianTarget)
        if energyDiff > 0.4 {
            return 0.7 // Significant mismatch
        }

        return 1.0 // Good fit
    }

    // MARK: - Arc Phase Energy Scoring (WS-4)

    /// Calculates energy match score against the arc phase's target energy range.
    /// Songs within range get 1.0; outside songs penalized by distance.
    private func calculateArcPhaseEnergyScore(songEnergy: Double, phase: ArcPhase) -> Double {
        if phase.targetEnergyRange.contains(songEnergy) { return 1.0 }
        let rangeWidth = phase.targetEnergyRange.upperBound - phase.targetEnergyRange.lowerBound
        let distance = songEnergy < phase.targetEnergyRange.lowerBound
            ? phase.targetEnergyRange.lowerBound - songEnergy
            : songEnergy - phase.targetEnergyRange.upperBound
        return max(0.0, 1.0 - distance / max(0.2, rangeWidth))
    }
}
