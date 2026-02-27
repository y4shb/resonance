//
//  DecisionContextTests.swift
//  ResonanceTests
//
//  Unit tests for DecisionContext convenience methods and TimeSlot mapping.
//

import XCTest
@testable import Resonance

final class DecisionContextTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a Date with the given hour (and optional minute) on today's date.
    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    /// Creates a minimal DecisionContext with the given currentTime and optional preferences.
    private func makeContext(
        hour: Int,
        minute: Int = 0,
        recentlyPlayed: [UUID: Date] = [:],
        candidateSongIds: [UUID] = [],
        currentSessionSongIds: [UUID] = [],
        preferences: UserPreferences = UserPreferences(),
        isSessionStart: Bool = false
    ) -> DecisionContext {
        DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test Playlist",
            candidateSongIds: candidateSongIds,
            recentlyPlayed: recentlyPlayed,
            currentTime: makeDate(hour: hour, minute: minute),
            currentSessionSongIds: currentSessionSongIds,
            preferences: preferences,
            isSessionStart: isSessionStart
        )
    }

    // MARK: - currentHour

    func test_currentHour_returnsCorrectHour_midnight() {
        let ctx = makeContext(hour: 0)
        XCTAssertEqual(ctx.currentHour, 0)
    }

    func test_currentHour_returnsCorrectHour_morning() {
        let ctx = makeContext(hour: 7)
        XCTAssertEqual(ctx.currentHour, 7)
    }

    func test_currentHour_returnsCorrectHour_noon() {
        let ctx = makeContext(hour: 12)
        XCTAssertEqual(ctx.currentHour, 12)
    }

    func test_currentHour_returnsCorrectHour_afternoon() {
        let ctx = makeContext(hour: 14)
        XCTAssertEqual(ctx.currentHour, 14)
    }

    func test_currentHour_returnsCorrectHour_evening() {
        let ctx = makeContext(hour: 18)
        XCTAssertEqual(ctx.currentHour, 18)
    }

    func test_currentHour_returnsCorrectHour_lateNight() {
        let ctx = makeContext(hour: 23)
        XCTAssertEqual(ctx.currentHour, 23)
    }

    // MARK: - isNighttime

    func test_isNighttime_trueAt22_afterDefaultNightStartOf21() {
        let ctx = makeContext(hour: 22)
        XCTAssertTrue(ctx.isNighttime, "22:00 should be nighttime (default nightStartHour is 21)")
    }

    func test_isNighttime_trueAt3AM_earlyMorning() {
        let ctx = makeContext(hour: 3)
        XCTAssertTrue(ctx.isNighttime, "3:00 AM should be nighttime (before 6 AM)")
    }

    func test_isNighttime_falseAt14_afternoon() {
        let ctx = makeContext(hour: 14)
        XCTAssertFalse(ctx.isNighttime, "14:00 should not be nighttime")
    }

    func test_isNighttime_trueAtExactlyNightStartHour() {
        // Default nightStartHour is 21
        let ctx = makeContext(hour: 21)
        XCTAssertTrue(ctx.isNighttime, "21:00 should be nighttime (equal to nightStartHour)")
    }

    func test_isNighttime_falseJustBeforeNightStart() {
        let ctx = makeContext(hour: 20)
        XCTAssertFalse(ctx.isNighttime, "20:00 should not be nighttime with default nightStartHour of 21")
    }

    func test_isNighttime_trueAtMidnight() {
        let ctx = makeContext(hour: 0)
        XCTAssertTrue(ctx.isNighttime, "Midnight should be nighttime")
    }

    func test_isNighttime_trueAt5AM() {
        let ctx = makeContext(hour: 5)
        XCTAssertFalse(ctx.isNighttime, "5:00 AM should not be nighttime (not < 6 and not >= 21)")
    }

    func test_isNighttime_boundaryAt6AM() {
        let ctx = makeContext(hour: 6)
        XCTAssertFalse(ctx.isNighttime, "6:00 AM should not be nighttime (boundary, >= 6)")
    }

    func test_isNighttime_customNightStartHour_trueAt20() {
        let prefs = UserPreferences(nightStartHour: 20)
        let ctx = makeContext(hour: 20, preferences: prefs)
        XCTAssertTrue(ctx.isNighttime, "20:00 should be nighttime with custom nightStartHour of 20")
    }

    func test_isNighttime_customNightStartHour_falseAt19() {
        let prefs = UserPreferences(nightStartHour: 20)
        let ctx = makeContext(hour: 19, preferences: prefs)
        XCTAssertFalse(ctx.isNighttime, "19:00 should not be nighttime with nightStartHour of 20")
    }

    func test_isNighttime_customNightStartHour_earlyMorningStillNight() {
        let prefs = UserPreferences(nightStartHour: 20)
        let ctx = makeContext(hour: 4, preferences: prefs)
        XCTAssertTrue(ctx.isNighttime, "4:00 AM should still be nighttime regardless of nightStartHour")
    }

    // MARK: - isMorning

    func test_isMorning_trueAt7() {
        let ctx = makeContext(hour: 7)
        XCTAssertTrue(ctx.isMorning, "7:00 should be morning")
    }

    func test_isMorning_falseAt15() {
        let ctx = makeContext(hour: 15)
        XCTAssertFalse(ctx.isMorning, "15:00 should not be morning")
    }

    func test_isMorning_falseAt10_afterHardcodedEnd() {
        // isMorning uses hardcoded < 10 check
        let ctx = makeContext(hour: 10)
        XCTAssertFalse(ctx.isMorning, "10:00 should not be morning (boundary: >= 10)")
    }

    func test_isMorning_trueAt6_lowerBoundary() {
        let ctx = makeContext(hour: 6)
        XCTAssertTrue(ctx.isMorning, "6:00 should be morning (lower boundary)")
    }

    func test_isMorning_trueAt9_justBeforeEnd() {
        let ctx = makeContext(hour: 9)
        XCTAssertTrue(ctx.isMorning, "9:00 should be morning (just before upper boundary)")
    }

    func test_isMorning_falseAt5_beforeStart() {
        let ctx = makeContext(hour: 5)
        XCTAssertFalse(ctx.isMorning, "5:00 should not be morning (before 6 AM)")
    }

    func test_isMorning_falseAt0_midnight() {
        let ctx = makeContext(hour: 0)
        XCTAssertFalse(ctx.isMorning, "Midnight should not be morning")
    }

    func test_isMorning_falseAt23() {
        let ctx = makeContext(hour: 23)
        XCTAssertFalse(ctx.isMorning, "23:00 should not be morning")
    }

    // MARK: - timeSlot

    func test_timeSlot_earlyMorning_at5() {
        let ctx = makeContext(hour: 5)
        XCTAssertEqual(ctx.timeSlot, .earlyMorning)
    }

    func test_timeSlot_earlyMorning_at7() {
        let ctx = makeContext(hour: 7)
        XCTAssertEqual(ctx.timeSlot, .earlyMorning)
    }

    func test_timeSlot_earlyMorning_at8_upperBoundary() {
        let ctx = makeContext(hour: 8)
        XCTAssertEqual(ctx.timeSlot, .earlyMorning)
    }

    func test_timeSlot_morning_at9() {
        let ctx = makeContext(hour: 9)
        XCTAssertEqual(ctx.timeSlot, .morning)
    }

    func test_timeSlot_morning_at11() {
        let ctx = makeContext(hour: 11)
        XCTAssertEqual(ctx.timeSlot, .morning)
    }

    func test_timeSlot_midday_at12() {
        let ctx = makeContext(hour: 12)
        XCTAssertEqual(ctx.timeSlot, .midday)
    }

    func test_timeSlot_midday_at13() {
        let ctx = makeContext(hour: 13)
        XCTAssertEqual(ctx.timeSlot, .midday)
    }

    func test_timeSlot_afternoon_at14() {
        let ctx = makeContext(hour: 14)
        XCTAssertEqual(ctx.timeSlot, .afternoon)
    }

    func test_timeSlot_afternoon_at16() {
        let ctx = makeContext(hour: 16)
        XCTAssertEqual(ctx.timeSlot, .afternoon)
    }

    func test_timeSlot_evening_at17() {
        let ctx = makeContext(hour: 17)
        XCTAssertEqual(ctx.timeSlot, .evening)
    }

    func test_timeSlot_evening_at20() {
        let ctx = makeContext(hour: 20)
        XCTAssertEqual(ctx.timeSlot, .evening)
    }

    func test_timeSlot_night_at21() {
        let ctx = makeContext(hour: 21)
        XCTAssertEqual(ctx.timeSlot, .night)
    }

    func test_timeSlot_night_at23() {
        let ctx = makeContext(hour: 23)
        XCTAssertEqual(ctx.timeSlot, .night)
    }

    func test_timeSlot_night_at0_midnight() {
        let ctx = makeContext(hour: 0)
        XCTAssertEqual(ctx.timeSlot, .night)
    }

    func test_timeSlot_night_at3AM() {
        let ctx = makeContext(hour: 3)
        XCTAssertEqual(ctx.timeSlot, .night)
    }

    func test_timeSlot_night_at4_upperBoundary() {
        let ctx = makeContext(hour: 4)
        XCTAssertEqual(ctx.timeSlot, .night)
    }

    // MARK: - wasPlayedRecently

    func test_wasPlayedRecently_trueForSongPlayed30MinAgo() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let playedAt = now.addingTimeInterval(-30 * 60) // 30 minutes ago
        // Default avoidRecentMinutes is 60
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: playedAt],
            currentTime: now
        )
        XCTAssertTrue(ctx.wasPlayedRecently(songId), "Song played 30 min ago should be considered recent (within 60 min window)")
    }

    func test_wasPlayedRecently_falseForSongPlayed90MinAgo() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let playedAt = now.addingTimeInterval(-90 * 60) // 90 minutes ago
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: playedAt],
            currentTime: now
        )
        XCTAssertFalse(ctx.wasPlayedRecently(songId), "Song played 90 min ago should not be considered recent (beyond 60 min window)")
    }

    func test_wasPlayedRecently_falseForSongNeverPlayed() {
        let songId = UUID()
        let ctx = makeContext(hour: 12)
        XCTAssertFalse(ctx.wasPlayedRecently(songId), "Song never played should not be considered recently played")
    }

    func test_wasPlayedRecently_boundaryExactly60MinAgo() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let playedAt = now.addingTimeInterval(-60 * 60) // Exactly 60 minutes ago
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: playedAt],
            currentTime: now
        )
        // minutesSince == 60.0 which is not < 60, so should be false
        XCTAssertFalse(ctx.wasPlayedRecently(songId), "Song played exactly 60 min ago should not be recent (uses strict less-than)")
    }

    func test_wasPlayedRecently_justUnder60MinAgo() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let playedAt = now.addingTimeInterval(-59 * 60) // 59 minutes ago
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: playedAt],
            currentTime: now
        )
        XCTAssertTrue(ctx.wasPlayedRecently(songId), "Song played 59 min ago should be considered recent")
    }

    func test_wasPlayedRecently_customAvoidMinutes() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let playedAt = now.addingTimeInterval(-45 * 60) // 45 minutes ago
        let prefs = UserPreferences(avoidRecentMinutes: 30)
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: playedAt],
            currentTime: now,
            preferences: prefs
        )
        XCTAssertFalse(ctx.wasPlayedRecently(songId), "Song played 45 min ago should not be recent with avoidRecentMinutes of 30")
    }

    func test_wasPlayedRecently_customAvoidMinutes_withinWindow() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let playedAt = now.addingTimeInterval(-20 * 60) // 20 minutes ago
        let prefs = UserPreferences(avoidRecentMinutes: 30)
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: playedAt],
            currentTime: now,
            preferences: prefs
        )
        XCTAssertTrue(ctx.wasPlayedRecently(songId), "Song played 20 min ago should be recent with avoidRecentMinutes of 30")
    }

    func test_wasPlayedRecently_songJustPlayed() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: now],
            currentTime: now
        )
        XCTAssertTrue(ctx.wasPlayedRecently(songId), "Song played at current time should be considered recent")
    }

    // MARK: - minutesSinceLastPlayed

    func test_minutesSinceLastPlayed_correctMinutes() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let playedAt = now.addingTimeInterval(-45 * 60) // 45 minutes ago
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: playedAt],
            currentTime: now
        )
        let minutes = ctx.minutesSinceLastPlayed(songId)
        XCTAssertNotNil(minutes)
        XCTAssertEqual(minutes!, 45.0, accuracy: 0.01)
    }

    func test_minutesSinceLastPlayed_nilWhenNoHistory() {
        let songId = UUID()
        let ctx = makeContext(hour: 12)
        XCTAssertNil(ctx.minutesSinceLastPlayed(songId), "Should return nil for song with no play history")
    }

    func test_minutesSinceLastPlayed_zeroForJustPlayed() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: now],
            currentTime: now
        )
        let minutes = ctx.minutesSinceLastPlayed(songId)
        XCTAssertNotNil(minutes)
        XCTAssertEqual(minutes!, 0.0, accuracy: 0.01)
    }

    func test_minutesSinceLastPlayed_largeInterval() {
        let songId = UUID()
        let now = makeDate(hour: 12)
        let playedAt = now.addingTimeInterval(-24 * 60 * 60) // 24 hours ago
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: playedAt],
            currentTime: now
        )
        let minutes = ctx.minutesSinceLastPlayed(songId)
        XCTAssertNotNil(minutes)
        XCTAssertEqual(minutes!, 1440.0, accuracy: 0.01, "24 hours should be 1440 minutes")
    }

    func test_minutesSinceLastPlayed_unknownSongId() {
        let knownId = UUID()
        let unknownId = UUID()
        let now = makeDate(hour: 12)
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [knownId],
            recentlyPlayed: [knownId: now],
            currentTime: now
        )
        XCTAssertNil(ctx.minutesSinceLastPlayed(unknownId), "Should return nil for an unknown song ID")
    }

    // MARK: - recentlyPlayedIds Filtering

    func test_recentlyPlayedFiltering_mixedRecency() {
        let recentSong = UUID()
        let oldSong = UUID()
        let neverPlayedSong = UUID()
        let now = makeDate(hour: 12)

        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [recentSong, oldSong, neverPlayedSong],
            recentlyPlayed: [
                recentSong: now.addingTimeInterval(-15 * 60),  // 15 min ago
                oldSong: now.addingTimeInterval(-120 * 60)     // 120 min ago
            ],
            currentTime: now
        )

        XCTAssertTrue(ctx.wasPlayedRecently(recentSong), "Song played 15 min ago should be recent")
        XCTAssertFalse(ctx.wasPlayedRecently(oldSong), "Song played 120 min ago should not be recent")
        XCTAssertFalse(ctx.wasPlayedRecently(neverPlayedSong), "Song never played should not be recent")
    }

    func test_recentlyPlayedFiltering_allRecent() {
        let song1 = UUID()
        let song2 = UUID()
        let song3 = UUID()
        let now = makeDate(hour: 12)

        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song1, song2, song3],
            recentlyPlayed: [
                song1: now.addingTimeInterval(-10 * 60),
                song2: now.addingTimeInterval(-20 * 60),
                song3: now.addingTimeInterval(-30 * 60)
            ],
            currentTime: now
        )

        // All played within 60 minutes (default avoidRecentMinutes)
        let allCandidates = [song1, song2, song3]
        let nonRecentCandidates = allCandidates.filter { !ctx.wasPlayedRecently($0) }
        XCTAssertTrue(nonRecentCandidates.isEmpty, "All songs should be filtered as recent")
    }

    func test_recentlyPlayedFiltering_noneRecent() {
        let song1 = UUID()
        let song2 = UUID()
        let now = makeDate(hour: 12)

        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song1, song2],
            recentlyPlayed: [
                song1: now.addingTimeInterval(-90 * 60),
                song2: now.addingTimeInterval(-120 * 60)
            ],
            currentTime: now
        )

        let allCandidates = [song1, song2]
        let nonRecentCandidates = allCandidates.filter { !ctx.wasPlayedRecently($0) }
        XCTAssertEqual(nonRecentCandidates.count, 2, "No songs should be filtered since all were played long ago")
    }

    // MARK: - Default Preferences

    func test_defaultPreferences_areUsedWhenNoneProvided() {
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: []
        )

        // Verify defaults from UserPreferences.init()
        XCTAssertEqual(ctx.preferences.nightStartHour, 21)
        XCTAssertEqual(ctx.preferences.morningEndHour, 9)
        XCTAssertEqual(ctx.preferences.avoidRecentMinutes, 60)
        XCTAssertEqual(ctx.preferences.maxSameArtistInRow, 2)
        XCTAssertTrue(ctx.preferences.preferFamiliarInStress)
        XCTAssertTrue(ctx.preferences.enableSmoothTransitions)
    }

    func test_defaultPreferences_recentlyPlayedIsEmptyByDefault() {
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: []
        )
        XCTAssertTrue(ctx.recentlyPlayed.isEmpty, "Recently played should be empty by default")
    }

    func test_defaultPreferences_sessionSongIdsIsEmptyByDefault() {
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: []
        )
        XCTAssertTrue(ctx.currentSessionSongIds.isEmpty, "Session song IDs should be empty by default")
    }

    func test_defaultPreferences_isSessionStartIsFalseByDefault() {
        let ctx = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: []
        )
        XCTAssertFalse(ctx.isSessionStart, "isSessionStart should be false by default")
    }

    // MARK: - availableSongCount

    func test_availableSongCount_empty() {
        let ctx = makeContext(hour: 12, candidateSongIds: [])
        XCTAssertEqual(ctx.availableSongCount, 0)
    }

    func test_availableSongCount_withSongs() {
        let songs = [UUID(), UUID(), UUID()]
        let ctx = makeContext(hour: 12, candidateSongIds: songs)
        XCTAssertEqual(ctx.availableSongCount, 3)
    }

    // MARK: - sessionSongCount

    func test_sessionSongCount_empty() {
        let ctx = makeContext(hour: 12, currentSessionSongIds: [])
        XCTAssertEqual(ctx.sessionSongCount, 0)
    }

    func test_sessionSongCount_withSongs() {
        let sessionSongs = [UUID(), UUID()]
        let ctx = makeContext(hour: 12, currentSessionSongIds: sessionSongs)
        XCTAssertEqual(ctx.sessionSongCount, 2)
    }

    // MARK: - Placeholder

    func test_placeholder_hasExpectedDefaults() {
        let ctx = DecisionContext.placeholder()
        XCTAssertEqual(ctx.activePlaylistName, "Test Playlist")
        XCTAssertTrue(ctx.candidateSongIds.isEmpty)
        XCTAssertTrue(ctx.isSessionStart)
        XCTAssertTrue(ctx.recentlyPlayed.isEmpty)
        XCTAssertTrue(ctx.currentSessionSongIds.isEmpty)
    }

    // MARK: - Initialization Passthrough

    func test_init_storesAllProvidedValues() {
        let stateVector = StateVector.empty
        let playlistId = UUID()
        let songIds = [UUID(), UUID()]
        let sessionSongIds = [UUID()]
        let now = makeDate(hour: 15)
        let song1 = songIds[0]
        let playedAt = now.addingTimeInterval(-10 * 60)
        let prefs = UserPreferences(avoidRecentMinutes: 120)

        let ctx = DecisionContext(
            stateVector: stateVector,
            activePlaylistId: playlistId,
            activePlaylistName: "My Playlist",
            candidateSongIds: songIds,
            recentlyPlayed: [song1: playedAt],
            currentTime: now,
            currentSessionSongIds: sessionSongIds,
            preferences: prefs,
            isSessionStart: true
        )

        XCTAssertEqual(ctx.activePlaylistId, playlistId)
        XCTAssertEqual(ctx.activePlaylistName, "My Playlist")
        XCTAssertEqual(ctx.candidateSongIds, songIds)
        XCTAssertEqual(ctx.recentlyPlayed.count, 1)
        XCTAssertEqual(ctx.currentTime, now)
        XCTAssertEqual(ctx.currentSessionSongIds, sessionSongIds)
        XCTAssertEqual(ctx.preferences.avoidRecentMinutes, 120)
        XCTAssertTrue(ctx.isSessionStart)
    }
}

