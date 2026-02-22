//
//  StateEngine.swift
//  Resonance
//
//  Real-time state estimation engine.
//  Processes biometric signals (HR, HRV), context signals (macOS, motion),
//  and manual mood input to produce a StateVector every 30 seconds.
//

#if os(iOS)

import Foundation

// MARK: - Manual Mood Input

/// Manual mood input from user (iOS slider or Watch 3-tap).
/// Decays over `StateEngineConstants.manualMoodDecayMinutes`.
struct ManualMoodInput: Sendable {
    let energy: Double      // 0.0 = exhausted, 1.0 = energized
    let valence: Double     // 0.0 = negative, 1.0 = positive
    let timestamp: Date

    /// Returns the decay-adjusted weight (1.0 when fresh, 0.0 after decay period).
    var currentWeight: Double {
        let ageMinutes = Date().timeIntervalSince(timestamp) / 60.0
        let decayMinutes = Double(StateEngineConstants.manualMoodDecayMinutes)
        guard ageMinutes < decayMinutes else { return 0.0 }
        return 1.0 - (ageMinutes / decayMinutes)
    }

    /// Whether this input is still active (within decay window).
    var isActive: Bool {
        currentWeight > 0.0
    }
}

// MARK: - State Engine

/// Produces a real-time StateVector by combining biometric, context, and manual signals.
/// Updates every 30 seconds via an internal timer.
@MainActor
final class StateEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var currentState: StateVector = .empty
    @Published private(set) var previousState: StateVector?

    // MARK: - Dependencies

    private let contextCollector: ContextCollector
    private let healthKitService: HealthKitService

    // MARK: - Internal State

    private var manualMood: ManualMoodInput?
    private var updateTimer: Timer?
    private var isRunning = false

    /// Cached resting heart rate from HealthKit (fetched once, refreshed periodically).
    private var restingHeartRate: Double?

    /// Last time we fetched resting HR.
    private var lastRestingHRFetch: Date?

    /// Current crown-based energy adjustment (-0.5 to 0.5)
    private var crownEnergyAdjustment: Double = 0.0
    /// When the crown adjustment was last applied
    private var crownAdjustmentTimestamp: Date?

    // MARK: - Initialization

    init(
        contextCollector: ContextCollector,
        healthKitService: HealthKitService
    ) {
        self.contextCollector = contextCollector
        self.healthKitService = healthKitService
        logInfo("StateEngine initialized", category: .stateEngine)
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Lifecycle

    /// Starts the 30-second state update loop.
    func startUpdating() {
        guard !isRunning else { return }
        isRunning = true

        // Fetch initial resting HR
        Task { await refreshRestingHeartRate() }

        // Initial update
        Task { await updateState() }

        // Schedule periodic updates
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: StateEngineConstants.updateIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateState()
            }
        }

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
        manualMood = ManualMoodInput(
            energy: clamp(energy, 0.0, 1.0),
            valence: clamp(valence, 0.0, 1.0),
            timestamp: Date()
        )
        logInfo(
            "Manual mood set: energy=\(String(format: "%.2f", energy)), valence=\(String(format: "%.2f", valence))",
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
        if lastRestingHRFetch == nil ||
            Date().timeIntervalSince(lastRestingHRFetch!) > 1800 {
            await refreshRestingHeartRate()
        }

        let context = contextCollector.aggregatedContext
        let biometric = context.biometric

        // 1. Calculate arousal from heart rate
        let arousalResult = calculateArousal(biometric: biometric)

        // 2. Calculate stress from HRV
        let stressResult = calculateStress(biometric: biometric)

        // 3. Infer activity context
        let activityContext = inferActivityContext(
            biometric: biometric,
            macOS: context.macOS,
            timeSlot: context.timeSlot,
            isWeekend: context.isWeekend
        )

        // 4. Synthesize full StateVector
        let state = synthesizeStateVector(
            arousal: arousalResult,
            stress: stressResult,
            activityContext: activityContext,
            biometric: biometric,
            macOS: context.macOS,
            timeSlot: context.timeSlot
        )

        // 5. Publish
        previousState = currentState
        currentState = state

        logDebug(
            "State updated: \(state.summary) | arousal=\(String(format: "%.2f", state.arousal)), "
            + "stress=\(String(format: "%.2f", state.stress)), energy=\(String(format: "%.2f", state.energy))",
            category: .stateEngine
        )
    }

    // MARK: - Arousal Calculation (plan.md §5.1.1)

    /// Calculates arousal (0-1) from heart rate using heart rate reserve method.
    func calculateArousal(biometric: BiometricSignal?) -> EstimateResult {
        guard let hr = biometric?.heartRate, hr > 0 else {
            return EstimateResult(value: 0.5, confidence: 0.0)
        }

        let resting = restingHeartRate ?? StateEngineConstants.defaultRestingHeartRate
        let maxHR = StateEngineConstants.maxHeartRateBase - Double(StateEngineConstants.defaultUserAge)
        let hrReserve = maxHR - resting

        guard hrReserve > 0 else {
            return EstimateResult(value: 0.5, confidence: 0.3)
        }

        let normalizedHR = (hr - resting) / hrReserve
        let arousal = clamp(normalizedHR, 0.0, 1.0)

        // Confidence based on signal quality
        let confidence = biometric?.sampleQuality ?? 0.5

        return EstimateResult(value: arousal, confidence: confidence)
    }

    // MARK: - Stress Calculation (plan.md §5.1.2)

    /// Calculates stress (0-1) from HRV. HRV is inversely correlated with stress.
    func calculateStress(biometric: BiometricSignal?) -> EstimateResult {
        guard let hrv = biometric?.hrv, hrv > 0 else {
            return EstimateResult(value: 0.5, confidence: 0.0)
        }

        // Use a population baseline if personal baseline unavailable
        let baselineHRV: Double = 50.0  // Typical resting SDNN for healthy adult

        let ratio = hrv / baselineHRV

        // Map ratio to stress (inverse relationship):
        // ratio 0.5 (low HRV) -> stress ~0.7
        // ratio 1.0 (baseline) -> stress ~0.4
        // ratio 1.5 (high HRV) -> stress ~0.1
        let stress = clamp(1.0 - (ratio * 0.6), 0.0, 1.0)

        let confidence = biometric?.sampleQuality ?? 0.5

        return EstimateResult(value: stress, confidence: confidence)
    }

    // MARK: - Energy Calculation (plan.md §5.1.4)

    /// Energy = composite of arousal and inverse stress.
    private func calculateEnergy(arousal: Double, stress: Double) -> Double {
        (arousal * 0.6) + ((1.0 - stress) * 0.4)
    }

    // MARK: - Focus Calculation (plan.md §5.1.4)

    /// Focus depends on context and stress level.
    private func calculateFocus(stress: Double, arousal: Double, context: ActivityContext) -> Double {
        switch context {
        case .deepWork:
            return clamp(0.8 - (stress * 0.3), 0.0, 1.0)
        case .work:
            return clamp(0.6 - (stress * 0.2), 0.0, 1.0)
        case .workout:
            return 0.3  // Physical focus, not mental
        case .preSleep:
            return clamp(0.3 - (arousal * 0.2), 0.0, 1.0)
        default:
            let base = 0.5 - (stress * 0.2)
            let lowArousalBonus = arousal < 0.4 ? 0.1 : 0.0
            return clamp(base + lowArousalBonus, 0.0, 1.0)
        }
    }

    // MARK: - Valence Calculation (plan.md §5.1.4)

    /// Valence (mood positivity). Default neutral, adjusted by stress, blended with manual input.
    private func calculateValence(stress: Double) -> Double {
        clamp(0.5 - (stress * 0.3), 0.0, 1.0)
    }

    // MARK: - Context Inference (plan.md §5.1.3)

    /// Infers activity context using a priority-based cascade.
    func inferActivityContext(
        biometric: BiometricSignal?,
        macOS: MacOSContextSignal?,
        timeSlot: TimeSlot,
        isWeekend: Bool
    ) -> ActivityContext {
        // Priority 1: Explicit workout detection (from Watch)
        if let bio = biometric {
            if bio.isInWorkout {
                return .workout
            }
        }

        // Priority 2: macOS signals
        if let mac = macOS {
            if mac.hasOngoingMeeting {
                return .work
            }
            if mac.focusModeActive,
               let name = mac.focusModeName?.lowercased(),
               name.contains("work") || name.contains("do not disturb") {
                return .deepWork
            }
            if mac.inferredWorkState == .deepWork {
                return .deepWork
            }
            if mac.inferredWorkState == .entertainment {
                return .relaxation
            }
        }

        // Priority 3: Motion-based inference
        if let bio = biometric, !bio.isStationary, bio.heartRate ?? 0 > 100 {
            // High HR + moving — could be commute or light activity
            return .commute
        }

        // Priority 4: Time-based defaults
        let hour = Calendar.current.component(.hour, from: Date())

        if hour >= 22 || hour < 5 {
            return .preSleep
        }

        if hour >= 5 && hour < 7 {
            return .morning
        }

        if hour >= 7 && hour < 9 && !isWeekend {
            return .commute
        }

        if hour >= 9 && hour < 17 && !isWeekend {
            return .work
        }

        if hour >= 17 && hour < 19 && !isWeekend {
            return .commute
        }

        // Priority 5: Fallback
        if biometric?.isStationary == true {
            return .relaxation
        }

        return .unknown
    }

    // MARK: - Music Need Inference (plan.md §5.1.5)

    /// Determines what the user needs from music based on state and context.
    func inferMusicNeed(state: StateVector) -> MusicNeed {
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

    // MARK: - StateVector Synthesis (plan.md §5.1.4)

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
            energy = blend(energy, mood.energy, weight: weight * 0.5)
            valence = blend(valence, mood.valence, weight: weight)
        }

        // Blend crown energy adjustment with decay
        if let crownTimestamp = crownAdjustmentTimestamp {
            let elapsed = Date().timeIntervalSince(crownTimestamp)
            if elapsed < CrownConstants.adjustmentDecaySeconds {
                let decayFactor = 1.0 - (elapsed / CrownConstants.adjustmentDecaySeconds)
                energy = clamp(energy + crownEnergyAdjustment * decayFactor, 0.0, 1.0)
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
        let confidence = clamp(biometricConfidence + sourceBonus, 0.0, 1.0)

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

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    private func blend(_ a: Double, _ b: Double, weight: Double) -> Double {
        a * (1.0 - weight) + b * weight
    }
}

// MARK: - Estimate Result

/// Intermediate result with value and confidence.
struct EstimateResult: Sendable {
    let value: Double
    let confidence: Double
}

#endif
