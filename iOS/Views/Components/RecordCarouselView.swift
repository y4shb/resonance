//
//  RecordCarouselView.swift
//  Resonance
//
//  3D CoverFlow-style horizontal album browser with vinyl sleeve cards.
//  Centered album faces forward; off-center items tilt on the Y-axis,
//  scale down, and fade. Magnetic snap-to-center behavior.
//

import SwiftUI
import MusicKit

// MARK: - Record Carousel View

struct RecordCarouselView: View {
    // MARK: - Properties

    /// Albums to display in the carousel
    let albums: [AlbumDisplayInfo]

    /// Callback when an album is tapped (navigates to Now Playing)
    var onAlbumSelected: ((AlbumDisplayInfo) -> Void)?

    /// Optional namespace for hero transitions to turntable
    var heroNamespace: Namespace.ID?

    @State private var centeredAlbumID: AlbumDisplayInfo.ID?

    private let cardSize: CGFloat = VinylConstants.recordDiameterCarousel + 20

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let screenWidth = proxy.size.width

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(albums) { album in
                        VinylSleeveCard(album: album)
                            .frame(width: cardSize, height: cardSize)
                            .scrollTransition(.interactive) { content, phase in
                                content
                                    .rotation3DEffect(
                                        .degrees(phase.value * -35),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.5
                                    )
                                    .scaleEffect(1 - abs(phase.value) * 0.15)
                                    .opacity(1 - abs(phase.value) * 0.3)
                            }
                            .onTapGesture {
                                onAlbumSelected?(album)
                            }
                            .id(album.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, (screenWidth - cardSize) / 2)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredAlbumID)
        }
        .frame(height: cardSize + 20)
        .accessibilityLabel("Album carousel")
        .accessibilityHint("Swipe left or right to browse albums. Tap to play.")
    }
}

// MARK: - Album Display Info

/// Lightweight album info for the carousel (decoupled from MusicKit).
struct AlbumDisplayInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let artwork: Artwork?
}

// MARK: - Vinyl Sleeve Card

/// A single album in the carousel, displayed as a square sleeve
/// with a vinyl disc edge peeking from the right side.
private struct VinylSleeveCard: View {
    let album: AlbumDisplayInfo

    var body: some View {
        ZStack(alignment: .trailing) {
            // Vinyl disc edge peeking out from right
            vinylEdge

            // Album artwork sleeve
            sleeveArtwork
        }
        .shadow(color: .black.opacity(0.35), radius: 8, x: 2, y: 4)
        .accessibilityLabel("\(album.title) by \(album.artistName)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to play this album")
    }

    // MARK: - Sleeve Artwork

    private var sleeveArtwork: some View {
        Group {
            if let artwork = album.artwork {
                ArtworkImage(artwork, width: VinylConstants.recordDiameterCarousel)
                    .cornerRadius(4)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(
                        width: VinylConstants.recordDiameterCarousel,
                        height: VinylConstants.recordDiameterCarousel
                    )
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.4))
                            Text(album.title)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    )
            }
        }
    }

    // MARK: - Vinyl Edge

    /// A thin dark semicircle peeking from the right side of the sleeve,
    /// simulating a vinyl record partially removed from its cover.
    private var vinylEdge: some View {
        Circle()
            .fill(VinylConstants.vinylBlack)
            .frame(
                width: VinylConstants.recordDiameterCarousel - 8,
                height: VinylConstants.recordDiameterCarousel - 8
            )
            .offset(x: 8)
            .mask(
                Rectangle()
                    .frame(width: 16, height: VinylConstants.recordDiameterCarousel)
                    .offset(x: (VinylConstants.recordDiameterCarousel / 2) - 4)
            )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        RecordCarouselView(
            albums: [
                AlbumDisplayInfo(id: "1", title: "Abbey Road", artistName: "The Beatles", artwork: nil),
                AlbumDisplayInfo(id: "2", title: "Dark Side of the Moon", artistName: "Pink Floyd", artwork: nil),
                AlbumDisplayInfo(id: "3", title: "Thriller", artistName: "Michael Jackson", artwork: nil),
                AlbumDisplayInfo(id: "4", title: "Kind of Blue", artistName: "Miles Davis", artwork: nil),
            ],
            onAlbumSelected: { album in
                print("Selected: \(album.title)")
            }
        )
    }
}
