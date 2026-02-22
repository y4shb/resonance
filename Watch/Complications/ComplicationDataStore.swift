import Foundation
import WidgetKit

/// Shared data store for complication/widget data.
/// Writes from the Watch app, reads from the Widget extension.
/// Uses App Group UserDefaults for cross-process communication.
struct ComplicationDataStore {
    private static let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard

    private enum Keys {
        static let songTitle = "complication.songTitle"
        static let artistName = "complication.artistName"
        static let stateEmoji = "complication.stateEmoji"
        static let heartRate = "complication.heartRate"
        static let isPlaying = "complication.isPlaying"
        static let energyLevel = "complication.energyLevel"
        static let currentContext = "complication.currentContext"
        static let lastUpdated = "complication.lastUpdated"
    }

    // MARK: - Write (from Watch app)

    static func update(from data: ComplicationData) {
        defaults.set(data.songTitle, forKey: Keys.songTitle)
        defaults.set(data.artistName, forKey: Keys.artistName)
        defaults.set(data.stateEmoji, forKey: Keys.stateEmoji)
        defaults.set(data.heartRate, forKey: Keys.heartRate)
        defaults.set(data.isPlaying, forKey: Keys.isPlaying)
        defaults.set(data.timestamp.timeIntervalSince1970, forKey: Keys.lastUpdated)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func updateFromNowPlaying(_ nowPlaying: NowPlayingPacket) {
        defaults.set(nowPlaying.songTitle, forKey: Keys.songTitle)
        defaults.set(nowPlaying.artistName, forKey: Keys.artistName)
        defaults.set(nowPlaying.isPlaying, forKey: Keys.isPlaying)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func updateState(emoji: String, heartRate: Double?, context: String?) {
        defaults.set(emoji, forKey: Keys.stateEmoji)
        if let hr = heartRate { defaults.set(hr, forKey: Keys.heartRate) }
        if let ctx = context { defaults.set(ctx, forKey: Keys.currentContext) }
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read (from Widget extension)

    static var currentData: ComplicationSnapshot {
        ComplicationSnapshot(
            songTitle: defaults.string(forKey: Keys.songTitle),
            artistName: defaults.string(forKey: Keys.artistName),
            stateEmoji: defaults.string(forKey: Keys.stateEmoji) ?? "\u{1F3B5}",
            heartRate: defaults.object(forKey: Keys.heartRate) as? Double,
            isPlaying: defaults.bool(forKey: Keys.isPlaying),
            currentContext: defaults.string(forKey: Keys.currentContext),
            lastUpdated: Date(timeIntervalSince1970: defaults.double(forKey: Keys.lastUpdated))
        )
    }
}

struct ComplicationSnapshot {
    let songTitle: String?
    let artistName: String?
    let stateEmoji: String
    let heartRate: Double?
    let isPlaying: Bool
    let currentContext: String?
    let lastUpdated: Date

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 300
    }
}
