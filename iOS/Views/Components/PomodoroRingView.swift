//
//  PomodoroRingView.swift
//  Resonance
//
//  Circular progress ring overlay for the Pomodoro focus timer.
//  Shows current phase (Focus/Break), countdown, and progress arc.
//  Designed to be small and non-intrusive in the corner of NowPlayingView.
//

#if os(iOS)

import SwiftUI

// MARK: - Pomodoro Ring View

struct PomodoroRingView: View {
    let timer: PomodoroTimer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringColor: Color {
        timer.phase == .focus ? .purple : .green
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(.ultraThinMaterial, lineWidth: 5)

            // Progress arc
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? .none : .linear(duration: 1),
                    value: timer.progress
                )

            // Center content
            VStack(spacing: 1) {
                Text(timer.phaseLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(ringColor)

                Text(timer.timeString)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pomodoro timer: \(timer.phaseLabel), \(timer.timeString) remaining")
        .accessibilityValue("\(Int(timer.progress * 100)) percent complete")
    }
}

// MARK: - Pomodoro Controls

/// Compact control buttons for the Pomodoro timer: skip and stop.
struct PomodoroControls: View {
    let timer: PomodoroTimer

    var body: some View {
        HStack(spacing: 12) {
            Button {
                timer.skip()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Skip to \(timer.phase == .focus ? "break" : "focus")")

            Button {
                timer.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Stop Pomodoro timer")
        }
    }
}

#endif
