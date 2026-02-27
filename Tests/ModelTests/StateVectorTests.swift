//
//  StateVectorTests.swift
//  ResonanceTests
//
//  Unit tests for StateVector, ActivityContext, MusicNeed, and DataSource types.
//

import XCTest
@testable import Resonance

final class StateVectorTests: XCTestCase {

    // MARK: - Empty Factory

    func test_empty_hasNeutralValues() {
        let state = StateVector.empty
        XCTAssertEqual(state.arousal, 0.5)
        XCTAssertEqual(state.energy, 0.5)
        XCTAssertEqual(state.focus, 0.5)
        XCTAssertEqual(state.stress, 0.5)
        XCTAssertEqual(state.valence, 0.5)
        XCTAssertEqual(state.context, .unknown)
        XCTAssertEqual(state.inferredNeed, .maintain)
        XCTAssertEqual(state.confidence, 0.0)
        XCTAssertTrue(state.dataSources.isEmpty)
    }

    // MARK: - Summary

    func test_summary_producesReadableString() {
        let state = StateVector(
            context: .workout,
            inferredNeed: .energize,
            confidence: 0.75
        )

        let summary = state.summary
        XCTAssertTrue(summary.contains("Workout"), "Summary should include context display name")
        XCTAssertTrue(summary.contains("Energize"), "Summary should include need display name")
        XCTAssertTrue(summary.contains("75%"), "Summary should include confidence percentage")
    }

    func test_summary_unknownContext() {
        let state = StateVector(
            context: .unknown,
            inferredNeed: .maintain,
            confidence: 0.0
        )

        let summary = state.summary
        XCTAssertTrue(summary.contains("Unknown"))
        XCTAssertTrue(summary.contains("0%"))
    }

    // MARK: - Dominant Characteristic

    func test_dominantCharacteristic_highEnergy() {
        let state = StateVector(
            arousal: 0.3,
            energy: 0.9,
            focus: 0.2,
            stress: 0.1,
            valence: 0.5
        )
        XCTAssertEqual(state.dominantCharacteristic, "High Energy")
    }

    func test_dominantCharacteristic_stressed() {
        let state = StateVector(
            arousal: 0.3,
            energy: 0.2,
            focus: 0.1,
            stress: 0.95,
            valence: 0.5
        )
        XCTAssertEqual(state.dominantCharacteristic, "Stressed")
    }

    func test_dominantCharacteristic_focused() {
        let state = StateVector(
            arousal: 0.3,
            energy: 0.4,
            focus: 0.95,
            stress: 0.1,
            valence: 0.5
        )
        XCTAssertEqual(state.dominantCharacteristic, "Focused")
    }

    func test_dominantCharacteristic_relaxed() {
        // Relaxed = 1.0 - stress. With stress = 0.0, Relaxed = 1.0
        let state = StateVector(
            arousal: 0.3,
            energy: 0.4,
            focus: 0.4,
            stress: 0.0,
            valence: 0.5
        )
        XCTAssertEqual(state.dominantCharacteristic, "Relaxed")
    }

    // MARK: - Equatable

    func test_equatable_sameValues() {
        let date = Date()
        let a = StateVector(
            arousal: 0.5, energy: 0.5, focus: 0.5, stress: 0.5, valence: 0.5,
            context: .work, inferredNeed: .focus, timestamp: date
        )
        let b = StateVector(
            arousal: 0.5, energy: 0.5, focus: 0.5, stress: 0.5, valence: 0.5,
            context: .work, inferredNeed: .focus, timestamp: date
        )
        XCTAssertEqual(a, b)
    }

