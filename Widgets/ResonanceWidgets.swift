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
        .description("Shows the currently playing song selected by Resonance.")
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
            isPlaying: true,
            explanation: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        let snapshot = WidgetDataStore.currentNowPlaying
        let entry = NowPlayingEntry(
            date: Date(),
            songTitle: snapshot.songTitle,
            artistName: snapshot.artistName,
            isPlaying: snapshot.isPlaying,
            explanation: snapshot.explanation
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let snapshot = WidgetDataStore.currentNowPlaying
        let entry = NowPlayingEntry(
            date: Date(),
            songTitle: snapshot.songTitle,
            artistName: snapshot.artistName,
            isPlaying: snapshot.isPlaying,
            explanation: snapshot.explanation
        )

        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Now Playing Entry

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let songTitle: String
    let artistName: String
    let isPlaying: Bool
    let explanation: String?
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
                Text("Resonance")
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
                    Text("Resonance")
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

                if let explanation = entry.explanation {
                    Text(explanation)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
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
        .description("Shows your current state as detected by Resonance.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - State Provider

struct StateProvider: TimelineProvider {
    func placeholder(in context: Context) -> StateEntry {
        StateEntry(date: Date(), stateEmoji: "\u{1F60C}", stateName: "Relaxed", energy: 0.5, heartRate: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StateEntry) -> Void) {
        let snapshot = WidgetDataStore.currentState
        let entry = StateEntry(
            date: Date(),
            stateEmoji: snapshot.stateEmoji,
            stateName: snapshot.stateName,
            energy: snapshot.energy,
            heartRate: snapshot.heartRate
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StateEntry>) -> Void) {
        let snapshot = WidgetDataStore.currentState
        let entry = StateEntry(
            date: Date(),
            stateEmoji: snapshot.stateEmoji,
            stateName: snapshot.stateName,
            energy: snapshot.energy,
            heartRate: snapshot.heartRate
        )
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - State Entry

struct StateEntry: TimelineEntry {
    let date: Date
    let stateEmoji: String
    let stateName: String
    let energy: Double
    let heartRate: Double?
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

            if let heartRate = entry.heartRate {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text("\(Int(heartRate)) BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Energy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
