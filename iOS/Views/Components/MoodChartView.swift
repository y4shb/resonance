//
//  MoodChartView.swift
//  Resonance
//
//  Circular donut chart visualizing the distribution of songs across
//  EmotionCategory values. Uses custom SwiftUI Path drawing with
//  animatable arc segments. Tapping a segment highlights it and shows
//  the mood name and song count in the center.
//

import SwiftUI
import CoreData

// MARK: - Mood Segment

/// Data for a single arc segment in the mood donut chart.
struct MoodSegment: Identifiable, Equatable {
    let id: String
    let category: EmotionCategory
    let count: Int
    let startAngle: Double   // radians
    let endAngle: Double     // radians

    static func == (lhs: MoodSegment, rhs: MoodSegment) -> Bool {
        lhs.id == rhs.id && lhs.count == rhs.count
    }
}

// MARK: - Mood Arc Segment Shape

/// A single arc segment shape with animatable start/end angles.
struct MoodArcSegment: Shape {
    var startAngle: Double
    var endAngle: Double
    var outerRadius: CGFloat
    var innerRadius: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle, endAngle) }
        set {
            startAngle = newValue.first
            endAngle = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Offset by -90 degrees so 0 starts at the top
        let rotationOffset = Angle.degrees(-90)
        let start = Angle.radians(startAngle) + rotationOffset
        let end = Angle.radians(endAngle) + rotationOffset

        var path = Path()

        // Outer arc (clockwise)
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )

        // Line to inner arc
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: end,
            endAngle: start,
            clockwise: true
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Mood Chart View

/// Donut chart showing song distribution by emotion category.
///
/// Each arc segment represents an `EmotionCategory` sized by song count.
/// Tiny segments (under 8 degrees) are merged into an "Other" bucket.
/// Tapping a segment highlights it and displays the mood name plus count
/// in the donut's center hole.
struct MoodChartView: View {
    // MARK: - Properties

    let songs: [Song]

    /// Called when the user taps a segment to navigate to the mood detail.
    var onSegmentSelected: ((EmotionCategory, [Song]) -> Void)?

    @State private var selectedSegment: MoodSegment?
    @State private var segments: [MoodSegment] = []
    @State private var otherCount = 0
    @State private var isOtherSelected = false
    @State private var animateChart = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Chart Dimensions

    /// Outer radius of the donut chart in points.
    private let outerRadius: CGFloat = 140

    /// Inner radius as a fraction of the outer radius (donut hole size).
    private let innerRadiusRatio: CGFloat = 0.6

    /// Minimum arc angle (degrees) before a segment is merged into "Other".
    private let minimumAngleDegrees: Double = 8

    /// Gap between adjacent arc segments in radians.
    private let gapRadians: Double = 0.02

    private var innerRadius: CGFloat {
        outerRadius * innerRadiusRatio
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            if songs.isEmpty {
                emptyChartView
            } else {
                chartHeader

                ZStack {
                    // Arc segments
                    ForEach(segments) { segment in
                        segmentView(for: segment)
                    }

                    // "Other" arc if present
                    if let otherSegment = buildOtherSegment() {
                        otherSegmentView(for: otherSegment)
                    }

                    // Center label
                    centerLabel
                }
                .frame(width: outerRadius * 2, height: outerRadius * 2)
                .onAppear {
                    buildSegments()
                    if reduceMotion {
                        animateChart = true
                    } else {
                        withAnimation(.easeOut(duration: 0.6)) {
                            animateChart = true
                        }
                    }
                }
                .onChange(of: songs.count) {
                    buildSegments()
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Mood distribution chart with \(segments.count) categories")
            }
        }
    }

    // MARK: - Empty Chart View

    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Mood Data")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Mood distribution will appear after your library is analyzed.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Chart Header

