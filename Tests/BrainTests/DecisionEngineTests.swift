//
//  DecisionEngineTests.swift
//  ResonanceTests
//
//  Unit tests for GuardFilters (FilterReason, FilterResult) and
//  DecisionContext helper methods. The DecisionEngine itself requires
//  Core Data setup, so we focus on the independently testable pieces.
//

import XCTest
@testable import Resonance

// MARK: - FilterReason Tests

final class FilterReasonTests: XCTestCase {

    func test_playedRecently_rawValue() {
        XCTAssertEqual(FilterReason.playedRecently.rawValue, "Played too recently")
    }

    func test_sameArtistLimit_rawValue() {
        XCTAssertEqual(FilterReason.sameArtistLimit.rawValue, "Too many songs from same artist in a row")
    }

    func test_bpmTooHighForTime_rawValue() {
        XCTAssertEqual(FilterReason.bpmTooHighForTime.rawValue, "BPM too high for current time of day")
    }

    func test_bpmTooHighForState_rawValue() {
        XCTAssertEqual(FilterReason.bpmTooHighForState.rawValue, "BPM too high for current biometric state")
    }

    func test_energyMismatch_rawValue() {
        XCTAssertEqual(FilterReason.energyMismatch.rawValue, "Energy level mismatched for guard adjustment")
    }

    func test_noValidId_rawValue() {
        XCTAssertEqual(FilterReason.noValidId.rawValue, "Song has no valid identifier")
    }

    func test_allCases_haveNonEmptyRawValues() {
        let allCases: [FilterReason] = [
            .playedRecently,
            .sameArtistLimit,
            .bpmTooHighForTime,
            .bpmTooHighForState,
            .energyMismatch,
            .noValidId
        ]

        for reason in allCases {
            XCTAssertFalse(reason.rawValue.isEmpty, "\(reason) should have a non-empty rawValue")
        }
    }
}

// MARK: - DecisionContext Tests

final class DecisionContextTests: XCTestCase {

    // MARK: - Time Helpers

    func test_isNighttime_at22_returnsTrue() {
        let context = makeContext(hour: 22)
        XCTAssertTrue(context.isNighttime)
    }

    func test_isNighttime_at3AM_returnsTrue() {
        let context = makeContext(hour: 3)
        XCTAssertTrue(context.isNighttime)
    }

    func test_isNighttime_atNoon_returnsFalse() {
        let context = makeContext(hour: 12)
        XCTAssertFalse(context.isNighttime)
    }

    func test_isMorning_at7AM_returnsTrue() {
        let context = makeContext(hour: 7)
        XCTAssertTrue(context.isMorning)
    }

    func test_isMorning_at11AM_returnsFalse() {
        let context = makeContext(hour: 11)
        XCTAssertFalse(context.isMorning)
    }

    func test_currentHour_returnsCorrectHour() {
        let context = makeContext(hour: 15)
        XCTAssertEqual(context.currentHour, 15)
    }

    // MARK: - Time Slots

    func test_timeSlot_earlyMorning() {
        let context = makeContext(hour: 6)
        XCTAssertEqual(context.timeSlot, .earlyMorning)
    }

    func test_timeSlot_morning() {
        let context = makeContext(hour: 10)
        XCTAssertEqual(context.timeSlot, .morning)
    }

    func test_timeSlot_midday() {
        let context = makeContext(hour: 13)
        XCTAssertEqual(context.timeSlot, .midday)
    }

    func test_timeSlot_afternoon() {
        let context = makeContext(hour: 15)
        XCTAssertEqual(context.timeSlot, .afternoon)
    }

    func test_timeSlot_evening() {
        let context = makeContext(hour: 19)
        XCTAssertEqual(context.timeSlot, .evening)
    }

    func test_timeSlot_night() {
        let context = makeContext(hour: 23)
        XCTAssertEqual(context.timeSlot, .night)
    }

    func test_timeSlot_lateNight() {
        let context = makeContext(hour: 2)
        XCTAssertEqual(context.timeSlot, .night)
    }

    // MARK: - Recency Checking

