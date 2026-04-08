//
//  ResonanceScoreTrendView.swift
//  Resonance
//
//  Weekly/monthly trend chart for resonance scores using Swift Charts.
//  Displays a smooth line chart with gradient fill and segmented time range picker.
//

import SwiftUI
import Charts

// MARK: - Resonance Score Trend View

struct ResonanceScoreTrendView: View {
    let scores: [ResonanceScoreHistoryEntry]
    @State private var selectedRange: TrendRange = .week

    // MARK: - Trend Range

    enum TrendRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case allTime = "All Time"

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .allTime: return nil
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Range picker
            Picker("Range", selection: $selectedRange) {
                ForEach(TrendRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if filteredScores.isEmpty {
                emptyStateView
            } else {
                chartView
                statsRow
            }
        }
        .navigationTitle("Resonance Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart(filteredScores) { entry in
            // Area fill
            AreaMark(
                x: .value("Date", entry.date),
                y: .value("Score", entry.score)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [ResonanceColors.accent.opacity(0.3), ResonanceColors.accent.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            // Line
            LineMark(
                x: .value("Date", entry.date),
                y: .value("Score", entry.score)
            )
            .foregroundStyle(ResonanceColors.accent)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)

            // Data points
            PointMark(
                x: .value("Date", entry.date),
                y: .value("Score", entry.score)
            )
            .foregroundStyle(ResonanceColors.accent)
            .symbolSize(filteredScores.count > 14 ? 0 : 30)
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: xAxisTickCount)) { _ in
                AxisGridLine()
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .frame(height: 220)
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartAccessibilityLabel)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(averageScore)",
                label: "Average",
                color: averageScoreColor
            )

            Divider()
                .frame(height: 30)

            statItem(
                value: "\(highScore)",
                label: "Best",
                color: .green
            )

            Divider()
                .frame(height: 30)

            statItem(
                value: "\(filteredScores.count)",
                label: "Sessions",
                color: ResonanceColors.accent
            )
        }
        .padding(.horizontal)
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Data Yet")
                .font(.headline)

            Text("Complete listening sessions to see your resonance score trends here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 220)
        .padding()
    }

    // MARK: - Computed Properties

    private var filteredScores: [ResonanceScoreHistoryEntry] {
        guard let days = selectedRange.days else { return scores }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return scores.filter { $0.date >= cutoff }
    }

    private var averageScore: Int {
        guard !filteredScores.isEmpty else { return 0 }
        let total = filteredScores.reduce(0) { $0 + $1.score }
        // Use Double division + rounding to avoid truncation bias from integer division
        return Int(round(Double(total) / Double(filteredScores.count)))
    }

    private var highScore: Int {
        filteredScores.map(\.score).max() ?? 0
    }

    private var averageScoreColor: Color {
        if averageScore >= 85 { return .green }
        if averageScore >= 70 { return ResonanceColors.accent }
        if averageScore >= 50 { return .orange }
        return .red
    }

    private var xAxisTickCount: Int {
        switch selectedRange {
        case .week: return 7
        case .month: return 5
        case .allTime: return 6
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month, .allTime:
            return .dateTime.month(.abbreviated).day()
        }
    }

    private var chartAccessibilityLabel: String {
        "Resonance score trend chart showing \(filteredScores.count) sessions "
        + "with an average score of \(averageScore)"
    }
}

// MARK: - Preview

#Preview {
    let sampleScores: [ResonanceScoreHistoryEntry] = (0..<14).map { i in
        ResonanceScoreHistoryEntry(
            id: UUID(),
            date: Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(),
            score: Int.random(in: 55...95),
            biometricScore: Int.random(in: 50...100),
            engagementScore: Int.random(in: 50...100),
            tracksPlayed: Int.random(in: 5...20),
            sessionDuration: Double.random(in: 900...3600),
            sessionIntent: "energize"
        )
    }

    NavigationStack {
        ResonanceScoreTrendView(scores: sampleScores)
    }
}
