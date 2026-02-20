//
//  ResonanceWidgets.swift
//  Resonance Widgets
//
//  Widget extension for iOS home screen and lock screen widgets
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct ResonanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
        StateWidget()
    }
}

// MARK: - Now Playing Widget

struct NowPlayingWidget: Widget {
    let kind: String = "NowPlayingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the currently playing song selected by AI DJ.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Now Playing Provider

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(
            date: Date(),
            songTitle: "Song Title",
            artistName: "Artist Name",
            isPlaying: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        let entry = NowPlayingEntry(
            date: Date(),
            songTitle: "Weightless",
            artistName: "Marconi Union",
            isPlaying: true
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        // In production, this would read from the App Group shared data
        let entry = NowPlayingEntry(
            date: Date(),
            songTitle: "No song playing",
            artistName: "Open AI DJ to start",
            isPlaying: false
        )

        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        completion(timeline)
    }
}

// MARK: - Now Playing Entry

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let songTitle: String
    let artistName: String
    let isPlaying: Bool
}

// MARK: - Now Playing Widget View

struct NowPlayingWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: NowPlayingEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.isPlaying ? "music.note" : "pause.fill")
                    .foregroundStyle(.blue)
                Text("AI DJ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.songTitle)
                .font(.headline)
                .lineLimit(2)

            Text(entry.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
    }

    var mediumView: some View {
        HStack(spacing: 12) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: entry.isPlaying ? "play.fill" : "pause.fill")
                        .foregroundStyle(.blue)
                    Text("AI DJ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.songTitle)
                    .font(.headline)
                    .lineLimit(2)

                Text(entry.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding()
    }

    var rectangularView: some View {
        HStack {
            Image(systemName: "music.note")
            VStack(alignment: .leading) {
                Text(entry.songTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - State Widget

struct StateWidget: Widget {
    let kind: String = "StateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StateProvider()) { entry in
            StateWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Current State")
        .description("Shows your current state as detected by AI DJ.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - State Provider

struct StateProvider: TimelineProvider {
    func placeholder(in context: Context) -> StateEntry {
        StateEntry(date: Date(), stateEmoji: "😌", stateName: "Relaxed", energy: 0.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (StateEntry) -> Void) {
        let entry = StateEntry(date: Date(), stateEmoji: "🧘", stateName: "Calm", energy: 0.3)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StateEntry>) -> Void) {
        let entry = StateEntry(date: Date(), stateEmoji: "❓", stateName: "Unknown", energy: 0.5)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        completion(timeline)
    }
}

// MARK: - State Entry

struct StateEntry: TimelineEntry {
    let date: Date
    let stateEmoji: String
    let stateName: String
    let energy: Double
}

// MARK: - State Widget View

struct StateWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: StateEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallStateView
        case .accessoryCircular:
            circularView
        default:
            smallStateView
        }
    }

    var smallStateView: some View {
        VStack(spacing: 8) {
            Text(entry.stateEmoji)
                .font(.system(size: 40))

            Text(entry.stateName)
                .font(.headline)

            // Energy bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue)
                        .frame(width: geo.size.width * entry.energy)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)

            Text("Energy")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text(entry.stateEmoji)
                .font(.title)
        }
    }
}