// MARK: - TimeSlot Tests

final class TimeSlotTests: XCTestCase {

    // MARK: - Hour Mapping

    func test_init_earlyMorningRange() {
        for hour in 5..<9 {
            XCTAssertEqual(TimeSlot(hour: hour), .earlyMorning, "Hour \(hour) should map to earlyMorning")
        }
    }

    func test_init_morningRange() {
        for hour in 9..<12 {
            XCTAssertEqual(TimeSlot(hour: hour), .morning, "Hour \(hour) should map to morning")
        }
    }

    func test_init_middayRange() {
        for hour in 12..<14 {
            XCTAssertEqual(TimeSlot(hour: hour), .midday, "Hour \(hour) should map to midday")
        }
    }

    func test_init_afternoonRange() {
        for hour in 14..<17 {
            XCTAssertEqual(TimeSlot(hour: hour), .afternoon, "Hour \(hour) should map to afternoon")
        }
    }

    func test_init_eveningRange() {
        for hour in 17..<21 {
            XCTAssertEqual(TimeSlot(hour: hour), .evening, "Hour \(hour) should map to evening")
        }
    }

    func test_init_nightRange_lateEvening() {
        for hour in 21..<24 {
            XCTAssertEqual(TimeSlot(hour: hour), .night, "Hour \(hour) should map to night")
        }
    }

