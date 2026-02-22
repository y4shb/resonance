import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let entry = ComplicationEntry(date: Date(), snapshot: ComplicationDataStore.currentData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: Date(), snapshot: ComplicationDataStore.currentData)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: ComplicationSnapshot
}

extension ComplicationSnapshot {
    static let placeholder = ComplicationSnapshot(
        songTitle: "Song Title",
        artistName: "Artist",
        stateEmoji: "\u{1F3B5}",
        heartRate: 72,
        isPlaying: true,
        currentContext: nil,
        lastUpdated: Date()
    )
}

// MARK: - Circular Complication

struct CircularComplicationView: View {
    let snapshot: ComplicationSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Text(snapshot.stateEmoji)
                    .font(.title3)
                if let hr = snapshot.heartRate {
                    Text("\(Int(hr))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Rectangular Complication

struct RectangularComplicationView: View {
    let snapshot: ComplicationSnapshot

    var body: some View {
        HStack(spacing: 6) {
            Text(snapshot.stateEmoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.songTitle ?? "Not Playing")
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let artist = snapshot.artistName {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let hr = snapshot.heartRate {
                        Text("\u{2661}\(Int(hr))")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Inline Complication

struct InlineComplicationView: View {
    let snapshot: ComplicationSnapshot

    var body: some View {
        if let title = snapshot.songTitle {
            Text("\(snapshot.stateEmoji) \(title)")
        } else {
            Text("\(snapshot.stateEmoji) Resonance")
        }
    }
}

// MARK: - Corner Complication

struct CornerComplicationView: View {
    let snapshot: ComplicationSnapshot

    var body: some View {
        Text(snapshot.stateEmoji)
            .font(.title3)
            .widgetLabel {
                if let hr = snapshot.heartRate {
                    Text("\u{2661}\(Int(hr))")
                }
            }
    }
}

// MARK: - Widget Definition

@main
struct ResonanceComplicationBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingComplication()
    }
}

struct NowPlayingComplication: Widget {
    let kind = "ResonanceComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            ComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Resonance")
        .description("Current song and state")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct ComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            RectangularComplicationView(snapshot: entry.snapshot)
        case .accessoryInline:
            InlineComplicationView(snapshot: entry.snapshot)
        case .accessoryCorner:
            CornerComplicationView(snapshot: entry.snapshot)
        default:
            CircularComplicationView(snapshot: entry.snapshot)
        }
    }
}
