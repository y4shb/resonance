//
//  SongScorerTests.swift
//  ResonanceTests
//
//  Unit tests for SongScorer's target BPM/energy calculations
//  and end-to-end song scoring with Core Data Song objects.
//

import XCTest
import CoreData
@testable import Resonance

final class SongScorerTests: XCTestCase {

    private var scorer: SongScorer!

    override func setUp() {
        super.setUp()
        scorer = SongScorer()
    }

    override func tearDown() {
        scorer = nil
        super.tearDown()
    }

    // MARK: - Target BPM

    func test_calculateTargetBPM_energizeNeed_highBPM() {
        let state = StateVector(
            energy: 0.5,
            inferredNeed: .energize
        )
        let context = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            currentTime: makeDate(hour: 14) // afternoon, no night cap
        )

        let targetBPM = scorer.calculateTargetBPM(state: state, context: context)

        // Energize range is 120-160; at energy 0.5 → mid-range (~140)
        XCTAssertGreaterThanOrEqual(targetBPM, 120)
        XCTAssertLessThanOrEqual(targetBPM, 160)
    }

    func test_calculateTargetBPM_calmNeed_lowBPM() {
        let state = StateVector(
            energy: 0.3,
            inferredNeed: .calm
        )
        let context = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            currentTime: makeDate(hour: 14)
        )

        let targetBPM = scorer.calculateTargetBPM(state: state, context: context)

        // Calm range is 60-90
        XCTAssertGreaterThanOrEqual(targetBPM, 50) // absolute min
        XCTAssertLessThanOrEqual(targetBPM, 100)
    }

    func test_calculateTargetBPM_nightCap_applied() {
        let state = StateVector(
            energy: 0.8,
            inferredNeed: .energize
        )
        let prefs = UserPreferences(nightMaxBPM: 90, nightStartHour: 21)
        let context = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            currentTime: makeDate(hour: 23), // nighttime
            preferences: prefs
        )

        let targetBPM = scorer.calculateTargetBPM(state: state, context: context)

        // Night cap should limit to nightMaxBPM
        XCTAssertLessThanOrEqual(targetBPM, 90)
    }

    func test_calculateTargetBPM_focusNeed_moderateBPM() {
        let state = StateVector(
            energy: 0.5,
            inferredNeed: .focus
        )
        let context = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            currentTime: makeDate(hour: 10)
        )

        let targetBPM = scorer.calculateTargetBPM(state: state, context: context)

        // Focus range is 80-110
        XCTAssertGreaterThanOrEqual(targetBPM, 80)
        XCTAssertLessThanOrEqual(targetBPM, 130)
    }

    // MARK: - Target Energy

    func test_calculateTargetEnergy_energizeNeed_highEnergy() {
        let state = StateVector(
            arousal: 0.5,
            inferredNeed: .energize
        )

        let targetEnergy = scorer.calculateTargetEnergy(state: state)

        XCTAssertGreaterThan(targetEnergy, 0.6, "Energize need should produce high target energy")
    }

    func test_calculateTargetEnergy_calmNeed_lowEnergy() {
        let state = StateVector(
            stress: 0.3,
            inferredNeed: .calm
        )

        let targetEnergy = scorer.calculateTargetEnergy(state: state)

        XCTAssertLessThan(targetEnergy, 0.4, "Calm need should produce low target energy")
    }

    func test_calculateTargetEnergy_maintainNeed_matchesStateEnergy() {
        let state = StateVector(
            energy: 0.65,
            inferredNeed: .maintain
        )

        let targetEnergy = scorer.calculateTargetEnergy(state: state)

        XCTAssertEqual(targetEnergy, 0.65, accuracy: 0.001, "Maintain should match current energy")
    }

    func test_calculateTargetEnergy_transitionNeed_middleGround() {
        let state = StateVector(
            inferredNeed: .transition
        )

        let targetEnergy = scorer.calculateTargetEnergy(state: state)

        XCTAssertEqual(targetEnergy, 0.5, "Transition should return 0.5")
    }

    // MARK: - End-to-End Scoring with Core Data

    func test_scoreSong_producesValidScore() {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.viewContext

        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
        song.id = UUID()
        song.appleMusicId = "test_song_1"
        song.title = "Test Song"
        song.artistName = "Test Artist"
        song.albumName = "Test Album"
        song.bpm = 120
        song.energyEstimate = 0.6
        song.valence = 0.7
        song.instrumentalness = 0.3
        song.familiarityScore = 0.5
        song.durationSeconds = 240

        try? context.save()

        let state = StateVector(
            energy: 0.5,
            context: .work,
            inferredNeed: .maintain
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 14)
        )

        let score = scorer.scoreSong(song, context: decisionContext)

        XCTAssertEqual(score.songTitle, "Test Song")
        XCTAssertEqual(score.artistName, "Test Artist")
        XCTAssertGreaterThanOrEqual(score.bpmMatchScore, 0.0)
        XCTAssertLessThanOrEqual(score.bpmMatchScore, 1.0)
        XCTAssertGreaterThanOrEqual(score.energyMatchScore, 0.0)
        XCTAssertLessThanOrEqual(score.energyMatchScore, 1.0)
    }

    func test_scoreSong_unknownBPM_neutralBPMScore() {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.viewContext

        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
        song.id = UUID()
        song.appleMusicId = "test_no_bpm"
        song.title = "No BPM Song"
        song.artistName = "Artist"
        song.bpm = 0 // Unknown BPM
        song.energyEstimate = 0.5
        song.durationSeconds = 200

        try? context.save()

        let state = StateVector(inferredNeed: .maintain)
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 12)
        )

        let score = scorer.scoreSong(song, context: decisionContext)

        // Unknown BPM → 0.5 neutral score
        XCTAssertEqual(score.bpmMatchScore, 0.5, accuracy: 0.001)
    }

    func test_scoreSong_contextAlignment_workoutHighEnergy() {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.viewContext

        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
        song.id = UUID()
        song.appleMusicId = "workout_song"
        song.title = "Workout Banger"
        song.artistName = "DJ"
        song.bpm = 140
        song.energyEstimate = 0.9
        song.valence = 0.8
        song.instrumentalness = 0.2
        song.durationSeconds = 200

        try? context.save()

        let state = StateVector(
            energy: 0.8,
            context: .workout,
            inferredNeed: .energize
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 10)
        )

        let score = scorer.scoreSong(song, context: decisionContext)

        // High energy song in workout context should have high context alignment
        XCTAssertGreaterThan(score.contextAlignmentScore, 0.7)
    }

    // MARK: - Helpers

    private func makeDate(hour: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let components = DateComponents(
            year: 2026, month: 2, day: 22,
            hour: hour, minute: 0, second: 0
        )
        return calendar.date(from: components)!
    }
}