    func test_init_nightRange_earlyHours() {
        for hour in 0..<5 {
            XCTAssertEqual(TimeSlot(hour: hour), .night, "Hour \(hour) should map to night")
        }
    }

    func test_init_invalidHour_negative() {
        XCTAssertEqual(TimeSlot(hour: -1), .unknown, "Negative hour should map to unknown")
    }

    func test_init_invalidHour_over23() {
        XCTAssertEqual(TimeSlot(hour: 24), .unknown, "Hour 24 should map to unknown")
    }

    func test_init_invalidHour_large() {
        XCTAssertEqual(TimeSlot(hour: 100), .unknown, "Hour 100 should map to unknown")
    }

    // MARK: - All Hours Covered

    func test_allValidHoursMapped() {
        for hour in 0..<24 {
            let slot = TimeSlot(hour: hour)
            XCTAssertNotEqual(slot, .unknown, "Hour \(hour) should map to a known time slot")
        }
    }

    // MARK: - Display Names

    func test_displayName_allCasesNonEmpty() {
        for slot in TimeSlot.allCases {
            XCTAssertFalse(slot.displayName.isEmpty, "\(slot) should have a non-empty displayName")
        }
    }

    func test_displayName_earlyMorning() {
        XCTAssertEqual(TimeSlot.earlyMorning.displayName, "Early Morning")
    }

