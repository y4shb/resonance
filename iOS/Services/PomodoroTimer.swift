//
//  PomodoroTimer.swift
//  Resonance
//
//  Optional Pomodoro focus timer for Deep Work sessions.
//  25-minute focus blocks with 5-minute breaks. Drives context changes
//  via StateEngine.setManualMood() to shift the AI DJ between focus and
//  relaxation BPM arcs at each transition.
//
//  Timer survives backgrounding because MusicKit holds an audio session.
//

#if os(iOS)

import Combine
import Foundation
import Observation
import UIKit

// MARK: - Pomodoro Phase

/// The three states of the Pomodoro timer.
enum PomodoroPhase: String, Sendable {
    case idle       // Timer not running
    case focus      // 25-minute focus block
    case shortBreak // 5-minute break
}

// MARK: - Pomodoro Timer

/// Manages a Pomodoro focus timer with 25/5 cycles. Drives the AI DJ's
/// context between .deepWork (focus) and .relaxation (break) by calling
/// StateEngine.setManualMood() at each transition.
@MainActor
@Observable
final class PomodoroTimer {

    // MARK: - State

    /// Current phase of the timer.
    private(set) var phase: PomodoroPhase = .idle

    /// Seconds remaining in the current phase.
    private(set) var secondsRemaining: Int = PomodoroConstants.focusDuration

    /// Number of completed focus blocks in the current run.
    private(set) var completedBlocks: Int = 0

    // MARK: - Dependencies

    /// State engine for driving context changes. Set externally after init.
    weak var stateEngine: StateEngine?

    // MARK: - Constants

    private enum PomodoroConstants {
        static let focusDuration = 25 * 60    // 25 minutes
        static let breakDuration = 5 * 60     // 5 minutes

        // Mood values that push StateEngine toward the right context
        static let focusEnergy = 0.55
        static let focusValence = 0.6
        static let breakEnergy = 0.3
        static let breakValence = 0.65
    }

    // MARK: - Private State

    private var cancellable: AnyCancellable?

    // MARK: - Computed Properties

    /// Whether the timer is actively running (not idle).
    var isActive: Bool { phase != .idle }

    /// Progress of the current phase (0.0 to 1.0).
    var progress: Double {
        let total = phase == .focus
            ? PomodoroConstants.focusDuration
            : PomodoroConstants.breakDuration
        guard total > 0 else { return 0 }
        return 1.0 - Double(secondsRemaining) / Double(total)
    }

    /// Formatted time string (MM:SS).
    var timeString: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Display label for the current phase.
    var phaseLabel: String {
        switch phase {
        case .idle: return "Ready"
        case .focus: return "Focus"
        case .shortBreak: return "Break"
        }
    }

    // MARK: - Public API

    /// Starts the Pomodoro timer from the focus phase.
    func start() {
        phase = .focus
        secondsRemaining = PomodoroConstants.focusDuration
        completedBlocks = 0
        applyFocusContext()
        scheduleTimer()

        logInfo("Pomodoro started: 25-min focus block", category: .general)
    }

    /// Skips the current phase and transitions to the next.
    func skip() {
        transition()
    }

    /// Stops the Pomodoro timer and returns to idle.
    func stop() {
        phase = .idle
        secondsRemaining = PomodoroConstants.focusDuration
        cancellable = nil

        logInfo("Pomodoro stopped after \(completedBlocks) completed blocks", category: .general)
    }

    // MARK: - Timer Logic

    private func scheduleTimer() {
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        guard phase != .idle else {
            cancellable = nil
            return
        }

        secondsRemaining -= 1
        if secondsRemaining <= 0 {
            transition()
        }
    }

    private func transition() {
        // Haptic notification at transition
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        switch phase {
        case .focus:
            completedBlocks += 1
            phase = .shortBreak
            secondsRemaining = PomodoroConstants.breakDuration
            applyBreakContext()
            logInfo("Pomodoro: focus block \(completedBlocks) complete, starting 5-min break", category: .general)

        case .shortBreak:
            phase = .focus
            secondsRemaining = PomodoroConstants.focusDuration
            applyFocusContext()
            logInfo("Pomodoro: break complete, starting focus block \(completedBlocks + 1)", category: .general)

        case .idle:
            break
        }
    }

    // MARK: - Context Driving

    /// Sets mood values that push StateEngine toward .deepWork / .focus need.
    private func applyFocusContext() {
        stateEngine?.setManualMood(
            energy: PomodoroConstants.focusEnergy,
            valence: PomodoroConstants.focusValence
        )
    }

    /// Sets mood values that push StateEngine toward .relaxation / .calm need.
    private func applyBreakContext() {
        stateEngine?.setManualMood(
            energy: PomodoroConstants.breakEnergy,
            valence: PomodoroConstants.breakValence
        )
    }
}

#endif
