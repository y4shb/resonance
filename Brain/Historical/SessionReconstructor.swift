//
//  SessionReconstructor.swift
//  Resonance
//
//  Reconstructs HistoricalSession entities from unprocessed PlaybackEvents.
//  Groups events by time proximity (30-minute gap rule), enriches with
//  biometric data from HealthKit, and correlates with sleep.
//

#if os(iOS)

import Foundation
import CoreData

final class SessionReconstructor {

    // MARK: - Properties

    private let persistence: PersistenceController
    private let healthKitService: HealthKitService

    // MARK: - Initialization

    init(
        persistence: PersistenceController = .shared,
        healthKitService: HealthKitService
    ) {
        self.persistence = persistence
        self.healthKitService = healthKitService
    }

    // MARK: - Main Entry Points

    /// Reconstructs all unprocessed PlaybackEvents into HistoricalSessions.
    /// Returns the number of sessions created.
    @discardableResult
    func reconstructSessions() async throws -> Int {
        try await reconstructSessions(since: nil)
    }

    /// Reconstructs unprocessed PlaybackEvents into HistoricalSessions,
    /// optionally limited to events after `since` (with overlap buffer).
    /// Returns the number of sessions created.
    @discardableResult
    func reconstructSessions(since: Date?) async throws -> Int {
        logInfo("Starting session reconstruction (since: \(since?.description ?? "all time"))", category: .background)

        let context = persistence.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Fetch unprocessed events
        let events = try await fetchUnprocessedEvents(since: since, in: context)

        guard !events.isEmpty else {
            logInfo("No unprocessed PlaybackEvents found, skipping reconstruction", category: .background)
            return 0
        }

        logInfo("Found \(events.count) unprocessed PlaybackEvents to reconstruct", category: .background)

        // Group into session clusters
        let groups = groupIntoSessions(events)
        logInfo("Grouped into \(groups.count) candidate sessions", category: .background)

        var sessionsCreated = 0
        var batchCount = 0

        for group in groups {
            // Support cooperative cancellation between groups
            try Task.checkCancellation()

            do {
                let session = try await buildSession(from: group, in: context)
                sessionsCreated += 1
                batchCount += 1

                logDebug(
                    "Built session \(session.value(forKey: "id") ?? "unknown") "
                    + "with \(group.count) events, duration \(session.durationMinutes) min",
                    category: .background
                )

                // Save in batches
                if batchCount >= BackfillConstants.sessionSaveBatchSize {
                    try saveContext(context)
                    batchCount = 0
                    logDebug("Saved batch of \(BackfillConstants.sessionSaveBatchSize) sessions", category: .persistence)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logError("Failed to build session from group of \(group.count) events", error: error, category: .background)
                // Continue with next group rather than aborting entirely
            }
        }

        // Save any remaining unsaved sessions
        if batchCount > 0 {
            try saveContext(context)
            logDebug("Saved final batch of \(batchCount) sessions", category: .persistence)
        }

        logInfo("Session reconstruction complete: created \(sessionsCreated) sessions", category: .background)
        return sessionsCreated
    }

    // MARK: - Fetch Unprocessed Events

    /// Fetches PlaybackEvents that have no associated session, sorted by startedAt.
    private func fetchUnprocessedEvents(since: Date?, in context: NSManagedObjectContext) async throws -> [PlaybackEvent] {
        try await context.perform {
            let request = NSFetchRequest<PlaybackEvent>(entityName: "PlaybackEvent")

            var predicates: [NSPredicate] = [
                NSPredicate(format: "session == nil")
            ]

            if let since = since {
                // Apply overlap buffer so we don't miss events near the boundary
                let bufferedDate = since.addingTimeInterval(-Double(BackfillConstants.incrementalOverlapMinutes) * 60)
                predicates.append(NSPredicate(format: "startedAt >= %@", bufferedDate as NSDate))
            }

            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
            request.fetchBatchSize = 50

            return try context.fetch(request)
        }
    }

    // MARK: - Grouping

    /// Groups sorted PlaybackEvents into session clusters based on the gap rule.
    /// Events separated by more than `SessionConstants.sessionGapMinutes` minutes
    /// start a new session. Sessions shorter than `SessionConstants.minimumSessionMinutes`
    /// are filtered out.
    private func groupIntoSessions(_ events: [PlaybackEvent]) -> [[PlaybackEvent]] {
        guard !events.isEmpty else { return [] }

        let gapThresholdSeconds = Double(SessionConstants.sessionGapMinutes) * 60.0
        let minimumDurationSeconds = Double(SessionConstants.minimumSessionMinutes) * 60.0

        var groups: [[PlaybackEvent]] = []
        var currentGroup: [PlaybackEvent] = [events[0]]

        for i in 1..<events.count {
            let previousEvent = events[i - 1]
            let currentEvent = events[i]

            // Use endedAt if available, otherwise estimate end time from startedAt + songDuration
            let previousEndTime: Date
            if let endedAt = previousEvent.endedAt {
                previousEndTime = endedAt
            } else if let startedAt = previousEvent.startedAt {
                previousEndTime = startedAt.addingTimeInterval(previousEvent.songDuration)
            } else {
                // Fallback: treat as same session
                currentGroup.append(currentEvent)
                continue
            }

            guard let currentStartTime = currentEvent.startedAt else {
                currentGroup.append(currentEvent)
                continue
            }

            let gap = currentStartTime.timeIntervalSince(previousEndTime)

            if gap > gapThresholdSeconds {
                // Gap exceeds threshold: finalize current group and start new one
                groups.append(currentGroup)
                currentGroup = [currentEvent]
            } else {
                currentGroup.append(currentEvent)
            }
        }

        // Don't forget the last group
        groups.append(currentGroup)

        // Filter out sessions that are too short
        let filteredGroups = groups.filter { group in
            guard let firstStart = group.first?.startedAt else { return false }

            let lastEvent = group.last!
            let lastEnd: Date
            if let endedAt = lastEvent.endedAt {
                lastEnd = endedAt
            } else if let startedAt = lastEvent.startedAt {
                lastEnd = startedAt.addingTimeInterval(lastEvent.songDuration)
            } else {
                return false
            }

            let durationSeconds = lastEnd.timeIntervalSince(firstStart)
            return durationSeconds >= minimumDurationSeconds
        }

        let dropped = groups.count - filteredGroups.count
        if dropped > 0 {
            logDebug("Filtered out \(dropped) sessions shorter than \(SessionConstants.minimumSessionMinutes) minutes", category: .background)
        }

        return filteredGroups
    }

    // MARK: - Build Session

    /// Creates a HistoricalSession entity from a group of PlaybackEvents,
    /// enriching it with biometric data, sleep correlation, context inference,
    /// and overall scoring.
    private func buildSession(from events: [PlaybackEvent], in context: NSManagedObjectContext) async throws -> HistoricalSession {
        // Step 1: Create the entity and set core attributes
        let session: HistoricalSession = try await context.perform {
            guard let session = NSEntityDescription.insertNewObject(forEntityName: "HistoricalSession", into: context) as? HistoricalSession else {
                throw SessionReconstructionError.entityCreationFailed("HistoricalSession")
            }

            // Identity
            session.id = UUID()

            // Time boundaries
            guard let startTime = events.first?.startedAt else {
                throw SessionReconstructionError.missingEventData("startedAt on first event")
            }

            let lastEvent = events.last!
            let endTime: Date
            if let endedAt = lastEvent.endedAt {
                endTime = endedAt
            } else if let startedAt = lastEvent.startedAt {
                endTime = startedAt.addingTimeInterval(lastEvent.songDuration)
            } else {
                endTime = startTime
            }

            session.startTime = startTime
            session.endTime = endTime
            session.durationMinutes = endTime.timeIntervalSince(startTime) / 60.0

            // Link events to session
            for event in events {
                event.session = session
            }

            // Playback statistics
            let totalSongs = Int64(events.count)
            let totalSkips = Int64(events.filter { $0.wasSkipped }.count)
            let skipRate = totalSongs > 0 ? Double(totalSkips) / Double(totalSongs) : 0.0
            let avgListenPct = totalSongs > 0
                ? events.reduce(0.0) { $0 + $1.listenPercentage } / Double(totalSongs)
                : 0.0

            session.totalSongsPlayed = totalSongs
            session.totalSkips = totalSkips
            session.skipRate = skipRate
            session.avgListenPercentage = avgListenPct

            // Day of week (1 = Sunday, 7 = Saturday per Calendar)
            let dayOfWeek = Calendar.current.component(.weekday, from: startTime)
            session.dayOfWeek = Int16(dayOfWeek)

            // Time slot
            let hour = Calendar.current.component(.hour, from: startTime)
            session.timeOfDaySlot = TimeSlot(hour: hour).rawValue

            // Playlist linking: if all events' songs share the same playlist, link it
            self.linkPlaylistIfShared(session: session, events: events)

            return session
        }

        // Step 2: Enrich with biometric data from HealthKit
        await enrichWithBiometrics(session: session, in: context)

        // Step 3: Correlate with subsequent sleep
        await correlateSleep(session: session, in: context)

        // Step 4: Infer activity context
        let inferredContext = await inferContext(session: session, in: context)
        await context.perform {
            session.contextType = inferredContext.rawValue
        }

        // Step 5: Score the session and set overallImpactScore
        await context.perform {
            session.overallImpactScore = self.scoreSession(session)
        }

        return session
    }

    // MARK: - Biometric Enrichment

    /// Enriches a HistoricalSession with heart rate and HRV data from HealthKit.
    /// Fetches data in a window of +-5 minutes around the session boundaries.
    private func enrichWithBiometrics(session: HistoricalSession, in context: NSManagedObjectContext) async {
        guard let startTime = session.startTime, let endTime = session.endTime else {
            logWarning("Cannot enrich biometrics: session missing start/end time", category: .background)
            return
        }

        let bufferSeconds: TimeInterval = 5.0 * 60.0  // 5-minute buffer
        let queryStart = startTime.addingTimeInterval(-bufferSeconds)
        let queryEnd = endTime.addingTimeInterval(bufferSeconds)

        // Fetch heart rate history
        do {
            let hrSamples = try await healthKitService.fetchHeartRateHistory(from: queryStart, to: queryEnd)

            if !hrSamples.isEmpty {
                let hrValues = hrSamples.map { $0.value }
                let avgHR = hrValues.reduce(0.0, +) / Double(hrValues.count)
                let minHR = hrValues.min() ?? 0.0
                let maxHR = hrValues.max() ?? 0.0

                // Starting HR: sample closest to session start
                let startingHR = hrSamples
                    .min(by: { abs($0.date.timeIntervalSince(startTime)) < abs($1.date.timeIntervalSince(startTime)) })?
                    .value ?? 0.0

                // Ending HR: sample closest to session end
                let endingHR = hrSamples
                    .min(by: { abs($0.date.timeIntervalSince(endTime)) < abs($1.date.timeIntervalSince(endTime)) })?
                    .value ?? 0.0

                await context.perform {
                    session.avgHeartRate = avgHR
                    session.minHeartRate = minHR
                    session.maxHeartRate = maxHR
                    session.startingHeartRate = startingHR
                    session.endingHeartRate = endingHR
                    session.deltaHeartRate = endingHR - startingHR
                }

                logDebug(
                    "Enriched HR: avg=\(String(format: "%.1f", avgHR)), "
                    + "delta=\(String(format: "%.1f", endingHR - startingHR))",
                    category: .background
                )
            }
        } catch {
            logWarning("Failed to fetch heart rate history for session enrichment", category: .background)
        }

        // Fetch HRV history
        do {
            let hrvSamples = try await healthKitService.fetchHRVHistory(from: queryStart, to: queryEnd)

            if !hrvSamples.isEmpty {
                let hrvValues = hrvSamples.map { $0.value }
                let avgHRV = hrvValues.reduce(0.0, +) / Double(hrvValues.count)

                // Starting HRV: sample closest to session start
                let startingHRV = hrvSamples
                    .min(by: { abs($0.date.timeIntervalSince(startTime)) < abs($1.date.timeIntervalSince(startTime)) })?
                    .value ?? 0.0

                // Ending HRV: sample closest to session end
                let endingHRV = hrvSamples
                    .min(by: { abs($0.date.timeIntervalSince(endTime)) < abs($1.date.timeIntervalSince(endTime)) })?
                    .value ?? 0.0

                await context.perform {
                    session.avgHRV = avgHRV
                    session.startingHRV = startingHRV
                    session.endingHRV = endingHRV
                    session.deltaHRV = endingHRV - startingHRV
                }

                logDebug(
                    "Enriched HRV: avg=\(String(format: "%.1f", avgHRV)), "
                    + "delta=\(String(format: "%.1f", endingHRV - startingHRV))",
                    category: .background
                )
            }
        } catch {
            logWarning("Failed to fetch HRV history for session enrichment", category: .background)
        }
    }

    // MARK: - Sleep Correlation

    /// Correlates the session with subsequent sleep data.
    /// Looks for substantial sleep (>=3 hours) within 12 hours after session end.
    private func correlateSleep(session: HistoricalSession, in context: NSManagedObjectContext) async {
        guard let endTime = session.endTime else {
            logWarning("Cannot correlate sleep: session missing end time", category: .background)
            return
        }

        let sleepWindowEnd = endTime.addingTimeInterval(Double(SessionConstants.sleepCorrelationWindowHours) * 3600.0)

        do {
            let sleepSessions = try await healthKitService.fetchSleepAnalysis(from: endTime, to: sleepWindowEnd)

            guard !sleepSessions.isEmpty else {
                logDebug("No sleep data found within \(SessionConstants.sleepCorrelationWindowHours)h of session end", category: .background)
                return
            }

            // Calculate total sleep duration and deep sleep duration
            let totalSleepHours = sleepSessions.reduce(0.0) { $0 + $1.durationHours }

            // Filter for substantial sleep (not naps)
            guard totalSleepHours >= BackfillConstants.minimumSubstantialSleepHours else {
                logDebug(
                    "Sleep duration \(String(format: "%.1f", totalSleepHours))h below "
                    + "minimum threshold of \(BackfillConstants.minimumSubstantialSleepHours)h",
                    category: .background
                )
                return
            }

            let deepSleepHours = sleepSessions.filter { $0.isDeepSleep }.reduce(0.0) { $0 + $1.durationHours }
            let deepSleepPct = totalSleepHours > 0 ? deepSleepHours / totalSleepHours : 0.0

            // Normalize deep sleep percentage by ideal (0.25)
            let normalizedDeepPct = min(1.0, deepSleepPct / BackfillConstants.idealDeepSleepPercentage)

            // Sleep score: weighted combination of duration and deep sleep quality
            let durationScore = min(1.0, totalSleepHours / 8.0)
            let sleepScore = durationScore * 0.6 + normalizedDeepPct * 0.4

            await context.perform {
                // Use NSNumber since these fields have usesScalarValueType="NO"
                session.nextNightSleepScore = NSNumber(value: sleepScore)
                session.nextNightSleepDuration = NSNumber(value: totalSleepHours)
                session.nextNightDeepSleepPct = NSNumber(value: deepSleepPct)
            }

            logDebug(
                "Correlated sleep: duration=\(String(format: "%.1f", totalSleepHours))h, "
                + "deep=\(String(format: "%.1f%%", deepSleepPct * 100)), "
                + "score=\(String(format: "%.2f", sleepScore))",
                category: .background
            )
        } catch {
            logWarning("Failed to fetch sleep data for correlation", category: .background)
        }
    }

    // MARK: - Context Inference

    /// Infers the ActivityContext for a session based on workout overlap
    /// and time-of-day heuristics. Checks for HealthKit workout first,
    /// then falls back to weekend-aware time-of-day mapping.
    private func inferContext(session: HistoricalSession, in context: NSManagedObjectContext) async -> ActivityContext {
        guard let startTime = session.startTime, let endTime = session.endTime else {
            return .unknown
        }

        // First: check for HealthKit workout overlapping the session window
        do {
            let workouts = try await healthKitService.fetchWorkouts(from: startTime, to: endTime)
            if let primaryWorkout = workouts.first {
                // Set workout-related fields on the session
                await context.perform {
                    session.isWorkoutSession = true
                    session.workoutType = primaryWorkout.activityName
                    session.workoutCalories = workouts.reduce(0.0) { $0 + $1.totalEnergyBurned }
                }
                logDebug("Inferred context: workout (\(primaryWorkout.activityName))", category: .background)
                return .workout
            }
        } catch {
            logWarning("Failed to fetch workouts for context inference", category: .background)
        }

        // Fallback: time-of-day and weekend-aware heuristics
        let hour = Calendar.current.component(.hour, from: startTime)
        let weekday = Calendar.current.component(.weekday, from: startTime)
        let isWeekend = (weekday == 1 || weekday == 7)  // Sunday = 1, Saturday = 7

        let inferred: ActivityContext
        if isWeekend {
            inferred = inferWeekendContext(hour: hour)
        } else {
            inferred = inferWeekdayContext(hour: hour)
        }

        logDebug("Inferred context: \(inferred.rawValue) (hour=\(hour), weekend=\(isWeekend))", category: .background)
        return inferred
    }

    /// Weekday context mapping:
    /// - 5..<7   -> morning
    /// - 7..<9   -> commute
    /// - 9..<17  -> work
    /// - 17..<19 -> commute
    /// - 19..<22 -> relaxation
    /// - 22..<24, 0..<5 -> preSleep
    private func inferWeekdayContext(hour: Int) -> ActivityContext {
        switch hour {
        case 5..<7:
            return .morning
        case 7..<9:
            return .commute
        case 9..<17:
            return .work
        case 17..<19:
            return .commute
        case 19..<22:
            return .relaxation
        case 22..<24, 0..<5:
            return .preSleep
        default:
            return .unknown
        }
    }

    /// Weekend context mapping:
    /// - 5..<9   -> morning
    /// - 9..<22  -> relaxation
    /// - 22..<24, 0..<5 -> preSleep
    private func inferWeekendContext(hour: Int) -> ActivityContext {
        switch hour {
        case 5..<9:
            return .morning
        case 9..<22:
            return .relaxation
        case 22..<24, 0..<5:
            return .preSleep
        default:
            return .unknown
        }
    }

    // MARK: - Session Scoring

    /// Computes the overall impact score for a session based on skip rate,
    /// HRV delta, engagement, and sleep quality.
    ///
    /// Formula: `(skipScore * 0.25) + (hrvScore * 0.30) + (engagementScore * 0.25) + (sleepScore * 0.20)`
    ///
    /// - skipScore: `1.0 - skipRate`
    /// - hrvScore: `clamp(0.5 + deltaHRV / 20.0)`
    /// - engagementScore: `avgListenPercentage`
    /// - sleepScore: `nextNightSleepScore ?? 0.5`
    private func scoreSession(_ session: HistoricalSession) -> Double {
        let skipScore = 1.0 - session.skipRate
        let hrvScore = clamp(0.5 + session.deltaHRV / 20.0)
        let engagementScore = session.avgListenPercentage
        let sleepScore = session.nextNightSleepScore?.doubleValue ?? 0.5

        let overall = (skipScore * 0.25) + (hrvScore * 0.30) + (engagementScore * 0.25) + (sleepScore * 0.20)
        return clamp(overall)
    }

    // MARK: - Playlist Linking

    /// If all events in the session share a common playlist, link the session to it.
    private func linkPlaylistIfShared(session: HistoricalSession, events: [PlaybackEvent]) {
        guard !events.isEmpty else { return }

        // Collect the playlist sets from each event's song and intersect
        var commonPlaylists: Set<NSManagedObject>?

        for event in events {
            guard let song = event.song,
                  let playlists = song.value(forKey: "playlists") as? NSSet,
                  let playlistObjects = playlists as? Set<NSManagedObject>,
                  !playlistObjects.isEmpty else {
                // If any song has no playlist, there's no shared playlist
                commonPlaylists = nil
                break
            }

            if let existing = commonPlaylists {
                commonPlaylists = existing.intersection(playlistObjects)
            } else {
                commonPlaylists = playlistObjects
            }

            // If intersection is empty, no shared playlist possible
            if let common = commonPlaylists, common.isEmpty {
                break
            }
        }

        // Link if there is at least one common playlist (pick the first)
        if let common = commonPlaylists, let playlist = common.first {
            session.setValue(playlist, forKey: "playlist")
            logDebug("Linked session to playlist: \(playlist.value(forKey: "name") ?? "unknown")", category: .background)
        }
    }

    // MARK: - Helpers

    /// Clamps a value to the [0.0, 1.0] range.
    private func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    /// Saves the managed object context, throwing on failure.
    private func saveContext(_ context: NSManagedObjectContext) throws {
        try context.performAndWait {
            guard context.hasChanges else { return }
            try context.save()
        }
    }
}

// MARK: - Errors

enum SessionReconstructionError: LocalizedError {
    case entityCreationFailed(String)
    case missingEventData(String)

    var errorDescription: String? {
        switch self {
        case .entityCreationFailed(let entity):
            return "Failed to create Core Data entity: \(entity)"
        case .missingEventData(let field):
            return "PlaybackEvent missing required data: \(field)"
        }
    }
}

#endif
