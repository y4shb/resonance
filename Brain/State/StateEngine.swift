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

    // MARK: - Internal State

    var manualMood: ManualMoodInput?
    private var updateTimer: Timer?
    private var isRunning = false

    /// Cached resting heart rate from HealthKit (fetched once, refreshed periodically).
    var restingHeartRate: Double?

    /// Last time we fetched resting HR.
    private var lastRestingHRFetch: Date?

    /// Current crown-based energy adjustment (-0.5 to 0.5)
    var crownEnergyAdjustment: Double = 0.0
    /// When the crown adjustment was last applied
    var crownAdjustmentTimestamp: Date?

    /// Cached VO2 Max for HR zone normalization (Workstream 3.1).
    var cachedVO2Max: Double?
    /// Last time we fetched VO2 Max.
    private var lastVO2MaxFetch: Date?

    /// Whether an irregular heart rhythm was recently detected (Workstream 3.8).
    private var hasRecentIrregularRhythm: Bool = false
    /// Last time we checked for irregular rhythm events.
    private var lastIrregularRhythmCheck: Date?

    // MARK: - MusicNeed Hysteresis

    /// Minimum hold time (seconds) and consecutive sample count before switching.
    private let musicNeedHoldSeconds: TimeInterval = 60.0
    private let musicNeedDebounceCount: Int = 3
    private var lastNeedChangeTimestamp: Date?
    private var committedNeed: MusicNeed = .maintain
    private var candidateNeedHistory: [MusicNeed] = []

    // MARK: - Initialization

    init(
        contextCollector: ContextCollector,
        healthKitService: HealthKitService,
        personalBaseline: PersonalBaseline = PersonalBaseline()
    ) {
        self.contextCollector = contextCollector
        self.healthKitService = healthKitService
        self.personalBaseline = personalBaseline
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

        // Fetch initial resting HR, VO2 Max, check irregular rhythm,
        // compute sleep baseline, then perform first state update
        Task {
            await refreshRestingHeartRate()
            await refreshVO2Max()
            await checkIrregularHeartRhythm()
            contextCollector.computeSleepBaselineIfNeeded(using: healthKitService)
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

        // 1. Calculate arousal from heart rate (uses VO2 Max if available)
        let arousalResult = calculateArousal(biometric: biometric)

        // 2. Calculate stress from HRV
        var stressResult = calculateStress(biometric: biometric)

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
            + "stress=\(String(format: "%.2f", state.stress)), energy=\(String(format: "%.2f", state.energy))",
            category: .stateEngine
        )
    }

    // MARK: - Music Need Inference (plan.md Section 5.1.5)
    // Note: inferActivityContext is in ActivityContextInference.swift

    /// Determines what the user needs from music. Applies hysteresis (60s hold,
    /// 3 consecutive agreeing samples) to prevent rapid need switching.
    func inferMusicNeed(state: StateVector) -> MusicNeed {
        return applyNeedHysteresis(computeRawMusicNeed(state: state))
    }

    private func computeRawMusicNeed(state: StateVector) -> MusicNeed {
        // Context-driven needs (highest priority)
        switch state.context {
        case .workout:
            return state.energy < 0.5 ? .energize : .maintain
        case .postWorkout:
            return .calm
        case .preSleep:
            return .calm
        case .deepWork:
            return .focus
        case .work:
            if state.focus > 0.6 {
                return .focus
            }
        default:
            break
        }

        // State-driven needs
        if state.stress > 0.7 {
            return .calm
        }

        if state.energy < 0.3 && state.arousal < 0.4 {
            return .energize
        }

        // Detect significant state change
        if let prev = previousState {
            let delta = abs(state.arousal - prev.arousal) + abs(state.stress - prev.stress)
            if delta > 0.4 {
                return .transition
            }
        }

        return .maintain
    }

    /// Applies hysteresis: requires hold time + consecutive agreement.
    private func applyNeedHysteresis(_ rawNeed: MusicNeed) -> MusicNeed {
        if rawNeed == committedNeed {
            candidateNeedHistory.removeAll()
            return committedNeed
        }

        candidateNeedHistory.append(rawNeed)

        let recent = candidateNeedHistory.suffix(musicNeedDebounceCount)
        let allAgree = recent.count >= musicNeedDebounceCount
            && recent.allSatisfy { $0 == rawNeed }
        guard allAgree else { return committedNeed }

        if let lastChange = lastNeedChangeTimestamp,
           Date().timeIntervalSince(lastChange) < musicNeedHoldSeconds {
            return committedNeed
        }

        committedNeed = rawNeed
        lastNeedChangeTimestamp = Date()
        candidateNeedHistory.removeAll()
        logInfo("MusicNeed changed to \(rawNeed.rawValue) (hysteresis passed)", category: .stateEngine)
        return committedNeed
    }

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
        var valence = calculateValence(stress: stress.value)

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
            dataSources: dataSources
        )

        state.inferredNeed = inferMusicNeed(state: state)

        return state
    }

    // MARK: - Helpers

    private func refreshRestingHeartRate() async {
        do {
            if let rhr = try await healthKitService.fetchRestingHeartRate() {
                restingHeartRate = rhr
                logDebug("Resting HR updated: \(rhr) BPM", category: .stateEngine)
            }
        } catch {
            logDebug("Could not fetch resting HR: \(error.localizedDescription)", category: .stateEngine)
        }
        lastRestingHRFetch = Date()
    }

    // MARK: - VO2 Max (Workstream 3.1)

    private func refreshVO2Max() async {
        do {
            if let vo2 = try await healthKitService.fetchVO2Max() {
                cachedVO2Max = vo2
                logDebug(
                    "VO2 Max updated: \(String(format: "%.1f", vo2)) mL/kg/min",
                    category: .stateEngine
                )
            }
        } catch {
            logDebug(
                "Could not fetch VO2 Max: \(error.localizedDescription)",
                category: .stateEngine
            )
        }
        lastVO2MaxFetch = Date()
    }

    // MARK: - Irregular Heart Rhythm (Workstream 3.8)

    private func checkIrregularHeartRhythm() async {
        do {
            let events = try await healthKitService.fetchIrregularHeartRhythmEvents(days: 7)

            // Consider it "recent" if any event occurred in the last 24 hours
            let oneDayAgo = Date().addingTimeInterval(-86400)
            let recentEvents = events.filter { $0 > oneDayAgo }
            hasRecentIrregularRhythm = !recentEvents.isEmpty

            if hasRecentIrregularRhythm {
                logWarning(
                    "Irregular heart rhythm detected (\(recentEvents.count) events in last 24h) "
                    + "- biometric reliability reduced",
                    category: .stateEngine
                )
            }
        } catch {
            logDebug(
                "Could not check irregular rhythm: \(error.localizedDescription)",
                category: .stateEngine
            )
        }
        lastIrregularRhythmCheck = Date()
    }
}

#endif
