//
//  InsightsEngine.swift
//  Resonance
//
//  Computes statistical correlations between music features and biometric
//  outcomes. Aggregates PlaybackEvent data, SongEffect correlations, and
//  ResonanceScoreHistory trends to produce actionable health-music insights.
//
//  Data thresholds:
//    - 10+ sessions for trend insights
//    - 5+ events per genre for genre-HR correlations
//    - 7+ days of data for weekly mood trends
//
//  Results are cached with a 1-hour TTL and computed on a background queue
//  using async/await.
//

#if os(iOS)

import Foundation
import CoreData

// MARK: - Insight Type

/// The category of correlation an insight represents.
enum InsightType: String, CaseIterable, Sendable {
    case genreHRCorrelation
    case keyMoodCorrelation
    case tempoHRVCorrelation
    case sessionLengthWellness
    case timeOfDayPreference
    case mostResonantTrack
    case weeklyMoodTrend

    var icon: String {
        switch self {
        case .genreHRCorrelation:     return "guitars.fill"
        case .keyMoodCorrelation:     return "music.quarternote.3"
        case .tempoHRVCorrelation:    return "metronome.fill"
        case .sessionLengthWellness:  return "clock.fill"
        case .timeOfDayPreference:    return "sun.and.horizon.fill"
        case .mostResonantTrack:      return "star.fill"
        case .weeklyMoodTrend:        return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Chart Data Point

/// A single point for mini-chart rendering within insight cards.
struct InsightChartPoint: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let value: Double
}

// MARK: - Insight

/// A computed insight correlating music features with biometric outcomes.
struct Insight: Identifiable, Sendable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    /// Primary numeric value (e.g., percentage change, BPM, score).
    let value: Double
    /// Statistical confidence (0.0 - 1.0) based on sample count and variance.
    let confidence: Double
    /// Optional data points for rendering a mini chart within the insight card.
    let chartData: [InsightChartPoint]
}

// MARK: - Time Range

/// The time window over which insights are computed.
enum InsightTimeRange: String, CaseIterable, Sendable {
    case week = "Week"
    case month = "Month"
    case allTime = "All Time"

    var days: Int? {
        switch self {
        case .week:    return 7
        case .month:   return 30
        case .allTime: return nil
        }
    }
}

// MARK: - Most Resonant Track Data

/// Lightweight representation of the user's most resonant track.
struct MostResonantTrackData: Sendable {
    let title: String
    let artist: String
    let artworkURL: String?
    let averageHRDelta: Double
    let playCount: Int
}

// MARK: - Insights Engine

/// Computes and caches music-biometric correlation insights.
///
/// Fetches data from Core Data (PlaybackEvent, Song, SongEffect, HistoricalSession)
/// and UserDefaults (ResonanceScoreHistory, SessionHistory) to produce insights
/// that surface in the InsightsView dashboard.
@MainActor
final class InsightsEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var insights: [Insight] = []
    @Published private(set) var isLoading = false
    @Published private(set) var mostResonantTrack: MostResonantTrackData?
    @Published private(set) var totalSessions: Int = 0
    @Published private(set) var totalListeningMinutes: Double = 0
    @Published private(set) var averageResonanceScore: Int = 0

    // MARK: - Dependencies

    private let persistence: PersistenceController
    private let scoreStore: ResonanceScoreStore
    private let sessionHistoryService: SessionHistoryService

    // MARK: - Cache

    private var cachedInsights: [InsightTimeRange: (insights: [Insight], timestamp: Date)] = [:]
    private static let cacheTTL: TimeInterval = 3600 // 1 hour

    // MARK: - Thresholds

    private enum Threshold {
        static let minimumSessionsForTrends = 10
        static let minimumEventsPerGenre = 5
        static let minimumDaysForWeeklyTrend = 7
        static let minimumEventsForCorrelation = 8
    }

    // MARK: - Initialization

    init(
        persistence: PersistenceController = .shared,
        scoreStore: ResonanceScoreStore = ResonanceScoreStore(),
        sessionHistoryService: SessionHistoryService = SessionHistoryService()
    ) {
        self.persistence = persistence
        self.scoreStore = scoreStore
        self.sessionHistoryService = sessionHistoryService
    }

    // MARK: - Public API

