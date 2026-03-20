//
//  LearningTests.swift
//  ResonanceTests
//
//  Unit tests for the real-time learning loop calculators:
//  SkipPenaltyCalculator, ResponseCreditCalculator, and SessionQualityScorer.
//

import XCTest
@testable import Resonance

final class SkipPenaltyCalculatorTests: XCTestCase {

    func test_noSkip_zeroPenalty() {
        let result = SkipPenaltyCalculator.calculate(
            wasSkipped: false,
            listenPercentage: 0.95
        )
        XCTAssertFalse(result.isSkip)
        XCTAssertEqual(result.penalty, 0.0)
        XCTAssertEqual(result.skipTiming, .noSkip)
    }

    func test_earlySkip_severePenalty() {
        let result = SkipPenaltyCalculator.calculate(
            wasSkipped: true,
            listenPercentage: 0.05
        )
        XCTAssertTrue(result.isSkip)
        XCTAssertEqual(result.skipTiming, .earlySkip)
        XCTAssertEqual(result.penalty, -0.3, accuracy: 0.01)
    }

    func test_lateSkip_moderatePenalty() {
        let result = SkipPenaltyCalculator.calculate(
            wasSkipped: true,
            listenPercentage: 0.20
        )
        XCTAssertTrue(result.isSkip)
        XCTAssertEqual(result.skipTiming, .lateSkip)
        XCTAssertEqual(result.penalty, -0.15, accuracy: 0.01)
    }

    func test_autoDetectedSkip_lowListenPercentage() {
        // Not manually skipped, but listen % below threshold
        let result = SkipPenaltyCalculator.calculate(
            wasSkipped: false,
            listenPercentage: 0.10
        )
        XCTAssertTrue(result.isSkip)
    }

    func test_weightedPenalty_usesPreferences() {
        let prefs = UserPreferences.default
        let result = SkipPenaltyCalculator.calculate(
            wasSkipped: true,
            listenPercentage: 0.05,
            preferences: prefs
        )
        XCTAssertEqual(result.weightedPenalty, result.penalty * prefs.skipPenaltyWeight, accuracy: 0.001)
    }
}

final class ResponseCreditCalculatorTests: XCTestCase {

    func test_positiveHRV_positiveCalmCredit() {
        let result = ResponseCreditCalculator.calculate(
            hrvDelta: 10.0,  // Significant positive HRV change
            hrDelta: -5.0,   // Slight HR decrease
            hrAtStart: 70.0,
            hrvAtStart: 40.0,
            listenPercentage: 0.95,
            wasSkipped: false
        )
        XCTAssertGreaterThan(result.calmCredit, 0.0, "Positive HRV should give positive calm credit")
        XCTAssertTrue(result.hasBiometricData)
        XCTAssertEqual(result.maxConfidence, 1.0)
    }

    func test_noBiometrics_reducedConfidence() {
        let result = ResponseCreditCalculator.calculate(
            hrvDelta: 0.0,
            hrDelta: 0.0,
            listenPercentage: 0.80,
            wasSkipped: false
        )
        XCTAssertFalse(result.hasBiometricData)
        XCTAssertEqual(result.maxConfidence, 0.7, accuracy: 0.01)
    }

    func test_skippedSong_negativeSignal() {
        let result = ResponseCreditCalculator.calculate(
            hrvDelta: 5.0,
            hrDelta: 0.0,
            listenPercentage: 0.15,
            wasSkipped: true
        )
        // Even with positive HRV, a skip should reduce credits
        let fullListenResult = ResponseCreditCalculator.calculate(
            hrvDelta: 5.0,
            hrDelta: 0.0,
            listenPercentage: 0.95,
            wasSkipped: false
        )
        XCTAssertLessThan(result.calmCredit, fullListenResult.calmCredit)
    }
}

final class SessionQualityScorerTests: XCTestCase {

    func test_perfectSession_highScore() {
        let result = SessionQualityScorer.score(
            skipRate: 0.0,
            deltaHRV: 10.0,
            avgListenPercentage: 0.95,
            sleepScore: 0.9,
            songCount: 10
        )
        XCTAssertGreaterThan(result.overallScore, 0.8)
    }

    func test_poorSession_lowScore() {
        let result = SessionQualityScorer.score(
            skipRate: 0.8,
            deltaHRV: -10.0,
            avgListenPercentage: 0.3,
            sleepScore: 0.2,
            songCount: 10
        )
        XCTAssertLessThan(result.overallScore, 0.4)
    }

    func test_noSleepData_usesNeutral() {
        let result = SessionQualityScorer.score(
            skipRate: 0.5,
            deltaHRV: 0.0,
            avgListenPercentage: 0.5,
            sleepScore: nil
        )
        XCTAssertFalse(result.hasSleepData)
        XCTAssertEqual(result.sleepScore, 0.5)
    }

    func test_runningSession_tracksMetrics() {
        var session = SessionQualityScorer.RunningSession()
        session.recordSong(wasSkipped: false, listenPercentage: 0.9, currentHRV: 50.0)
        session.recordSong(wasSkipped: true, listenPercentage: 0.1, currentHRV: 55.0)
        session.recordSong(wasSkipped: false, listenPercentage: 0.8, currentHRV: 52.0)

        XCTAssertEqual(session.totalSongs, 3)
        XCTAssertEqual(session.totalSkips, 1)
        XCTAssertEqual(session.skipRate, 1.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(session.deltaHRV, 2.0, accuracy: 0.01) // 52 - 50
    }
}
