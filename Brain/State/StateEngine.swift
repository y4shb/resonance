//
//  StateEngine.swift
//  Resonance
//
//  Real-time state estimation engine.
//  Processes biometric signals (HR, HRV), context signals (macOS, motion),
//  and manual mood input to produce a StateVector every 30 seconds.
//
//  Related files:
//  - StateEngineTypes.swift: ManualMoodInput, EstimateResult
//  - StateCalculationHelpers.swift: Arousal, stress, energy, focus, valence calculations
//  - ActivityContextInference.swift: Activity context inference logic
//

#if os(iOS)

import Foundation

// MARK: - State Engine

/// Produces a real-time StateVector by combining biometric, context, and manual signals.
/// Updates every 30 seconds via an internal timer.
@MainActor
final class StateEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var currentState: StateVector = .empty
    @Published private(set) var previousState: StateVector?

    // MARK: - Dependencies

    let contextCollector: ContextCollector
    let healthKitService: HealthKitService

    /// Personal HRV baseline tracker, replacing the hardcoded 50ms population default.
    let personalBaseline: PersonalBaseline

    /// Learned circadian rhythm profile manager for personalized energy/context inference.
    let circadianManager: CircadianProfileManager

    /// Refines Watch-side emotion classification with iPhone context.
    let emotionRefinementEngine: EmotionRefinementEngine

    // MARK: - Internal State

    var manualMood: ManualMoodInput?

    /// Active mood trajectory for guided mood journeys (MoodTabView).
    @Published private(set) var moodTrajectory: MoodTrajectory?

    private var updateTimer: Timer?
    private var isRunning = false

    /// Cached resting heart rate from HealthKit (fetched once, refreshed periodically).
    var restingHeartRate: Double?

    /// Last time we fetched resting HR.
    /// Internal access for HealthKit refresh helpers in MusicNeedInference.swift.
    var lastRestingHRFetch: Date?

    /// Current crown-based energy adjustment (-0.5 to 0.5)
    var crownEnergyAdjustment = 0.0
    /// When the crown adjustment was last applied
    var crownAdjustmentTimestamp: Date?

    /// Cached VO2 Max for HR zone normalization (Workstream 3.1).
    var cachedVO2Max: Double?
    /// Last time we fetched VO2 Max.
    /// Internal access for HealthKit refresh helpers in MusicNeedInference.swift.
    var lastVO2MaxFetch: Date?

    /// Whether an irregular heart rhythm was recently detected (Workstream 3.8).
    /// Internal access for HealthKit refresh helpers in MusicNeedInference.swift.
    var hasRecentIrregularRhythm = false
    /// Last time we checked for irregular rhythm events.
    /// Internal access for HealthKit refresh helpers in MusicNeedInference.swift.
    var lastIrregularRhythmCheck: Date?

    // MARK: - R3: HR Acceleration Tracking (Appelhans & Luecken 2006)
    /// Rolling HR buffer for acceleration: ~4 samples (2 min at 30s intervals).
    private var recentHRSamples: [(timestamp: Date, hr: Double)] = []
    private let maxHRHistorySamples = 4
    /// Most recent HR acceleration rate (BPM/min). Updated each cycle.
    private(set) var lastHRAcceleration: Double = 0.0

    // MARK: - R6: Sleep-Derived Morning Baseline (de Zambotti et al. 2023)
    /// Cached morning mood baseline from overnight metrics. Nil until available.
    private(set) var morningMoodBaseline: MorningMoodBaseline?

    // MARK: - MusicNeed Hysteresis

    /// Minimum hold time (seconds) and consecutive sample count before switching.
    /// Note: internal access for MusicNeedInference.swift extension.
    let musicNeedHoldSeconds: TimeInterval = 60.0
    let musicNeedDebounceCount = 3
    var lastNeedChangeTimestamp: Date?
    var committedNeed: MusicNeed = .maintain
    var candidateNeedHistory: [MusicNeed] = []

    // MARK: - Initialization

    init(
        contextCollector: ContextCollector,
        healthKitService: HealthKitService,
        personalBaseline: PersonalBaseline = PersonalBaseline(),
        circadianManager: CircadianProfileManager = CircadianProfileManager(),
        emotionRefinementEngine: EmotionRefinementEngine = EmotionRefinementEngine()
    ) {
        self.contextCollector = contextCollector
        self.healthKitService = healthKitService
        self.personalBaseline = personalBaseline
        self.circadianManager = circadianManager
        self.emotionRefinementEngine = emotionRefinementEngine
        logInfo("StateEngine initialized", category: .stateEngine)
    }

    deinit {
        let timer = updateTimer
        DispatchQueue.main.async {
            timer?.invalidate()
        }
    }

    // MARK: - Lifecycle

    /// Starts the 30-second state update loop.
    func startUpdating() {
        guard !isRunning else { return }
        isRunning = true

        // Wire up overnight temperature callback to emotion refinement engine
        contextCollector.onOvernightTemperature = { [weak self] packet in
            self?.emotionRefinementEngine.processOvernightTemperature(packet)
        }

        // Fetch initial resting HR, VO2 Max, check irregular rhythm,
        // compute sleep baseline, refresh circadian profile, then perform first state update
        Task {
            await refreshRestingHeartRate()
            await refreshVO2Max()
            await checkIrregularHeartRhythm()
            contextCollector.computeSleepBaselineIfNeeded(using: healthKitService)
            circadianManager.refreshProfileIfNeeded(using: healthKitService)
            await updateState()
        }

        // Schedule periodic updates
        let timer = Timer.scheduledTimer(
            withTimeInterval: StateEngineConstants.updateIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateState()
            }
        }
        timer.tolerance = 3.0  // 10% tolerance (3s on 30s interval) for battery optimization
        updateTimer = timer

        logInfo("StateEngine started (interval: \(StateEngineConstants.updateIntervalSeconds)s)", category: .stateEngine)
    }

    /// Stops the state update loop.
    func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
        isRunning = false
        logInfo("StateEngine stopped", category: .stateEngine)
    }

    // MARK: - Manual Mood Input

    /// Records a manual mood input from the user (iOS or Watch).
    func setManualMood(energy: Double, valence: Double) {
        let clampedEnergy = Self.clamp(energy, 0.0, 1.0)
        let clampedValence = Self.clamp(valence, 0.0, 1.0)
        manualMood = ManualMoodInput(
            energy: clampedEnergy,
            valence: clampedValence,
            timestamp: Date()
        )
        logInfo(
            "Manual mood set: energy=\(String(format: "%.2f", clampedEnergy)), valence=\(String(format: "%.2f", clampedValence))",
            category: .stateEngine
        )
        // Trigger immediate state update
        Task { await updateState() }
    }

    // MARK: - Mood Trajectory

    /// Sets a mood trajectory for guided mood journeys. Also sets the manual
    /// mood to the current values so the state engine immediately reflects input.
    func setMoodTrajectory(
        current: (energy: Double, valence: Double),
        target: (energy: Double, valence: Double)
    ) {
        let t = MoodTrajectory(
            currentEnergy: Self.clamp(current.energy, 0.0, 1.0),
            currentValence: Self.clamp(current.valence, 0.0, 1.0),
            targetEnergy: Self.clamp(target.energy, 0.0, 1.0),
            targetValence: Self.clamp(target.valence, 0.0, 1.0),
            timestamp: Date()
        )
        moodTrajectory = t
        setManualMood(energy: current.energy, valence: current.valence)
        logInfo("Mood trajectory set: gap=\(String(format: "%.2f", t.gapMagnitude)), ~\(t.estimatedSongsToTarget) songs", category: .stateEngine)
    }

    /// Clears the active mood trajectory.
    func clearMoodTrajectory() {
        moodTrajectory = nil
        logInfo("Mood trajectory cleared", category: .stateEngine)
    }

    // MARK: - Crown Adjustment

    /// Applies a crown rotation adjustment from Watch.
    /// Modifies the energy target for the next state synthesis.
    func applyCrownAdjustment(_ adjustment: CrownAdjustment) {
        crownEnergyAdjustment = max(-CrownConstants.maxAdjustment,
                                     min(CrownConstants.maxAdjustment, adjustment.delta))
        crownAdjustmentTimestamp = Date()
        logInfo("Crown adjustment applied: \(String(format: "%.2f", adjustment.delta))",
                category: .stateEngine)
        Task { await updateState() }
    }

    // MARK: - Core Update

    private func updateState() async {
        // Refresh resting HR every 30 minutes
        if let lastFetch = lastRestingHRFetch {
            if Date().timeIntervalSince(lastFetch) > 1800 {
                await refreshRestingHeartRate()
            }
        } else {
            await refreshRestingHeartRate()
        }

        // Refresh VO2 Max every 6 hours (Workstream 3.1)
        if let lastFetch = lastVO2MaxFetch {
            if Date().timeIntervalSince(lastFetch) > 21600 {
                await refreshVO2Max()
            }
        }

        // Check irregular rhythm every hour (Workstream 3.8)
        if let lastCheck = lastIrregularRhythmCheck {
            if Date().timeIntervalSince(lastCheck) > 3600 {
                await checkIrregularHeartRhythm()
            }
        }

        let context = contextCollector.aggregatedContext
        let biometric = context.biometric

        // R3: Track HR history for acceleration-based transition detection
        if let hr = biometric?.heartRate, hr > 0 {
            recentHRSamples.append((timestamp: Date(), hr: hr))
            if recentHRSamples.count > maxHRHistorySamples {
                recentHRSamples.removeFirst()
            }
        }

        // R3: Compute HR acceleration using actual timestamps for accurate rate
        let previousSample: (timestamp: Date, hr: Double)? = {
            guard recentHRSamples.count >= maxHRHistorySamples else { return nil }
            return recentHRSamples.first
        }()
        lastHRAcceleration = Self.calculateHRAcceleration(
            currentHR: biometric?.heartRate ?? 0.0,
            previousSample: previousSample
        )

        // R6: Compute morning mood baseline from overnight metrics if available
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 && morningMoodBaseline == nil {
            if let sleepBaseline = context.sleepBaseline {
                morningMoodBaseline = MorningMoodBaseline.compute(
                    sleepDuration: sleepBaseline.totalSleepHours,
                    deepSleepPct: sleepBaseline.deepSleepPercentage,
                    overnightHRV: personalBaseline.currentBaseline,
                    baselineHRV: PersonalBaseline.populationDefault,
                    overnightRespRate: biometric?.respiratoryRate)
                logDebug("Morning mood baseline: stress=\(String(format: "%.3f", morningMoodBaseline?.stressAdjustment ?? 0)), valence=\(String(format: "%.3f", morningMoodBaseline?.valenceAdjustment ?? 0))", category: .stateEngine)
            }
        } else if hour >= 12 {
            // Reset morning baseline after noon so it recomputes next morning
            morningMoodBaseline = nil
        }

        // 1. Calculate arousal from heart rate (uses VO2 Max if available)
        let arousalResult = calculateArousal(biometric: biometric)

        // 2. Calculate stress from HRV (R1: now includes circadian HRV correction)
        var stressResult = calculateStress(biometric: biometric)

        // R6: Apply sleep-derived morning stress adjustment
        if hour >= 5 && hour < 12, let moodBaseline = morningMoodBaseline {
            let adjustedStress = Self.clamp(
                stressResult.value + moodBaseline.stressAdjustment,
                0.0, 1.0
            )
            stressResult = EstimateResult(value: adjustedStress, confidence: stressResult.confidence)
        }

        // 3. If irregular rhythm detected, set biometric reliability to 0.0 (Workstream 3.8)
        if hasRecentIrregularRhythm {
            stressResult = EstimateResult(value: stressResult.value, confidence: 0.0)
            logDebug(
                "Irregular rhythm detected: biometric reliability set to 0.0",
                category: .stateEngine
            )
        }

        // 4. Infer activity context
        let activityContext = inferActivityContext(
            biometric: biometric,
            macOS: context.macOS,
            timeSlot: context.timeSlot,
            isWeekend: context.isWeekend
        )

        // 5. Save previous state before synthesizing (so inferMusicNeed sees correct previous)
        previousState = currentState

        // 6. Synthesize full StateVector
        let state = synthesizeStateVector(
            arousal: arousalResult,
            stress: stressResult,
            activityContext: activityContext,
            biometric: biometric,
            macOS: context.macOS,
            timeSlot: context.timeSlot
        )

        // 7. Publish
        currentState = state

        logDebug(
            "State updated: \(state.summary) | arousal=\(String(format: "%.2f", state.arousal)), "
            + "stress=\(String(format: "%.2f", state.stress)), energy=\(String(format: "%.2f", state.energy)), "
            + "hrAccel=\(String(format: "%.1f", lastHRAcceleration)) BPM/min",
            category: .stateEngine
        )
    }

    // MARK: - Music Need Inference (plan.md Section 5.1.5)
    // Note: inferActivityContext is in ActivityContextInference.swift
    // Note: computeRawMusicNeed and applyNeedHysteresis are in
    //       MusicNeedInference.swift to keep this file under 500 lines.

    // MARK: - StateVector Synthesis (plan.md Section 5.1.4)

    /// Combines all signals into a unified StateVector.
    private func synthesizeStateVector(
        arousal: EstimateResult,
        stress: EstimateResult,
        activityContext: ActivityContext,
        biometric: BiometricSignal?,
        macOS: MacOSContextSignal?,
        timeSlot: TimeSlot
    ) -> StateVector {
        var energy = calculateEnergy(arousal: arousal.value, stress: stress.value)
        let focus = calculateFocus(stress: stress.value, arousal: arousal.value, context: activityContext)

        // R2: Use multi-signal valence when biometric data is available,
        // falling back to stress-only valence otherwise.
        // Reference: Kreibig, Cognition & Emotion 2010
        let sleepBaseline = contextCollector.aggregatedContext.sleepBaseline
        var valence: Double
        if biometric != nil {
            valence = calculateValence(
                stress: stress.value,
                arousal: arousal.value,
                biometric: biometric,
                sleepBaseline: sleepBaseline
            )
        } else {
            valence = calculateValence(stress: stress.value)
        }

        // R6: Apply sleep-derived morning valence adjustment
        let currentHour = Calendar.current.component(.hour, from: Date())
        if currentHour >= 5 && currentHour < 12, let moodBaseline = morningMoodBaseline {
            valence = Self.clamp(valence + moodBaseline.valenceAdjustment, 0.0, 1.0)
        }

        // Emotion refinement: adjust valence based on Watch emotion classification
        let watchEmotionalState = biometric?.emotionalState
        let watchEmotionConfidence = biometric?.emotionConfidence ?? 0.0
        let refinedEmotion = emotionRefinementEngine.refineEmotionalState(
            watchState: watchEmotionalState,
            watchConfidence: watchEmotionConfidence,
            currentStress: stress.value,
            currentEnergy: energy,
            isFocusModeActive: contextCollector.aggregatedContext.isFocusModeActive,
            isInWorkout: biometric?.isInWorkout ?? false
        )
        valence = emotionRefinementEngine.refineValence(
            baseValence: valence,
            emotionalState: refinedEmotion,
            confidence: watchEmotionConfidence
        )

        // Apply temperature-based morning energy adjustment
        energy = Self.clamp(
            energy + emotionRefinementEngine.morningEnergyAdjustment(),
            0.0, 1.0
        )

        // Blend with manual mood input if active
        if let mood = manualMood, mood.isActive {
            let weight = mood.currentWeight * 0.7  // Max 70% manual influence
            energy = Self.blend(energy, mood.energy, weight: weight * 0.5)
            valence = Self.blend(valence, mood.valence, weight: weight)
        }

        // Blend crown energy adjustment with decay
        if let crownTimestamp = crownAdjustmentTimestamp {
            let elapsed = Date().timeIntervalSince(crownTimestamp)
            if elapsed < CrownConstants.adjustmentDecaySeconds {
                let decayFactor = 1.0 - (elapsed / CrownConstants.adjustmentDecaySeconds)
                energy = Self.clamp(energy + crownEnergyAdjustment * decayFactor, 0.0, 1.0)
            } else {
                crownEnergyAdjustment = 0.0
                crownAdjustmentTimestamp = nil
            }
        }

        // Collect data sources
        var dataSources = Set<DataSource>()
        dataSources.insert(.timeOfDay)

        if biometric?.heartRate != nil {
            dataSources.insert(.heartRate)
        }
        if biometric?.hrv != nil {
            dataSources.insert(.hrv)
        }
        if biometric != nil {
            dataSources.insert(.motion)
        }
        if macOS != nil {
            dataSources.insert(.macOSContext)
        }
        if manualMood?.isActive == true {
            dataSources.insert(.manualMoodInput)
        }
        if crownAdjustmentTimestamp != nil {
            dataSources.insert(.crownInput)
        }
        if let profile = circadianManager.currentProfile,
           profile.confidence >= CircadianIntegrationConstants.minimumConfidenceForDataSource {
            dataSources.insert(.circadianProfile)
        }
        if biometric?.movementMagnitude != nil {
            dataSources.insert(.watchMotionDetail)
        }
        if emotionRefinementEngine.latestOvernightTemp != nil {
            dataSources.insert(.skinTemperature)
        }
        if refinedEmotion != nil {
            dataSources.insert(.emotionClassification)
        }

        // Confidence: average of biometric confidence, boosted by data source count
        let biometricConfidence = (arousal.confidence + stress.confidence) / 2.0
        let sourceBonus = min(0.3, Double(dataSources.count) * 0.05)
        let confidence = Self.clamp(biometricConfidence + sourceBonus, 0.0, 1.0)

        var state = StateVector(
            arousal: arousal.value,
            energy: energy,
            focus: focus,
            stress: stress.value,
            valence: valence,
            context: activityContext,
            inferredNeed: .maintain,  // Set below
            timestamp: Date(),
            confidence: confidence,
            dataSources: dataSources,
            emotionalStateRaw: refinedEmotion?.rawValue
        )

        state.inferredNeed = inferMusicNeed(state: state)

        return state
    }

}

#endif