    /// Computes insights for the given time range, returning cached results
    /// if the cache is still valid.
    func computeInsights(for timeRange: InsightTimeRange) async {
        // Check cache
        if let cached = cachedInsights[timeRange],
           Date().timeIntervalSince(cached.timestamp) < Self.cacheTTL {
            insights = cached.insights
            return
        }

        isLoading = true
        defer { isLoading = false }

        let cutoffDate = cutoff(for: timeRange)
        let computed = await computeAllInsights(since: cutoffDate)

        cachedInsights[timeRange] = (insights: computed, timestamp: Date())
        insights = computed

        // Compute top-level stats
        await computeTopLevelStats(since: cutoffDate)
    }

    /// Invalidates the cache, forcing a fresh computation on next request.
    func invalidateCache() {
        cachedInsights.removeAll()
    }

    // MARK: - Private: Compute All Insights

    private func computeAllInsights(since cutoffDate: Date?) async -> [Insight] {
        var result: [Insight] = []

        // Fetch events on a background context
        let events = await fetchPlaybackEvents(since: cutoffDate)
        let sessions = sessionHistoryService.fetchAll().filter { entry in
            guard let cutoff = cutoffDate else { return true }
            return entry.date >= cutoff
        }
        let scores = scoreStore.fetchAll().filter { entry in
            guard let cutoff = cutoffDate else { return true }
            return entry.date >= cutoff
        }

        // 1. Genre vs HR correlation
        if let insight = computeGenreHRCorrelation(events: events) {
            result.append(insight)
        }

        // 2. Key (musical) vs mood correlation
        if let insight = computeKeyMoodCorrelation(events: events) {
            result.append(insight)
        }

        // 3. Tempo vs HRV correlation
        if let insight = computeTempoHRVCorrelation(events: events) {
            result.append(insight)
        }

        // 4. Session length vs wellness
        if let insight = computeSessionLengthWellness(sessions: sessions) {
            result.append(insight)
        }

        // 5. Time-of-day preference
        if let insight = computeTimeOfDayPreference(sessions: sessions) {
            result.append(insight)
        }

        // 6. Most resonant track
        if let insight = computeMostResonantTrack(events: events) {
            result.append(insight)
        }

        // 7. Weekly mood trend
        if let insight = computeWeeklyMoodTrend(scores: scores) {
            result.append(insight)
        }

        return result
    }

    // MARK: - Private: Top-Level Stats

    private func computeTopLevelStats(since cutoffDate: Date?) async {
        let sessions = sessionHistoryService.fetchAll().filter { entry in
            guard let cutoff = cutoffDate else { return true }
            return entry.date >= cutoff
        }
        let scores = scoreStore.fetchAll().filter { entry in
            guard let cutoff = cutoffDate else { return true }
            return entry.date >= cutoff
        }

        totalSessions = sessions.count
        totalListeningMinutes = sessions.reduce(0) { $0 + $1.duration / 60.0 }

        if !scores.isEmpty {
            let total = scores.reduce(0) { $0 + $1.score }
            averageResonanceScore = Int(round(Double(total) / Double(scores.count)))
        } else {
            averageResonanceScore = 0
        }
    }

    // MARK: - Private: Genre vs HR Correlation

    private func computeGenreHRCorrelation(events: [PlaybackEventData]) -> Insight? {
        // Group events by genre, compute average HR delta per genre
        var genreHRDeltas: [String: [Double]] = [:]

        for event in events {
            guard let genres = event.genreNames, !genres.isEmpty,
                  abs(event.hrDelta) > 0.1 else { continue }

            let primaryGenre = genres.first ?? "Unknown"
            genreHRDeltas[primaryGenre, default: []].append(event.hrDelta)
        }

        // Filter genres with enough data
        let qualifiedGenres = genreHRDeltas.filter { $0.value.count >= Threshold.minimumEventsPerGenre }
        guard !qualifiedGenres.isEmpty else { return nil }

        // Find most calming genre (largest negative HR delta)
        let averages = qualifiedGenres.mapValues { deltas in
            deltas.reduce(0, +) / Double(deltas.count)
        }

        guard let (bestGenre, bestDelta) = averages.min(by: { $0.value < $1.value }) else {
            return nil
        }

        let totalSamples = qualifiedGenres.values.reduce(0) { $0 + $1.count }
        let confidence = min(1.0, Double(totalSamples) / 50.0)

        let chartPoints = averages.sorted { $0.value < $1.value }.prefix(5).map { genre, delta in
            InsightChartPoint(label: genre, value: delta)
        }

        let direction = bestDelta < 0 ? "lowers" : "raises"
        return Insight(
            type: .genreHRCorrelation,
            title: "\(bestGenre) \(direction) your heart rate",
            description: "\(bestGenre) shifts your heart rate by an average of \(String(format: "%.1f", bestDelta)) BPM across \(qualifiedGenres[bestGenre]?.count ?? 0) listens.",
            value: bestDelta,
            confidence: confidence,
            chartData: chartPoints
        )
    }

