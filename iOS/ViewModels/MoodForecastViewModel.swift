//
//  MoodForecastViewModel.swift
//  Resonance
//
//  ViewModel connecting the MoodForecastEngine to the MoodForecastView.
//  Manages forecast generation, user modifications, playlist reordering,
//  inline preview forecasts, and post-session actual trajectory overlay.
//

#if os(iOS)
import Foundation
import Observation

// MARK: - Mood Forecast View Model

/// Manages the Mood Forecast feature lifecycle: generating predictions,
/// handling user modifications to the energy curve, and producing a
/// reordered song list that matches the accepted trajectory.
///
/// Supports two forecast states:
/// - `previewForecast`: lightweight inline preview shown in SessionIntentPicker
/// - `forecast`: full interactive forecast shown in the MoodForecastView sheet
@MainActor
@Observable
final class MoodForecastViewModel {

    // MARK: - Observed State

    /// The current forecast, if one has been generated.
    var forecast: MoodForecast?

    /// A lightweight preview forecast shown inline in the intent picker.
    /// Generated without opening the full sheet.
    var previewForecast: MoodForecast?

    /// Whether the forecast sheet is visible.
    var isShowingForecast = false

    /// Songs reordered to match the accepted forecast curve.
    private(set) var reorderedSongs: [SongFeatures] = []

    /// Whether a forecast has been accepted for the current session.
    private(set) var hasAcceptedForecast = false

    /// The accepted forecast from the session, preserved for post-session overlay.
    /// After a session ends, this is compared against `actualTrajectory`.
    private(set) var acceptedForecast: MoodForecast?

    /// The actual energy trajectory recorded during a completed session.
    /// Populated by the session engine after session end.
    var actualTrajectory: [ForecastPoint]?

    // MARK: - Private

    private let engine = MoodForecastEngine()

    // MARK: - Preview Forecast API

    /// Generates a preview forecast for inline display in the intent picker.
    /// Does NOT open the full forecast sheet.
    ///
    /// - Parameters:
    ///   - intent: The user-selected music need
    ///   - timeSlot: Current time of day
    ///   - currentHRV: Current HRV reading (optional)
    ///   - playlistSongs: Available songs in the selected playlist
    ///   - sessionDuration: Planned session duration in seconds
    func generatePreviewForecast(
        intent: MusicNeed,
        timeSlot: TimeSlot,
        currentHRV: Double?,
        playlistSongs: [SongFeatures],
        sessionDuration: TimeInterval = 1800
    ) {
        previewForecast = engine.generateForecast(
            intent: intent,
            timeSlot: timeSlot,
            currentHRV: currentHRV,
            playlistSongs: playlistSongs,
            sessionDuration: sessionDuration
        )

        logDebug(
            "MoodForecastViewModel: preview forecast generated for inline display",
            category: .sessionPlanner
        )
    }

    /// Promotes the current preview forecast to the full interactive forecast
    /// and opens the forecast sheet for customization.
    func promotePreviewToForecast() {
        guard let preview = previewForecast else { return }
        forecast = preview
        isShowingForecast = true
        hasAcceptedForecast = false

        logInfo(
            "MoodForecastViewModel: preview promoted to full forecast, showing sheet",
            category: .sessionPlanner
        )
    }

    // MARK: - Full Forecast API

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
        acceptedForecast = modified
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

    // MARK: - Post-Session Actual Trajectory

    /// Records the actual energy trajectory after a session completes.
    /// Called by the session engine with timestamped energy samples.
    ///
    /// - Parameter points: The actual energy values recorded during the session,
    ///   normalized to 0.0-1.0 with timestamps matching the session duration.
    func recordActualTrajectory(_ points: [ForecastPoint]) {
        actualTrajectory = points

        logInfo(
            "MoodForecastViewModel: recorded actual trajectory with \(points.count) points",
            category: .sessionPlanner
        )
    }

    /// Whether both predicted and actual trajectories are available for overlay.
    var hasOverlayData: Bool {
        acceptedForecast != nil && actualTrajectory != nil
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
        previewForecast = nil
        reorderedSongs = []
        hasAcceptedForecast = false
        isShowingForecast = false
        acceptedForecast = nil
        actualTrajectory = nil
    }
}
#endif
