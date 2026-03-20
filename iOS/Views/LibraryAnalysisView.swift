//
//  LibraryAnalysisView.swift
//  Resonance
//
//  Displays library analysis progress on first launch with a pulsing brain icon,
//  song count, progress bar, and current phase indicator.
//

#if os(iOS)

import SwiftUI

// MARK: - Library Analysis View

/// Full-screen view shown during the initial library analysis after onboarding.
/// Displays a pulsing brain icon, progress bar, song count, and a skip button.
struct LibraryAnalysisView: View {

    // MARK: - Properties

    /// The library analysis engine driving this view's progress state.
    let engine: LibraryAnalysisEngine

    /// Callback invoked when analysis completes or the user taps "Skip for Now".
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants

    /// Size of the pulsing brain icon in points.
    private static let brainIconSize: CGFloat = 72

    // MARK: - Computed Properties

    /// Clamped progress to guard against negative or out-of-range values.
    private var clampedProgress: Double {
        min(1, max(0, engine.progress))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Pulsing brain icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: Self.brainIconSize))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, isActive: !engine.isComplete && !reduceMotion)
                .accessibilityHidden(true)

            // Title
            Text("Analyzing Your Library")
                .font(.title)
                .fontWeight(.bold)

            // Song count
            if engine.totalSongs > 0 {
                Text("\(engine.analyzedSongs) of \(engine.totalSongs) songs")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text("Preparing analysis...")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: clampedProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .accessibilityLabel("Analysis progress")
                    .accessibilityValue("\(Int(clampedProgress * 100)) percent")

                // Current phase
                Text(engine.currentPhase.isEmpty ? "Starting..." : engine.currentPhase)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Skip button
            Button {
                onComplete()
            } label: {
                Text("Skip for Now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Skip library analysis")
            .accessibilityHint("Skips the analysis and enters the app. Analysis can continue in the background.")
            .padding(.bottom, 40)
        }
        .padding()
        .onChange(of: engine.isComplete) { _, isComplete in
            if isComplete {
                onComplete()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let engine = LibraryAnalysisEngine()
    LibraryAnalysisView(engine: engine) {
        // no-op
    }
}

#endif
