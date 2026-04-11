//
//  CassettePlayerView.swift
//  Resonance
//
//  Realistic cassette tape where the ALBUM ARTWORK IS the cassette shell.
//  The entire cassette surface displays the current track's artwork, with
//  circular cutouts at the reel hub positions revealing the spinning reels
//  and wound tape beneath.
//
//  Standard compact cassette proportions: ~1.57:1 (width:height).
//  Uses .blendMode(.destinationOut) + .compositingGroup() to punch
//  transparent holes through the artwork layer.
//
//  The cassette ejects and inserts with a fluid spring animation when
//  tracks change, with haptic feedback at the "click" moment.
//

import SwiftUI
import MusicKit

// MARK: - Cassette Player View

struct CassettePlayerView: View {
    let artwork: MusicKit.Artwork?
    let isPlaying: Bool
    let playbackProgress: Double
    let accentColor: Color
    let songId: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Cassette swap animation state
    @State private var swapPhase: CassetteSwapPhase = .seated
    @State private var previousSongId: String = ""

    // MARK: - Dimensions

    private let cassetteWidth: CGFloat = 310
    private var cassetteHeight: CGFloat { cassetteWidth / 1.57 }

    // Reel window geometry
    private var reelWindowDiameter: CGFloat { cassetteHeight * 0.44 }
    private var reelCenterY: CGFloat { cassetteHeight * 0.54 }
    private var leftReelX: CGFloat { cassetteWidth * 0.24 }
    private var rightReelX: CGFloat { cassetteWidth * 0.76 }
    private var hubRadius: CGFloat { reelWindowDiameter * 0.15 }

    var body: some View {
        cassetteBody
            .onChange(of: songId) { oldValue, newValue in
                guard oldValue != newValue, !oldValue.isEmpty else {
                    previousSongId = newValue
                    return
                }
                triggerSwapAnimation()
                previousSongId = newValue
            }
            .onAppear { previousSongId = songId }
    }

    // MARK: - Cassette Body