    // MARK: - Private: Key vs Mood Correlation

    private func computeKeyMoodCorrelation(events: [PlaybackEventData]) -> Insight? {
        // Use valence as a proxy for mood, correlate with song valence
        let validEvents = events.filter { $0.songValence > 0 && abs($0.hrvDelta) > 0.1 }
        guard validEvents.count >= Threshold.minimumEventsForCorrelation else { return nil }

        // Bucket songs into high-valence vs low-valence
        let highValence = validEvents.filter { $0.songValence >= 0.6 }
        let lowValence = validEvents.filter { $0.songValence < 0.4 }

        guard !highValence.isEmpty, !lowValence.isEmpty else { return nil }

        let highValenceAvgHRV = highValence.map(\.hrvDelta).reduce(0, +) / Double(highValence.count)
        let lowValenceAvgHRV = lowValence.map(\.hrvDelta).reduce(0, +) / Double(lowValence.count)

        let confidence = min(1.0, Double(validEvents.count) / 40.0)

        let chartPoints = [
            InsightChartPoint(label: "Upbeat", value: highValenceAvgHRV),
            InsightChartPoint(label: "Mellow", value: lowValenceAvgHRV)
        ]

        let betterType = highValenceAvgHRV > lowValenceAvgHRV ? "upbeat" : "mellow"
        let delta = abs(highValenceAvgHRV - lowValenceAvgHRV)

        return Insight(
            type: .keyMoodCorrelation,
            title: "\(betterType.capitalized) songs improve your HRV",
            description: "\(betterType.capitalized) tracks boost your HRV by \(String(format: "%.1f", delta)) ms more than \(betterType == "upbeat" ? "mellow" : "upbeat") ones.",
            value: delta,
            confidence: confidence,
            chartData: chartPoints
        )
    }

    // MARK: - Private: Tempo vs HRV Correlation

    private func computeTempoHRVCorrelation(events: [PlaybackEventData]) -> Insight? {
        let validEvents = events.filter { $0.bpm > 0 && abs($0.hrvDelta) > 0.1 }
        guard validEvents.count >= Threshold.minimumEventsForCorrelation else { return nil }

        // Bucket by tempo ranges
        struct TempoBucket {
            let label: String
            let range: ClosedRange<Double>
        }
        let buckets = [
            TempoBucket(label: "Slow (<80)", range: 0...80),
            TempoBucket(label: "Mid (80-120)", range: 80...120),
            TempoBucket(label: "Fast (120-150)", range: 120...150),
            TempoBucket(label: "Very Fast (>150)", range: 150...300)
        ]

        var chartPoints: [InsightChartPoint] = []
        var bestBucket = ""
        var bestHRV = -Double.infinity

        for bucket in buckets {
            let bucketEvents = validEvents.filter { bucket.range.contains($0.bpm) }
            guard bucketEvents.count >= 3 else { continue }

            let avgHRV = bucketEvents.map(\.hrvDelta).reduce(0, +) / Double(bucketEvents.count)
            chartPoints.append(InsightChartPoint(label: bucket.label, value: avgHRV))

            if avgHRV > bestHRV {
                bestHRV = avgHRV
                bestBucket = bucket.label
            }
        }

        guard !chartPoints.isEmpty, bestHRV > -Double.infinity else { return nil }

        let confidence = min(1.0, Double(validEvents.count) / 50.0)

        return Insight(
            type: .tempoHRVCorrelation,
            title: "\(bestBucket) tempo boosts your HRV",
            description: "Songs in the \(bestBucket.lowercased()) BPM range increase your HRV by \(String(format: "%.1f", bestHRV)) ms on average.",
            value: bestHRV,
            confidence: confidence,
            chartData: chartPoints
        )
    }

    // MARK: - Private: Session Length vs Wellness

