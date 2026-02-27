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

    func test_scoreSong_producesValidScore() throws {
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

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        XCTAssertEqual(score.songTitle, "Test Song")
        XCTAssertEqual(score.artistName, "Test Artist")
        XCTAssertGreaterThanOrEqual(score.bpmMatchScore, 0.0)
        XCTAssertLessThanOrEqual(score.bpmMatchScore, 1.0)
        XCTAssertGreaterThanOrEqual(score.energyMatchScore, 0.0)
        XCTAssertLessThanOrEqual(score.energyMatchScore, 1.0)
    }

    func test_scoreSong_unknownBPM_neutralBPMScore() throws {
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

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        // Unknown BPM → 0.5 neutral score
        XCTAssertEqual(score.bpmMatchScore, 0.5, accuracy: 0.001)
    }

    func test_scoreSong_contextAlignment_workoutHighEnergy() throws {
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

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        // High energy song in workout context should have high context alignment
        XCTAssertGreaterThan(score.contextAlignmentScore, 0.7)
    }

    // MARK: - BPM Match Score

    func test_bpmMatch_exactTarget_scoreNearOne() throws {
        // For maintain need with energy 0.5, target BPM = 90 + 0.5 * 40 = 110
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        let song = makeSong(in: ctx, bpm: 110, energy: 0.5)
        try? ctx.save()

        let state = StateVector(
            energy: 0.5,
            inferredNeed: .maintain
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 14)
        )

        let targetBPM = scorer.calculateTargetBPM(state: state, context: decisionContext)
        // Set the song BPM to exactly the target
        song.bpm = targetBPM
        try? ctx.save()

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        // Exact match → BPM delta is 0 → score = 1.0
        XCTAssertEqual(score.bpmMatchScore, 1.0, accuracy: 0.001,
                       "Song at exact target BPM should get a BPM match score near 1.0")
    }

    func test_bpmMatch_50BPMAway_lowScore() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        let state = StateVector(
            energy: 0.5,
            inferredNeed: .maintain
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            currentTime: makeDate(hour: 14)
        )

        let targetBPM = scorer.calculateTargetBPM(state: state, context: decisionContext)

        // Place the song exactly 50 BPM away from target (at bpmTolerance boundary)
        let song = makeSong(in: ctx, bpm: targetBPM + 50, energy: 0.5)
        try? ctx.save()

        let updatedContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 14)
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: updatedContext))

        // bpmTolerance is 50, delta is 50 → score = max(0, 1.0 - 50/50) = 0.0
        XCTAssertEqual(score.bpmMatchScore, 0.0, accuracy: 0.01,
                       "Song 50 BPM away from target should get a BPM match score near 0.0")
    }

    // MARK: - Energy Match Score

    func test_energyMatch_exactTarget_scoreNearOne() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        let state = StateVector(
            energy: 0.5,
            inferredNeed: .maintain
        )
        // maintain → targetEnergy = state.energy = 0.5
        let song = makeSong(in: ctx, bpm: 110, energy: 0.5)
        try? ctx.save()

        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 14)
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        // energyDelta = |0.5 - 0.5| = 0 → score = 1.0
        XCTAssertEqual(score.energyMatchScore, 1.0, accuracy: 0.001,
                       "Song at exact target energy should get an energy match score near 1.0")
    }

    func test_energyMatch_oppositeEnergy_lowScore() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        let state = StateVector(
            stress: 0.0,
            inferredNeed: .calm
        )
        // calm target energy = 0.3 - 0.0*0.1 = 0.3
        // Song energy = 0.9 → delta = |0.9 - 0.3| = 0.6 → score = 1.0 - 0.6 = 0.4
        let song = makeSong(in: ctx, bpm: 80, energy: 0.9)
        try? ctx.save()

        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 14)
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        // Target energy ~0.3, song energy 0.9, delta 0.6 → score = 0.4
        XCTAssertLessThanOrEqual(score.energyMatchScore, 0.5,
                                 "Song with energy far from target should get a low energy match score")
    }

    // MARK: - Context Alignment

    func test_contextAlignment_preSleep_lowEnergySong_highAlignment() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        // preSleep formula: energyFit * 0.4 + bpmFit * 0.3 + instrumentalFit * 0.3
        // energy=0.1 → energyFit = max(0, 1.0 - 0.1*1.5) = 0.85
        // bpm=70 < 80 → bpmFit = 1.0
        // instrumentalness=0.9 → instrumentalFit = 0.9*0.8 = 0.72
        // total = 0.85*0.4 + 1.0*0.3 + 0.72*0.3 = 0.34 + 0.30 + 0.216 = 0.856
        let song = makeSong(in: ctx, bpm: 70, energy: 0.1)
        song.instrumentalness = 0.9
        try? ctx.save()

        let state = StateVector(
            energy: 0.3,
            context: .preSleep,
            inferredNeed: .calm
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 22)
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        XCTAssertGreaterThan(score.contextAlignmentScore, 0.7,
                             "Low energy, low BPM, instrumental song should align well with preSleep context")
    }

    func test_contextAlignment_focus_highInstrumentalness_highAlignment() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        // deepWork formula: instrumentalFit * 0.5 + energyFit * 0.5
        // instrumentalness=0.9 → instrumentalFit = 0.9
        // energy=0.4 → energyFit = 1.0 - |0.4 - 0.4| = 1.0
        // total = 0.9*0.5 + 1.0*0.5 = 0.95
        let song = makeSong(in: ctx, bpm: 90, energy: 0.4)
        song.instrumentalness = 0.9
        try? ctx.save()

        let state = StateVector(
            energy: 0.5,
            focus: 0.7,
            context: .deepWork,
            inferredNeed: .focus
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 10)
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        XCTAssertGreaterThan(score.contextAlignmentScore, 0.8,
                             "High instrumentalness song in deepWork context should have high alignment")
    }

    // MARK: - Familiarity Scoring

    func test_familiarity_highFamiliarityUnderStress_highScore() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        let song = makeSong(in: ctx, bpm: 100, energy: 0.5)
        song.familiarityScore = 0.8
        try? ctx.save()

        // stress > 0.6 with preferFamiliarInStress = true → boost = 1.3
        // familiarityScore = clamp(0.8 * 1.3, 0, 1) = clamp(1.04, 0, 1) = 1.0
        let state = StateVector(
            energy: 0.5,
            stress: 0.8,
            context: .work,
            inferredNeed: .maintain
        )
        let prefs = UserPreferences(preferFamiliarInStress: true)
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 14),
            preferences: prefs
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        XCTAssertGreaterThanOrEqual(score.familiarityScore, 0.9,
                                    "High familiarity song when stressed should get boosted familiarity score")
    }

    func test_familiarity_zeroFamiliarity_lowerScore() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        let song = makeSong(in: ctx, bpm: 100, energy: 0.5)
        song.familiarityScore = 0.0
        try? ctx.save()

        let state = StateVector(
            energy: 0.5,
            inferredNeed: .maintain
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 14)
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        // familiarityScore = 0.0 * boost = 0.0
        XCTAssertEqual(score.familiarityScore, 0.0, accuracy: 0.001,
                       "Song with zero familiarity should produce a familiarity score of 0.0")
    }

    // MARK: - Recency Penalty

    func test_recencyPenalty_recentlyPlayedSong_penalized() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        let song = makeSong(in: ctx, bpm: 110, energy: 0.5)
        try? ctx.save()

        let now = makeDate(hour: 14)
        // Song played 10 minutes ago; default avoidRecentMinutes = 60
        // recencyPenalty = 1.0 - (10 / 60) = 0.833
        let tenMinutesAgo = now.addingTimeInterval(-10 * 60)

        let state = StateVector(
            energy: 0.5,
            inferredNeed: .maintain
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            recentlyPlayed: [song.id!: tenMinutesAgo],
            currentTime: now
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        XCTAssertGreaterThan(score.recencyPenalty, 0.5,
                             "Song played 10 minutes ago should have a significant recency penalty")
    }

    func test_recencyPenalty_notRecentlyPlayed_noPenalty() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        let song = makeSong(in: ctx, bpm: 110, energy: 0.5)
        try? ctx.save()

        let state = StateVector(
            energy: 0.5,
            inferredNeed: .maintain
        )
        // No recentlyPlayed entry for this song → penalty = 0.0
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 14)
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        XCTAssertEqual(score.recencyPenalty, 0.0, accuracy: 0.001,
                       "Song not recently played should have zero recency penalty")
    }

    // MARK: - Time of Day Scoring

    func test_timeOfDayScore_morningSongAtMorningTime_goodScore() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        // Morning time slot (9-12) has suggestedMaxBPM = 130
        // Song at 100 BPM <= 130 → timeOfDayScore = 1.0
        let song = makeSong(in: ctx, bpm: 100, energy: 0.5)
        song.valence = 0.8
        try? ctx.save()

        let state = StateVector(
            energy: 0.5,
            context: .morning,
            inferredNeed: .maintain
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 10)
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        XCTAssertEqual(score.timeOfDayScore, 1.0, accuracy: 0.001,
                       "Moderate BPM song during morning should get a perfect time-of-day score")
    }

    func test_timeOfDayScore_highBPMAtNight_penalized() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        // Night time slot (21-5) has suggestedMaxBPM = 90
        // Song at 150 BPM → excess = 60 → score = max(0.3, 1.0 - 60/60) = max(0.3, 0.0) = 0.3
        let song = makeSong(in: ctx, bpm: 150, energy: 0.9)
        try? ctx.save()

        let state = StateVector(
            energy: 0.5,
            inferredNeed: .maintain
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            currentTime: makeDate(hour: 22)
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        XCTAssertLessThan(score.timeOfDayScore, 0.5,
                          "High BPM song at night should receive a time-of-day penalty")
    }

    // MARK: - scoreAllCandidates

    func test_scoreAllCandidates_returnsSortedHighestFirst() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        // Create songs with clearly different energy levels relative to target.
        // maintain need with energy 0.5 → targetEnergy = 0.5
        let songClose = makeSong(in: ctx, bpm: 110, energy: 0.5, title: "Close Match")
        let songMedium = makeSong(in: ctx, bpm: 110, energy: 0.3, title: "Medium Match")
        let songFar = makeSong(in: ctx, bpm: 110, energy: 0.0, title: "Far Match")
        try? ctx.save()

        let state = StateVector(
            energy: 0.5,
            inferredNeed: .maintain
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [songClose.id!, songMedium.id!, songFar.id!],
            currentTime: makeDate(hour: 14)
        )

        let results = scorer.scoreAllCandidates(
            [songFar, songClose, songMedium],
            context: decisionContext
        )

        XCTAssertEqual(results.count, 3, "Should return scores for all 3 candidates")

        // Verify descending order
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(
                results[i].finalScore,
                results[i + 1].finalScore,
                "Results should be sorted by finalScore in descending order"
            )
        }
    }

    func test_scoreAllCandidates_emptyCandidates_returnsEmpty() {
        let state = StateVector(
            energy: 0.5,
            inferredNeed: .maintain
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            currentTime: makeDate(hour: 14)
        )

        let results = scorer.scoreAllCandidates([], context: decisionContext)

        XCTAssertTrue(results.isEmpty,
                      "scoreAllCandidates with empty song list should return empty array")
    }

    // MARK: - Final Score Clamping

    func test_finalScore_isNeverNegative() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        // Create a song that will score poorly on most dimensions and has a
        // maximum recency penalty to push the score as negative as possible.
        let song = makeSong(in: ctx, bpm: 180, energy: 0.0)
        song.familiarityScore = 0.0
        try? ctx.save()

        let now = makeDate(hour: 23)
        // Song played 1 minute ago → recencyPenalty = 1.0 - (1/60) ≈ 0.983
        let oneMinuteAgo = now.addingTimeInterval(-60)

        let state = StateVector(
            energy: 0.9,
            context: .preSleep,
            inferredNeed: .calm
        )
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [song.id!],
            recentlyPlayed: [song.id!: oneMinuteAgo],
            currentTime: now
        )

        let score = try XCTUnwrap(scorer.scoreSong(song, context: decisionContext))

        XCTAssertGreaterThanOrEqual(score.finalScore, 0.0,
                                    "Final score should always be clamped to non-negative")
    }

    // MARK: - Nil ID Handling

    func test_scoreSong_nilId_returnsNil() throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.viewContext

        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: ctx) as! Song
        // Do NOT set song.id — it remains nil
        song.appleMusicId = "no_id_song"
        song.title = "No ID Song"
        song.artistName = "Artist"
        song.bpm = 120
        song.energyEstimate = 0.5
        song.durationSeconds = 200
        try? ctx.save()

        let state = StateVector(inferredNeed: .maintain)
        let decisionContext = DecisionContext(
            stateVector: state,
            activePlaylistId: UUID(),
            activePlaylistName: "Test",
            candidateSongIds: [],
            currentTime: makeDate(hour: 12)
        )

        let score = scorer.scoreSong(song, context: decisionContext)

        XCTAssertNil(score, "Song with nil id should return nil score")
    }

    // MARK: - Helpers

    /// Creates a Song entity with commonly needed defaults pre-filled.
    private func makeSong(
        in context: NSManagedObjectContext,
        bpm: Double,
        energy: Double,
        title: String = "Test Song"
    ) -> Song {
        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
        song.id = UUID()
        song.appleMusicId = "test_\(UUID().uuidString)"
        song.title = title
        song.artistName = "Test Artist"
        song.albumName = "Test Album"
        song.bpm = bpm
        song.energyEstimate = energy
        song.valence = 0.5
        song.instrumentalness = 0.5
        song.familiarityScore = 0.5
        song.durationSeconds = 200
        return song
    }

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
