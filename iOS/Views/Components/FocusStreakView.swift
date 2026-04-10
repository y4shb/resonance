//
//  FocusStreakView.swift
//  Resonance
//
//  Visualizes the E1 ADHD Focus Mode streak timeline.
//  Shows a horizontal bar of colored segments representing focus periods,
//  with teal for deep focus, teal.opacity(0.5) for light focus, and red
//  dots for distraction markers. Pomodoro boundary lines divide the bar.
//  A growing animated segment shows the current active streak.
//
//  Follows Resonance design language: glass card background, .teal accent,
//  accessible labels, and reduce-motion guards on all animations.
//

#if os(iOS)

import SwiftUI

// MARK: - Focus Streak View

/// Horizontal timeline showing focus streaks with Pomodoro markers and stats.
struct FocusStreakView: View {
    let streaks: [FocusStreak]
    let currentStreak: FocusStreak?
    let pomodoroPhase: PomodoroPhase
    let pomodoroProgress: Double
    let totalFocusMinutes: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed

    /// Total streak count including the current ongoing streak.
    private var totalStreakCount: Int {
        streaks.count + (currentStreak != nil ? 1 : 0)
    }

    /// Duration of the longest streak in minutes.
    private var longestStreakMinutes: Double? {
        let completedMax = streaks.map(\.durationMinutes).max() ?? 0
        let currentDuration = currentStreak?.durationMinutes ?? 0
        let longest = max(completedMax, currentDuration)
        return longest > 0 ? longest : nil
    }

    /// Total distraction recovery count across all streaks.
    private var totalRecoveries: Int {
        let completedCount = streaks.reduce(0) { $0 + $1.distractionCount }
        let currentCount = currentStreak?.distractionCount ?? 0
        return completedCount + currentCount
    }

