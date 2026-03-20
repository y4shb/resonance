//
//  MusicNeedInference.swift
//  Resonance
//
//  Music need inference, hysteresis logic, and HealthKit refresh helpers
//  for the StateEngine. Extracted from StateEngine.swift to keep files
//  under the 500-line limit.
//
//  Related files:
//  - StateEngine.swift: Core state engine
//  - StateCalculationHelpers.swift: Calculation functions (R1, R2, R3)
//  - ActivityContextInference.swift: Activity context inference
//

#if os(iOS)

import Foundation

// MARK: - Music Need Inference

extension StateEngine {

    // MARK: - Thresholds

    /// Named constants for state-driven music need thresholds.
    private enum NeedThresholds {
        /// Energy below this triggers energize need during workouts.
        static let workoutLowEnergy: Double = 0.5
        /// Focus above this triggers focus need during work context.
        static let workFocusThreshold: Double = 0.6
        /// Stress above this triggers calm need.
        static let highStress: Double = 0.7
        /// Energy below this (combined with low arousal) triggers energize.
        static let lowEnergy: Double = 0.3
        /// Arousal below this (combined with low energy) triggers energize.
        static let lowArousal: Double = 0.4
        /// HR acceleration signal weight in the combined transition score.
        static let hrAccelerationWeight: Double = 0.3
        /// Combined score above this triggers transition need.
        static let transitionThreshold: Double = 0.4
    }

    // MARK: - Public API

    /// Determines what the user needs from music.
    ///
    /// Applies hysteresis (60s hold, 3 consecutive agreeing samples) to
    /// prevent rapid need switching.
    ///
    /// - Parameter state: The current state vector from biometric inputs.
    /// - Returns: The stabilized `MusicNeed` after hysteresis filtering.
    internal func inferMusicNeed(state: StateVector) -> MusicNeed {
        return applyNeedHysteresis(computeRawMusicNeed(state: state))
    }

    /// Computes the raw music need from the current state without hysteresis.
    ///
    /// Priority order:
    /// 1. Context-driven needs (workout, post-workout, pre-sleep, deep work, work)
    /// 2. State-driven needs (high stress, low energy)
    /// 3. Transition detection via HR acceleration (R3)
    /// 4. Default: maintain
    ///
    /// - Parameter state: The current state vector from biometric inputs.
    /// - Returns: The raw `MusicNeed` before hysteresis filtering.
    internal func computeRawMusicNeed(state: StateVector) -> MusicNeed {
        // Context-driven needs (highest priority)
        switch state.context {
        case .workout:
            return state.energy < NeedThresholds.workoutLowEnergy ? .energize : .maintain
        case .postWorkout:
            return .calm
        case .preSleep:
            return .calm
        case .deepWork:
            return .focus
        case .work:
            if state.focus > NeedThresholds.workFocusThreshold {
                return .focus
            }
        default:
            break
        }

        // State-driven needs
        if state.stress > NeedThresholds.highStress {
            return .calm
        }

        if state.energy < NeedThresholds.lowEnergy && state.arousal < NeedThresholds.lowArousal {
            return .energize
        }

        // Detect significant state change, enhanced with HR acceleration (R3).
        // HR acceleration > 5 BPM/min indicates rapid emotional state transitions.
        // Reference: Appelhans & Luecken, Psychophysiology 2006
        if let prev = previousState {
            let delta = abs(state.arousal - prev.arousal) + abs(state.stress - prev.stress)
            let transitionSignal = Self.transitionSignalFromHRAcceleration(lastHRAcceleration)
            let combinedScore = delta + transitionSignal * NeedThresholds.hrAccelerationWeight
            if combinedScore > NeedThresholds.transitionThreshold {
                return .transition
            }
        }

        return .maintain
    }

    // MARK: - Hysteresis

    /// Applies hysteresis: requires hold time plus consecutive agreement.
    ///
    /// Prevents rapid oscillation between music needs by requiring
    /// `musicNeedDebounceCount` consecutive agreeing samples and a minimum
    /// hold time of `musicNeedHoldSeconds` before committing a change.
    ///
    /// - Parameter rawNeed: The unfiltered music need from `computeRawMusicNeed`.
    /// - Returns: The committed `MusicNeed` after hysteresis filtering.
    internal func applyNeedHysteresis(_ rawNeed: MusicNeed) -> MusicNeed {
        if rawNeed == committedNeed {
            candidateNeedHistory.removeAll()
            return committedNeed
        }

        candidateNeedHistory.append(rawNeed)

        let recent = candidateNeedHistory.suffix(musicNeedDebounceCount)
        let allAgree = recent.count >= musicNeedDebounceCount
            && recent.allSatisfy { $0 == rawNeed }
        guard allAgree else { return committedNeed }

        if let lastChange = lastNeedChangeTimestamp,
           Date().timeIntervalSince(lastChange) < musicNeedHoldSeconds {
            return committedNeed
        }

        committedNeed = rawNeed
        lastNeedChangeTimestamp = Date()
        candidateNeedHistory.removeAll()
        logInfo("MusicNeed changed to \(rawNeed.rawValue) (hysteresis passed)", category: .stateEngine)
        return committedNeed
    }

    // MARK: - HealthKit Refresh Helpers

    func refreshRestingHeartRate() async {
        do {
            if let rhr = try await healthKitService.fetchRestingHeartRate() {
                restingHeartRate = rhr
                logDebug("Resting HR updated: \(rhr) BPM", category: .stateEngine)
            }
        } catch {
            logDebug("Could not fetch resting HR: \(error.localizedDescription)", category: .stateEngine)
        }
        lastRestingHRFetch = Date()
    }

    func refreshVO2Max() async {
        do {
            if let vo2 = try await healthKitService.fetchVO2Max() {
                cachedVO2Max = vo2
                logDebug("VO2 Max updated: \(String(format: "%.1f", vo2))", category: .stateEngine)
            }
        } catch {
            logDebug("Could not fetch VO2 Max: \(error.localizedDescription)", category: .stateEngine)
        }
        lastVO2MaxFetch = Date()
    }

    func checkIrregularHeartRhythm() async {
        do {
            let events = try await healthKitService.fetchIrregularHeartRhythmEvents(days: 7)
            let oneDayAgo = Date().addingTimeInterval(-86400)
            let recentEvents = events.filter { $0 > oneDayAgo }
            hasRecentIrregularRhythm = !recentEvents.isEmpty
            if hasRecentIrregularRhythm {
                logWarning("Irregular rhythm (\(recentEvents.count) events in 24h) - reliability reduced", category: .stateEngine)
            }
        } catch {
            logDebug("Could not check irregular rhythm: \(error.localizedDescription)", category: .stateEngine)
        }
        lastIrregularRhythmCheck = Date()
    }
}

#endif