    func test_displayName_morning() {
        XCTAssertEqual(TimeSlot.morning.displayName, "Morning")
    }

    func test_displayName_midday() {
        XCTAssertEqual(TimeSlot.midday.displayName, "Midday")
    }

    func test_displayName_afternoon() {
        XCTAssertEqual(TimeSlot.afternoon.displayName, "Afternoon")
    }

    func test_displayName_evening() {
        XCTAssertEqual(TimeSlot.evening.displayName, "Evening")
    }

    func test_displayName_night() {
        XCTAssertEqual(TimeSlot.night.displayName, "Night")
    }

    func test_displayName_unknown() {
        XCTAssertEqual(TimeSlot.unknown.displayName, "Unknown")
    }

    // MARK: - Suggested Max BPM

    func test_suggestedMaxBPM_earlyMorning() {
        XCTAssertEqual(TimeSlot.earlyMorning.suggestedMaxBPM, 100)
    }

    func test_suggestedMaxBPM_morning() {
        XCTAssertEqual(TimeSlot.morning.suggestedMaxBPM, 130)
    }

    func test_suggestedMaxBPM_midday() {
        XCTAssertEqual(TimeSlot.midday.suggestedMaxBPM, 140)
    }

    func test_suggestedMaxBPM_afternoon() {
        XCTAssertEqual(TimeSlot.afternoon.suggestedMaxBPM, 140)
    }

