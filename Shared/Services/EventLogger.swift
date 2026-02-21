//
//  EventLogger.swift
//  Resonance
//
//  Logs playback events to Core Data.
//  Tracks song start/end, listen percentage, skip detection, and biometric deltas.
//

#if os(iOS)

import Foundation
import CoreData
import Combine
import MusicKit

/// Logs playback events to Core Data.
/// Tracks song start/end, listen percentage, skip detection, and biometric deltas.
final class EventLogger: ObservableObject {

    // MARK: - Properties

    private let persistence: PersistenceController
    private let songRepository: SongRepository
    private var cancellables = Set<AnyCancellable>()

    /// Guards against duplicate subscriptions if observeNowPlaying() is called multiple times.
    private var isObservingNowPlaying = false

    /// The object ID of the currently active PlaybackEvent (nil if nothing playing).
    @Published private(set) var activeEventObjectID: NSManagedObjectID?

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        self.songRepository = SongRepository(persistence: persistence)
    }

    // MARK: - Event Lifecycle

    /// Called when a new song starts playing.
    func logPlaybackStart(
        songAppleMusicId: String,
        wasAISelected: Bool,
        selectionScore: Double?,
        selectionReason: String?,
        currentHeartRate: Double?,
        currentHRV: Double?
    ) {
        // Find the Song entity on the main context via the repository.
        guard let song = songRepository.findByAppleMusicId(songAppleMusicId) else {
            logWarning(
                "EventLogger: no Song found for appleMusicId '\(songAppleMusicId)' — skipping event creation",
                category: .persistence
            )
            return
        }

        let songObjectID = song.objectID

        let context = persistence.viewContext

        context.perform {
            guard let songInContext = try? context.existingObject(with: songObjectID) as? Song else {
                logWarning(
                    "EventLogger: song not found in view context for objectID \(songObjectID)",
                    category: .persistence
                )
                return
            }

            guard let event = NSEntityDescription.insertNewObject(
                forEntityName: "PlaybackEvent",
                into: context
            ) as? PlaybackEvent else {
                logError(
                    "EventLogger: failed to create PlaybackEvent entity",
                    error: NSError(domain: "EventLogger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Entity cast failed"]),
                    category: .persistence
                )
                return
            }

            event.id = UUID()
            event.startedAt = Date()
            event.wasAISelected = wasAISelected
            event.selectionScore = selectionScore.map { NSNumber(value: $0) }
            event.selectionReason = selectionReason
            event.hrAtStart = currentHeartRate ?? 0.0
            event.hrvAtStart = currentHRV ?? 0.0
            event.song = songInContext

            do {
                try context.save()
                DispatchQueue.main.async {
                    self.activeEventObjectID = event.objectID
                    logInfo(
                        "EventLogger: playback started for '\(songInContext.title)' — objectID: \(event.objectID)",
                        category: .persistence
                    )
                }
            } catch {
                logError(
                    "EventLogger: failed to save playback start event",
                    error: error,
                    category: .persistence
                )
            }
        }
    }

    /// Called when a song finishes or is skipped.
    func logPlaybackEnd(
        wasSkipped: Bool,
        skipReason: String?,
        currentHeartRate: Double?,
        currentHRV: Double?
    ) {
        guard let eventObjectID = activeEventObjectID else {
            logDebug("EventLogger: logPlaybackEnd called but no active event — ignoring", category: .persistence)
            return
        }

        // Clear immediately so back-to-back calls (e.g. skip then observeNowPlaying) become no-ops.
        activeEventObjectID = nil

        // Capture the hr/hrv values before entering the background task closure.
        let hrAtEnd = currentHeartRate
        let hrvAtEnd = currentHRV
        let wasSkippedParam = wasSkipped
        let skipReasonParam = skipReason

        persistence.performBackgroundTask { [weak self] context in
            guard let self = self else { return }

            do {
                guard let event = try context.existingObject(with: eventObjectID) as? PlaybackEvent else {
                    logWarning(
                        "EventLogger: PlaybackEvent not found in background context for objectID \(eventObjectID)",
                        category: .persistence
                    )
                    return
                }

                let endedAt = Date()
                event.endedAt = endedAt

                guard let startedAt = event.startedAt else {
                    logWarning(
                        "EventLogger: PlaybackEvent has nil startedAt — cannot compute duration",
                        category: .persistence
                    )
                    return
                }
                let durationListened = endedAt.timeIntervalSince(startedAt)
                event.durationListened = durationListened

                let songDuration = event.song?.durationSeconds ?? 0.0
                let listenPercentage: Double
                if songDuration > 0 {
                    listenPercentage = min(max(durationListened / songDuration, 0.0), 1.0)
                } else {
                    listenPercentage = 0.0
                }
                event.listenPercentage = listenPercentage

                // Mark as skipped if the caller says so OR if listen percentage is below threshold.
                event.wasSkipped = wasSkippedParam || listenPercentage < LearningConstants.minimumListenPercentage
                event.skipReason = skipReasonParam

                event.hrAtEnd = hrAtEnd ?? 0.0
                event.hrvAtEnd = hrvAtEnd ?? 0.0
                // Only compute deltas when both values are meaningful (non-zero)
                if let hr = hrAtEnd, event.hrAtStart > 0 {
                    event.hrDelta = hr - event.hrAtStart
                }
                if let hrv = hrvAtEnd, event.hrvAtStart > 0 {
                    event.hrvDelta = hrv - event.hrvAtStart
                }

                if context.hasChanges {
                    try context.save()
                }

                logInfo(
                    "EventLogger: playback ended — listened \(String(format: "%.1f", listenPercentage * 100))%, " +
                    "skipped: \(event.wasSkipped)",
                    category: .persistence
                )

                // Update playback stats on the song.
                if let song = event.song {
                    self.songRepository.updatePlaybackStats(for: song, event: event)
                }

            } catch {
                logError(
                    "EventLogger: failed to save playback end event",
                    error: error,
                    category: .persistence
                )
            }

            // activeEventObjectID was already cleared synchronously above.
        }
    }

    // MARK: - MusicKit Integration

    /// Subscribes to a MusicKitService's nowPlayingPublisher to auto-detect song changes.
    func observeNowPlaying(_ publisher: AnyPublisher<MusicPlayer.Queue.Entry?, Never>) {
        guard !isObservingNowPlaying else { return }
        isObservingNowPlaying = true

        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entry in
                guard let self = self else { return }

                // If there was a previous song playing, end it (not a manual skip).
                if self.activeEventObjectID != nil {
                    self.logPlaybackEnd(
                        wasSkipped: false,
                        skipReason: nil,
                        currentHeartRate: nil,
                        currentHRV: nil
                    )
                }

                // If the new entry has a song, start a new event.
                if let entry = entry, case .song(let song) = entry.item {
                    self.logPlaybackStart(
                        songAppleMusicId: song.id.rawValue,
                        wasAISelected: false,
                        selectionScore: nil,
                        selectionReason: nil,
                        currentHeartRate: nil,
                        currentHRV: nil
                    )
                }
                // If entry is nil, we've already ended the previous event above.
            }
            .store(in: &cancellables)
    }

    // MARK: - Queries

    func fetchRecentEvents(since: Date) -> [PlaybackEvent] {
        let request = NSFetchRequest<PlaybackEvent>(entityName: "PlaybackEvent")
        request.predicate = NSPredicate(format: "startedAt >= %@", since as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]

        do {
            return try persistence.viewContext.fetch(request)
        } catch {
            logError(
                "EventLogger: failed to fetch recent events since \(since)",
                error: error,
                category: .persistence
            )
            return []
        }
    }

    func fetchEvents(forSongAppleMusicId appleMusicId: String) -> [PlaybackEvent] {
        let request = NSFetchRequest<PlaybackEvent>(entityName: "PlaybackEvent")
        request.predicate = NSPredicate(format: "song.appleMusicId == %@", appleMusicId)
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]

        do {
            return try persistence.viewContext.fetch(request)
        } catch {
            logError(
                "EventLogger: failed to fetch events for song '\(appleMusicId)'",
                error: error,
                category: .persistence
            )
            return []
        }
    }
}

#endif