    private func computeSessionLengthWellness(sessions: [SessionHistoryEntry]) -> Insight? {
        guard sessions.count >= Threshold.minimumSessionsForTrends else { return nil }

        // Bucket sessions by duration
        struct DurationBucket {
            let label: String
            let range: ClosedRange<TimeInterval>
        }
        let buckets = [
            DurationBucket(label: "<15 min", range: 0...900),
            DurationBucket(label: "15-30 min", range: 900...1800),
            DurationBucket(label: "30-60 min", range: 1800...3600),
            DurationBucket(label: ">60 min", range: 3600...86400)
        ]

        var chartPoints: [InsightChartPoint] = []
        var bestBucket = ""
        var bestHRV = -Double.infinity

        for bucket in buckets {
            let bucketSessions = sessions.filter { bucket.range.contains($0.duration) }
            guard bucketSessions.count >= 3 else { continue }

            let avgHRV = bucketSessions.map(\.hrvDelta).reduce(0, +) / Double(bucketSessions.count)
            chartPoints.append(InsightChartPoint(label: bucket.label, value: avgHRV))

            if avgHRV > bestHRV {
                bestHRV = avgHRV
                bestBucket = bucket.label
            }
        }

        guard !chartPoints.isEmpty, bestHRV > -Double.infinity else { return nil }

        let confidence = min(1.0, Double(sessions.count) / 30.0)

        return Insight(
            type: .sessionLengthWellness,
            title: "\(bestBucket) sessions work best for you",
            description: "Sessions lasting \(bestBucket.lowercased()) produce the best HRV improvement (\(String(format: "+%.1f", bestHRV)) ms).",
            value: bestHRV,
            confidence: confidence,
            chartData: chartPoints
        )
    }

    // MARK: - Private: Time-of-Day Preference

    private func computeTimeOfDayPreference(sessions: [SessionHistoryEntry]) -> Insight? {
        guard sessions.count >= Threshold.minimumSessionsForTrends else { return nil }

        // Group by session type (morning/afternoon/evening/night)
        var typeGroups: [String: [SessionHistoryEntry]] = [:]
        for session in sessions {
            typeGroups[session.sessionType, default: []].append(session)
        }

        var chartPoints: [InsightChartPoint] = []
        var bestTime = ""
        var bestQuality = -Double.infinity

        for (type, entries) in typeGroups {
            guard entries.count >= 3 else { continue }
            let avgQuality = entries.map(\.qualityScore).reduce(0, +) / Double(entries.count)
            chartPoints.append(InsightChartPoint(label: type.capitalized, value: avgQuality))

            if avgQuality > bestQuality {
                bestQuality = avgQuality
                bestTime = type
            }
        }

        guard !chartPoints.isEmpty, bestQuality > -Double.infinity else { return nil }

        let confidence = min(1.0, Double(sessions.count) / 30.0)
        let qualityPercent = Int(bestQuality * 100)

        return Insight(
            type: .timeOfDayPreference,
            title: "Your best time is \(bestTime)",
            description: "\(bestTime.capitalized) sessions score \(qualityPercent)% on average -- your music resonates most during this time.",
            value: bestQuality,
            confidence: confidence,
            chartData: chartPoints.sorted { $0.value > $1.value }
        )
    }

    // MARK: - Private: Most Resonant Track

    private func computeMostResonantTrack(events: [PlaybackEventData]) -> Insight? {
        // Group by song, find the one with best average HR alignment
        var songEvents: [String: (title: String, artist: String, artworkURL: String?, deltas: [Double])] = [:]

        for event in events {
            guard let songId = event.songAppleMusicId,
                  let title = event.songTitle,
                  let artist = event.songArtist else { continue }

            var entry = songEvents[songId] ?? (title: title, artist: artist, artworkURL: event.artworkURL, deltas: [])
            entry.deltas.append(abs(event.hrDelta))
            songEvents[songId] = entry
        }

        // Require at least 3 plays
        let qualified = songEvents.filter { $0.value.deltas.count >= 3 }
        guard !qualified.isEmpty else { return nil }

        // Best track = lowest absolute HR delta (most calming / stabilizing)
        guard let (_, best) = qualified.min(by: {
            let avg1 = $0.value.deltas.reduce(0, +) / Double($0.value.deltas.count)
            let avg2 = $1.value.deltas.reduce(0, +) / Double($1.value.deltas.count)
            return avg1 < avg2
        }) else { return nil }

        let avgDelta = best.deltas.reduce(0, +) / Double(best.deltas.count)
        let confidence = min(1.0, Double(best.deltas.count) / 10.0)

        mostResonantTrack = MostResonantTrackData(
            title: best.title,
            artist: best.artist,
            artworkURL: best.artworkURL,
            averageHRDelta: avgDelta,
            playCount: best.deltas.count
        )

        return Insight(
            type: .mostResonantTrack,
            title: "\"\(best.title)\" is your most resonant track",
            description: "By \(best.artist) -- your heart rate stays most stable (avg \(String(format: "%.1f", avgDelta)) BPM delta) across \(best.deltas.count) listens.",
            value: avgDelta,
            confidence: confidence,
            chartData: []
        )
    }