    func test_equatable_differentValues() {
        let a = StateVector(energy: 0.3)
        let b = StateVector(energy: 0.7)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Additional Dominant Characteristic Tests

    func test_dominantCharacteristic_alert() {
        let state = StateVector(
            arousal: 0.95,
            energy: 0.3,
            focus: 0.3,
            stress: 0.4,
            valence: 0.3
        )
        XCTAssertEqual(state.dominantCharacteristic, "Alert")
    }

    func test_dominantCharacteristic_positive() {
        let state = StateVector(
            arousal: 0.3,
            energy: 0.3,
            focus: 0.3,
            stress: 0.4,
            valence: 0.95
        )
        XCTAssertEqual(state.dominantCharacteristic, "Positive")
    }

    func test_dominantCharacteristic_neutralState_isDeterministic() {
        // All dimensions at 0.5 — Relaxed is also 1.0 - 0.5 = 0.5
        // All characteristics are equal; verify it returns a deterministic result
        let state = StateVector(
            arousal: 0.5,
            energy: 0.5,
            focus: 0.5,
            stress: 0.5,
            valence: 0.5
        )
        let result = state.dominantCharacteristic
        XCTAssertFalse(result.isEmpty, "dominantCharacteristic should never be empty")

        // Verify determinism: calling it again yields the same value
        let resultAgain = state.dominantCharacteristic
        XCTAssertEqual(result, resultAgain, "dominantCharacteristic should be deterministic for neutral state")
    }

    // MARK: - StateVector Custom DataSources

    func test_customDataSources_areStored() {
        let sources: Set<DataSource> = [.heartRate, .motion, .hrv]
        let state = StateVector(dataSources: sources)
        XCTAssertEqual(state.dataSources, sources)
        XCTAssertTrue(state.dataSources.contains(.heartRate))
        XCTAssertTrue(state.dataSources.contains(.motion))
        XCTAssertTrue(state.dataSources.contains(.hrv))
        XCTAssertEqual(state.dataSources.count, 3)
    }

    // MARK: - StateVector Timestamp

    func test_timestamp_isSetCorrectly() {
        let specificDate = Date(timeIntervalSince1970: 1_000_000)
        let state = StateVector(timestamp: specificDate)
        XCTAssertEqual(state.timestamp, specificDate)
    }

    func test_timestamp_defaultIsNow() {
        let before = Date()
        let state = StateVector()
        let after = Date()
        XCTAssertGreaterThanOrEqual(state.timestamp, before)
        XCTAssertLessThanOrEqual(state.timestamp, after)
    }

    // MARK: - StateVector Confidence Boundaries

    func test_confidence_zeroValue() {
        let state = StateVector(confidence: 0.0)
        XCTAssertEqual(state.confidence, 0.0)
    }

    func test_confidence_oneValue() {
        let state = StateVector(confidence: 1.0)
        XCTAssertEqual(state.confidence, 1.0)
    }
}

// MARK: - ActivityContext Tests

final class ActivityContextTests: XCTestCase {

    func test_allCases_containsExpectedCount() {
        XCTAssertEqual(ActivityContext.allCases.count, 10)
    }

    func test_displayName_workout() {
        XCTAssertEqual(ActivityContext.workout.displayName, "Workout")
    }

    func test_displayName_deepWork() {
        XCTAssertEqual(ActivityContext.deepWork.displayName, "Deep Work")
    }

    func test_displayName_preSleep() {
        XCTAssertEqual(ActivityContext.preSleep.displayName, "Pre-Sleep")
    }

    func test_displayName_postWorkout() {
        XCTAssertEqual(ActivityContext.postWorkout.displayName, "Post-Workout")
    }

    func test_displayName_allCasesNonEmpty() {
        for context in ActivityContext.allCases {
            XCTAssertFalse(context.displayName.isEmpty, "\(context) should have a non-empty displayName")
        }
    }

    func test_rawValues_areNonEmpty() {
        for context in ActivityContext.allCases {
            XCTAssertFalse(context.rawValue.isEmpty, "\(context) should have a non-empty rawValue")
        }
    }

    func test_codableRoundTrip() throws {
        for context in ActivityContext.allCases {
            let encoded = try JSONEncoder().encode(context)
            let decoded = try JSONDecoder().decode(ActivityContext.self, from: encoded)
            XCTAssertEqual(decoded, context, "\(context) should survive Codable round-trip")
        }
    }
}

// MARK: - MusicNeed Tests

final class MusicNeedTests: XCTestCase {

    func test_allCases_containsExpectedCount() {
        XCTAssertEqual(MusicNeed.allCases.count, 5)
    }

    func test_displayName_energize() {
        XCTAssertEqual(MusicNeed.energize.displayName, "Energize")
    }

    func test_displayName_calm() {
        XCTAssertEqual(MusicNeed.calm.displayName, "Calm")
    }

    func test_displayName_focus() {
        XCTAssertEqual(MusicNeed.focus.displayName, "Focus")
    }

