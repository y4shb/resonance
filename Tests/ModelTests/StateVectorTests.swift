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
