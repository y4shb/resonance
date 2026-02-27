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

    // MARK: - Arousal Edge Cases

    /// HR of 180 should produce arousal very close to 1.0.
    /// Formula: (180 - 70) / (185 - 70) = 110 / 115 ≈ 0.957
    @MainActor
    func test_arousalCalculation_veryHighHR_approachesOne() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 180,
            hrv: nil,
            isStationary: false,
            isInWorkout: true,
            sampleQuality: 0.9
        )
        let result = engine.calculateArousal(biometric: bio)
        XCTAssertGreaterThan(result.value, 0.9, "HR of 180 should produce arousal > 0.9")
        XCTAssertLessThanOrEqual(result.value, 1.0, "Arousal must be clamped at 1.0")
    }

    /// HR above max (e.g. 200) should clamp arousal to 1.0.
    /// Formula: (200 - 70) / 115 = 1.13, clamped to 1.0
    @MainActor
    func test_arousalCalculation_hrAboveMax_clampsToOne() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 200,
            hrv: nil,
            isStationary: false,
            isInWorkout: true,
            sampleQuality: 1.0
        )
        let result = engine.calculateArousal(biometric: bio)
        XCTAssertEqual(result.value, 1.0, accuracy: 0.001, "HR above max should clamp arousal to 1.0")
    }

    /// HR of 50 (below resting) should produce arousal clamped to 0.0.
    /// Formula: (50 - 70) / 115 = -0.174, clamped to 0.0
    @MainActor
    func test_arousalCalculation_veryLowHR_clampsToZero() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 50,
            hrv: nil,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let result = engine.calculateArousal(biometric: bio)
        XCTAssertEqual(result.value, 0.0, accuracy: 0.001, "HR of 50 (below resting) should clamp arousal to 0.0")
    }

    /// HR exactly at resting (70) should produce arousal of 0.0.
    @MainActor
    func test_arousalCalculation_hrAtResting_returnsZero() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: StateEngineConstants.defaultRestingHeartRate,
            hrv: nil,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let result = engine.calculateArousal(biometric: bio)
        XCTAssertEqual(result.value, 0.0, accuracy: 0.001, "HR at resting should produce arousal of 0.0")
    }

    /// Confidence from arousal should match the biometric signal's sampleQuality.
    @MainActor
    func test_arousalCalculation_confidenceMatchesSampleQuality() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 100,
            hrv: nil,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.65
        )
        let result = engine.calculateArousal(biometric: bio)
        XCTAssertEqual(result.confidence, 0.65, accuracy: 0.001,
                       "Arousal confidence should equal sampleQuality")
    }

    /// Nil biometric signal (not just nil HR) should return default arousal.
    @MainActor
    func test_arousalCalculation_nilBiometric_returnsDefault() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let result = engine.calculateArousal(biometric: nil)
        XCTAssertEqual(result.value, 0.5, "Nil biometric should return default 0.5 arousal")
        XCTAssertEqual(result.confidence, 0.0, "Nil biometric should have zero confidence")
    }

    // MARK: - Stress Edge Cases

    /// HRV exactly at baseline (50ms) should produce stress of 0.4.
    /// Formula: 1.0 - (50/50 * 0.6) = 1.0 - 0.6 = 0.4
    @MainActor
    func test_stressCalculation_hrvAtBaseline_returnsExpectedValue() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: nil,
            hrv: 50,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let result = engine.calculateStress(biometric: bio)
        XCTAssertEqual(result.value, 0.4, accuracy: 0.001,
                       "HRV at baseline (50ms) should produce stress of 0.4")
    }

    /// Very high HRV (>= ~83.3ms) should clamp stress to 0.0.
    /// Formula: 1.0 - (100/50 * 0.6) = 1.0 - 1.2 = -0.2, clamped to 0.0
    @MainActor
    func test_stressCalculation_veryHighHRV_clampsToZero() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: nil,
            hrv: 100,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.9
        )
        let result = engine.calculateStress(biometric: bio)
        XCTAssertEqual(result.value, 0.0, accuracy: 0.001,
                       "Very high HRV (100ms) should clamp stress to 0.0")
    }

    /// Very low HRV (e.g. 5ms) should produce stress close to 1.0.
    /// Formula: 1.0 - (5/50 * 0.6) = 1.0 - 0.06 = 0.94
    @MainActor
    func test_stressCalculation_veryLowHRV_producesHighStress() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: nil,
            hrv: 5,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let result = engine.calculateStress(biometric: bio)
        XCTAssertEqual(result.value, 0.94, accuracy: 0.01,
                       "Very low HRV (5ms) should produce stress near 0.94")
    }

    /// Confidence from stress should match the biometric signal's sampleQuality.
    @MainActor
    func test_stressCalculation_confidenceMatchesSampleQuality() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: nil,
            hrv: 40,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.75
        )
        let result = engine.calculateStress(biometric: bio)
        XCTAssertEqual(result.confidence, 0.75, accuracy: 0.001,
                       "Stress confidence should equal sampleQuality")
    }

    /// Nil biometric signal (not just nil HRV) should return default stress.
    @MainActor
    func test_stressCalculation_nilBiometric_returnsDefault() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let result = engine.calculateStress(biometric: nil)
        XCTAssertEqual(result.value, 0.5, "Nil biometric should return default 0.5 stress")
        XCTAssertEqual(result.confidence, 0.0, "Nil biometric should have zero confidence")
    }

    // MARK: - Arousal & Stress Both Present

    /// When both HR and HRV are provided, both arousal and stress should have confidence > 0.
    @MainActor
    func test_arousalAndStress_bothReturnPositiveConfidence_whenBiometricPresent() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 90,
            hrv: 45,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let arousalResult = engine.calculateArousal(biometric: bio)
        let stressResult = engine.calculateStress(biometric: bio)
        XCTAssertGreaterThan(arousalResult.confidence, 0.0,
                             "Arousal confidence should be > 0 when HR is present")
        XCTAssertGreaterThan(stressResult.confidence, 0.0,
                             "Stress confidence should be > 0 when HRV is present")
    }

    /// Arousal and stress values should be consistent: high HR with low HRV means
    /// high arousal AND high stress (sympathetic dominance).
    @MainActor
    func test_arousalAndStress_highHR_lowHRV_bothElevated() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 150,
            hrv: 15,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.9
        )
        let arousalResult = engine.calculateArousal(biometric: bio)
        let stressResult = engine.calculateStress(biometric: bio)
        XCTAssertGreaterThan(arousalResult.value, 0.5, "High HR should produce elevated arousal")
        XCTAssertGreaterThan(stressResult.value, 0.5, "Low HRV should produce elevated stress")
    }

    /// Low HR with high HRV means low arousal AND low stress (parasympathetic dominance).
    @MainActor
    func test_arousalAndStress_lowHR_highHRV_bothLow() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 72,
            hrv: 80,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.9
        )
        let arousalResult = engine.calculateArousal(biometric: bio)
        let stressResult = engine.calculateStress(biometric: bio)
        XCTAssertLessThan(arousalResult.value, 0.1, "Low HR near resting should produce very low arousal")
        XCTAssertLessThan(stressResult.value, 0.1, "High HRV should produce very low stress")
    }

    // MARK: - Context Inference: Commute Detection

    /// Non-stationary movement with moderate HR (100-130) should infer commute context.
    @MainActor
    func test_contextInference_commuteDetection_moderateHR_moving() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 110,
            hrv: nil,
            isStationary: false,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let context = engine.inferActivityContext(
            biometric: bio,
            macOS: nil,
            timeSlot: .morning,
            isWeekend: false
        )
        XCTAssertEqual(context, .commute,
                       "Moving with moderate HR (110) should infer commute")
    }

    /// Non-stationary with very high HR (>130) but no workout flag should infer workout
    /// via motion-based detection (priority 3).
    @MainActor
    func test_contextInference_workoutInferred_highHR_moving_noWorkoutFlag() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 145,
            hrv: nil,
            isStationary: false,
            isInWorkout: false,
            sampleQuality: 0.8
        )
        let context = engine.inferActivityContext(
            biometric: bio,
            macOS: nil,
            timeSlot: .afternoon,
            isWeekend: false
        )
        XCTAssertEqual(context, .workout,
                       "Moving with very high HR (145) should infer workout even without workout flag")
    }

    // MARK: - Context Inference: macOS Signals

    /// macOS ongoing meeting should infer work context.
    @MainActor
    func test_contextInference_macOS_ongoingMeeting_returnsWork() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let macSignal = MacOSContextSignal(
            hasOngoingMeeting: true,
            inferredWorkState: .meetings
        )
        let context = engine.inferActivityContext(
            biometric: nil,
            macOS: macSignal,
            timeSlot: .morning,
            isWeekend: false
        )
        XCTAssertEqual(context, .work,
                       "Ongoing meeting should infer work context")
    }

    /// macOS entertainment state should infer relaxation.
    @MainActor
    func test_contextInference_macOS_entertainment_returnsRelaxation() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let macSignal = MacOSContextSignal(
            focusModeActive: false,
            inferredWorkState: .entertainment
        )
        let context = engine.inferActivityContext(
            biometric: nil,
            macOS: macSignal,
            timeSlot: .evening,
            isWeekend: true
        )
        XCTAssertEqual(context, .relaxation,
                       "Entertainment work state should infer relaxation")
    }

    /// macOS "Do Not Disturb" focus mode should infer deep work.
    @MainActor
    func test_contextInference_macOS_doNotDisturb_returnsDeepWork() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let macSignal = MacOSContextSignal(
            focusModeActive: true,
            focusModeName: "Do Not Disturb",
            inferredWorkState: .idle
        )
        let context = engine.inferActivityContext(
            biometric: nil,
            macOS: macSignal,
            timeSlot: .afternoon,
            isWeekend: false
        )
        XCTAssertEqual(context, .deepWork,
                       "Do Not Disturb focus mode should infer deep work")
    }

    /// Meeting detection should take priority over focus mode deep work
    /// (both are priority 2, but meeting is checked first).
    @MainActor
    func test_contextInference_macOS_meetingTakesPriorityOverFocusMode() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let macSignal = MacOSContextSignal(
            focusModeActive: true,
            focusModeName: "Work Focus",
            hasOngoingMeeting: true,
            inferredWorkState: .deepWork
        )
        let context = engine.inferActivityContext(
            biometric: nil,
            macOS: macSignal,
            timeSlot: .morning,
            isWeekend: false
        )
        XCTAssertEqual(context, .work,
                       "Ongoing meeting should take priority over focus mode")
    }

    // MARK: - Context Inference: Time-Based Fallback

    /// When no biometric or macOS signal is available, context should fall back to
    /// a time-based default. The exact result depends on the system clock, but it
    /// must be one of the expected time-based contexts.
    @MainActor
    func test_contextInference_noSignals_fallsBackToTimeBasedContext() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let context = engine.inferActivityContext(
            biometric: nil,
            macOS: nil,
            timeSlot: .morning,
            isWeekend: false
        )
        // Without biometric or macOS signals, the engine falls back to Calendar.current hour.
        // The result must be one of the time-based contexts.
        let timeBasedContexts: Set<ActivityContext> = [
            .preSleep, .morning, .commute, .work, .relaxation
        ]
        XCTAssertTrue(timeBasedContexts.contains(context),
                      "No-signal fallback should produce a time-based context, got: \(context)")
    }

    /// Stationary biometric with nil HR should still fall through to time-based fallback
    /// (priority 3 requires non-stationary, so stationary skips it).
    @MainActor
    func test_contextInference_stationaryNilHR_fallsToTimeBased() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: nil,
            hrv: nil,
            isStationary: true,
            isInWorkout: false,
            sampleQuality: 0.5
        )
        let context = engine.inferActivityContext(
            biometric: bio,
            macOS: nil,
            timeSlot: .afternoon,
            isWeekend: false
        )
        let timeBasedContexts: Set<ActivityContext> = [
            .preSleep, .morning, .commute, .work, .relaxation
        ]
        XCTAssertTrue(timeBasedContexts.contains(context),
                      "Stationary with nil HR should fall to time-based context, got: \(context)")
    }

    /// Moving but with low HR (<=100) and no workout flag should fall to time-based.
    @MainActor
    func test_contextInference_movingLowHR_noWorkout_fallsToTimeBased() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let bio = BiometricSignal(
            heartRate: 85,
            hrv: nil,
            isStationary: false,
            isInWorkout: false,
            sampleQuality: 0.7
        )
        let context = engine.inferActivityContext(
            biometric: bio,
            macOS: nil,
            timeSlot: .evening,
            isWeekend: false
        )
        // HR <= 100 while moving does not trigger commute or workout
        let timeBasedContexts: Set<ActivityContext> = [
            .preSleep, .morning, .commute, .work, .relaxation
        ]
        XCTAssertTrue(timeBasedContexts.contains(context),
                      "Moving with low HR should fall to time-based context, got: \(context)")
    }

    // MARK: - ManualMoodInput Edge Cases

    /// Input exactly 1 minute past the decay window should have weight 0.0.
    func test_manualMoodInput_justExpired_oneMinutePastDecay_zeroWeight() {
        let justExpiredTimestamp = Date().addingTimeInterval(
            -Double(StateEngineConstants.manualMoodDecayMinutes) * 60 - 60
        )
        let input = ManualMoodInput(
            energy: 0.6,
            valence: 0.4,
            timestamp: justExpiredTimestamp
        )
        XCTAssertEqual(input.currentWeight, 0.0,
                       "Input 1 minute past decay window should have zero weight")
        XCTAssertFalse(input.isActive,
                       "Input 1 minute past decay window should be inactive")
    }

    /// Input exactly at the decay boundary should have weight 0.0 (guard uses <, not <=).
    func test_manualMoodInput_exactlyAtDecayBoundary_zeroWeight() {
        let exactBoundaryTimestamp = Date().addingTimeInterval(
            -Double(StateEngineConstants.manualMoodDecayMinutes) * 60
        )
        let input = ManualMoodInput(
            energy: 0.5,
            valence: 0.5,
            timestamp: exactBoundaryTimestamp
        )
        // The guard uses `ageMinutes < decayMinutes`, so exactly at boundary returns 0.0
        XCTAssertEqual(input.currentWeight, 0.0, accuracy: 0.01,
                       "Input exactly at decay boundary should have zero weight")
    }

    /// Energy and valence values should be stored exactly as provided.
    func test_manualMoodInput_storesEnergyAndValence() {
        let input = ManualMoodInput(
            energy: 0.33,
            valence: 0.91,
            timestamp: Date()
        )
        XCTAssertEqual(input.energy, 0.33, accuracy: 0.001)
        XCTAssertEqual(input.valence, 0.91, accuracy: 0.001)
    }

    /// Near-zero decay (1 second old) should have weight very close to 1.0.
    func test_manualMoodInput_oneSecondOld_nearFullWeight() {
        let input = ManualMoodInput(
            energy: 0.5,
            valence: 0.5,
            timestamp: Date().addingTimeInterval(-1)
        )
        XCTAssertGreaterThan(input.currentWeight, 0.99,
                             "Input 1 second old should have weight very close to 1.0")
        XCTAssertTrue(input.isActive)
    }

    // MARK: - Music Need Inference

    /// Workout context with low energy should infer energize need.
    @MainActor
    func test_inferMusicNeed_workout_lowEnergy_returnsEnergize() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let state = StateVector(
            arousal: 0.7,
            energy: 0.3,
            focus: 0.3,
            stress: 0.4,
            valence: 0.5,
            context: .workout,
            inferredNeed: .maintain
        )
        let need = engine.inferMusicNeed(state: state)
        XCTAssertEqual(need, .energize,
                       "Workout with low energy should need energize")
    }

    /// Workout context with sufficient energy should infer maintain need.
    @MainActor
    func test_inferMusicNeed_workout_highEnergy_returnsMaintain() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let state = StateVector(
            arousal: 0.8,
            energy: 0.7,
            focus: 0.3,
            stress: 0.3,
            valence: 0.6,
            context: .workout,
            inferredNeed: .maintain
        )
        let need = engine.inferMusicNeed(state: state)
        XCTAssertEqual(need, .maintain,
                       "Workout with sufficient energy should need maintain")
    }

    /// Pre-sleep context should always infer calm need.
    @MainActor
    func test_inferMusicNeed_preSleep_returnsCalm() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let state = StateVector(
            arousal: 0.3,
            energy: 0.4,
            focus: 0.2,
            stress: 0.3,
            valence: 0.5,
            context: .preSleep,
            inferredNeed: .maintain
        )
        let need = engine.inferMusicNeed(state: state)
        XCTAssertEqual(need, .calm,
                       "Pre-sleep context should always need calm")
    }

    /// Post-workout context should infer calm need.
    @MainActor
    func test_inferMusicNeed_postWorkout_returnsCalm() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let state = StateVector(
            arousal: 0.5,
            energy: 0.5,
            focus: 0.3,
            stress: 0.4,
            valence: 0.5,
            context: .postWorkout,
            inferredNeed: .maintain
        )
        let need = engine.inferMusicNeed(state: state)
        XCTAssertEqual(need, .calm,
                       "Post-workout context should need calm")
    }

    /// Deep work context should infer focus need.
    @MainActor
    func test_inferMusicNeed_deepWork_returnsFocus() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let state = StateVector(
            arousal: 0.4,
            energy: 0.6,
            focus: 0.7,
            stress: 0.3,
            valence: 0.5,
            context: .deepWork,
            inferredNeed: .maintain
        )
        let need = engine.inferMusicNeed(state: state)
        XCTAssertEqual(need, .focus,
                       "Deep work context should need focus")
    }

    /// High stress (>0.7) outside of context-specific rules should infer calm.
    @MainActor
    func test_inferMusicNeed_highStress_returnsCalm() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let state = StateVector(
            arousal: 0.5,
            energy: 0.5,
            focus: 0.4,
            stress: 0.85,
            valence: 0.3,
            context: .relaxation,
            inferredNeed: .maintain
        )
        let need = engine.inferMusicNeed(state: state)
        XCTAssertEqual(need, .calm,
                       "High stress (0.85) should need calm regardless of context")
    }

    /// Low energy + low arousal outside specific contexts should infer energize.
    @MainActor
    func test_inferMusicNeed_lowEnergyLowArousal_returnsEnergize() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let state = StateVector(
            arousal: 0.2,
            energy: 0.2,
            focus: 0.3,
            stress: 0.3,
            valence: 0.5,
            context: .relaxation,
            inferredNeed: .maintain
        )
        let need = engine.inferMusicNeed(state: state)
        XCTAssertEqual(need, .energize,
                       "Low energy and low arousal should need energize")
    }

    /// Work context with high focus should infer focus need.
    @MainActor
    func test_inferMusicNeed_work_highFocus_returnsFocus() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let state = StateVector(
            arousal: 0.4,
            energy: 0.6,
            focus: 0.8,
            stress: 0.2,
            valence: 0.6,
            context: .work,
            inferredNeed: .maintain
        )
        let need = engine.inferMusicNeed(state: state)
        XCTAssertEqual(need, .focus,
                       "Work context with high focus (0.8) should need focus")
    }

    /// Neutral state with relaxation context should infer maintain.
    @MainActor
    func test_inferMusicNeed_neutralState_returnsMaintain() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        let state = StateVector(
            arousal: 0.5,
            energy: 0.5,
            focus: 0.5,
            stress: 0.5,
            valence: 0.5,
            context: .relaxation,
            inferredNeed: .maintain
        )
        let need = engine.inferMusicNeed(state: state)
        XCTAssertEqual(need, .maintain,
                       "Neutral state should need maintain")
    }

    // MARK: - setManualMood & State Update Cycle

    /// setManualMood should store values and the manualMood should be reflected
    /// as active immediately after setting.
    @MainActor
    func test_setManualMood_storesValuesAndTriggersUpdate() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        engine.setManualMood(energy: 0.9, valence: 0.1)
        // The initial state should still be .empty or have been updated.
        // We cannot directly inspect manualMood (private), but we can verify
        // the engine accepted the call without error. This also exercises
        // the clamping path.
        // Just ensure the engine's currentState is accessible (no crash).
        let _ = engine.currentState
    }

    /// setManualMood should clamp out-of-range values.
    @MainActor
    func test_setManualMood_clampsValues() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        // These out-of-range values should be clamped without error.
        engine.setManualMood(energy: 1.5, valence: -0.3)
        let _ = engine.currentState
    }

    // MARK: - StateVector.empty

    /// StateVector.empty should have all default (neutral) values.
    func test_stateVector_empty_hasNeutralDefaults() {
        let empty = StateVector.empty
        XCTAssertEqual(empty.arousal, 0.5)
        XCTAssertEqual(empty.energy, 0.5)
        XCTAssertEqual(empty.focus, 0.5)
        XCTAssertEqual(empty.stress, 0.5)
        XCTAssertEqual(empty.valence, 0.5)
        XCTAssertEqual(empty.context, .unknown)
        XCTAssertEqual(empty.inferredNeed, .maintain)
        XCTAssertEqual(empty.confidence, 0.0)
        XCTAssertTrue(empty.dataSources.isEmpty)
    }

    // MARK: - EstimateResult

    /// EstimateResult should store values as provided.
    func test_estimateResult_storesValues() {
        let result = EstimateResult(value: 0.42, confidence: 0.88)
        XCTAssertEqual(result.value, 0.42, accuracy: 0.001)
        XCTAssertEqual(result.confidence, 0.88, accuracy: 0.001)
    }

    // MARK: - Engine Initial State

    /// A freshly created engine should have currentState == .empty and nil previousState.
    @MainActor
    func test_engine_initialState_isEmpty() {
        let engine = StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
        XCTAssertEqual(engine.currentState, StateVector.empty,
                       "Fresh engine should have empty current state")
        XCTAssertNil(engine.previousState,
                     "Fresh engine should have nil previous state")
    }
}
