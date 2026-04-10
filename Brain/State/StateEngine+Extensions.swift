//
//  StateEngine+Extensions.swift
//  Resonance
//
//  Bridge properties that forward detector state to the view model layer.
//  Keeps StateEngine.swift focused on core state synthesis while exposing
//  derived properties needed by NowPlayingViewModel and other consumers.
//

#if os(iOS)

import Foundation

extension StateEngine {

    // MARK: - E1: Focus Streaks (FocusStateDetector)

    /// All completed focus streaks that met the minimum duration threshold,
    /// plus the currently active streak if one is in progress.
    var focusStreaks: [FocusStreak] {
        var streaks = focusDetector.completedStreaks
        if let current = focusDetector.currentStreak {
            streaks.append(current)
        }
        return streaks
    }

    /// The currently active focus streak, if the user is in one.
    var currentFocusStreak: FocusStreak? {
        focusDetector.currentStreak
    }

    /// Total minutes spent in deep or light focus across all recorded streaks.
    var totalFocusMinutes: Double {
        focusDetector.totalFocusMinutesToday
    }

    // MARK: - E2: Workout Recovery (WorkoutRecoveryManager)

    /// Whether the state engine has detected a post-workout recovery phase.
    var isInRecoveryMode: Bool {
        workoutRecoveryManager.state != .inactive
    }

    /// Current workout recovery metrics (HR decline, motion level, recovery stage).
    var recoveryMetrics: WorkoutRecoveryMetrics? {
        workoutRecoveryManager.currentMetrics
    }

    // MARK: - E4: Anxiety Detection (AnxietyDetector)

    /// Current anxiety level derived from stress and HRV signals.
    var currentAnxietyLevel: AnxietyLevel {
        anxietyDetector.currentLevel
    }
}

#endif