    // MARK: - Private: Weekly Mood Trend

    private func computeWeeklyMoodTrend(scores: [ResonanceScoreHistoryEntry]) -> Insight? {
        guard scores.count >= Threshold.minimumDaysForWeeklyTrend else { return nil }

        // Group by week number
        let calendar = Calendar.current
        var weeklyAverages: [(weekLabel: String, average: Double)] = []

        let grouped = Dictionary(grouping: scores) { entry in
            calendar.component(.weekOfYear, from: entry.date)
        }

        let sortedWeeks = grouped.keys.sorted()
        for week in sortedWeeks.suffix(8) {
            guard let entries = grouped[week], !entries.isEmpty else { continue }
            let avg = Double(entries.map(\.score).reduce(0, +)) / Double(entries.count)
            weeklyAverages.append((weekLabel: "W\(week)", average: avg))
        }

        guard weeklyAverages.count >= 2 else { return nil }

        let chartPoints = weeklyAverages.map { InsightChartPoint(label: $0.weekLabel, value: $0.average) }

        // Compute trend direction
        let firstHalf = weeklyAverages.prefix(weeklyAverages.count / 2)
        let secondHalf = weeklyAverages.suffix(weeklyAverages.count / 2)

        let firstAvg = firstHalf.map(\.average).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map(\.average).reduce(0, +) / Double(secondHalf.count)
        let trendDelta = secondAvg - firstAvg

        let confidence = min(1.0, Double(scores.count) / 30.0)
        let direction = trendDelta >= 0 ? "improving" : "declining"
        let trendPercent = abs(trendDelta)

        return Insight(
            type: .weeklyMoodTrend,
            title: "Your resonance is \(direction)",
            description: "Weekly resonance scores have shifted by \(String(format: "%+.1f", trendDelta)) points. \(direction == "improving" ? "Keep it up!" : "Try adjusting your listening habits.")",
            value: trendPercent,
            confidence: confidence,
            chartData: chartPoints
        )
    }

    // MARK: - Private: Core Data Fetch

    /// Lightweight DTO extracted from PlaybackEvent + Song on a background context.
    private struct PlaybackEventData: Sendable {
        let hrDelta: Double
        let hrvDelta: Double
        let bpm: Double
        let songValence: Double
        let genreNames: [String]?
        let songAppleMusicId: String?
        let songTitle: String?
        let songArtist: String?
        let artworkURL: String?
        let startedAt: Date?
        let wasSkipped: Bool
    }

    private func fetchPlaybackEvents(since cutoffDate: Date?) async -> [PlaybackEventData] {
        return await withCheckedContinuation { continuation in
            persistence.performBackgroundTask { context in
                let request = NSFetchRequest<PlaybackEvent>(entityName: "PlaybackEvent")

                if let cutoff = cutoffDate {
                    request.predicate = NSPredicate(format: "startedAt >= %@", cutoff as NSDate)
                }

                request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
                request.relationshipKeyPathsForPrefetching = ["song"]

                do {
                    let events = try context.fetch(request)
                    let mapped: [PlaybackEventData] = events.map { event in
                        let song = event.song
                        return PlaybackEventData(
                            hrDelta: event.hrDelta,
                            hrvDelta: event.hrvDelta,
                            bpm: song?.bpm ?? 0,
                            songValence: song?.valence ?? 0,
                            genreNames: song?.genreNames as? [String],
                            songAppleMusicId: song?.appleMusicId,
                            songTitle: song?.title,
                            songArtist: song?.artistName,
                            artworkURL: song?.artworkURL,
                            startedAt: event.startedAt,
                            wasSkipped: event.wasSkipped
                        )
                    }
                    continuation.resume(returning: mapped)
                } catch {
                    logError(
                        "InsightsEngine: failed to fetch playback events",
                        error: error,
                        category: .persistence
                    )
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Private: Helpers

    private func cutoff(for range: InsightTimeRange) -> Date? {
        guard let days = range.days else { return nil }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())
    }
}

#endif
