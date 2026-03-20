//
//  ResonanceComponents.swift
//  Resonance
//
//  Reusable UI components for the Resonance design system.
//  Provides consistent styling across all screens: cards, buttons,
//  badges, metric cells, and progress bars.
//

import SwiftUI

// MARK: - ResonanceCard

/// A glass-material card container with rounded corners and a subtle shadow.
///
/// Use this as a container for grouped content throughout the app.
///
///     ResonanceCard {
///         Text("Card content")
///     }
struct ResonanceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ResonanceColors.cardBackground)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - ResonancePrimaryButtonStyle

/// A capsule-shaped primary button with the accent color background.
///
/// Apply with `.buttonStyle(ResonancePrimaryButtonStyle())`.
struct ResonancePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ResonanceColors.accent)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - ResonanceSecondaryButtonStyle

/// A capsule-shaped secondary button with an ultra-thin material background.
///
/// Apply with `.buttonStyle(ResonanceSecondaryButtonStyle())`.
struct ResonanceSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - ResonanceStatusBadge

/// A compact status indicator with a colored dot and label text.
///
/// Renders as a capsule-shaped pill with a small colored circle and descriptive text.
///
///     ResonanceStatusBadge(text: "Active", color: .green)
struct ResonanceStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 0)
                .accessibilityHidden(true)

            Text(text)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(text)")
    }
}

// MARK: - ResonanceMetricCell

/// A vertical stat display showing an icon, value, and descriptive label.
///
/// Used in grids or stacks to present numeric metrics consistently.
///
///     ResonanceMetricCell(
///         icon: "clock.fill",
///         value: "45m",
///         label: "Duration",
///         color: .blue
///     )
struct ResonanceMetricCell: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - ResonanceProgressBar

/// A themed horizontal progress bar with a capsule track and fill.
///
/// The fill width animates smoothly when the progress value changes.
///
///     ResonanceProgressBar(progress: 0.75, color: .green, height: 6)
struct ResonanceProgressBar: View {
    /// Progress value from 0.0 to 1.0.
    let progress: Double

    /// Fill color for the progress indicator.
    var color: Color = ResonanceColors.accent

    /// Height of the progress bar in points.
    var height: CGFloat = 6

    /// Clamped progress value to prevent layout issues.
    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))

                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent")
    }
}

// MARK: - Previews

#Preview("ResonanceCard") {
    ResonanceCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card Title")
                .font(.headline)
            Text("Card content goes here with a description.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}

#Preview("Primary Button") {
    Button("Get Started") {}
        .buttonStyle(ResonancePrimaryButtonStyle())
        .padding()
}

#Preview("Secondary Button") {
    Button("Learn More") {}
        .buttonStyle(ResonanceSecondaryButtonStyle())
        .padding()
}

#Preview("Status Badge") {
    HStack(spacing: 12) {
        ResonanceStatusBadge(text: "Active", color: .green)
        ResonanceStatusBadge(text: "Paused", color: .orange)
        ResonanceStatusBadge(text: "Ended", color: .red)
    }
    .padding()
}

#Preview("Metric Cells") {
    LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ], spacing: 12) {
        ResonanceMetricCell(icon: "clock.fill", value: "45m", label: "Duration", color: .blue)
        ResonanceMetricCell(icon: "music.note", value: "12", label: "Songs", color: .purple)
        ResonanceMetricCell(icon: "forward.fill", value: "8%", label: "Skip Rate", color: .green)
    }
    .padding()
}

#Preview("Progress Bars") {
    VStack(spacing: 16) {
        ResonanceProgressBar(progress: 0.25, color: .red)
        ResonanceProgressBar(progress: 0.5, color: .orange)
        ResonanceProgressBar(progress: 0.75, color: .blue)
        ResonanceProgressBar(progress: 1.0, color: .green, height: 10)
    }
    .padding()
}