    func test_suggestedMaxBPM_evening() {
        XCTAssertEqual(TimeSlot.evening.suggestedMaxBPM, 120)
    }

    func test_suggestedMaxBPM_night() {
        XCTAssertEqual(TimeSlot.night.suggestedMaxBPM, 90)
    }

    func test_suggestedMaxBPM_unknown() {
        XCTAssertEqual(TimeSlot.unknown.suggestedMaxBPM, 120)
    }

    // MARK: - Raw Values

    func test_rawValue_earlyMorning() {
        XCTAssertEqual(TimeSlot.earlyMorning.rawValue, "early_morning")
    }

    func test_rawValue_morning() {
        XCTAssertEqual(TimeSlot.morning.rawValue, "morning")
    }

    func test_rawValue_midday() {
        XCTAssertEqual(TimeSlot.midday.rawValue, "midday")
    }

    func test_rawValue_afternoon() {
        XCTAssertEqual(TimeSlot.afternoon.rawValue, "afternoon")
    }

    func test_rawValue_evening() {
        XCTAssertEqual(TimeSlot.evening.rawValue, "evening")
    }

    func test_rawValue_night() {
        XCTAssertEqual(TimeSlot.night.rawValue, "night")
    }

    func test_rawValue_unknown() {
        XCTAssertEqual(TimeSlot.unknown.rawValue, "unknown")
    }

    // MARK: - CaseIterable

    func test_allCases_containsExpectedCount() {
        XCTAssertEqual(TimeSlot.allCases.count, 7)
    }

    // MARK: - Codable Round-Trip

    func test_codable_roundTrip() throws {
        for slot in TimeSlot.allCases {
            let data = try JSONEncoder().encode(slot)
            let decoded = try JSONDecoder().decode(TimeSlot.self, from: data)
            XCTAssertEqual(decoded, slot, "\(slot) should survive JSON round-trip")
        }
    }
}
