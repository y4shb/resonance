//
//  ActivityContextInference.swift
//  Resonance
//
//  Pure-function activity context inference logic, extracted from StateEngine
//  to keep individual files under the 500-line limit.
//
//  Uses a priority-based cascade: workout detection > macOS signals >
//  motion-based inference > time-based defaults.
//

#if os(iOS)

import Foundation

extension StateEngine {

    // MARK: - Context Inference (plan.md Section 5.1.3)

    /// Infers activity context using a priority-based cascade.
    func inferActivityContext(
        biometric: BiometricSignal?,
        macOS: MacOSContextSignal?,
        timeSlot: TimeSlot,
        isWeekend: Bool
    ) -> ActivityContext {
        // Priority 1: Explicit workout detection (from Watch)
        if let bio = biometric {
            if bio.isInWorkout {
                return .workout
            }
        }

        // Priority 2: macOS signals
        if let mac = macOS {
            if mac.hasOngoingMeeting {
                return .work
            }
            if mac.focusModeActive,
               let name = mac.focusModeName?.lowercased(),
               name.contains("work") || name.contains("do not disturb") {
                return .deepWork
            }
            if mac.inferredWorkState == .deepWork {
                return .deepWork
            }
            if mac.inferredWorkState == .entertainment {
                return .relaxation
            }
        }

        // Priority 3: Motion-based inference (HR + movement)
        if let bio = biometric, !bio.isStationary {
            let hr = bio.heartRate ?? 0
            if hr > 130 {
                return .workout
            }
            if hr > 100 {
                return .commute
            }
        }

        // Priority 4: Circadian-aware time-based defaults
        // Uses learned wake/sleep landmarks when available, static fallback otherwise
        let hour = Calendar.current.component(.hour, from: Date())
        return circadianManager.circadianActivityContext(forHour: hour, isWeekend: isWeekend)
    }
}

#endif
