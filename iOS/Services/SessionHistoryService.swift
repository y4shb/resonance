//
//  SessionHistoryService.swift
//  Resonance
//
//  Provides historical session trend data for the post-session summary.
//  Tracks session counts by type (time-of-day category) and computes
//  trend deltas by comparing recent performance against historical averages.
//
//  Data flow:
//    1. After each session, `recordSession` persists a lightweight entry.
//    2. Before showing the summary, `computeTrendInsight` queries history
//       to produce a SessionTrendInsight for the current session's type.
//
//  Storage: UserDefaults (same pattern as ResonanceScoreStore) to avoid
//  Core Data migration. Entries are kept in a rolling 365-day window.
//

#if os(iOS)

import Foundation

// MARK: - Session History Entry

/// A lightweight historical session record for trend computation.
/// Stored as JSON in UserDefaults alongside resonance score history.
struct SessionHistoryEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    /// Time-of-day category (morning, afternoon, evening, night).
    let sessionType: String
    /// Session duration in seconds.
    let duration: TimeInterval
    /// Session quality score (0.0 - 1.0).
    let qualityScore: Double
    /// HRV delta during the session (positive = improved).
    let hrvDelta: Double
    /// Average BPM during the session.
    let averageBPM: Double
    /// Skip rate (0.0 - 1.0).
    let skipRate: Double
    /// Resonance score (0-100), if computed.
    let resonanceScore: Int?
}

// MARK: - Session History Service

/// Persists and queries session history for trend computation.
/// Compares same-type sessions (e.g., only evening sessions) for
/// meaningful trend insights like "Your wind-down time improved 15%".
final class SessionHistoryService {

    // MARK: - Constants

    private let storageKey = "resonance_session_history"
    private let defaults: UserDefaults
    private static let maxEntries = 365

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Record Session

    /// Records a completed session for future trend analysis.
    func recordSession(
        date: Date = Date(),
        duration: TimeInterval,
        qualityScore: Double,
        hrvDelta: Double,
        averageBPM: Double,
        skipRate: Double,
        resonanceScore: Int? = nil
    ) {
        let entry = SessionHistoryEntry(
            id: UUID(),
            date: date,
            sessionType: Self.sessionType(for: date),
            duration: duration,
            qualityScore: qualityScore,
            hrvDelta: hrvDelta,
            averageBPM: averageBPM,
            skipRate: skipRate,
            resonanceScore: resonanceScore
        )

        var entries = fetchAll()
        entries.append(entry)

        // Trim to rolling window
        if entries.count > Self.maxEntries {
            entries = Array(entries.suffix(Self.maxEntries))
        }

        persist(entries)
    }

    // MARK: - Compute Trend Insight

    /// Computes a trend insight for the current session by comparing
    /// against historical sessions of the same type.
    ///
    /// - Parameters:
    ///   - currentDate: The current session's timestamp.
    ///   - currentQuality: The current session's quality score.
    ///   - currentHRVDelta: The current session's HRV delta.
    /// - Returns: A `SessionTrendInsight` if enough history exists, otherwise nil.
    func computeTrendInsight(
        currentDate: Date = Date(),
        currentQuality: Double,
        currentHRVDelta: Double
    ) -> SessionTrendInsight? {
        let sessionType = Self.sessionType(for: currentDate)
        let sameTypeSessions = fetchAll().filter { $0.sessionType == sessionType }

        // Need at least 3 historical sessions for a meaningful trend
        guard sameTypeSessions.count >= 3 else { return nil }

        let sessionCount = sameTypeSessions.count + 1 // Include current

        // Determine the trend metric based on session type
        let (trendDelta, metricLabel) = computeTrendMetric(
            sessionType: sessionType,
            historicalSessions: sameTypeSessions,
            currentQuality: currentQuality,
            currentHRVDelta: currentHRVDelta
        )

        return SessionTrendInsight(
            sessionCount: sessionCount,
            sessionTypeLabel: sessionType,
            trendDelta: trendDelta,
            trendMetricLabel: metricLabel
        )
    }

    // MARK: - Session Count

    /// Returns the total number of sessions of a given type.
    func sessionCount(for date: Date = Date()) -> Int {
        let sessionType = Self.sessionType(for: date)
        return fetchAll().filter { $0.sessionType == sessionType }.count
    }

    // MARK: - Fetch All

    func fetchAll() -> [SessionHistoryEntry] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([SessionHistoryEntry].self, from: data)
                .sorted { $0.date < $1.date }
        } catch {
            return []
        }
    }

    // MARK: - Private Helpers

    private func persist(_ entries: [SessionHistoryEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            defaults.set(data, forKey: storageKey)
        } catch {
            #if DEBUG
            print("SessionHistoryService: failed to persist entries: \(error)")
            #endif
        }
    }

    /// Computes the trend delta and metric label for the current session type.
    ///
    /// For evening/night sessions: tracks HRV improvement (wind-down time).
    /// For morning sessions: tracks quality score trend (morning readiness).
    /// For other sessions: tracks resonance score or quality trend.
    private func computeTrendMetric(
        sessionType: String,
        historicalSessions: [SessionHistoryEntry],
        currentQuality: Double,
        currentHRVDelta: Double
    ) -> (Double, String) {
        switch sessionType {
        case "evening", "night":
            // Track HRV improvement trend (wind-down effectiveness)
            let historicalAvgHRV = historicalSessions.map(\.hrvDelta).reduce(0, +)
                / Double(historicalSessions.count)
            let delta = historicalAvgHRV != 0
                ? (currentHRVDelta - historicalAvgHRV) / abs(historicalAvgHRV)
                : (currentHRVDelta > 0 ? 0.1 : -0.1)
            return (clamp(delta, -1.0, 1.0), "wind-down time")

        case "morning":
            // Track quality improvement (morning energy boost)
            let historicalAvgQuality = historicalSessions.map(\.qualityScore).reduce(0, +)
                / Double(historicalSessions.count)
            let delta = historicalAvgQuality != 0
                ? (currentQuality - historicalAvgQuality) / historicalAvgQuality
                : (currentQuality > 0.5 ? 0.1 : -0.1)
            return (clamp(delta, -1.0, 1.0), "energy boost")

        default:
            // Track overall quality trend
            let historicalAvgQuality = historicalSessions.map(\.qualityScore).reduce(0, +)
                / Double(historicalSessions.count)
            let delta = historicalAvgQuality != 0
                ? (currentQuality - historicalAvgQuality) / historicalAvgQuality
                : (currentQuality > 0.5 ? 0.1 : -0.1)
            return (clamp(delta, -1.0, 1.0), "session quality")
        }
    }

    /// Classifies a date into a session type based on hour of day.
    /// Compares same-type sessions so trends are meaningful
    /// (e.g., "Your 12th evening session" not "Your 85th session overall").
    static func sessionType(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:  return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default:      return "night"
        }
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

#endif