    private var chartHeader: some View {
        HStack {
            Image(systemName: "chart.pie.fill")
                .foregroundStyle(ResonanceColors.accent)
                .font(.caption)
                .accessibilityHidden(true)

            Text("Mood Distribution")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Text("\(songs.count) songs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mood Distribution, \(songs.count) songs")
    }

    // MARK: - Segment View

    @ViewBuilder
    private func segmentView(for segment: MoodSegment) -> some View {
        let isSelected = selectedSegment?.id == segment.id && !isOtherSelected

        MoodArcSegment(
            startAngle: animateChart ? segment.startAngle : 0,
            endAngle: animateChart ? segment.endAngle : 0,
            outerRadius: isSelected ? outerRadius + 6 : outerRadius,
            innerRadius: isSelected ? innerRadius - 2 : innerRadius
        )
        .fill(segment.category.color.opacity(isSelected ? 1.0 : 0.8))
        .shadow(color: isSelected ? segment.category.color.opacity(0.4) : .clear, radius: 6)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: isSelected)
        .onTapGesture {
            handleSegmentTap(segment)
        }
        .accessibilityLabel("\(segment.category.displayName): \(segment.count) songs")
        .accessibilityHint("Tap to view songs in this mood")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func otherSegmentView(for segment: MoodSegment) -> some View {
        let isSelected = isOtherSelected

        MoodArcSegment(
            startAngle: animateChart ? segment.startAngle : 0,
            endAngle: animateChart ? segment.endAngle : 0,
            outerRadius: isSelected ? outerRadius + 6 : outerRadius,
            innerRadius: isSelected ? innerRadius - 2 : innerRadius
        )
        .fill(Color.gray.opacity(isSelected ? 0.7 : 0.5))
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: isSelected)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOtherSelected.toggle()
                if isOtherSelected {
                    selectedSegment = nil
                }
            }
        }
        .accessibilityLabel("Other: \(otherCount) songs")
    }

    // MARK: - Center Label

    private var centerLabel: some View {
        VStack(spacing: 4) {
            if let selected = selectedSegment, !isOtherSelected {
                Text(selected.category.displayName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(selected.category.color)
                    .transition(.opacity)

                Text("\(selected.count) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if isOtherSelected {
                Text("Other")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                    .transition(.opacity)

                Text("\(otherCount) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else {
                Image(systemName: "waveform.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)

                Text("Tap a mood")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
        }
        .frame(width: innerRadius * 1.4)
        .multilineTextAlignment(.center)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: selectedSegment?.id)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: isOtherSelected)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Segment Building

    /// Groups songs by emotion category and computes arc angles.
    private func buildSegments() {
        guard !songs.isEmpty else {
            segments = []
            otherCount = 0
            return
        }

        // Classify each song
        var categoryCounts: [EmotionCategory: Int] = [:]
        for song in songs {
            let category = EmotionCategory.classify(
                energy: song.energyEstimate,
                valence: song.valence
            )
            categoryCounts[category, default: 0] += 1
        }

        let totalSongs = Double(songs.count)
        let minimumAngleRadians = minimumAngleDegrees * .pi / 180.0

        // Separate significant vs tiny segments
        var significant: [(EmotionCategory, Int)] = []
        var tinyTotal = 0

        for category in EmotionCategory.allCases {
            guard let count = categoryCounts[category], count > 0 else { continue }
            let angle = (Double(count) / totalSongs) * 2.0 * .pi
            if angle >= minimumAngleRadians {
                significant.append((category, count))
            } else {
                tinyTotal += count
            }
        }

        otherCount = tinyTotal

        // Compute arc angles for significant segments
        let significantTotal = significant.reduce(0) { $0 + $1.1 }
        let availableAngle = 2.0 * .pi - (tinyTotal > 0 ? minimumAngleRadians : 0)
        let totalGap = gapRadians * Double(significant.count + (tinyTotal > 0 ? 1 : 0))
        let drawableAngle = max(availableAngle - totalGap, 0)

        var builtSegments: [MoodSegment] = []
        var currentAngle = 0.0

        for (category, count) in significant {
            let proportion = Double(count) / Double(significantTotal)
            let sweep = proportion * drawableAngle
            let start = currentAngle
            let end = currentAngle + sweep

            builtSegments.append(MoodSegment(
                id: category.rawValue,
                category: category,
                count: count,
                startAngle: start,
                endAngle: end
            ))

            currentAngle = end + gapRadians
        }

        segments = builtSegments
    }

    /// Builds the "Other" segment if tiny categories exist.
    private func buildOtherSegment() -> MoodSegment? {
        guard otherCount > 0, let lastSegment = segments.last else { return nil }

        let start = lastSegment.endAngle + gapRadians
        let end = 2.0 * .pi

        return MoodSegment(
            id: "other",
            category: .chill, // placeholder -- color is overridden
            count: otherCount,
            startAngle: start,
            endAngle: end
        )
    }

    // MARK: - Interaction

    private func handleSegmentTap(_ segment: MoodSegment) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isOtherSelected = false
            if selectedSegment?.id == segment.id {
                // Second tap navigates to detail
                let matchingSongs = songs.filter { song in
                    EmotionCategory.classify(
                        energy: song.energyEstimate,
                        valence: song.valence
                    ) == segment.category
                }
                onSegmentSelected?(segment.category, matchingSongs)
                selectedSegment = nil
            } else {
                selectedSegment = segment
            }
        }
    }
}
