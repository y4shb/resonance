//
//  WidgetDataStoreTests.swift
//  ResonanceTests
//
//  Unit tests for WidgetDataStore read/write round-trips via App Group UserDefaults.
//

import XCTest
@testable import Resonance

final class WidgetDataStoreTests: XCTestCase {

    // MARK: - Now Playing

    func test_updateNowPlaying_writesAndReads() {
        WidgetDataStore.updateNowPlaying(
            title: "Test Song",
            artist: "Test Artist",
            isPlaying: true,
            progress: 0.5,
            duration: 240,
            explanation: "Calm selection"
        )
        let snapshot = WidgetDataStore.currentNowPlaying
        XCTAssertEqual(snapshot.songTitle, "Test Song")
        XCTAssertEqual(snapshot.artistName, "Test Artist")
        XCTAssertTrue(snapshot.isPlaying)
        XCTAssertEqual(snapshot.progress, 0.5, accuracy: 0.01)
        XCTAssertEqual(snapshot.duration, 240, accuracy: 0.01)
        XCTAssertEqual(snapshot.explanation, "Calm selection")
    }

    func test_updateNowPlaying_nilExplanation() {
        WidgetDataStore.updateNowPlaying(
            title: "Manual Pick",
            artist: "Some Artist",
            isPlaying: false,
            progress: 0.0,
            duration: 180,
            explanation: nil
        )
        let snapshot = WidgetDataStore.currentNowPlaying
        XCTAssertEqual(snapshot.songTitle, "Manual Pick")
        XCTAssertNil(snapshot.explanation)
    }

    // MARK: - State

    func test_updateState_writesAndReads() {
        WidgetDataStore.updateState(
            emoji: "\u{1F9D8}",
            stateName: "Relaxation",
            energy: 0.3,
            heartRate: 65,
            context: "relaxation"
        )
        let snapshot = WidgetDataStore.currentState
        XCTAssertEqual(snapshot.stateName, "Relaxation")
        XCTAssertEqual(snapshot.energy, 0.3, accuracy: 0.01)
        XCTAssertEqual(snapshot.heartRate!, 65, accuracy: 0.01)
        XCTAssertEqual(snapshot.stateEmoji, "\u{1F9D8}")
        XCTAssertEqual(snapshot.context, "relaxation")
    }

    func test_updateState_nilHeartRate() {
        WidgetDataStore.updateState(
            emoji: "\u{1F3B5}",
            stateName: "Unknown",
            energy: 0.5,
            heartRate: nil,
            context: "unknown"
        )
        let snapshot = WidgetDataStore.currentState
        XCTAssertNil(snapshot.heartRate)
        XCTAssertEqual(snapshot.stateName, "Unknown")
    }

    // MARK: - Staleness

    func test_freshSnapshot_isNotStale() {
        WidgetDataStore.updateNowPlaying(
            title: "Fresh",
            artist: "Artist",
            isPlaying: true,
            progress: 0.1,
            duration: 200,
            explanation: nil
        )
        let snapshot = WidgetDataStore.currentNowPlaying
        XCTAssertFalse(snapshot.isStale)
    }
}
