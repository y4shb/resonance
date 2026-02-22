//
//  StateEngineTests.swift
//  ResonanceTests
//
//  Unit tests for StateEngine's arousal, stress, and context inference calculations.
//

import XCTest
@testable import Resonance

final class StateEngineTests: XCTestCase {

    // MARK: - Arousal

    @MainActor
    func test_arousalCalculation_normalHR() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 100,
            hrv: nil,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let result = engine.calculateArousal(biometric: bio)
        XCTAssertGreaterThan(result.value, 0.0)
        XCTAssertLessThanOrEqual(result.value, 1.0)
    }

    @MainActor
    func test_arousalCalculation_nilHR_returnsDefault() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: nil,
            hrv: nil,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let result = engine.calculateArousal(biometric: bio)
        XCTAssertEqual(result.value, 0.5, "Nil HR should return default 0.5 arousal")
        XCTAssertEqual(result.confidence, 0.0, "Nil HR should have zero confidence")
    }

    // MARK: - Stress

    @MainActor
    func test_stressCalculation_highHRV() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: nil,
            hrv: 75,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let result = engine.calculateStress(biometric: bio)
        // High HRV = low stress
        XCTAssertLessThan(result.value, 0.5)
    }

    @MainActor
    func test_stressCalculation_lowHRV() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: nil,
            hrv: 20,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let result = engine.calculateStress(biometric: bio)
        // Low HRV = high stress
        XCTAssertGreaterThan(result.value, 0.5)
    }

    @MainActor
    func test_stressCalculation_nilHRV_returnsDefault() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: nil,
            hrv: nil,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let result = engine.calculateStress(biometric: bio)
        XCTAssertEqual(result.value, 0.5, "Nil HRV should return default 0.5 stress")
        XCTAssertEqual(result.confidence, 0.0, "Nil HRV should have zero confidence")
    }

    // MARK: - Context Inference

    @MainActor
    func test_contextInference_workout() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 150,
            hrv: nil,
            isStationary: false,
            isInWorkout: true,
            sampleQuality: 0.9
        )
        let context = engine.inferActivityContext(
            biometric: bio,
            macOS: nil,
            timeSlot: .afternoon,
            isWeekend: false
        )
        XCTAssertEqual(context, .workout)
    }

    @MainActor
    func test_contextInference_deepWork_fromMacOS() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let macSignal = MacOSContextSignal(
            focusModeActive: true,
            focusModeName: "Work Focus",
            inferredWorkState: .deepWork
        )
        let context = engine.inferActivityContext(
            biometric: nil,
            macOS: macSignal,
            timeSlot: .morning,
            isWeekend: false
        )
        XCTAssertEqual(context, .deepWork)
    }

    @MainActor
    func test_contextInference_workoutTakesPriority() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 160,
            hrv: nil,
            isStationary: false,
            isInWorkout: true,
            sampleQuality: 0.9
        )
        let macSignal = MacOSContextSignal(
            focusModeActive: true,
            focusModeName: "Work Focus",
            inferredWorkState: .deepWork
        )
        let context = engine.inferActivityContext(
            biometric: bio,
            macOS: macSignal,
            timeSlot: .morning,
            isWeekend: false
        )
        // Workout should take priority over macOS deep work
        XCTAssertEqual(context, .workout)
    }

    // MARK: - ManualMoodInput

    func test_manualMoodInput_freshInput_fullWeight() {
        let input = ManualMoodInput(
            energy: 0.8,
            valence: 0.7,
            timestamp: Date()
        )
        XCTAssertEqual(input.currentWeight, 1.0, accuracy: 0.05)
        XCTAssertTrue(input.isActive)
    }

    func test_manualMoodInput_expiredInput_zeroWeight() {
        let expiredTimestamp = Date().addingTimeInterval(
            -Double(StateEngineConstants.manualMoodDecayMinutes + 1) * 60
        )
        let input = ManualMoodInput(
            energy: 0.8,
            valence: 0.7,
            timestamp: expiredTimestamp
        )
        XCTAssertEqual(input.currentWeight, 0.0)
        XCTAssertFalse(input.isActive)
    }

    func test_manualMoodInput_halfDecayed_partialWeight() {
        let halfwayTimestamp = Date().addingTimeInterval(
            -Double(StateEngineConstants.manualMoodDecayMinutes) * 60 / 2.0
        )
        let input = ManualMoodInput(
            energy: 0.8,
            valence: 0.7,
            timestamp: halfwayTimestamp
        )
        XCTAssertEqual(input.currentWeight, 0.5, accuracy: 0.1)
        XCTAssertTrue(input.isActive)
    }
}
