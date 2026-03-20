//
//  AmbientGlowView.swift
//  Resonance
//
//  Renders a soft radial glow behind album artwork using the dominant color
//  extracted from the current track's album art. The glow animates smoothly
//  when the color transitions between songs.
//
//  P2-21: Album Art Ambient Glow
//

import SwiftUI

// MARK: - Ambient Glow View

/// A radial gradient background that creates a soft ambient glow effect
/// using the dominant color from album artwork.
///
/// The glow radiates outward from the center at 25% opacity, fading to clear.
/// Color transitions are animated with a smooth crossfade when the track changes.
struct AmbientGlowView: View {
    // MARK: - Properties

    /// The dominant color extracted from the current album artwork.
    let color: Color

    /// Whether to respect the user's reduce motion preference.
    let reduceMotion: Bool

    /// The blur radius for softening the glow edges.
    private let blurRadius: CGFloat = 40

    /// The transition animation duration in seconds.
    private let transitionDuration = 1.2

    // MARK: - State

    /// Internal opacity state used for animated transitions.
    @State private var glowOpacity = 1.0

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            RadialGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.25),
                    color.opacity(0.12),
                    color.opacity(0.04),
                    Color.clear
                ]),
                center: .center,
                startRadius: 20,
                endRadius: geometry.size.width * 0.8
            )
            .blur(radius: blurRadius)
            .opacity(glowOpacity)
        }
        .ignoresSafeArea()
        .onChange(of: color.description) {
            animateColorTransition()
        }
    }

    // MARK: - Animation

    /// Animates a subtle opacity pulse when the glow color changes,
    /// creating a smooth crossfade between tracks.
    private func animateColorTransition() {
        guard !reduceMotion else { return }

        withAnimation(.easeOut(duration: transitionDuration * 0.3)) {
            glowOpacity = 0.4
        }

        withAnimation(
            .easeIn(duration: transitionDuration * 0.7)
                .delay(transitionDuration * 0.3)
        ) {
            glowOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Ambient Glow - Blue") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientGlowView(color: .blue, reduceMotion: false)
        Text("Album Art")
            .font(.title)
            .foregroundStyle(.white)
    }
}

#Preview("Ambient Glow - Orange") {
    ZStack {
        Color(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x12 / 255.0)
            .ignoresSafeArea()
        AmbientGlowView(color: .orange, reduceMotion: false)
        Text("Album Art")
            .font(.title)
            .foregroundStyle(.white)
    }
}