    private var cassetteBody: some View {
        ZStack {
            // Layer 0: Dark interior (visible through reel cutouts)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.03, green: 0.03, blue: 0.05))

            // Layer 1: Tape spools (wound tape visible through cutouts)
            tapeSpools

            // Layer 2: Spinning reel hubs with gear teeth
            reelHubs

            // Layer 3: Album art with reel cutouts punched through
            albumArtWithCutouts

            // Layer 4: Cassette overlay details (sheen, bezels, screws, label)
            cassetteOverlays
        }
        .frame(width: cassetteWidth, height: cassetteHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .rotation3DEffect(.degrees(2), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
        // Swap animation modifiers
        .offset(y: swapOffset)
        .scaleEffect(swapScale)
        .opacity(swapOpacity)
        .rotation3DEffect(.degrees(swapTilt), axis: (x: 1, y: 0, z: 0))
    }

    // MARK: - Album Art with Reel Cutouts

    /// The album artwork fills the entire cassette shell. Circular holes are
    /// punched through at the reel positions using destinationOut blending,
    /// revealing the spinning tape reels underneath.
    private var albumArtWithCutouts: some View {
        ZStack {
            // Full-bleed album art as cassette shell
            Group {
                if let artwork = artwork {
                    ArtworkImage(artwork, width: cassetteWidth, height: cassetteWidth)
                        .scaledToFill()
                        .frame(width: cassetteWidth, height: cassetteHeight)
                        .clipped()
                        .overlay(
                            // Subtle darkening so reel chrome bezels stand out
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.1),
                                    Color.black.opacity(0.02),
                                    Color.black.opacity(0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    // Gradient placeholder when no artwork
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.35),
                            Color(red: 0.12, green: 0.12, blue: 0.15),
                            accentColor.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }

            // Punch out left reel window
            Circle()
                .fill(.black)
                .frame(width: reelWindowDiameter + 4, height: reelWindowDiameter + 4)
                .position(x: leftReelX, y: reelCenterY)
                .blendMode(.destinationOut)

            // Punch out right reel window
            Circle()
                .fill(.black)
                .frame(width: reelWindowDiameter + 4, height: reelWindowDiameter + 4)
                .position(x: rightReelX, y: reelCenterY)
                .blendMode(.destinationOut)

            // Tape head slot cutout at bottom center
            Capsule()
                .fill(.black)
                .frame(width: cassetteWidth * 0.18, height: 5)
                .position(x: cassetteWidth / 2, y: cassetteHeight - 10)
                .blendMode(.destinationOut)

            // Guide pin holes (flanking the head slot)
            Circle()
                .fill(.black)
                .frame(width: 5, height: 5)
                .position(x: cassetteWidth * 0.34, y: cassetteHeight - 10)
                .blendMode(.destinationOut)

            Circle()
                .fill(.black)
                .frame(width: 5, height: 5)
                .position(x: cassetteWidth * 0.66, y: cassetteHeight - 10)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    // MARK: - Tape Spools

    /// Brown circles representing wound magnetic tape. Supply (left) shrinks
    /// and take-up (right) grows as playback progresses.
    private var tapeSpools: some View {
        ZStack {
            // Left spool (supply — more tape at start)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.18, green: 0.13, blue: 0.08),
                            Color(red: 0.25, green: 0.18, blue: 0.12).opacity(0.8)
                        ],
                        center: .center,
                        startRadius: hubRadius * 1.5,
                        endRadius: spoolRadius(isSupply: true)
                    )
                )
                .frame(
                    width: spoolRadius(isSupply: true) * 2,
                    height: spoolRadius(isSupply: true) * 2
                )
                .position(x: leftReelX, y: reelCenterY)

            // Right spool (take-up — grows with progress)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.18, green: 0.13, blue: 0.08),
                            Color(red: 0.25, green: 0.18, blue: 0.12).opacity(0.8)
                        ],
                        center: .center,
                        startRadius: hubRadius * 1.5,
                        endRadius: spoolRadius(isSupply: false)
                    )
                )
                .frame(
                    width: spoolRadius(isSupply: false) * 2,
                    height: spoolRadius(isSupply: false) * 2
                )
                .position(x: rightReelX, y: reelCenterY)
        }
    }

    /// Tape spool radius varies with playback progress
    private func spoolRadius(isSupply: Bool) -> CGFloat {
        let minRadius = reelWindowDiameter * 0.20
        let maxRadius = reelWindowDiameter * 0.44
        if isSupply {
            return maxRadius - CGFloat(playbackProgress) * (maxRadius - minRadius)
        } else {
            return minRadius + CGFloat(playbackProgress) * (maxRadius - minRadius)
        }
    }

    // MARK: - Reel Hubs (spinning gear teeth)

    /// Metal reel hubs with gear teeth, rendered via Canvas for 120fps
    /// spinning animation on ProMotion displays.
    private var reelHubs: some View {
        TimelineView(.animation(paused: !isPlaying || reduceMotion)) { timeline in
            Canvas { context, size in
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let rpm: Double = isPlaying ? 1.5 : 0
                let angle = seconds * rpm * .pi * 2

                drawReelHub(in: &context, center: CGPoint(x: leftReelX, y: reelCenterY), angle: angle)
                drawReelHub(in: &context, center: CGPoint(x: rightReelX, y: reelCenterY), angle: angle)
            }
        }
        .frame(width: cassetteWidth, height: cassetteHeight)
        .allowsHitTesting(false)
    }

    private func drawReelHub(in context: inout GraphicsContext, center: CGPoint, angle: Double) {
        let teethCount = 6
        let toothLength: CGFloat = 4
        let toothWidth: CGFloat = 2.5

        // Hub circle
        let hubPath = Path(ellipseIn: CGRect(
            x: center.x - hubRadius,
            y: center.y - hubRadius,
            width: hubRadius * 2,
            height: hubRadius * 2
        ))
        context.fill(hubPath, with: .color(Color(red: 0.32, green: 0.32, blue: 0.36)))
        context.stroke(hubPath, with: .color(Color.white.opacity(0.2)), lineWidth: 0.5)

        // Gear teeth
        for i in 0..<teethCount {
            let toothAngle = angle + Double(i) * (.pi * 2 / Double(teethCount))
            let cosA = cos(toothAngle)
            let sinA = sin(toothAngle)
            let perpCos = cos(toothAngle + .pi / 2)
            let perpSin = sin(toothAngle + .pi / 2)

            let innerX = center.x + cosA * (hubRadius - 1)
            let innerY = center.y + sinA * (hubRadius - 1)
            let outerX = center.x + cosA * (hubRadius + toothLength)
            let outerY = center.y + sinA * (hubRadius + toothLength)

            var toothPath = Path()
            toothPath.move(to: CGPoint(
                x: innerX - perpCos * toothWidth / 2,
                y: innerY - perpSin * toothWidth / 2))
            toothPath.addLine(to: CGPoint(
                x: innerX + perpCos * toothWidth / 2,
                y: innerY + perpSin * toothWidth / 2))
            toothPath.addLine(to: CGPoint(
                x: outerX + perpCos * toothWidth / 2,
                y: outerY + perpSin * toothWidth / 2))
            toothPath.addLine(to: CGPoint(
                x: outerX - perpCos * toothWidth / 2,
                y: outerY - perpSin * toothWidth / 2))
            toothPath.closeSubpath()

            context.fill(toothPath, with: .color(Color(red: 0.32, green: 0.32, blue: 0.36)))
        }

        // Center spindle hole
        let holeRadius = hubRadius * 0.35
        let holePath = Path(ellipseIn: CGRect(
            x: center.x - holeRadius,
            y: center.y - holeRadius,
            width: holeRadius * 2,
            height: holeRadius * 2
        ))
        context.fill(holePath, with: .color(Color(red: 0.04, green: 0.04, blue: 0.06)))
    }

    // MARK: - Cassette Overlay Details

    /// Glass sheen, chrome reel bezels, label strip, corner screws, and border.
    /// All rendered on top of the album art layer.
    private var cassetteOverlays: some View {
        ZStack {
            // Glass sheen across the album art (simulates glossy cassette shell)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.white.opacity(0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Chrome bezels around reel windows
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: reelWindowDiameter + 6, height: reelWindowDiameter + 6)
                .position(x: leftReelX, y: reelCenterY)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: reelWindowDiameter + 6, height: reelWindowDiameter + 6)
                .position(x: rightReelX, y: reelCenterY)

            // Inner shadow rings (depth illusion inside reel windows)
            Circle()
                .stroke(Color.black.opacity(0.4), lineWidth: 1)
                .frame(width: reelWindowDiameter + 2, height: reelWindowDiameter + 2)
                .position(x: leftReelX, y: reelCenterY)

            Circle()
                .stroke(Color.black.opacity(0.4), lineWidth: 1)
                .frame(width: reelWindowDiameter + 2, height: reelWindowDiameter + 2)
                .position(x: rightReelX, y: reelCenterY)

            // Tape head slot bezel
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                .frame(width: cassetteWidth * 0.18 + 2, height: 7)
                .position(x: cassetteWidth / 2, y: cassetteHeight - 10)

            // Label strip at top (frosted band overlaid on artwork)
            VStack {
                HStack {
                    Rectangle()
                        .fill(accentColor.opacity(0.4))
                        .frame(width: 30, height: 1.5)
                        .cornerRadius(0.75)

                    Spacer()

                    Text("RESONANCE")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.6), radius: 2)

                    Spacer()

                    Rectangle()
                        .fill(accentColor.opacity(0.4))
                        .frame(width: 30, height: 1.5)
                        .cornerRadius(0.75)
                }
                .padding(.horizontal, 20)
                .padding(.top, cassetteHeight * 0.06)

                Spacer()
            }

            // Corner screws
            cornerScrews

            // Shell border with chrome highlight
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // Accent neon glow edge
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.12), lineWidth: 0.5)
                .blur(radius: 2)
        }
        .frame(width: cassetteWidth, height: cassetteHeight)
        .allowsHitTesting(false)
    }

    // MARK: - Corner Screws

    private var cornerScrews: some View {
        let screwSize: CGFloat = 6
        let inset: CGFloat = 8

        return ZStack {
            ForEach(0..<4, id: \.self) { corner in
                Circle()
                    .fill(Color(red: 0.28, green: 0.28, blue: 0.32))
                    .frame(width: screwSize, height: screwSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .overlay(
                        // Phillips head cross
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 0.5, height: screwSize * 0.6)
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: screwSize * 0.6, height: 0.5)
                        }
                    )
                    .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                    .position(screwPosition(corner: corner, inset: inset))
            }
        }
    }

    private func screwPosition(corner: Int, inset: CGFloat) -> CGPoint {
        switch corner {
        case 0: return CGPoint(x: inset, y: inset)
        case 1: return CGPoint(x: cassetteWidth - inset, y: inset)
        case 2: return CGPoint(x: inset, y: cassetteHeight - inset)
        case 3: return CGPoint(x: cassetteWidth - inset, y: cassetteHeight - inset)
        default: return .zero
        }
    }

    // MARK: - Swap Animation

    private var swapOffset: CGFloat {
        switch swapPhase {
        case .seated: return 0
        case .ejecting: return -280
        case .gone: return 280
        case .inserting: return 0
        }
    }

    private var swapScale: CGFloat {
        switch swapPhase {
        case .seated: return 1.0
        case .ejecting: return 0.9
        case .gone: return 0.85
        case .inserting: return 1.0
        }
    }

    private var swapOpacity: Double {
        switch swapPhase {
        case .seated: return 1.0
        case .ejecting: return 0.3
        case .gone: return 0
        case .inserting: return 1.0
        }
    }

    private var swapTilt: Double {
        switch swapPhase {
        case .seated: return 0
        case .ejecting: return -5
        case .gone: return 5
        case .inserting: return 0
        }
    }

    private func triggerSwapAnimation() {
        guard !reduceMotion else { return }

        // Phase 1: Eject current cassette
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            swapPhase = .ejecting
        }

        // Phase 2: Snap to "gone" (invisible, below screen)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.linear(duration: 0.01)) {
                swapPhase = .gone
            }

            // Phase 3: Insert new cassette from below
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                    swapPhase = .inserting
                }

                // Phase 4: Settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    swapPhase = .seated
                }
            }
        }

        // Haptic: cassette click
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            impact.impactOccurred()
        }
    }
}

// MARK: - Cassette Swap Phase

enum CassetteSwapPhase {
    case seated     // In the deck, normal position
    case ejecting   // Sliding up and out
    case gone       // Off-screen, invisible
    case inserting  // Sliding in from below
}

// MARK: - Preview

#Preview("Cassette - Album Art") {
    ZStack {
        Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
        CassettePlayerView(
            artwork: nil,
            isPlaying: true,
            playbackProgress: 0.35,
            accentColor: ResonanceColors.accent,
            songId: "test-song-1"
        )
    }
}

#Preview("Cassette - Paused") {
    ZStack {
        Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
        CassettePlayerView(
            artwork: nil,
            isPlaying: false,
            playbackProgress: 0.7,
            accentColor: .purple,
            songId: "test-song-2"
        )
    }
}
