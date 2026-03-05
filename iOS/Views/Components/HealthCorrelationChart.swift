//
//  HealthCorrelationChart.swift
//  Resonance
//
//  Overlays music BPM with heart rate and HRV on a synchronized timeline chart.
//  Uses Swift Charts framework for clear, interactive data visualization.
//  Shows the correlation between music choices and biometric responses.
//

import SwiftUI
import Charts

// MARK: - Chart Data Types

/// A single data point for the health correlation timeline.
struct CorrelationDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let series: CorrelationSeries
}

/// The type of data series in the chart.
enum CorrelationSeries: String, CaseIterable {
    case songBPM = "Song BPM"
    case heartRate = "Heart Rate"
    case hrvTrend = "HRV Trend"

    var color: Color {
        switch self {
        case .songBPM: return .blue
        case .heartRate: return .red
        case .hrvTrend: return .green
        }
    }

    var icon: String {
        switch self {
        case .songBPM: return "music.note"
        case .heartRate: return "heart.fill"
        case .hrvTrend: return "waveform.path.ecg"
        }
    }
}

// MARK: - Health Correlation Chart

struct HealthCorrelationChart: View {
    let dataPoints: [CorrelationDataPoint]
    let sessionDuration: TimeInterval

    @State private var selectedSeries: Set<CorrelationSeries> = Set(CorrelationSeries.allCases)
    @State private var selectedPoint: CorrelationDataPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(.blue)

                Text("Music & Body")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Series toggles
            HStack(spacing: 12) {
                ForEach(CorrelationSeries.allCases, id: \.self) { series in
                    SeriesToggle(
                        series: series,
                        isSelected: selectedSeries.contains(series)
                    ) {
                        if selectedSeries.contains(series) {
                            selectedSeries.remove(series)
                        } else {
                            selectedSeries.insert(series)
                        }
                    }
                }
            }

            // Chart
            Chart {
                ForEach(filteredDataPoints) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value),
                        series: .value("Series", point.series.rawValue)
                    )
                    .foregroundStyle(point.series.color)
                    .lineStyle(StrokeStyle(
                        lineWidth: point.series == .hrvTrend ? 1.5 : 2,
                        dash: point.series == .hrvTrend ? [4, 4] : []
                    ))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartLegend(.hidden)
            .frame(height: 180)

            // Summary stats
            if !dataPoints.isEmpty {
                summaryRow
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Health correlation chart showing song BPM, heart rate, and HRV trends")
    }

    // MARK: - Filtered Data

    private var filteredDataPoints: [CorrelationDataPoint] {
        dataPoints.filter { selectedSeries.contains($0.series) }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 16) {
            if let avgBPM = averageValue(for: .songBPM) {
                StatPill(label: "Avg BPM", value: "\(Int(avgBPM))", color: .blue)
            }
            if let avgHR = averageValue(for: .heartRate) {
                StatPill(label: "Avg HR", value: "\(Int(avgHR))", color: .red)
            }
            if let avgHRV = averageValue(for: .hrvTrend) {
                StatPill(label: "Avg HRV", value: "\(Int(avgHRV))", color: .green)
            }
        }
    }

    private func averageValue(for series: CorrelationSeries) -> Double? {
        let values = dataPoints.filter { $0.series == series }.map(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var formattedDuration: String {
        let minutes = Int(sessionDuration / 60)
        if minutes < 60 { return "\(minutes)m session" }
        return "\(minutes / 60)h \(minutes % 60)m session"
    }
}

// MARK: - Series Toggle

struct SeriesToggle: View {
    let series: CorrelationSeries
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: series.icon)
                    .font(.caption2)
                Text(series.rawValue)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? series.color : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? series.color.opacity(0.15) : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(series.rawValue) \(isSelected ? "visible" : "hidden")")
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