    func test_wasPlayedRecently_withinWindow_returnsTrue() {
        let songId = UUID()
        let now = Date()
        let tenMinutesAgo = now.addingTimeInterval(-10 * 60) // 10 minutes ago

        let context = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: tenMinutesAgo],
            currentTime: now,
            preferences: UserPreferences(avoidRecentMinutes: 60)
        )

        XCTAssertTrue(context.wasPlayedRecently(songId))
    }

    func test_wasPlayedRecently_outsideWindow_returnsFalse() {
        let songId = UUID()
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-120 * 60) // 120 minutes ago

        let context = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: twoHoursAgo],
            currentTime: now,
            preferences: UserPreferences(avoidRecentMinutes: 60)
        )

        XCTAssertFalse(context.wasPlayedRecently(songId))
    }

    func test_wasPlayedRecently_neverPlayed_returnsFalse() {
        let songId = UUID()
        let context = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [:],
            currentTime: Date()
        )

        XCTAssertFalse(context.wasPlayedRecently(songId))
    }

    func test_minutesSinceLastPlayed_neverPlayed_returnsNil() {
        let songId = UUID()
        let context = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            recentlyPlayed: [:]
        )

        XCTAssertNil(context.minutesSinceLastPlayed(songId))
    }

    func test_minutesSinceLastPlayed_recentSong_returnsCorrectMinutes() {
        let songId = UUID()
        let now = Date()
        let thirtyMinutesAgo = now.addingTimeInterval(-30 * 60)

        let context = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songId],
            recentlyPlayed: [songId: thirtyMinutesAgo],
            currentTime: now
        )

        let minutes = context.minutesSinceLastPlayed(songId)
        XCTAssertNotNil(minutes)
        XCTAssertEqual(minutes!, 30.0, accuracy: 0.1)
    }

    // MARK: - Convenience Properties

    func test_availableSongCount_matchesCandidateIds() {
        let ids = [UUID(), UUID(), UUID()]
        let context = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: ids
        )

        XCTAssertEqual(context.availableSongCount, 3)
    }

    func test_sessionSongCount_matchesSessionIds() {
        let sessionIds = [UUID(), UUID()]
        let context = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            currentSessionSongIds: sessionIds
        )

        XCTAssertEqual(context.sessionSongCount, 2)
    }

    func test_isSessionStart_reflectsInitValue() {
        let context = DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            isSessionStart: true
        )

        XCTAssertTrue(context.isSessionStart)
    }

    // MARK: - Placeholder Factory

    func test_placeholder_createsValidContext() {
        let context = DecisionContext.placeholder()
        XCTAssertEqual(context.activePlaylistName, "Test Playlist")
        XCTAssertTrue(context.candidateSongIds.isEmpty)
        XCTAssertTrue(context.isSessionStart)
    }

    // MARK: - Helpers

    /// Creates a DecisionContext with the current time set to a specific hour today.
    private func makeContext(hour: Int) -> DecisionContext {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let components = DateComponents(
            year: 2026, month: 2, day: 22,
            hour: hour, minute: 0, second: 0
        )
        let date = calendar.date(from: components)!

        return DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            currentTime: date
        )
    }
}

// MARK: - TimeSlot Tests

final class TimeSlotTests: XCTestCase {

    func test_allCases_containExpectedCount() {
        XCTAssertEqual(TimeSlot.allCases.count, 7)
    }

    func test_displayNames_areNonEmpty() {
        for slot in TimeSlot.allCases {
            XCTAssertFalse(slot.displayName.isEmpty, "\(slot) should have a non-empty displayName")
        }
    }

    func test_suggestedMaxBPM_nightIsLowest() {
        let nightBPM = TimeSlot.night.suggestedMaxBPM
        let middayBPM = TimeSlot.midday.suggestedMaxBPM
        XCTAssertLessThan(nightBPM, middayBPM)
    }

    func test_suggestedMaxBPM_earlyMorningIsLow() {
        XCTAssertEqual(TimeSlot.earlyMorning.suggestedMaxBPM, 100)
    }

    func test_suggestedMaxBPM_middayIsHigh() {
        XCTAssertEqual(TimeSlot.midday.suggestedMaxBPM, 140)
    }

    func test_rawValues_areNonEmpty() {
        for slot in TimeSlot.allCases {
            XCTAssertFalse(slot.rawValue.isEmpty, "\(slot) should have a non-empty rawValue")
        }
    }
}

// MARK: - GuardFilters Instantiation Test

final class GuardFiltersTests: XCTestCase {

    func test_guardFilters_canBeInstantiated() {
        let filters = GuardFilters()
        XCTAssertNotNil(filters)
    }

    func test_filterResult_acceptedCount_matchesAcceptedArray() {
        // FilterResult.acceptedCount is a computed property on accepted.count.
        // We cannot construct FilterResult with Song objects without Core Data,
        // but we can verify the type relationship by constructing with empty arrays.
        let result = FilterResult(accepted: [], rejected: [], totalCandidates: 0)
        XCTAssertEqual(result.acceptedCount, 0)
        XCTAssertEqual(result.totalCandidates, 0)
        XCTAssertTrue(result.accepted.isEmpty)
        XCTAssertTrue(result.rejected.isEmpty)
    }
}
