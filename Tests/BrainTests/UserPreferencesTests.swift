//
//  UserPreferencesTests.swift
//  ResonanceTests
//
//  Unit tests for UserPreferences: default values, weight normalization,
//  validation, presets, and persistence round-tripping.
//

import XCTest
@testable import Resonance

final class UserPreferencesTests: XCTestCase {

    // MARK: - Default Values

    func test_defaultPreferences_weightsExactlySumToOne() {
        let prefs = UserPreferences.default
        let sum = prefs.bpmWeight + prefs.energyWeight + prefs.familiarityWeight
            + prefs.historicalWeight + prefs.contextWeight
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func test_defaultPreferences_individualWeightValues() {
        let prefs = UserPreferences.default
        XCTAssertEqual(prefs.bpmWeight, 0.15, accuracy: 0.001)
        XCTAssertEqual(prefs.energyWeight, 0.20, accuracy: 0.001)
        XCTAssertEqual(prefs.familiarityWeight, 0.15, accuracy: 0.001)
        XCTAssertEqual(prefs.historicalWeight, 0.25, accuracy: 0.001)
        XCTAssertEqual(prefs.contextWeight, 0.25, accuracy: 0.001)
    }

    func test_defaultPreferences_behavioralDefaults() {
        let prefs = UserPreferences.default
        XCTAssertEqual(prefs.avoidRecentMinutes, 60)
        XCTAssertEqual(prefs.maxSameArtistInRow, 2)
        XCTAssertTrue(prefs.preferFamiliarInStress)
        XCTAssertTrue(prefs.enableSmoothTransitions)
    }

    func test_defaultPreferences_timeOfDayDefaults() {
        let prefs = UserPreferences.default
        XCTAssertEqual(prefs.morningMaxBPM, 120)
        XCTAssertEqual(prefs.nightMaxBPM, 100)
        XCTAssertEqual(prefs.nightStartHour, 21)
        XCTAssertEqual(prefs.morningEndHour, 9)
    }

    func test_defaultPreferences_learningDefaults() {
        let prefs = UserPreferences.default
        XCTAssertEqual(prefs.skipPenaltyWeight, 0.5, accuracy: 0.001)
        XCTAssertEqual(prefs.hrvResponseWeight, 0.3, accuracy: 0.001)
        XCTAssertEqual(prefs.learningRate, 0.2, accuracy: 0.001)
    }

    func test_defaultPreferences_privacyDefaults() {
        let prefs = UserPreferences.default
        XCTAssertFalse(prefs.shareAnalytics)
        XCTAssertTrue(prefs.backupToiCloud)
    }

    // MARK: - Weight Validation

    func test_areWeightsValid_defaultIsTrue() {
        let prefs = UserPreferences.default
        XCTAssertTrue(prefs.areWeightsValid)
    }

    func test_areWeightsValid_slightlyOff_isTrue() {
        // Weights summing to 0.98 should still be valid (within 0.95-1.05 range)
        let prefs = UserPreferences(
            bpmWeight: 0.19,
            energyWeight: 0.20,
            familiarityWeight: 0.19,
            historicalWeight: 0.20,
            contextWeight: 0.20
        )
        XCTAssertTrue(prefs.areWeightsValid)
    }

    func test_areWeightsValid_wayOff_isFalse() {
        let prefs = UserPreferences(
            bpmWeight: 0.5,
            energyWeight: 0.5,
            familiarityWeight: 0.5,
            historicalWeight: 0.5,
            contextWeight: 0.5
        )
        XCTAssertFalse(prefs.areWeightsValid, "Weights summing to 2.5 should not be valid")
    }

    // MARK: - Normalize Weights

    func test_normalizeWeights_sumsToOne() {
        var prefs = UserPreferences(
            bpmWeight: 0.5,
            energyWeight: 0.5,
            familiarityWeight: 0.5,
            historicalWeight: 0.5,
            contextWeight: 0.5
        )
        prefs.normalizeWeights()
        let sum = prefs.bpmWeight + prefs.energyWeight + prefs.familiarityWeight
            + prefs.historicalWeight + prefs.contextWeight
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func test_normalizeWeights_preservesRelativeProportions() {
        var prefs = UserPreferences(
            bpmWeight: 1.0,
            energyWeight: 2.0,
            familiarityWeight: 1.0,
            historicalWeight: 3.0,
            contextWeight: 3.0
        )
        prefs.normalizeWeights()
        // Total was 10, so each is divided by 10
        XCTAssertEqual(prefs.bpmWeight, 0.1, accuracy: 0.001)
        XCTAssertEqual(prefs.energyWeight, 0.2, accuracy: 0.001)
        XCTAssertEqual(prefs.familiarityWeight, 0.1, accuracy: 0.001)
        XCTAssertEqual(prefs.historicalWeight, 0.3, accuracy: 0.001)
        XCTAssertEqual(prefs.contextWeight, 0.3, accuracy: 0.001)
    }

    func test_normalizeWeights_allZero_doesNotDivideByZero() {
        var prefs = UserPreferences(
            bpmWeight: 0.0,
            energyWeight: 0.0,
            familiarityWeight: 0.0,
            historicalWeight: 0.0,
            contextWeight: 0.0
        )
        // Should not crash — guard total > 0 in implementation
        prefs.normalizeWeights()
        XCTAssertEqual(prefs.bpmWeight, 0.0)
        XCTAssertEqual(prefs.energyWeight, 0.0)
    }

    func test_normalizeWeights_alreadyNormalized_noChange() {
        var prefs = UserPreferences.default
        let originalBPM = prefs.bpmWeight
        prefs.normalizeWeights()
        XCTAssertEqual(prefs.bpmWeight, originalBPM, accuracy: 0.0001)
    }

    // MARK: - Validated

    func test_validated_normalizesWeights() {
        let prefs = UserPreferences(
            bpmWeight: 2.0,
            energyWeight: 2.0,
            familiarityWeight: 2.0,
            historicalWeight: 2.0,
            contextWeight: 2.0
        )
        let validated = prefs.validated()
        let sum = validated.bpmWeight + validated.energyWeight + validated.familiarityWeight
            + validated.historicalWeight + validated.contextWeight
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func test_validated_clampsAvoidRecentMinutes() {
        let prefs = UserPreferences(avoidRecentMinutes: 9999)
        let validated = prefs.validated()
        XCTAssertLessThanOrEqual(validated.avoidRecentMinutes, 480)
    }

    func test_validated_clampsNegativeAvoidRecentMinutes() {
        let prefs = UserPreferences(avoidRecentMinutes: -10)
        let validated = prefs.validated()
        XCTAssertGreaterThanOrEqual(validated.avoidRecentMinutes, 0)
    }

    func test_validated_clampsMaxSameArtistInRow() {
        let tooHigh = UserPreferences(maxSameArtistInRow: 100)
        XCTAssertLessThanOrEqual(tooHigh.validated().maxSameArtistInRow, 10)

        let tooLow = UserPreferences(maxSameArtistInRow: 0)
        XCTAssertGreaterThanOrEqual(tooLow.validated().maxSameArtistInRow, 1)
    }

    func test_validated_clampsMorningMaxBPM() {
        let tooHigh = UserPreferences(morningMaxBPM: 999)
        XCTAssertLessThanOrEqual(tooHigh.validated().morningMaxBPM, 200)

        let tooLow = UserPreferences(morningMaxBPM: 10)
        XCTAssertGreaterThanOrEqual(tooLow.validated().morningMaxBPM, 60)
    }

    func test_validated_clampsNightMaxBPM() {
        let tooHigh = UserPreferences(nightMaxBPM: 999)
        XCTAssertLessThanOrEqual(tooHigh.validated().nightMaxBPM, 200)

        let tooLow = UserPreferences(nightMaxBPM: 10)
        XCTAssertGreaterThanOrEqual(tooLow.validated().nightMaxBPM, 40)
    }

    func test_validated_clampsNightStartHour() {
        let tooHigh = UserPreferences(nightStartHour: 25)
        XCTAssertLessThanOrEqual(tooHigh.validated().nightStartHour, 23)

        let tooLow = UserPreferences(nightStartHour: 5)
        XCTAssertGreaterThanOrEqual(tooLow.validated().nightStartHour, 18)
    }

    func test_validated_clampsMorningEndHour() {
        let tooHigh = UserPreferences(morningEndHour: 20)
        XCTAssertLessThanOrEqual(tooHigh.validated().morningEndHour, 12)

        let tooLow = UserPreferences(morningEndHour: 1)
        XCTAssertGreaterThanOrEqual(tooLow.validated().morningEndHour, 5)
    }

    func test_validated_clampsSkipPenaltyWeight() {
        let tooHigh = UserPreferences(skipPenaltyWeight: 5.0)
        XCTAssertLessThanOrEqual(tooHigh.validated().skipPenaltyWeight, 1.0)

        let tooLow = UserPreferences(skipPenaltyWeight: -1.0)
        XCTAssertGreaterThanOrEqual(tooLow.validated().skipPenaltyWeight, 0.0)
    }

    func test_validated_clampsHrvResponseWeight() {
        let tooHigh = UserPreferences(hrvResponseWeight: 5.0)
        XCTAssertLessThanOrEqual(tooHigh.validated().hrvResponseWeight, 1.0)

        let tooLow = UserPreferences(hrvResponseWeight: -1.0)
        XCTAssertGreaterThanOrEqual(tooLow.validated().hrvResponseWeight, 0.0)
    }

    func test_validated_clampsLearningRate() {
        let tooHigh = UserPreferences(learningRate: 5.0)
        XCTAssertLessThanOrEqual(tooHigh.validated().learningRate, 0.5)

        let tooLow = UserPreferences(learningRate: 0.001)
        XCTAssertGreaterThanOrEqual(tooLow.validated().learningRate, 0.05)
    }

    func test_validated_doesNotMutateOriginal() {
        let original = UserPreferences(avoidRecentMinutes: 9999)
        let _ = original.validated()
        XCTAssertEqual(original.avoidRecentMinutes, 9999, "validated() should return a copy, not mutate")
    }

    // MARK: - Presets

    func test_focusPreset_highContextWeight() {
        let prefs = UserPreferences.focusPreset
        XCTAssertGreaterThan(prefs.contextWeight, 0.2)
    }

    func test_focusPreset_weightsAreValid() {
        let prefs = UserPreferences.focusPreset
        XCTAssertTrue(prefs.areWeightsValid)
    }

    func test_focusPreset_smoothTransitionsEnabled() {
        let prefs = UserPreferences.focusPreset
        XCTAssertTrue(prefs.enableSmoothTransitions)
    }

    func test_workoutPreset_highEnergyWeight() {
        let prefs = UserPreferences.workoutPreset
        XCTAssertGreaterThan(prefs.energyWeight, 0.2)
    }

    func test_workoutPreset_highBpmWeight() {
        let prefs = UserPreferences.workoutPreset
        XCTAssertGreaterThan(prefs.bpmWeight, 0.2)
    }

    func test_workoutPreset_weightsAreValid() {
        let prefs = UserPreferences.workoutPreset
        XCTAssertTrue(prefs.areWeightsValid)
    }

    func test_workoutPreset_highNightMaxBPM() {
        let prefs = UserPreferences.workoutPreset
        // Workout should allow higher BPM even at night
        XCTAssertGreaterThan(prefs.nightMaxBPM, UserPreferences.default.nightMaxBPM)
    }

    func test_relaxationPreset_highHistoricalWeight() {
        let prefs = UserPreferences.relaxationPreset
        XCTAssertGreaterThan(prefs.historicalWeight, 0.2)
    }

    func test_relaxationPreset_lowNightMaxBPM() {
        let prefs = UserPreferences.relaxationPreset
        XCTAssertLessThan(prefs.nightMaxBPM, UserPreferences.default.nightMaxBPM)
    }

    func test_relaxationPreset_weightsAreValid() {
        let prefs = UserPreferences.relaxationPreset
        XCTAssertTrue(prefs.areWeightsValid)
    }

    func test_relaxationPreset_prefersFamiliarInStress() {
        let prefs = UserPreferences.relaxationPreset
        XCTAssertTrue(prefs.preferFamiliarInStress)
    }

    // MARK: - Codable Round-Trip

    func test_encodeDecode_roundTrips() throws {
        var original = UserPreferences()
        original.avoidRecentMinutes = 42
        original.maxSameArtistInRow = 5
        original.bpmWeight = 0.33
        original.shareAnalytics = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserPreferences.self, from: data)

        XCTAssertEqual(decoded.avoidRecentMinutes, 42)
        XCTAssertEqual(decoded.maxSameArtistInRow, 5)
        XCTAssertEqual(decoded.bpmWeight, 0.33, accuracy: 0.001)
        XCTAssertTrue(decoded.shareAnalytics)
    }

    func test_encodeDecode_preservesAllFields() throws {
        let original = UserPreferences(
            bpmWeight: 0.1,
            energyWeight: 0.2,
            familiarityWeight: 0.3,
            historicalWeight: 0.15,
            contextWeight: 0.25,
            avoidRecentMinutes: 90,
            maxSameArtistInRow: 3,
            preferFamiliarInStress: false,
            enableSmoothTransitions: false,
            morningMaxBPM: 130,
            nightMaxBPM: 80,
            nightStartHour: 22,
            morningEndHour: 8,
            skipPenaltyWeight: 0.6,
            hrvResponseWeight: 0.4,
            learningRate: 0.15,
            shareAnalytics: true,
            backupToiCloud: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)

        XCTAssertEqual(decoded.bpmWeight, 0.1, accuracy: 0.001)
        XCTAssertEqual(decoded.energyWeight, 0.2, accuracy: 0.001)
        XCTAssertEqual(decoded.familiarityWeight, 0.3, accuracy: 0.001)
        XCTAssertEqual(decoded.historicalWeight, 0.15, accuracy: 0.001)
        XCTAssertEqual(decoded.contextWeight, 0.25, accuracy: 0.001)
        XCTAssertEqual(decoded.avoidRecentMinutes, 90)
        XCTAssertEqual(decoded.maxSameArtistInRow, 3)
        XCTAssertFalse(decoded.preferFamiliarInStress)
        XCTAssertFalse(decoded.enableSmoothTransitions)
        XCTAssertEqual(decoded.morningMaxBPM, 130, accuracy: 0.001)
        XCTAssertEqual(decoded.nightMaxBPM, 80, accuracy: 0.001)
        XCTAssertEqual(decoded.nightStartHour, 22)
        XCTAssertEqual(decoded.morningEndHour, 8)
        XCTAssertEqual(decoded.skipPenaltyWeight, 0.6, accuracy: 0.001)
        XCTAssertEqual(decoded.hrvResponseWeight, 0.4, accuracy: 0.001)
        XCTAssertEqual(decoded.learningRate, 0.15, accuracy: 0.001)
        XCTAssertTrue(decoded.shareAnalytics)
        XCTAssertFalse(decoded.backupToiCloud)
    }

    // MARK: - Persistence (save/load/reset)

    func test_loadWithNoSavedData_returnsDefault() {
        // Reset first to clear any previously saved prefs
        UserPreferences.reset()
        let loaded = UserPreferences.load()
        // Should fall back to default values
        XCTAssertEqual(loaded.avoidRecentMinutes, 60)
        XCTAssertEqual(loaded.maxSameArtistInRow, 2)
    }

    func test_saveAndLoad_roundTrips() throws {
        // Reset to start clean
        UserPreferences.reset()

        var prefs = UserPreferences()
        prefs.avoidRecentMinutes = 42
        prefs.maxSameArtistInRow = 5
        prefs.bpmWeight = 0.33
        try prefs.save()

        let loaded = UserPreferences.load()
        XCTAssertEqual(loaded.avoidRecentMinutes, 42)
        XCTAssertEqual(loaded.maxSameArtistInRow, 5)
        XCTAssertEqual(loaded.bpmWeight, 0.33, accuracy: 0.001)

        // Clean up
        UserPreferences.reset()
    }

    func test_reset_clearsPersistedPreferences() throws {
        var prefs = UserPreferences()
        prefs.avoidRecentMinutes = 999
        try prefs.save()

        UserPreferences.reset()
        let loaded = UserPreferences.load()
        // After reset, should return defaults
        XCTAssertEqual(loaded.avoidRecentMinutes, 60)
    }

    // MARK: - Custom Initialization

    func test_customInit_setsAllProperties() {
        let prefs = UserPreferences(
            bpmWeight: 0.1,
            energyWeight: 0.2,
            familiarityWeight: 0.3,
            historicalWeight: 0.15,
            contextWeight: 0.25,
            avoidRecentMinutes: 45,
            maxSameArtistInRow: 4,
            preferFamiliarInStress: false,
            enableSmoothTransitions: false,
            morningMaxBPM: 150,
            nightMaxBPM: 85,
            nightStartHour: 22,
            morningEndHour: 7,
            skipPenaltyWeight: 0.7,
            hrvResponseWeight: 0.2,
            learningRate: 0.3,
            shareAnalytics: true,
            backupToiCloud: false
        )

        XCTAssertEqual(prefs.bpmWeight, 0.1, accuracy: 0.001)
        XCTAssertEqual(prefs.avoidRecentMinutes, 45)
        XCTAssertEqual(prefs.maxSameArtistInRow, 4)
        XCTAssertFalse(prefs.preferFamiliarInStress)
        XCTAssertFalse(prefs.enableSmoothTransitions)
        XCTAssertEqual(prefs.morningMaxBPM, 150, accuracy: 0.001)
        XCTAssertEqual(prefs.nightMaxBPM, 85, accuracy: 0.001)
        XCTAssertEqual(prefs.nightStartHour, 22)
        XCTAssertEqual(prefs.morningEndHour, 7)
        XCTAssertEqual(prefs.skipPenaltyWeight, 0.7, accuracy: 0.001)
        XCTAssertEqual(prefs.hrvResponseWeight, 0.2, accuracy: 0.001)
        XCTAssertEqual(prefs.learningRate, 0.3, accuracy: 0.001)
        XCTAssertTrue(prefs.shareAnalytics)
        XCTAssertFalse(prefs.backupToiCloud)
    }

    func test_defaultInit_usesParameterDefaults() {
        // Calling UserPreferences() should use all the default parameter values
        let prefs = UserPreferences()
        let defaultPrefs = UserPreferences.default
        XCTAssertEqual(prefs.bpmWeight, defaultPrefs.bpmWeight)
        XCTAssertEqual(prefs.energyWeight, defaultPrefs.energyWeight)
        XCTAssertEqual(prefs.avoidRecentMinutes, defaultPrefs.avoidRecentMinutes)
    }
}
