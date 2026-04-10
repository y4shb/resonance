//
//  MoodLadderView.swift
//  Resonance
//
//  Visualizes the E6 emotional regulation ladder progress.
//  Vertical ladder with HRV-verified rungs, calming color palette,
//  glass background, animated position indicator, and a11y support.
//

#if os(iOS)

import SwiftUI

// MARK: - Mood Ladder View

/// Vertical ladder showing valence progression with HRV verification at each rung.
struct MoodLadderView: View {
    let session: MoodLadderSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Calming palette -- muted warm tones, no alarming reds
    private let deepDistressColor = Color(red: 0.55, green: 0.42, blue: 0.35)
    private let moderateDistressColor = Color(red: 0.65, green: 0.55, blue: 0.40)
    private let mildDistressColor = Color(red: 0.72, green: 0.65, blue: 0.50)
    private let approachingNeutralColor = Color(red: 0.55, green: 0.68, blue: 0.58)
    private let neutralColor = Color(red: 0.45, green: 0.70, blue: 0.68)

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if session.isActive {
                activeLadderContent
            } else {
                completionContent
            }
        }
        .padding(16)
        .glassEffect(.regular)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mood regulation ladder")
    }

    // MARK: - Active Ladder

    private var activeLadderContent: some View {
        VStack(spacing: 16) {
            headerView
            ladderVisualization
            progressInfo
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.clipboard")
                        .foregroundStyle(ResonanceColors.accent)
                        .font(.subheadline)
                        .accessibilityHidden(true)

                    Text("Mood Regulation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Elapsed time badge
            Text(formattedElapsed)
                .font(.caption2)
                .fontWeight(.medium)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(ResonanceColors.accent.opacity(0.15))
                )
                .foregroundStyle(ResonanceColors.accent)
                .accessibilityLabel("Elapsed time: \(formattedElapsed)")
        }
    }

    private var statusText: String {
        switch session.startState {
        case .neutral:
            return "Monitoring"
        case .mildDistress:
            return "Gentle mood lift in progress"
        case .moderateDistress:
            return "Guided mood recovery"
        case .acuteDistress:
            return "Deep calming session active"
        }
    }

    // MARK: - Vertical Ladder Visualization

    private var ladderVisualization: some View {
        HStack(alignment: .top, spacing: 12) {
            // Vertical ladder with rungs
            VStack(spacing: 0) {
                ForEach(Array(session.rungs.enumerated().reversed()), id: \.element.id) { index, rung in
                    rungRow(rung: rung, index: index)

                    if index > 0 {
                        // Connector between rungs
                        connectorLine(fromIndex: index - 1, toIndex: index)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func rungRow(rung: LadderRung, index: Int) -> some View {
        let isCurrent = index == session.currentStep && session.isActive
        let isPast = index < session.currentStep
        let rungColor = colorForValence(rung.targetValence)

        return HStack(spacing: 10) {
            // Position indicator / checkmark
            ZStack {
                Circle()
                    .fill(isPast ? rungColor.opacity(0.3) : rungColor.opacity(0.1))
                    .frame(width: 32, height: 32)

                if isCurrent {
                    currentPositionDot(color: rungColor)
                } else if isPast && rung.hrvVerified {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(rungColor)
                } else if isPast {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(rungColor.opacity(0.6))
                } else {
                    Circle()
                        .fill(rungColor.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)

            // Rung details
            VStack(alignment: .leading, spacing: 2) {
                Text(rungLabel(for: rung, index: index))
                    .font(.subheadline)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(isCurrent ? .primary : .secondary)

                if let hrv = rung.hrvAtRung {
                    HStack(spacing: 4) {
                        Image(systemName: rung.hrvVerified ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 9))
                            .foregroundStyle(rung.hrvVerified ? .green : .secondary)
                            .accessibilityHidden(true)

                        Text("HRV: \(Int(hrv))ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Valence label
            Text(valenceLabel(rung.targetValence))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(rungColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(rungColor.opacity(0.12))
                )
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rungAccessibilityLabel(rung: rung, index: index))
    }

    @State private var dotPulsed = false

    @ViewBuilder
    private func currentPositionDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .shadow(color: color.opacity(0.5), radius: 6, x: 0, y: 0)
            .scaleEffect(dotPulsed ? 1.15 : 1.0)
            .onAppear {
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        dotPulsed = true
                    }
                }
            }
    }

    private func connectorLine(fromIndex: Int, toIndex: Int) -> some View {
        let isPast = toIndex <= session.currentStep
        return Rectangle()
            .fill(
                isPast
                    ? ResonanceColors.accent.opacity(0.3)
                    : Color.secondary.opacity(0.15)
            )
            .frame(width: 2, height: 16)
            .padding(.leading, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Progress Info

    private var progressInfo: some View {
        HStack(spacing: 16) {
            progressMetric(
                icon: "music.note.list",
                value: "\(session.tracksPlayed)",
                label: "Tracks"
            )

            progressMetric(
                icon: "arrow.up.right",
                value: "\(Int(session.progress * 100))%",
                label: "Progress"
            )

            progressMetric(
                icon: "target",
                value: valenceLabel(session.targetValence),
                label: "Target"
            )
        }
        .padding(.top, 4)
    }

    private func progressMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption2).foregroundStyle(ResonanceColors.accent).accessibilityHidden(true)
            Text(value).font(.subheadline).fontWeight(.semibold).monospacedDigit()
            Text(label).font(.system(size: 9)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Completion Content

    private var completionContent: some View {
        VStack(spacing: 16) {
            completionHeader
            moodComparison
            completionStats

            Text("Music-based mood support is not a substitute for professional mental health care.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var completionHeader: some View {
        let (icon, color, message): (String, Color, String) = {
            switch session.completionReason {
            case .targetReached:  return ("checkmark.seal.fill", .green, "Target mood reached and verified")
            case .timeoutElapsed: return ("clock.badge.checkmark", ResonanceColors.accent, "Session time limit reached")
            case .userCancelled:  return ("xmark.circle", .secondary, "Session ended by user")
            case .inProgress:     return ("circle", .secondary, "Session in progress")
            }
        }()
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundStyle(color).font(.subheadline).accessibilityHidden(true)
                    Text("Session Complete").font(.headline)
                }
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var moodComparison: some View {
        let afterValence = session.valenceProgression.last ?? session.startValence
        return HStack(spacing: 20) {
            moodComparisonItem(label: "Before", valence: session.startValence)
            Image(systemName: "arrow.right").font(.title3).foregroundStyle(.secondary).accessibilityHidden(true)
            moodComparisonItem(label: "After", valence: afterValence)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mood changed from \(valenceLabel(session.startValence)) to \(valenceLabel(afterValence))")
    }

    private func moodComparisonItem(label: String, valence: Double) -> some View {
        let color = colorForValence(valence)
        return VStack(spacing: 6) {
            Text(label).font(.caption2).foregroundStyle(.tertiary)
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 56, height: 56)
                Circle().fill(color.opacity(0.3)).frame(width: 40, height: 40)
                Text(valenceEmoji(valence)).font(.title2)
            }
            Text(valenceLabel(valence)).font(.caption).fontWeight(.medium).foregroundStyle(color)
        }
    }

    // MARK: - Completion Stats

    private var completionStats: some View {
        HStack(spacing: 16) {
            progressMetric(
                icon: "music.note.list",
                value: "\(session.tracksPlayed)",
                label: "Tracks Played"
            )

            progressMetric(
                icon: "clock",
                value: formattedElapsed,
                label: "Duration"
            )

            let verifiedCount = session.rungs.filter(\.hrvVerified).count
            progressMetric(
                icon: "checkmark.shield",
                value: "\(verifiedCount)/\(session.rungs.count)",
                label: "HRV Verified"
            )
        }
    }

    /// Maps valence to a calming color (muted warm tones, no reds).
    private func colorForValence(_ valence: Double) -> Color {
        switch valence {
        case ..<0.15:
            return deepDistressColor
        case 0.15..<0.25:
            return moderateDistressColor
        case 0.25..<0.35:
            return mildDistressColor
        case 0.35..<0.45:
            return approachingNeutralColor
        default:
            return neutralColor
        }
    }

    // MARK: - Label Helpers

    private func valenceLabel(_ valence: Double) -> String {
        switch valence {
        case ..<0.15: return "Very Low"
        case 0.15..<0.25: return "Low"
        case 0.25..<0.35: return "Below Avg"
        case 0.35..<0.45: return "Near Neutral"
        case 0.45..<0.55: return "Neutral"
        case 0.55..<0.70: return "Positive"
        default: return "Very Positive"
        }
    }

    private func valenceEmoji(_ valence: Double) -> String {
        switch valence {
        case ..<0.20: return "\u{1F614}" // pensive face
        case 0.20..<0.35: return "\u{1F615}" // confused face
        case 0.35..<0.50: return "\u{1F610}" // neutral face
        case 0.50..<0.65: return "\u{1F642}" // slightly smiling
        default: return "\u{1F60A}" // smiling with eyes
        }
    }

    private func rungLabel(for rung: LadderRung, index: Int) -> String {
        if index == 0 {
            return "Match (Start)"
        } else if index == session.rungs.count - 1 {
            return "Target (Neutral)"
        } else {
            return "Shift +\(index)"
        }
    }

    private func rungAccessibilityLabel(rung: LadderRung, index: Int) -> String {
        let label = rungLabel(for: rung, index: index)
        let valence = valenceLabel(rung.targetValence)
        let status: String
        if index == session.currentStep && session.isActive {
            status = "Current position"
        } else if index < session.currentStep {
            status = rung.hrvVerified ? "Completed, HRV verified" : "Completed"
        } else {
            status = "Upcoming"
        }
        return "\(label), valence \(valence), \(status)"
    }

    // MARK: - Time Formatting

    private var formattedElapsed: String {
        let totalSeconds = Int(session.elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

private enum MoodLadderPreviewData {
    static let now = Date()
    static var moderateActive: MoodLadderSession {
        MoodLadderSession(
            startState: .moderateDistress, startValence: 0.18, targetValence: 0.50,
            rungs: [
                LadderRung(targetValence: 0.18, hrvVerified: true, hrvAtRung: 32, reachedAt: now.addingTimeInterval(-240)),
                LadderRung(targetValence: 0.28, hrvVerified: true, hrvAtRung: 36, reachedAt: now.addingTimeInterval(-120)),
                LadderRung(targetValence: 0.38), LadderRung(targetValence: 0.48),
            ],
            currentStep: 2, tracksPlayed: 4, hrvAtEachStep: [32, 36, nil, nil],
            valenceProgression: [0.18, 0.22, 0.30, 0.34],
            startedAt: now.addingTimeInterval(-300), completionReason: .inProgress)
    }
    static var completed: MoodLadderSession {
        MoodLadderSession(
            startState: .mildDistress, startValence: 0.28, targetValence: 0.50,
            rungs: [
                LadderRung(targetValence: 0.28, hrvVerified: true, hrvAtRung: 38, reachedAt: now.addingTimeInterval(-360)),
                LadderRung(targetValence: 0.38, hrvVerified: true, hrvAtRung: 42, reachedAt: now.addingTimeInterval(-180)),
                LadderRung(targetValence: 0.48, hrvVerified: true, hrvAtRung: 48, reachedAt: now),
            ],
            currentStep: 3, tracksPlayed: 6, hrvAtEachStep: [38, 42, 48],
            valenceProgression: [0.28, 0.33, 0.40, 0.46, 0.49, 0.52],
            startedAt: now.addingTimeInterval(-420), completionReason: .targetReached)
    }
    static var acuteActive: MoodLadderSession {
        MoodLadderSession(
            startState: .acuteDistress, startValence: 0.08, targetValence: 0.50,
            rungs: [
                LadderRung(targetValence: 0.08, hrvVerified: true, hrvAtRung: 22, reachedAt: now.addingTimeInterval(-480)),
                LadderRung(targetValence: 0.18, hrvVerified: true, hrvAtRung: 25, reachedAt: now.addingTimeInterval(-360)),
                LadderRung(targetValence: 0.28), LadderRung(targetValence: 0.38),
                LadderRung(targetValence: 0.48),
            ],
            currentStep: 2, tracksPlayed: 3, hrvAtEachStep: [22, 25, nil, nil, nil],
            valenceProgression: [0.08, 0.14, 0.20],
            startedAt: now.addingTimeInterval(-480), completionReason: .inProgress)
    }
}

#Preview("Active - Moderate Distress") {
    MoodLadderView(session: MoodLadderPreviewData.moderateActive)
        .padding().background(Color(.systemGroupedBackground))
}

#Preview("Completed - Target Reached") {
    MoodLadderView(session: MoodLadderPreviewData.completed)
        .padding().background(Color(.systemGroupedBackground))
}

#Preview("Active - Acute Distress") {
    MoodLadderView(session: MoodLadderPreviewData.acuteActive)
        .padding().background(Color(.systemGroupedBackground))
}

#endif