    func test_displayName_maintain() {
        XCTAssertEqual(MusicNeed.maintain.displayName, "Maintain")
    }

    func test_displayName_transition() {
        XCTAssertEqual(MusicNeed.transition.displayName, "Transition")
    }

    func test_description_allCasesNonEmpty() {
        for need in MusicNeed.allCases {
            XCTAssertFalse(need.description.isEmpty, "\(need) should have a non-empty description")
        }
    }

    func test_displayName_allCasesNonEmpty() {
        for need in MusicNeed.allCases {
            XCTAssertFalse(need.displayName.isEmpty, "\(need) should have a non-empty displayName")
        }
    }

    func test_description_containsMeaningfulText() {
        // Verify each description contains more than just the raw case name
        for need in MusicNeed.allCases {
            let desc = need.description
            XCTAssertNotEqual(desc, need.rawValue,
                "\(need).description should contain meaningful text, not just the rawValue")
            XCTAssertGreaterThan(desc.count, need.rawValue.count,
                "\(need).description should be longer than just the rawValue")
        }
    }

    func test_codableRoundTrip() throws {
        for need in MusicNeed.allCases {
            let encoded = try JSONEncoder().encode(need)
            let decoded = try JSONDecoder().decode(MusicNeed.self, from: encoded)
            XCTAssertEqual(decoded, need, "\(need) should survive Codable round-trip")
        }
    }
}

// MARK: - DataSource Tests

final class DataSourceTests: XCTestCase {

    func test_allCases_containsExpectedCount() {
        XCTAssertEqual(DataSource.allCases.count, 9)
    }

    func test_displayName_allCasesNonEmpty() {
        for source in DataSource.allCases {
            XCTAssertFalse(source.displayName.isEmpty, "\(source) should have a non-empty displayName")
        }
    }

    func test_displayName_heartRate() {
        XCTAssertEqual(DataSource.heartRate.displayName, "Heart Rate")
    }

    func test_displayName_crownInput() {
        XCTAssertEqual(DataSource.crownInput.displayName, "Crown Input")
    }
}

// MARK: - TimeSlot Tests

final class TimeSlotTests: XCTestCase {

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

    func test_allCases_existAndHaveSuggestedMaxBPM() {
        // TimeSlot has 7 cases
        XCTAssertEqual(TimeSlot.allCases.count, 7)

        for slot in TimeSlot.allCases {
            XCTAssertGreaterThan(slot.suggestedMaxBPM, 0,
                "\(slot) should have a positive suggestedMaxBPM")
        }
    }

    func test_rawValue_roundTrip() {
        for slot in TimeSlot.allCases {
            let rawValue = slot.rawValue
            let reconstructed = TimeSlot(rawValue: rawValue)
            XCTAssertNotNil(reconstructed, "\(slot) rawValue '\(rawValue)' should produce a valid TimeSlot")
            XCTAssertEqual(reconstructed, slot, "\(slot) should survive rawValue round-trip")
        }
    }

    func test_initFromHour_earlyMorning() {
        for hour in 5..<9 {
            XCTAssertEqual(TimeSlot(hour: hour), .earlyMorning,
                "Hour \(hour) should map to earlyMorning")
        }
    }

    func test_initFromHour_morning() {
        for hour in 9..<12 {
            XCTAssertEqual(TimeSlot(hour: hour), .morning,
                "Hour \(hour) should map to morning")
        }
    }

    func test_initFromHour_midday() {
        for hour in 12..<14 {
            XCTAssertEqual(TimeSlot(hour: hour), .midday,
                "Hour \(hour) should map to midday")
        }
    }

    func test_initFromHour_afternoon() {
        for hour in 14..<17 {
            XCTAssertEqual(TimeSlot(hour: hour), .afternoon,
                "Hour \(hour) should map to afternoon")
        }
    }

    func test_initFromHour_evening() {
        for hour in 17..<21 {
            XCTAssertEqual(TimeSlot(hour: hour), .evening,
                "Hour \(hour) should map to evening")
        }
    }

    func test_initFromHour_night() {
        for hour in [21, 22, 23, 0, 1, 2, 3, 4] {
            XCTAssertEqual(TimeSlot(hour: hour), .night,
                "Hour \(hour) should map to night")
        }
    }
}
