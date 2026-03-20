//
//  MoodForecastViewModel.swift
//  Resonance
//
//  ViewModel connecting the MoodForecastEngine to the MoodForecastView.
//  Manages forecast generation, user modifications, and playlist reordering.
//

#if os(iOS)
import Foundation
import Observation

// MARK: - Mood Forecast View Model

/// Manages the Mood Forecast feature lifecycle: generating predictions,
/// handling user modifications to the energy curve, and producing a
/// reordered song list that matches the accepted trajectory.
@MainActor
@Observable
final class MoodForecastViewModel {

    // MARK: - Observed State

    /// The current forecast, if one has been generated.
    var forecast: MoodForecast?

    /// Whether the forecast sheet is visible.
    var isShowingForecast = false

    /// Songs reordered to match the accepted forecast curve.
    private(set) var reorderedSongs: [SongFeatures] = []

    /// Whether a forecast has been accepted for the current session.
    private(set) var hasAcceptedForecast = false

    // MARK: - Private

    private let engine = MoodForecastEngine()

    // MARK: - Public API

    /// Generates a new forecast based on session parameters.
    ///
    /// - Parameters:
    ///   - intent: The user-selected music need
    ///   - timeSlot: Current time of day
    ///   - currentHRV: Current HRV reading (optional)
    ///   - playlistSongs: Available songs in the selected playlist
    ///   - sessionDuration: Planned session duration in seconds
    func generateForecast(
        intent: MusicNeed,
        timeSlot: TimeSlot,
        currentHRV: Double?,
        playlistSongs: [SongFeatures],
        sessionDuration: TimeInterval = 1800
    ) {
        forecast = engine.generateForecast(
            intent: intent,
            timeSlot: timeSlot,
            currentHRV: currentHRV,
            playlistSongs: playlistSongs,
            sessionDuration: sessionDuration
        )
        isShowingForecast = true
        hasAcceptedForecast = false

        logInfo(
            "MoodForecastViewModel: forecast generated, showing sheet",
            category: .sessionPlanner
        )
    }

    /// Applies a user-modified forecast and reorders the playlist to match.
    ///
    /// - Parameters:
    ///   - modified: The forecast with user-adjusted control points
    ///   - songs: Songs to reorder
    func applyUserModification(_ modified: MoodForecast, songs: [SongFeatures]) {
        forecast = modified
        reorderedSongs = engine.reorderPlaylist(songs: songs, forecast: modified)
        hasAcceptedForecast = true
        isShowingForecast = false

        let modifiedCount = modified.points.filter(\.isUserModified).count
        logInfo(
            "MoodForecastViewModel: forecast accepted with \(modifiedCount) user modifications, "
            + "reordered \(reorderedSongs.count) songs",
            category: .sessionPlanner
        )
    }

    /// Dismisses the forecast sheet without applying changes.
    func dismiss() {
        isShowingForecast = false

        logDebug(
            "MoodForecastViewModel: forecast dismissed",
            category: .sessionPlanner
        )
    }

    /// Resets the forecast state for a new session.
    func reset() {
        forecast = nil
        reorderedSongs = []
        hasAcceptedForecast = false
        isShowingForecast = false
    }
}
#endif
