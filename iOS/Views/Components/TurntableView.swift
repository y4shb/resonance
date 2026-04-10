//
//  TurntableView.swift
//  Resonance
//
//  Composite turntable assembly: VinylRecordView + TonearmView on a
//  platter base, with rotation driven by VinylRotationController.
//  Manages the full-bleed blurred artwork background, song info,
//  transport controls, and coordinates sound effects.
//

import SwiftUI
import MusicKit

// MARK: - Turntable View

struct TurntableView: View {
    // MARK: - Properties

    @Bindable var viewModel: NowPlayingViewModel
    @ObservedObject var stateEngine: StateEngine
    var heroNamespace: Namespace.ID?

    // Rotation engine
    @State private var rotationController = VinylRotationController()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // Transport haptic triggers
    @State private var playPauseTrigger = 0
    @State private var skipTrigger = 0
    @State private var previousTrigger = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // Full-bleed blurred artwork background
            turntableBackground

            VStack(spacing: 0) {
                Spacer(minLength: 4)

                // Turntable assembly
                turntableAssembly
                    .padding(.bottom, 16)

                // Time labels
                timeLabels
                    .padding(.horizontal, 40)
                    .padding(.bottom, 8)

                Spacer(minLength: 4)
            }
        }
        .onChange(of: viewModel.isPlaying) { _, playing in
            rotationController.sync(with: playing)
            handlePlayStateChange(playing)
        }
        .onAppear {
            rotationController.sync(with: viewModel.isPlaying)
            if viewModel.isPlaying {
                VinylSFXPlayer.shared.startCrackle()
            }
        }
        .onDisappear {
            VinylSFXPlayer.shared.stopCrackle()
        }
    }

    // MARK: - Turntable Assembly

    private var turntableAssembly: some View {
        TimelineView(.animation(paused: !rotationController.isPlaying)) { timeline in
            ZStack(alignment: .topTrailing) {
                // Platter base (slightly larger than record)
                Circle()
                    .fill(VinylConstants.platterBase)
                    .frame(
                        width: VinylConstants.recordDiameterLarge + 20,
                        height: VinylConstants.recordDiameterLarge + 20
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 12)

                // Spinning vinyl record
                VinylRecordView(
                    artwork: viewModel.currentSong.artwork,
                    diameter: VinylConstants.recordDiameterLarge,
                    rotationDegrees: rotationController.degrees(at: timeline.date)
                )
                .modifier(HeroVinylModifier(namespace: heroNamespace))
                .frame(
                    width: VinylConstants.recordDiameterLarge,
                    height: VinylConstants.recordDiameterLarge
                )
                .position(
                    x: (VinylConstants.recordDiameterLarge + 20) / 2,
                    y: (VinylConstants.recordDiameterLarge + 20) / 2
                )

                // Tonearm overlay
                TonearmView(
                    progress: viewModel.playbackProgress,
                    isPlaying: viewModel.isPlaying,
                    onSeek: { progress in
                        viewModel.seek(to: progress)
                    },
                    onSeekStarted: {
                        viewModel.seekStarted()
                    }
                )
                .frame(width: 160, height: 200)
                .offset(x: 10, y: -10)
            }
            .frame(
                width: VinylConstants.recordDiameterLarge + 80,
                height: VinylConstants.recordDiameterLarge + 40
            )
        }
        .coordinateSpace(name: "turntable")
    }

    // MARK: - Time Labels

    private var timeLabels: some View {
        HStack {
            Text(viewModel.currentTime.formattedMinutesSeconds)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            Text(viewModel.duration.formattedMinutesSeconds)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Background

    private var turntableBackground: some View {
        ZStack {
            ResonanceColors.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()

            if let artwork = viewModel.currentSong.artwork {
                ArtworkImage(artwork, width: 600)
                    .blur(radius: 60)
                    .opacity(0.4)
                    .scaleEffect(1.2)
                    .ignoresSafeArea()
                    .animation(
                        reduceMotion ? .none : .easeInOut(duration: 0.8),
                        value: viewModel.currentSong.appleMusicId
                    )
            }

            // Dark scrim for readability
            Color.black.opacity(0.3)
                .ignoresSafeArea()
        }
    }

    // MARK: - Play State Changes

    private func handlePlayStateChange(_ playing: Bool) {
        if playing {
            VinylSFXPlayer.shared.playNeedleDrop()
            VinylSFXPlayer.shared.startCrackle()
        } else {
            VinylSFXPlayer.shared.playNeedleLift()
            VinylSFXPlayer.shared.stopCrackle()
        }
    }
}

// MARK: - Hero Vinyl Modifier

/// Conditionally applies matchedGeometryEffect for hero transitions.
private struct HeroVinylModifier: ViewModifier {
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content
                .matchedGeometryEffect(id: "heroArtwork", in: namespace)
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    TurntableView(
        viewModel: NowPlayingViewModel(musicService: MusicKitService()),
        stateEngine: StateEngine(
            contextCollector: ContextCollector(),
            healthKitService: HealthKitService()
        )
    )
}
