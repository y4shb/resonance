//
//  GuardFiltersTests.swift
//  ResonanceTests
//
//  Unit tests for GuardFilters pre-scoring filter logic including
//  ID validation, recency checks, same-artist limits, time-of-day
//  BPM caps, guard adjustments, and fallback behavior.
//

import XCTest
import CoreData
@testable import Resonance

final class GuardFiltersTests: XCTestCase {

    private var guardFilters: GuardFilters!
    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        guardFilters = GuardFilters()
        persistence = PersistenceController(inMemory: true)
        context = persistence.viewContext
    }

    override func tearDown() {
        guardFilters = nil
        persistence = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a Song entity in the in-memory Core Data context with sensible defaults.
    private func makeSong(
        id: UUID? = UUID(),
        appleMusicId: String? = "apple_test_\(UUID().uuidString.prefix(8))",
        artistName: String = "Test Artist",
        bpm: Double = 120,
        energyEstimate: Double = 0.5,
        title: String = "Test Song",
        durationSeconds: Double = 240
    ) -> Song {
        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
        song.id = id
        song.appleMusicId = appleMusicId
        song.title = title
        song.artistName = artistName
        song.bpm = bpm
        song.energyEstimate = energyEstimate
        song.durationSeconds = durationSeconds
        return song
    }

    /// Creates a Date for today at the given hour (0-23).
    private func makeDate(hour: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let components = DateComponents(
            year: 2026, month: 2, day: 27,
            hour: hour, minute: 0, second: 0
        )
        return calendar.date(from: components)!
    }

    /// Creates a default DecisionContext with customizable parameters.
    private func makeDecisionContext(
        hour: Int = 14,
        recentlyPlayed: [UUID: Date] = [:],
        preferences: UserPreferences = UserPreferences(),
        activityContext: ActivityContext = .unknown,
        inferredNeed: MusicNeed = .maintain,
        candidateSongIds: [UUID] = []
    ) -> DecisionContext {
        let state = StateVector(
            context: activityContext,
            inferredNeed: inferredNeed
        )
        return DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test Playlist",
            candidateSongIds: candidateSongIds,
            recentlyPlayed: recentlyPlayed,
            currentTime: makeDate(hour: hour),
            preferences: preferences
        )
    }

    // MARK: - Nil ID Filter

    func test_apply_songsWithNilId_rejected() {
        let song = makeSong(id: nil, title: "No ID Song")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0)
        XCTAssertEqual(result.rejected.count, 1)
        XCTAssertEqual(result.rejected.first?.reason, .noValidId)
    }

    func test_apply_allSongsWithNilId_allRejected() {
        let song1 = makeSong(id: nil, title: "No ID 1")
        let song2 = makeSong(id: nil, title: "No ID 2")
        let song3 = makeSong(id: nil, title: "No ID 3")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song1, song2, song3],
            context: decisionContext
        )

        XCTAssertEqual(result.accepted.count, 0)
        XCTAssertEqual(result.rejected.count, 3)
        XCTAssertTrue(result.rejected.allSatisfy { $0.reason == .noValidId })
    }

    func test_apply_songWithValidId_accepted() {
        let song = makeSong(id: UUID(), title: "Valid ID Song")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1)
        XCTAssertEqual(result.rejected.count, 0)
    }

    func test_apply_mixOfNilAndValidIds_onlyValidAccepted() {
        let songNoId = makeSong(id: nil, title: "No ID Song")
        let songWithId = makeSong(id: UUID(), title: "Valid Song")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [songNoId, songWithId],
            context: decisionContext
        )

        XCTAssertEqual(result.accepted.count, 1)
        XCTAssertEqual(result.accepted.first?.title, "Valid Song")
        XCTAssertEqual(result.rejected.count, 1)
        XCTAssertEqual(result.rejected.first?.reason, .noValidId)
        XCTAssertEqual(result.rejected.first?.song.title, "No ID Song")
    }

    func test_apply_songsWithNilAppleMusicId_stillPassIdGuard() {
        // GuardFilters only checks song.id (UUID), not appleMusicId.
        // A song with a valid UUID but nil appleMusicId should pass.
        let song = makeSong(id: UUID(), appleMusicId: nil, title: "No Apple Music ID")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.totalCandidates, 1)
        XCTAssertEqual(result.acceptedCount, 1,
            "Song with nil appleMusicId but valid id should pass the id guard")
    }

    // MARK: - Recency Filter

    func test_apply_recentlyPlayedSong_rejected() {
        let songId = UUID()
        let song = makeSong(id: songId, title: "Recent Song")
        // Played 10 minutes ago (default avoidRecentMinutes is 60)
        let playedAt = makeDate(hour: 14).addingTimeInterval(-10 * 60)
        let decisionContext = makeDecisionContext(
            hour: 14,
            recentlyPlayed: [songId: playedAt]
        )

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0,
            "Song played 10 minutes ago should be rejected (window is 60 min)")
        XCTAssertEqual(result.rejected.count, 1)
        XCTAssertEqual(result.rejected.first?.reason, .playedRecently)
    }

    func test_apply_songPlayedJustBeforeRecencyWindow_rejected() {
        let songId = UUID()
        let song = makeSong(id: songId, title: "Borderline Recent")
        // Played 59 minutes ago, still within the 60-minute default window
        let playedAt = makeDate(hour: 14).addingTimeInterval(-59 * 60)
        let decisionContext = makeDecisionContext(
            hour: 14,
            recentlyPlayed: [songId: playedAt]
        )

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0,
            "Song played 59 minutes ago should still be rejected (window is 60 min)")
        XCTAssertEqual(result.rejected.first?.reason, .playedRecently)
    }

    func test_apply_songOutsideRecencyWindow_notRejected() {
        let songId = UUID()
        let song = makeSong(id: songId, title: "Played Long Ago")
        // Played 90 minutes ago, default avoidRecentMinutes is 60
        let playedAt = makeDate(hour: 14).addingTimeInterval(-90 * 60)
        let decisionContext = makeDecisionContext(
            hour: 14,
            recentlyPlayed: [songId: playedAt]
        )

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Song played 90 minutes ago should NOT be rejected")
        XCTAssertEqual(result.rejected.count, 0)
    }

    func test_apply_songExactlyAtRecencyBoundary_notRejected() {
        let songId = UUID()
        let song = makeSong(id: songId, title: "Exactly At Boundary")
        // Played exactly 60 minutes ago. wasPlayedRecently uses < comparison,
        // so exactly 60 should NOT be rejected.
        let playedAt = makeDate(hour: 14).addingTimeInterval(-60 * 60)
        let decisionContext = makeDecisionContext(
            hour: 14,
            recentlyPlayed: [songId: playedAt]
        )

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Song at exactly the boundary (60 min) should NOT be rejected (< comparison)")
    }

    func test_apply_songNeverPlayed_notRejected() {
        let song = makeSong(title: "Never Played")
        let decisionContext = makeDecisionContext(recentlyPlayed: [:])

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Song that was never played should be accepted")
    }

    func test_apply_customAvoidRecentMinutes_isRespected() {
        let songId = UUID()
        let song = makeSong(id: songId, title: "Custom Recency")
        // Played 45 minutes ago, but custom window is only 30 minutes
        let playedAt = makeDate(hour: 14).addingTimeInterval(-45 * 60)
        let prefs = UserPreferences(avoidRecentMinutes: 30)
        let decisionContext = makeDecisionContext(
            hour: 14,
            recentlyPlayed: [songId: playedAt],
            preferences: prefs
        )

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Song played 45 min ago should pass a 30-min recency window")
    }

    func test_apply_customAvoidRecentMinutes_rejectsWithinWindow() {
        let songId = UUID()
        let song = makeSong(id: songId, title: "Within Custom Window")
        // Played 20 minutes ago, custom window is 30 minutes
        let playedAt = makeDate(hour: 14).addingTimeInterval(-20 * 60)
        let prefs = UserPreferences(avoidRecentMinutes: 30)
        let decisionContext = makeDecisionContext(
            hour: 14,
            recentlyPlayed: [songId: playedAt],
            preferences: prefs
        )

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0,
            "Song played 20 min ago should be rejected with 30-min recency window")
    }

    func test_apply_multipleRecentSongs_someAcceptedSomeRejected() {
        let recentId = UUID()
        let oldId = UUID()
        let recentSong = makeSong(id: recentId, title: "Recent")
        let oldSong = makeSong(id: oldId, title: "Old Enough")

        let recentPlayedAt = makeDate(hour: 14).addingTimeInterval(-15 * 60)
        let oldPlayedAt = makeDate(hour: 14).addingTimeInterval(-120 * 60)
        let decisionContext = makeDecisionContext(
            hour: 14,
            recentlyPlayed: [recentId: recentPlayedAt, oldId: oldPlayedAt]
        )

        let result = guardFilters.apply(
            candidates: [recentSong, oldSong],
            context: decisionContext
        )

        XCTAssertEqual(result.accepted.count, 1)
        XCTAssertEqual(result.accepted.first?.title, "Old Enough")
        XCTAssertEqual(result.rejected.count, 1)
        XCTAssertEqual(result.rejected.first?.song.title, "Recent")
    }

    // MARK: - Same-Artist Limit

    func test_apply_sameArtistLimit_exceeded_rejected() {
        let song = makeSong(artistName: "Artist X", title: "Song C")
        // Default maxSameArtistInRow is 2; 2 recent songs by same artist
        let recentArtists = ["Artist X", "Artist X"]
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext,
            recentArtists: recentArtists
        )

        XCTAssertEqual(result.accepted.count, 0,
            "Song from same artist should be rejected after 2 in a row")
        XCTAssertEqual(result.rejected.first?.reason, .sameArtistLimit)
    }

    func test_apply_sameArtistLimit_caseInsensitive() {
        let song = makeSong(artistName: "artist name", title: "Case Test")
        let recentArtists = ["Artist Name", "ARTIST NAME"]
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext,
            recentArtists: recentArtists
        )

        XCTAssertEqual(result.accepted.count, 0,
            "Artist comparison should be case-insensitive")
        XCTAssertEqual(result.rejected.first?.reason, .sameArtistLimit)
    }

    func test_apply_sameArtistBelowLimit_accepted() {
        let song = makeSong(artistName: "Artist X", title: "Song B")
        // Only 1 recent song by same artist (limit is 2)
        let recentArtists = ["Artist Y", "Artist X"]
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext,
            recentArtists: recentArtists
        )

        XCTAssertEqual(result.accepted.count, 1,
            "Song should be accepted when artist count is below the limit")
    }

    func test_apply_differentArtist_notFiltered() {
        let song = makeSong(artistName: "Different Artist", title: "Unique Song")
        let recentArtists = ["Artist A", "Artist A"]
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext,
            recentArtists: recentArtists
        )

        XCTAssertEqual(result.accepted.count, 1,
            "Song from a different artist should not be filtered")
    }

    func test_apply_emptyRecentArtists_doesNotFilter() {
        let song = makeSong(artistName: "Any Artist", title: "First Song")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext,
            recentArtists: []
        )

        XCTAssertEqual(result.accepted.count, 1,
            "With no recent artists, no filtering should occur")
    }

    func test_apply_sameArtistLimit_customMaxInRow_rejected() {
        let song = makeSong(artistName: "Popular Artist", title: "Hit Song")
        let recentArtists = ["Popular Artist", "Popular Artist", "Popular Artist"]
        let prefs = UserPreferences(maxSameArtistInRow: 3)
        let decisionContext = makeDecisionContext(preferences: prefs)

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext,
            recentArtists: recentArtists
        )

        XCTAssertEqual(result.accepted.count, 0,
            "Should be rejected when exactly at custom max (3)")
        XCTAssertEqual(result.rejected.first?.reason, .sameArtistLimit)
    }

    func test_apply_sameArtistLimit_customMaxInRow_belowLimit_accepted() {
        let song = makeSong(artistName: "Popular Artist", title: "Hit Song")
        let recentArtists = ["Popular Artist", "Popular Artist"]
        let prefs = UserPreferences(maxSameArtistInRow: 3)
        let decisionContext = makeDecisionContext(preferences: prefs)

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext,
            recentArtists: recentArtists
        )

        XCTAssertEqual(result.accepted.count, 1,
            "Should be accepted when below custom max of 3")
    }

    func test_apply_sameArtistLimit_mixedRecentArtists_breaksStreak() {
        let song = makeSong(artistName: "Target Artist", title: "Maybe OK")
        // Mixed: the trailing suffix(2) = ["Other Artist", "Target Artist"]
        let recentArtists = ["Target Artist", "Other Artist", "Target Artist"]
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext,
            recentArtists: recentArtists
        )

        // suffix(2) = ["Other Artist", "Target Artist"], only 1 match, below limit of 2
        XCTAssertEqual(result.accepted.count, 1,
            "Mixed artists in trailing window should not trigger filter")
    }

    func test_apply_defaultRecentArtists_isEmpty() {
        // When recentArtists is not provided, default is empty
        let song = makeSong(artistName: "Any Artist", title: "Default Test")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext
            // recentArtists omitted, defaults to []
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "Default empty recentArtists should not filter any songs")
    }

    // MARK: - Night BPM Hard Cap

    func test_apply_nighttime_highBPM_rejected() {
        // Default nightMaxBPM = 100, hard cap = 100 + 30 = 130
        let song = makeSong(bpm: 140, title: "Fast Night Song")
        let decisionContext = makeDecisionContext(hour: 23)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0,
            "Song with BPM 140 should be rejected at night (cap is 130)")
        XCTAssertEqual(result.rejected.first?.reason, .bpmTooHighForTime)
    }

    func test_apply_nighttime_songAtExactCap_accepted() {
        // nightMaxBPM = 100, hard cap = 130. Song at exactly 130 should NOT be filtered
        // because shouldFilterByTimeBPM uses songBPM > hardCap (strict greater than)
        let song = makeSong(bpm: 130, title: "At Cap Song")
        let decisionContext = makeDecisionContext(hour: 23)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Song at exactly the hard cap (130) should NOT be rejected (> comparison)")
    }

    func test_apply_nighttime_songBelowCap_accepted() {
        let song = makeSong(bpm: 90, title: "Chill Night Song")
        let decisionContext = makeDecisionContext(hour: 23)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Song with BPM 90 should be accepted at night")
    }

    func test_apply_daytime_highBPM_notFiltered() {
        let song = makeSong(bpm: 180, title: "Fast Day Song")
        let decisionContext = makeDecisionContext(hour: 14)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "High BPM songs should NOT be filtered during daytime")
    }

    func test_apply_morningTime_highBPM_notFiltered() {
        let song = makeSong(bpm: 180, title: "Morning Energizer")
        let decisionContext = makeDecisionContext(hour: 8)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "High BPM songs should NOT be filtered in the morning")
    }

    func test_apply_preSleepContext_highBPM_rejected() {
        // preSleep context should trigger BPM filter even at a non-night hour
        let song = makeSong(bpm: 150, title: "Pre-Sleep High BPM")
        let decisionContext = makeDecisionContext(
            hour: 14,
            activityContext: .preSleep,
            inferredNeed: .calm
        )

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0,
            "High BPM song should be rejected in preSleep context regardless of hour")
        XCTAssertEqual(result.rejected.first?.reason, .bpmTooHighForTime)
    }

    func test_apply_earlyMorning3AM_isNighttime_rejectsHighBPM() {
        // Hour 3 AM should be considered nighttime (< 6)
        let song = makeSong(bpm: 150, title: "3AM Song")
        let decisionContext = makeDecisionContext(hour: 3)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0,
            "Song with BPM 150 should be rejected at 3 AM (nighttime)")
        XCTAssertEqual(result.rejected.first?.reason, .bpmTooHighForTime)
    }

    func test_apply_hour5_isNighttime_rejectsHighBPM() {
        // Hour 5 is nighttime (< 6)
        let song = makeSong(bpm: 150, title: "5AM Song")
        let decisionContext = makeDecisionContext(hour: 5)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0,
            "Hour 5 should be nighttime and reject high BPM")
    }

    func test_apply_hour6_isNotNighttime_acceptsHighBPM() {
        // Hour 6 is NOT nighttime (nighttime is >= nightStartHour OR < 6)
        let song = makeSong(bpm: 150, title: "6AM Song")
        let decisionContext = makeDecisionContext(hour: 6)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Hour 6 should NOT be nighttime")
    }

    func test_apply_nightStartHourBoundary_isNighttime() {
        // Default nightStartHour is 21. Hour 21 should be nighttime.
        let song = makeSong(bpm: 150, title: "Boundary Night Song")
        let decisionContext = makeDecisionContext(hour: 21)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0,
            "Hour 21 (nightStartHour) should be nighttime")
    }

    func test_apply_hour20_isNotNighttime() {
        // Hour 20 is before nightStartHour (21), so NOT nighttime
        let song = makeSong(bpm: 150, title: "8PM Song")
        let decisionContext = makeDecisionContext(hour: 20)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Hour 20 should NOT be nighttime (nightStartHour is 21)")
    }

    func test_apply_unknownBPM_notFilteredAtNight() {
        // BPM of 0 means unknown, should never be filtered
        let song = makeSong(bpm: 0, title: "Unknown BPM Song")
        let decisionContext = makeDecisionContext(hour: 23)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Song with unknown BPM (0) should not be filtered")
    }

    func test_apply_customNightMaxBPM_isRespected() {
        // Custom nightMaxBPM = 80, so hard cap = 80 + 30 = 110
        let song = makeSong(bpm: 115, title: "Above Custom Cap")
        let prefs = UserPreferences(nightMaxBPM: 80)
        let decisionContext = makeDecisionContext(hour: 22, preferences: prefs)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 0,
            "Song at BPM 115 should be rejected (custom cap of 110)")
        XCTAssertEqual(result.rejected.first?.reason, .bpmTooHighForTime)
    }

    func test_apply_customNightMaxBPM_acceptsBelowCap() {
        // Custom nightMaxBPM = 80, hard cap = 110
        let song = makeSong(bpm: 105, title: "Below Custom Cap")
        let prefs = UserPreferences(nightMaxBPM: 80)
        let decisionContext = makeDecisionContext(hour: 22, preferences: prefs)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.accepted.count, 1,
            "Song at BPM 105 should be accepted (custom cap of 110)")
    }

    // MARK: - FilterResult Properties

    func test_filterResult_totalCandidates_matchesInput() {
        let songs = [
            makeSong(title: "Song 1"),
            makeSong(title: "Song 2"),
            makeSong(id: nil, title: "Song 3 No ID")
        ]
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(candidates: songs, context: decisionContext)

        XCTAssertEqual(result.totalCandidates, 3,
            "totalCandidates should equal the input count")
    }

    func test_filterResult_acceptedCount_matchesAcceptedArray() {
        let song1 = makeSong(title: "Song 1")
        let song2 = makeSong(title: "Song 2")
        let song3 = makeSong(id: nil, title: "Rejected Song")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song1, song2, song3],
            context: decisionContext
        )

        XCTAssertEqual(result.acceptedCount, result.accepted.count)
        XCTAssertEqual(result.acceptedCount, 2)
    }

    func test_filterResult_rejectedCountsByReason() {
        let songNoId = makeSong(id: nil, title: "No ID")

        let recentSongId = UUID()
        let songRecent = makeSong(id: recentSongId, title: "Recently Played")

        let songHighBPM = makeSong(bpm: 200, title: "Night High BPM")

        let songOK = makeSong(title: "Accepted Song")

        let playedAt = makeDate(hour: 23).addingTimeInterval(-5 * 60) // 5 min ago
        let decisionContext = makeDecisionContext(
            hour: 23,
            recentlyPlayed: [recentSongId: playedAt]
        )

        let result = guardFilters.apply(
            candidates: [songNoId, songRecent, songHighBPM, songOK],
            context: decisionContext
        )

        XCTAssertEqual(result.totalCandidates, 4)
        XCTAssertEqual(result.acceptedCount, 1)
        XCTAssertEqual(result.rejected.count, 3)

        let reasons = result.rejected.map { $0.reason }
        XCTAssertTrue(reasons.contains(.noValidId),
            "Should contain noValidId reason")
        XCTAssertTrue(reasons.contains(.playedRecently),
            "Should contain playedRecently reason")
        XCTAssertTrue(reasons.contains(.bpmTooHighForTime),
            "Should contain bpmTooHighForTime reason")
    }

    func test_filterResult_emptyCandidates() {
        let decisionContext = makeDecisionContext()
        let result = guardFilters.apply(candidates: [], context: decisionContext)

        XCTAssertEqual(result.totalCandidates, 0)
        XCTAssertEqual(result.acceptedCount, 0)
        XCTAssertEqual(result.rejected.count, 0)
    }

    func test_filterResult_allAccepted() {
        let song1 = makeSong(bpm: 80, title: "Chill 1")
        let song2 = makeSong(bpm: 100, title: "Chill 2")
        let song3 = makeSong(bpm: 110, title: "Moderate")
        let decisionContext = makeDecisionContext(hour: 14)

        let result = guardFilters.apply(
            candidates: [song1, song2, song3],
            context: decisionContext
        )

        XCTAssertEqual(result.totalCandidates, 3)
        XCTAssertEqual(result.acceptedCount, 3)
        XCTAssertEqual(result.rejected.count, 0)
    }

    func test_filterResult_allRejected() {
        let song1 = makeSong(id: nil, title: "No ID 1")
        let song2 = makeSong(id: nil, title: "No ID 2")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song1, song2],
            context: decisionContext
        )

        XCTAssertEqual(result.acceptedCount, 0,
            "All candidates filtered should result in empty accepted list")
        XCTAssertEqual(result.totalCandidates, 2)
        XCTAssertEqual(result.rejected.count, 2)
    }

    // MARK: - Guard Adjustment Tests

    func test_guardAdjustments_noBPMAdjustment_returnsStandardResult() {
        let song = makeSong(bpm: 140, title: "Normal Song")
        let decisionContext = makeDecisionContext(hour: 14)

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [song],
            context: decisionContext,
            bpmAdjustment: 0.0
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "No BPM adjustment should return standard filter result")
    }

    func test_guardAdjustments_smallNegativeAdjustment_noExtraFiltering() {
        // bpmAdjustment of -3.0 is > -5.0, so no extra filtering
        let song = makeSong(bpm: 140, title: "Song")
        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .calm
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [song],
            context: decisionContext,
            bpmAdjustment: -3.0
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "Adjustment of -3.0 (> -5.0) should not trigger extra filtering")
    }

    func test_guardAdjustments_exactlyMinusFive_noExtraFiltering() {
        // bpmAdjustment of -5.0 is NOT < -5.0, so no extra filtering
        let song = makeSong(bpm: 140, title: "Song")
        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .calm
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [song],
            context: decisionContext,
            bpmAdjustment: -5.0
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "Adjustment of exactly -5.0 should not trigger extra filtering (guard uses < -5.0)")
    }

    func test_guardAdjustments_largeBPMAdjustment_filtersHighBPM_calmNeed() {
        // nightMaxBPM = 100, adjustedMaxBPM = (100 + 30) + (-20) = 110
        // Songs above 110 BPM should be filtered when need is calm
        let songHigh = makeSong(bpm: 120, title: "Too High For Calm")
        let songLow1 = makeSong(bpm: 80, title: "Low 1")
        let songLow2 = makeSong(bpm: 90, title: "Low 2")
        let songLow3 = makeSong(bpm: 100, title: "Low 3")

        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .calm
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [songHigh, songLow1, songLow2, songLow3],
            context: decisionContext,
            bpmAdjustment: -20.0
        )

        // songHigh (120) > adjustedMaxBPM (110), should be filtered
        // 3 remaining >= 3, so the adjustment applies
        XCTAssertEqual(result.acceptedCount, 3,
            "High BPM song should be filtered by guard adjustment")
        XCTAssertTrue(
            result.rejected.contains(where: { $0.reason == .bpmTooHighForState }),
            "Should have bpmTooHighForState rejection reason"
        )
    }

    func test_guardAdjustments_largeBPMAdjustment_focusNeed() {
        // Guard adjustments also apply for .focus need
        let songHigh = makeSong(bpm: 140, title: "Too High For Focus")
        let songLow1 = makeSong(bpm: 70, title: "Low 1")
        let songLow2 = makeSong(bpm: 80, title: "Low 2")
        let songLow3 = makeSong(bpm: 85, title: "Low 3")

        let decisionContext = makeDecisionContext(
            hour: 10,
            inferredNeed: .focus
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [songHigh, songLow1, songLow2, songLow3],
            context: decisionContext,
            bpmAdjustment: -15.0
        )

        // adjustedMaxBPM = (100 + 30) + (-15) = 115
        // songHigh (140) > 115, should be filtered
        XCTAssertEqual(result.acceptedCount, 3)
        XCTAssertTrue(
            result.rejected.contains(where: { $0.reason == .bpmTooHighForState }),
            "Should have bpmTooHighForState rejection for focus need"
        )
    }

    func test_guardAdjustments_doesNotApply_forEnergizeNeed() {
        // Guard adjustments only apply for calm or focus need
        let song = makeSong(bpm: 150, title: "High Energy")
        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .energize
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [song],
            context: decisionContext,
            bpmAdjustment: -20.0
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "Guard adjustment should not apply for energize need")
    }

    func test_guardAdjustments_doesNotApply_forMaintainNeed() {
        let song = makeSong(bpm: 150, title: "Maintain High BPM")
        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .maintain
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [song],
            context: decisionContext,
            bpmAdjustment: -20.0
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "Guard adjustment should not apply for maintain need")
    }

    func test_guardAdjustments_doesNotApply_forTransitionNeed() {
        let song = makeSong(bpm: 150, title: "Transition Song")
        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .transition
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [song],
            context: decisionContext,
            bpmAdjustment: -20.0
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "Guard adjustment should not apply for transition need")
    }

    func test_guardAdjustments_fallback_whenTooFewCandidatesRemain() {
        // If guard adjustment would leave fewer than 3 candidates, fall back to standard result
        let songHigh1 = makeSong(bpm: 120, title: "High 1")
        let songHigh2 = makeSong(bpm: 130, title: "High 2")
        let songLow = makeSong(bpm: 80, title: "Low")

        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .calm
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [songHigh1, songHigh2, songLow],
            context: decisionContext,
            bpmAdjustment: -30.0
        )

        // adjustedMaxBPM = (100 + 30) + (-30) = 100
        // songHigh1 (120) and songHigh2 (130) would be filtered, leaving only 1 song
        // Since 1 < 3, it falls back to the standard result (all 3 accepted)
        XCTAssertEqual(result.acceptedCount, 3,
            "Should fall back to standard result when too few candidates remain")
    }

    func test_guardAdjustments_fallback_whenExactlyTwoRemain() {
        // 2 remaining is still < 3, should fall back
        let songHigh = makeSong(bpm: 140, title: "High BPM")
        let songMid1 = makeSong(bpm: 95, title: "Mid 1")
        let songMid2 = makeSong(bpm: 100, title: "Mid 2")

        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .calm
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [songHigh, songMid1, songMid2],
            context: decisionContext,
            bpmAdjustment: -30.0
        )

        // adjustedMaxBPM = 100, songHigh filtered, 2 remain => fallback
        XCTAssertEqual(result.acceptedCount, 3,
            "Should fall back when only 2 would remain (< 3)")
    }

    func test_guardAdjustments_appliesWhenExactlyThreeRemain() {
        // 3 remaining is >= 3, should apply the adjustment
        let songHigh = makeSong(bpm: 140, title: "Filtered Out")
        let songLow1 = makeSong(bpm: 80, title: "Low 1")
        let songLow2 = makeSong(bpm: 85, title: "Low 2")
        let songLow3 = makeSong(bpm: 90, title: "Low 3")

        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .calm
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [songHigh, songLow1, songLow2, songLow3],
            context: decisionContext,
            bpmAdjustment: -30.0
        )

        // adjustedMaxBPM = 100, songHigh (140) filtered, 3 remain => applied
        XCTAssertEqual(result.acceptedCount, 3,
            "Should apply adjustment when exactly 3 candidates remain")
        XCTAssertEqual(result.rejected.count, 1)
    }

    func test_guardAdjustments_unknownBPM_notFiltered() {
        // Songs with BPM 0 (unknown) should not be filtered by guard adjustment
        let songUnknown = makeSong(bpm: 0, title: "Unknown BPM")
        let songLow1 = makeSong(bpm: 70, title: "Low 1")
        let songLow2 = makeSong(bpm: 80, title: "Low 2")
        let songLow3 = makeSong(bpm: 85, title: "Low 3")

        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .calm
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [songUnknown, songLow1, songLow2, songLow3],
            context: decisionContext,
            bpmAdjustment: -20.0
        )

        // songUnknown has bpm 0, which fails `song.bpm > 0` check, so NOT filtered
        XCTAssertEqual(result.acceptedCount, 4,
            "Song with unknown BPM should not be filtered by adjustment")
    }

    func test_guardAdjustments_positiveAdjustment_noExtraFiltering() {
        // Positive BPM adjustment should not trigger extra filtering
        let song = makeSong(bpm: 150, title: "High BPM")
        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .calm
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [song],
            context: decisionContext,
            bpmAdjustment: 10.0
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "Positive BPM adjustment should not trigger extra filtering")
    }

    func test_guardAdjustments_defaultBPMAdjustment_isZero() {
        let song = makeSong(bpm: 140, title: "Song")
        let decisionContext = makeDecisionContext(hour: 14)

        // Calling without bpmAdjustment parameter, defaults to 0.0
        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [song],
            context: decisionContext
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "Default bpmAdjustment of 0.0 should not trigger extra filtering")
    }

    func test_guardAdjustments_combinesWithStandardFilters() {
        // Guard adjustments first apply standard filters, then additional BPM filtering
        let songNoId = makeSong(id: nil, title: "No ID")
        let songHighBPM = makeSong(bpm: 140, title: "High BPM Calm")
        let songLow1 = makeSong(bpm: 70, title: "Low 1")
        let songLow2 = makeSong(bpm: 75, title: "Low 2")
        let songLow3 = makeSong(bpm: 80, title: "Low 3")

        let decisionContext = makeDecisionContext(
            hour: 14,
            inferredNeed: .calm
        )

        let result = guardFilters.applyWithGuardAdjustments(
            candidates: [songNoId, songHighBPM, songLow1, songLow2, songLow3],
            context: decisionContext,
            bpmAdjustment: -20.0
        )

        // songNoId rejected by standard filter (.noValidId)
        // songHighBPM (140) > adjustedMaxBPM (110) rejected (.bpmTooHighForState)
        // 3 low songs remain >= 3, so adjustment applies
        XCTAssertEqual(result.acceptedCount, 3)
        XCTAssertEqual(result.rejected.count, 2)

        let reasons = result.rejected.map { $0.reason }
        XCTAssertTrue(reasons.contains(.noValidId))
        XCTAssertTrue(reasons.contains(.bpmTooHighForState))
    }

    // MARK: - Combined Filters / Integration Tests

    func test_apply_multipleFiltersApplied_simultaneousRejections() {
        // Song with no ID
        let songNoId = makeSong(id: nil, title: "No ID")

        // Song that was recently played
        let recentId = UUID()
        let songRecent = makeSong(id: recentId, title: "Recent")

        // Song with same artist limit exceeded
        let songSameArtist = makeSong(artistName: "Repeated", title: "Same Artist")

        // Song with high BPM at night
        let songHighBPM = makeSong(bpm: 200, title: "Night High BPM")

        // Song that passes all filters
        let songOK = makeSong(artistName: "Unique", bpm: 80, title: "Accepted")

        let playedAt = makeDate(hour: 23).addingTimeInterval(-5 * 60)
        let decisionContext = makeDecisionContext(
            hour: 23,
            recentlyPlayed: [recentId: playedAt]
        )

        let result = guardFilters.apply(
            candidates: [songNoId, songRecent, songSameArtist, songHighBPM, songOK],
            context: decisionContext,
            recentArtists: ["Repeated", "Repeated"]
        )

        XCTAssertEqual(result.totalCandidates, 5)
        XCTAssertEqual(result.acceptedCount, 1)
        XCTAssertEqual(result.accepted.first?.title, "Accepted")
        XCTAssertEqual(result.rejected.count, 4)
    }

    func test_apply_filterOrder_preservesAcceptedOrder() {
        let song1 = makeSong(bpm: 80, title: "First")
        let song2 = makeSong(bpm: 90, title: "Second")
        let song3 = makeSong(id: nil, title: "Filtered Out")
        let song4 = makeSong(bpm: 100, title: "Fourth")
        let decisionContext = makeDecisionContext(hour: 14)

        let result = guardFilters.apply(
            candidates: [song1, song2, song3, song4],
            context: decisionContext
        )

        XCTAssertEqual(result.accepted.count, 3)
        XCTAssertEqual(result.accepted[0].title, "First")
        XCTAssertEqual(result.accepted[1].title, "Second")
        XCTAssertEqual(result.accepted[2].title, "Fourth")
    }

    func test_apply_singleCandidate_accepted() {
        let song = makeSong(bpm: 100, title: "Solo Song")
        let decisionContext = makeDecisionContext(hour: 14)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.acceptedCount, 1)
        XCTAssertEqual(result.totalCandidates, 1)
    }

    func test_apply_singleCandidate_rejected() {
        let song = makeSong(id: nil, title: "Solo Reject")
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.acceptedCount, 0)
        XCTAssertEqual(result.totalCandidates, 1)
        XCTAssertEqual(result.rejected.count, 1)
    }

    func test_apply_filterPriority_idCheckedFirst() {
        // A song with nil id AND recently played should be rejected with .noValidId
        // because the id check comes before the recency check
        let song = makeSong(id: nil, title: "No ID + Recent")

        // Even though we set some random ID in recently played, the nil id check
        // should fire first. This tests the filter ordering.
        let decisionContext = makeDecisionContext(hour: 23)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.rejected.count, 1)
        XCTAssertEqual(result.rejected.first?.reason, .noValidId,
            "ID validation should be checked before other filters")
    }

    // MARK: - Large Candidate Pool

    func test_apply_largeCandidatePool_handledCorrectly() {
        var songs: [Song] = []
        for i in 0..<50 {
            let song = makeSong(bpm: Double(60 + i * 2), title: "Song \(i)")
            songs.append(song)
        }
        let decisionContext = makeDecisionContext(hour: 14)

        let result = guardFilters.apply(candidates: songs, context: decisionContext)

        XCTAssertEqual(result.totalCandidates, 50)
        XCTAssertEqual(result.acceptedCount, 50,
            "All 50 songs should be accepted during daytime")
        XCTAssertEqual(result.rejected.count, 0)
    }

    func test_apply_largeCandidatePool_withNightFilter() {
        // At night with default cap of 130, songs above 130 should be filtered
        var songs: [Song] = []
        for i in 0..<20 {
            let bpm = Double(100 + i * 5) // BPM: 100, 105, ..., 195
            songs.append(makeSong(bpm: bpm, title: "Song \(i)"))
        }
        let decisionContext = makeDecisionContext(hour: 23)

        let result = guardFilters.apply(candidates: songs, context: decisionContext)

        XCTAssertEqual(result.totalCandidates, 20)
        // Songs with BPM > 130 should be filtered: 135, 140, ..., 195 = 13 songs
        // Songs with BPM <= 130: 100, 105, 110, 115, 120, 125, 130 = 7 songs
        XCTAssertEqual(result.acceptedCount, 7)
        XCTAssertEqual(result.rejected.count, 13)
        XCTAssertTrue(
            result.rejected.allSatisfy { $0.reason == .bpmTooHighForTime }
        )
    }

    // MARK: - FilterReason Raw Values

    func test_filterReason_rawValues() {
        XCTAssertEqual(FilterReason.playedRecently.rawValue, "Played too recently")
        XCTAssertEqual(FilterReason.sameArtistLimit.rawValue, "Too many songs from same artist in a row")
        XCTAssertEqual(FilterReason.bpmTooHighForTime.rawValue, "BPM too high for current time of day")
        XCTAssertEqual(FilterReason.bpmTooHighForState.rawValue, "BPM too high for current biometric state")
        XCTAssertEqual(FilterReason.energyMismatch.rawValue, "Energy level mismatched for guard adjustment")
        XCTAssertEqual(FilterReason.noValidId.rawValue, "Song has no valid identifier")
    }

    // MARK: - Edge Cases

    func test_apply_songWithNilArtistName_notFilteredByArtist() {
        // If artistName is nil, the artist filter guard let fails and skips filtering
        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
        song.id = UUID()
        song.appleMusicId = "test_nil_artist"
        song.title = "No Artist Song"
        song.artistName = nil
        song.bpm = 100
        song.energyEstimate = 0.5
        song.durationSeconds = 200

        let recentArtists = ["Some Artist", "Some Artist"]
        let decisionContext = makeDecisionContext()

        let result = guardFilters.apply(
            candidates: [song],
            context: decisionContext,
            recentArtists: recentArtists
        )

        XCTAssertEqual(result.acceptedCount, 1,
            "Song with nil artistName should not be filtered by artist limit")
    }

    func test_apply_negativeBPM_notFilteredAtNight() {
        // Negative BPM is not > 0, should be treated like unknown
        let song = makeSong(bpm: -10, title: "Negative BPM")
        let decisionContext = makeDecisionContext(hour: 23)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.acceptedCount, 1,
            "Song with negative BPM should not be filtered (treated as unknown)")
    }

    func test_apply_veryHighBPM_filteredAtNight() {
        let song = makeSong(bpm: 300, title: "Extreme BPM")
        let decisionContext = makeDecisionContext(hour: 23)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.acceptedCount, 0)
        XCTAssertEqual(result.rejected.first?.reason, .bpmTooHighForTime)
    }

    func test_apply_midnightHour0_isNighttime() {
        // Hour 0 (midnight) is nighttime (< 6)
        let song = makeSong(bpm: 150, title: "Midnight Song")
        let decisionContext = makeDecisionContext(hour: 0)

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.acceptedCount, 0,
            "Midnight (hour 0) should be nighttime")
    }

    func test_apply_workoutContext_doesNotTriggerNightBPMFilter() {
        // Workout context (not preSleep) during daytime should not filter
        let song = makeSong(bpm: 180, title: "Workout Song")
        let decisionContext = makeDecisionContext(
            hour: 14,
            activityContext: .workout,
            inferredNeed: .energize
        )

        let result = guardFilters.apply(candidates: [song], context: decisionContext)

        XCTAssertEqual(result.acceptedCount, 1,
            "Workout context during daytime should not trigger BPM filter")
    }

    func test_apply_multipleRecentlyPlayedDifferentIds() {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        let song1 = makeSong(id: id1, title: "Recent 1")
        let song2 = makeSong(id: id2, title: "Recent 2")
        let song3 = makeSong(id: id3, title: "Not Recent")

        let now = makeDate(hour: 14)
        let decisionContext = makeDecisionContext(
            hour: 14,
            recentlyPlayed: [
                id1: now.addingTimeInterval(-5 * 60),   // 5 min ago
                id2: now.addingTimeInterval(-30 * 60),  // 30 min ago
                id3: now.addingTimeInterval(-120 * 60)  // 120 min ago
            ]
        )

        let result = guardFilters.apply(
            candidates: [song1, song2, song3],
            context: decisionContext
        )

        XCTAssertEqual(result.acceptedCount, 1)
        XCTAssertEqual(result.accepted.first?.title, "Not Recent")
        XCTAssertEqual(result.rejected.count, 2)
        XCTAssertTrue(result.rejected.allSatisfy { $0.reason == .playedRecently })
    }
}