    /// Total timeline duration for proportional segment sizing.
    private var totalTimelineDuration: TimeInterval {
        let allStreaks = streaks + (currentStreak.map { [$0] } ?? [])
        guard let earliest = allStreaks.map(\.startTime).min() else { return 1 }
        let latestEnd = allStreaks.compactMap(\.endTime).max() ?? Date()
        let latest = max(latestEnd, currentStreak?.startTime ?? latestEnd)
        let duration = latest.timeIntervalSince(earliest)
        return max(duration, 1)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            timelineBar
            statsRow
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassEffect(.regular)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(
            "Currently in \(pomodoroPhase == .focus ? "focus" : "break") mode"
        )
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Label("Focus Streak", systemImage: "brain.fill")
                .font(.caption)
                .foregroundStyle(.teal)
                .accessibilityHidden(true)

            Spacer()

            Text("\(Int(totalFocusMinutes)) min")
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(.teal)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Timeline Bar

    private var timelineBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background capsule
                Capsule()
                    .fill(.ultraThinMaterial)

                // Streak segments
                HStack(spacing: 1) {
                    ForEach(streaks) { streak in
                        streakSegment(streak, totalWidth: geo.size.width)
                    }

                    if let current = currentStreak {
                        growingSegment(current, totalWidth: geo.size.width)
                    }
                }
                .clipShape(Capsule())

                // Pomodoro boundary markers
                pomodoroMarkers(totalWidth: geo.size.width)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    // MARK: - Streak Segments

    /// A completed streak rendered as a colored capsule segment.
    private func streakSegment(
        _ streak: FocusStreak,
        totalWidth: CGFloat
    ) -> some View {
        let proportion = streak.duration / totalTimelineDuration
        let width = max(CGFloat(proportion) * totalWidth, 2)

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4)
                .fill(colorForStreak(streak))
                .frame(width: width, height: 8)

            // Distraction dot between streaks
            if streak.distractionCount > 0 {
                Circle()
                    .fill(Color.red)
                    .frame(width: 4, height: 4)
            }
        }
    }

    /// An animated growing segment for the currently active streak.
    private func growingSegment(
        _ streak: FocusStreak,
        totalWidth: CGFloat
    ) -> some View {
        let proportion = streak.duration / totalTimelineDuration
        let width = max(CGFloat(proportion) * totalWidth, 4)

        return RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [.teal, .teal.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: 8)
            .animation(
                reduceMotion ? .none
                    : .spring(response: 0.35, dampingFraction: 0.8),
                value: width
            )
    }

    /// Color for a completed streak based on its average RMSSD quality.
    private func colorForStreak(_ streak: FocusStreak) -> Color {
        let inDeepRange = ADHDFocusConstants.deepFocusRMSSDRange.contains(streak.avgRMSSD)
        if inDeepRange {
            return .teal
        }
        return .teal.opacity(0.5)
    }

    // MARK: - Pomodoro Markers

    /// Vertical lines at Pomodoro block boundaries.
    private func pomodoroMarkers(totalWidth: CGFloat) -> some View {
        let blockDuration = TimeInterval(ADHDFocusConstants.focusBlockDuration)
        let breakDuration = TimeInterval(ADHDFocusConstants.breakDuration)
        let cycleDuration = blockDuration + breakDuration
        let totalDuration = totalTimelineDuration

        // Calculate how many boundaries fit
        let boundaryCount = Int(totalDuration / cycleDuration)

        return ForEach(0..<max(boundaryCount, 0), id: \.self) { index in
            let offset = CGFloat(Double(index + 1) * cycleDuration / totalDuration) * totalWidth
            if offset < totalWidth {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 12)
                    .offset(x: offset)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            Label(
                "\(totalStreakCount) streaks",
                systemImage: "chart.bar.fill"
            )
            .accessibilityHidden(true)

            if let longest = longestStreakMinutes {
                Label(
                    "Longest: \(Int(longest)) min",
                    systemImage: "trophy.fill"
                )
                .accessibilityHidden(true)
            }

            if totalRecoveries > 0 {
                Label(
                    "\(totalRecoveries) recoveries",
                    systemImage: "arrow.counterclockwise"
                )
                .accessibilityHidden(true)
            }

            Spacer()
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts = [
            "Focus streak: \(Int(totalFocusMinutes)) minutes of focus"
        ]
        if totalStreakCount > 0 {
            parts.append("across \(totalStreakCount) streaks")
        }
        if let longest = longestStreakMinutes {
            parts.append("Longest streak: \(Int(longest)) minutes")
        }
        if totalRecoveries > 0 {
            parts.append("\(totalRecoveries) distraction recoveries")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Preview

#Preview("Focus Streak - Active") {
    let completedStreaks: [FocusStreak] = [
        FocusStreak(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-2700),
            peakRMSSD: 58.0,
            avgRMSSD: 52.0,
            distractionCount: 1,
            pomodoroBlockIndex: 0
        ),
        FocusStreak(
            startTime: Date().addingTimeInterval(-2400),
            endTime: Date().addingTimeInterval(-1200),
            peakRMSSD: 62.0,
            avgRMSSD: 55.0,
            distractionCount: 0,
            pomodoroBlockIndex: 1
        ),
    ]

    let currentStreak = FocusStreak(
        startTime: Date().addingTimeInterval(-600),
        peakRMSSD: 60.0,
        avgRMSSD: 54.0,
        pomodoroBlockIndex: 2
    )

    FocusStreakView(
        streaks: completedStreaks,
        currentStreak: currentStreak,
        pomodoroPhase: .focus,
        pomodoroProgress: 0.4,
        totalFocusMinutes: 42
    )
    .padding()
    .background(Color.black)
}

#Preview("Focus Streak - Empty") {
    FocusStreakView(
        streaks: [],
        currentStreak: nil,
        pomodoroPhase: .idle,
        pomodoroProgress: 0,
        totalFocusMinutes: 0
    )
    .padding()
    .background(Color.black)
}

#endif
