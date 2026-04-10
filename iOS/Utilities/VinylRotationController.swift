//
//  VinylRotationController.swift
//  Resonance
//
//  Pure SwiftUI rotation engine for vinyl record spinning.
//  Uses TimelineView(.animation(paused:)) to drive continuous rotation
//  with seamless pause/resume angle preservation.
//
//  Usage:
//    TimelineView(.animation(paused: !rotationController.isPlaying)) { timeline in
//        VinylRecordView(rotationDegrees: rotationController.degrees(at: timeline.date))
//    }
//

import SwiftUI

@Observable
final class VinylRotationController {
    // MARK: - Properties

    /// Whether the record is currently spinning
    private(set) var isPlaying = false

    /// Accumulated degrees from previous play sessions (preserved across pause/resume)
    private var accumulatedDegrees: Double = 0

    /// Timestamp when the current play session started
    private var playStartDate: Date = .now

    /// Degrees at the moment play was started (snapshot of accumulated)
    private var degreesAtStart: Double = 0

    /// Rotation speed in degrees per second
    private let degreesPerSecond: Double

    // MARK: - Init

    init(rpm: Double = VinylConstants.rpm) {
        self.degreesPerSecond = rpm * 6.0 // 360 degrees / 60 seconds * RPM
    }

    // MARK: - Public API

    /// Computes the current rotation angle for a given timeline date.
    /// Call this inside a `TimelineView` body to get the current angle.
    func degrees(at date: Date) -> Double {
        guard isPlaying else {
            return accumulatedDegrees.truncatingRemainder(dividingBy: 360)
        }
        let elapsed = date.timeIntervalSince(playStartDate)
        let total = degreesAtStart + elapsed * degreesPerSecond
        return total.truncatingRemainder(dividingBy: 360)
    }

    /// Start or resume spinning from the current angle.
    func play() {
        guard !isPlaying else { return }
        degreesAtStart = accumulatedDegrees
        playStartDate = .now
        isPlaying = true
    }

    /// Pause spinning, preserving the exact current angle.
    func pause() {
        guard isPlaying else { return }
        let elapsed = Date.now.timeIntervalSince(playStartDate)
        accumulatedDegrees = degreesAtStart + elapsed * degreesPerSecond
        // Wrap to prevent float drift over long sessions
        accumulatedDegrees = accumulatedDegrees.truncatingRemainder(dividingBy: 360)
        isPlaying = false
    }

    /// Reset rotation to 0 degrees.
    func reset() {
        pause()
        accumulatedDegrees = 0
        degreesAtStart = 0
    }

    /// Sync play state with an external isPlaying boolean (e.g., from ViewModel).
    func sync(with playing: Bool) {
        if playing && !isPlaying {
            play()
        } else if !playing && isPlaying {
            pause()
        }
    }
}
