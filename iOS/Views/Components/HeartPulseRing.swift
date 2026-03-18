//
//  HeartPulseRing.swift
//  Resonance
//
//  Pulsing ring overlay that beats at the user's heart rate.
//  Glows brighter when music BPM approaches HR (entrainment).
//

import SwiftUI

struct HeartPulseRing: View {
    let heartRate: Double       // BPM from HealthKit
    let musicBPM: Double        // BPM of current track
    let accentColor: Color      // Derived from album art
    let reduceMotion: Bool

    @State private var isPulsed: Bool = false

    /// How closely music BPM matches heart rate (0.0 - 1.0)
    private var entrainment: Double {
        guard heartRate > 0, musicBPM > 0 else { return 0 }
        let ratio = musicBPM / heartRate
        // Check direct match and half/double time
        let directMatch = 1.0 - min(abs(ratio - 1.0), 1.0)
        let halfMatch = 1.0 - min(abs(ratio - 0.5) * 2, 1.0)
        let doubleMatch = 1.0 - min(abs(ratio - 2.0), 1.0)
        return max(directMatch, halfMatch, doubleMatch)
    }

    /// Pulse duration derived from heart rate
    private var pulseDuration: Double {
        guard heartRate > 30 else { return 1.0 }
        return 60.0 / heartRate
    }

    /// Ring opacity based on entrainment
    private var ringOpacity: Double {
        let base = 0.15
        let entrainmentBoost = entrainment * 0.35
        return base + entrainmentBoost
    }

    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(accentColor.opacity(ringOpacity), lineWidth: isPulsed ? 2 : 4)
                .scaleEffect(isPulsed ? 1.08 : 1.0)
                .opacity(isPulsed ? 0.3 : ringOpacity)

            // Inner glow ring (visible during entrainment)
            if entrainment > 0.5 {
                Circle()
                    .stroke(accentColor.opacity(entrainment * 0.4), lineWidth: 2)
                    .scaleEffect(isPulsed ? 1.04 : 1.0)
                    .blur(radius: 4)
            }
        }
        .animation(
            reduceMotion ? .none :
                .easeInOut(duration: pulseDuration * 0.4)
                .repeatForever(autoreverses: true),
            value: isPulsed
        )
        .onAppear {
            if !reduceMotion {
                isPulsed = true
            }
        }
        .onChange(of: heartRate) {
            // Reset animation when HR changes significantly
            if !reduceMotion {
                isPulsed = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isPulsed = true
                }
            }
        }
    }
}
