//
//  StateEngine.swift
//  Resonance
//
//  Processes biometric signals and context to produce a StateVector.
//  Includes Yerkes-Dodson arousal optimization (6.5) and sleep preparation
//  detection (6.4).
//
//  Research enhancements:
//  - R1 Circadian HRV correction: Boudreau et al., PMC 2022
//  - R2 Multi-signal valence: Kreibig, Cognition & Emotion 2010
//  - R3 HR acceleration: Appelhans & Luecken, Psychophysiology 2006
//

import Foundation

// MARK: - Arousal State (Yerkes-Dodson Model)

/// Arousal state based on the Yerkes-Dodson inverted-U model.
/// Maps physiological arousal to performance/engagement.
public enum ArousalState: String, Codable, Sendable {
    /// Low arousal - bored/drowsy. Elevated RMSSD + low HR = parasympathetic dominant.
    case underAroused
    /// Optimal arousal - in flow. Moderate RMSSD = balanced ANS.
    case optimal
    /// Over-arousal - stressed. Low RMSSD + elevated HR = sympathetic dominant.
    case overAroused

    public var displayName: String {
        switch self {
        case .underAroused: return "Under-Aroused"
        case .optimal: return "Optimal"
        case .overAroused: return "Over-Aroused"
        }
    }

    /// Returns the recommended MusicNeed for this arousal state.
    public var recommendedNeed: MusicNeed {
        switch self {
        case .underAroused: return .energize
        case .optimal: return .maintain
        case .overAroused: return .calm
        }
    }
}

// MARK: - SharedStateEngine

/// Produces a StateVector from biometric signals, context, and time-of-day.
/// Implements Yerkes-Dodson arousal optimization (6.5) and sleep prep detection (6.4).
public final class SharedStateEngine: @unchecked Sendable {

    // MARK: - Lock for Thread Safety

    private let lock = NSLock()

    // MARK: - Configuration
    // All mutable state below is protected by `lock`.

    private var _restingHeartRate: Double
    private var _maxHeartRate: Double
    /// Typical bedtime hour (24h format). Used for sleep preparation detection.
    /// Falls back to circadian profile's typicalSleepHour when available.
    private var _typicalBedtimeHour: Int
    private let sleepPrepLeadMinutes = 45

    /// Circadian profile manager for personalized energy and context inference.
    private let _circadianManager: CircadianProfileManager

    // MARK: - E1: Focus State Detection

    /// Focus state detector for ADHD focus mode (E1).
    private let _focusDetector = FocusStateDetector()

    // MARK: - State

    private var _currentState: StateVector
    private var _arousalState: ArousalState = .optimal
    private var _isSleepPrepActive = false
    private var _recentRMSSD: [Double] = []
    private let maxRMSSDSamples = 10
    private var _recentHeartRates: [Double] = []
    private let maxHeartRateSamples = 10

    // MARK: - R3: HR Acceleration (Appelhans & Luecken 2006)
    /// Rolling HR buffer for acceleration: ~4 samples (2 min at 30s intervals).
    private var _hrAccelHistory: [Double] = []
    private let maxHRAccelSamples = 4
    private var _lastHRAcceleration: Double = 0.0

    // MARK: - Thread-Safe Accessors

    public var currentState: StateVector { lock.withLock { _currentState } }
    public var arousalState: ArousalState { lock.withLock { _arousalState } }
    public var isSleepPrepActive: Bool { lock.withLock { _isSleepPrepActive } }

    public var lastHRAcceleration: Double { lock.withLock { _lastHRAcceleration } }

    /// Public accessor for the focus state detector (E1).
    public var focusDetector: FocusStateDetector { _focusDetector }

    /// Current focus level derived from HRV signals (E1).
    public var currentFocusLevel: FocusLevel { _focusDetector.currentFocusLevel }

    // MARK: - Initialization

    init(
        restingHeartRate: Double = StateEngineConstants.defaultRestingHeartRate,
        userAge: Int = StateEngineConstants.defaultUserAge,
        typicalBedtimeHour: Int = 23,
        circadianManager: CircadianProfileManager = CircadianProfileManager()
    ) {
        self._restingHeartRate = restingHeartRate
        self._maxHeartRate = StateEngineConstants.maxHeartRateBase - Double(userAge)
        self._typicalBedtimeHour = typicalBedtimeHour
        self._circadianManager = circadianManager
        self._currentState = .empty

        logInfo("SharedStateEngine initialized (resting HR: \(restingHeartRate), max HR: \(_maxHeartRate))",
                category: .stateEngine)
    }

    // MARK: - Public API

    /// Updates the state vector from an aggregated context snapshot.
    /// Called every ~30 seconds by the context collection pipeline.
    public func update(from context: AggregatedContext) -> StateVector {
        return lock.withLock {
            let arousal = _estimateArousal(from: context)
            let energy = _estimateEnergy(from: context, arousal: arousal)
            let focus = _estimateFocus(from: context)
            let stress = _estimateStress(from: context)
            // R2: Use enhanced multi-signal valence
            let valence = _estimateValence(from: context, stress: stress)
            let activityContext = _inferActivityContext(from: context)
            let confidence = _calculateConfidence(from: context)

            // Track biometric history
            if let hrv = context.biometric?.hrv {
                _appendRMSSD(hrv)
                // E1: Update focus state detector with latest RMSSD
                _focusDetector.update(rmssd: hrv, timestamp: Date())
            }
            if let hr = context.biometric?.heartRate {
                _appendHeartRate(hr)
                // R3: Track HR for acceleration calculation
                _appendHRAccelSample(hr)
            }

            // R3: Compute HR acceleration (BPM change per minute)
            _lastHRAcceleration = _calculateHRAcceleration()

            // Yerkes-Dodson arousal classification (6.5)
            _arousalState = _classifyArousalState(
                rmssd: context.biometric?.hrv,
                heartRate: context.biometric?.heartRate
            )

            // Sleep preparation detection (6.4)
            _isSleepPrepActive = _detectSleepPreparation(
                currentHour: Calendar.current.component(.hour, from: context.timestamp),
                currentMinute: Calendar.current.component(.minute, from: context.timestamp)
            )

            // Infer music need, incorporating Yerkes-Dodson and sleep prep
            let inferredNeed = _inferMusicNeed(
                arousal: arousal,
                energy: energy,
                focus: focus,
                stress: stress,
                activityContext: activityContext,
                arousalState: _arousalState,
                isSleepPrep: _isSleepPrepActive
            )

            // Override context to preSleep when sleep prep is active
            let finalContext = _isSleepPrepActive ? .preSleep : activityContext

            var dataSources: Set<DataSource> = [.timeOfDay]
            if context.biometric?.heartRate != nil { dataSources.insert(.heartRate) }
            if context.biometric?.hrv != nil { dataSources.insert(.hrv) }
            if context.biometric != nil { dataSources.insert(.motion) }
            if context.macOS != nil { dataSources.insert(.macOSContext) }
            if let profile = _circadianManager.currentProfile,
               profile.confidence >= CircadianIntegrationConstants.minimumConfidenceForDataSource {
                dataSources.insert(.circadianProfile)
            }

            let stateVector = StateVector(
                arousal: arousal,
                energy: energy,
                focus: focus,
                stress: stress,
                valence: valence,
                context: finalContext,
                inferredNeed: inferredNeed,
                timestamp: context.timestamp,
                confidence: confidence,
                dataSources: dataSources
            )

            _currentState = stateVector

            logDebug(
                "SharedStateEngine update: arousal=\(String(format: "%.2f", arousal)), "
                + "energy=\(String(format: "%.2f", energy)), "
                + "yerkesState=\(_arousalState.rawValue), "
                + "sleepPrep=\(_isSleepPrepActive), "
                + "hrAccel=\(String(format: "%.1f", _lastHRAcceleration)) BPM/min, "
                + "need=\(inferredNeed.rawValue)",
                category: .stateEngine
            )

            return stateVector
        }
    }

    /// Updates the resting heart rate baseline (e.g., from HealthKit).
    public func updateRestingHeartRate(_ rhr: Double) {
        guard rhr > 30 && rhr < 120 else { return }
        lock.withLock { _restingHeartRate = rhr }
        logInfo("SharedStateEngine: resting heart rate updated to \(rhr)", category: .stateEngine)
    }

    /// Updates the typical bedtime hour for sleep prep detection.
    public func updateBedtimeHour(_ hour: Int) {
        guard hour >= 0 && hour < 24 else { return }
        lock.withLock { _typicalBedtimeHour = hour }
        logInfo("SharedStateEngine: bedtime hour updated to \(hour)", category: .stateEngine)
    }

    // MARK: - Biometric Estimation
    // All private methods below are called while holding `lock`.

    private func _estimateArousal(from context: AggregatedContext) -> Double {
        guard let hr = context.biometric?.heartRate else { return 0.5 }
        let range = _maxHeartRate - _restingHeartRate
        guard range > 0 else { return 0.5 }
        let normalized = (hr - _restingHeartRate) / range
        return clamp(normalized, 0.0, 1.0)
    }

    private func _estimateEnergy(from context: AggregatedContext, arousal: Double) -> Double {
        var energy = arousal
        let hour = Calendar.current.component(.hour, from: context.timestamp)

        // Apply circadian energy modifier (blends learned profile with static fallback)
        let circadianModifier = _circadianManager.blendedEnergyModifier(forHour: hour)
        energy += circadianModifier

        if context.biometric?.isInWorkout == true { energy = max(energy, 0.7) }
        return clamp(energy, 0.0, 1.0)
    }

    private func _estimateFocus(from context: AggregatedContext) -> Double {
        var focus = 0.5
        if let hrv = context.biometric?.hrv {
            if hrv >= 40 && hrv <= 80 { focus += 0.2 }
            else if hrv > 80 { focus -= 0.1 }
            else if hrv < 30 { focus -= 0.15 }
        }
        if let macOS = context.macOS {
            if macOS.focusModeActive { focus += 0.2 }
            switch macOS.inferredWorkState {
            case .deepWork: focus += 0.25
            case .casual: focus += 0.05
            case .meetings: focus -= 0.1
            case .entertainment: focus -= 0.2
            case .idle: focus -= 0.1
            }
        }
        return clamp(focus, 0.0, 1.0)
    }

    /// R1: Stress estimation with circadian HRV correction.
    /// Scales HRV thresholds by time-of-day to prevent afternoon false positives.
    /// Reference: Boudreau et al., PMC 2022; Hernando et al., Sensors 2018
    private func _estimateStress(from context: AggregatedContext) -> Double {
        var stress = 0.3
        if let hrv = context.biometric?.hrv {
            // R1: Scale thresholds by circadian factor (afternoon HRV naturally lower)
            let hour = Calendar.current.component(.hour, from: context.timestamp)
            let circadianFactor = Self.circadianHRVFactor(for: hour)

            let adjustedLow = 25.0 * circadianFactor
            let adjustedMedLow = 40.0 * circadianFactor
            let adjustedMedHigh = 60.0 * circadianFactor
            let adjustedHigh = 80.0 * circadianFactor

            if hrv < adjustedLow { stress += 0.35 }
            else if hrv < adjustedMedLow { stress += 0.2 }
            else if hrv < adjustedMedHigh { stress += 0.05 }
            else if hrv > adjustedHigh { stress -= 0.15 }
        }

        if let hr = context.biometric?.heartRate {
            let hrElevation = hr - _restingHeartRate
            if hrElevation > 30 && context.biometric?.isInWorkout != true { stress += 0.2 }
        }

        return clamp(stress, 0.0, 1.0)
    }

    /// R2: Multi-signal valence incorporating HRV trend and activity.
    /// Reference: Kreibig, Cognition & Emotion 2010; Mauss & Robinson, 2009
    private func _estimateValence(from context: AggregatedContext, stress: Double) -> Double {
        let stressComponent = -(stress - 0.5) * 0.35
        let activityBonus: Double = (context.biometric?.isInWorkout == true) ? 0.15 : 0.0
        let entertainmentBonus: Double = (context.macOS?.inferredWorkState == .entertainment) ? 0.1 : 0.0
        // R2: Rising HRV trend suggests improving mood
        let hrvTrendComponent: Double = {
            let trend = _calculateRMSSDTrend()
            return clamp(trend / 200.0, -0.10, 0.10)
        }()
        return clamp(0.5 + stressComponent + activityBonus + entertainmentBonus + hrvTrendComponent, 0.0, 1.0)
    }

    // MARK: - R1: Circadian HRV Factor (Boudreau et al. 2022)
    static func circadianHRVFactor(for hour: Int) -> Double {
        switch hour {
        case 0..<6:   return 1.15  // Early morning: HRV naturally elevated
        case 6..<10:  return 1.10  // Morning: still above average
        case 10..<14: return 1.00  // Late morning: baseline
        case 14..<18: return 0.85  // Afternoon: HRV naturally lower (nadir)
        case 18..<22: return 0.95  // Evening: recovering
        default:      return 1.05  // Night: rising with parasympathetic dominance
        }
    }

    // MARK: - R3: HR Acceleration (Appelhans & Luecken 2006)
    private func _calculateHRAcceleration() -> Double {
        guard _hrAccelHistory.count >= maxHRAccelSamples else { return 0.0 }
        let oldest = _hrAccelHistory.first ?? 0.0
        let newest = _hrAccelHistory.last ?? 0.0
        // maxHRAccelSamples samples at 30s intervals = 2 minutes
        return (newest - oldest) / 2.0
    }

    /// Transition signal (0-1) from HR acceleration. >0 = likely state transition.
    static func transitionSignalFromHRAcceleration(_ hrAcceleration: Double) -> Double {
        let absAccel = abs(hrAcceleration)
        guard absAccel > 5.0 else { return 0.0 }
        return min(1.0, absAccel / 10.0)
    }

    // MARK: - Activity Context Inference

    private func _inferActivityContext(from context: AggregatedContext) -> ActivityContext {
        // Workout detection takes priority
        if context.biometric?.isInWorkout == true {
            return .workout
        }

        // macOS context
        if let macOS = context.macOS {
            switch macOS.inferredWorkState {
            case .deepWork: return .deepWork
            case .casual, .meetings: return .work
            case .entertainment: return .relaxation
            case .idle: break
            }
        }

        // Circadian-aware time-based fallbacks
        let hour = Calendar.current.component(.hour, from: context.timestamp)
        let isWeekend: Bool = {
            let weekday = Calendar.current.component(.weekday, from: context.timestamp)
            return weekday == 1 || weekday == 7
        }()
        return _circadianManager.circadianActivityContext(forHour: hour, isWeekend: isWeekend)
    }

    // MARK: - Yerkes-Dodson Arousal Classification (6.5)

    /// Classifies arousal using HRV (RMSSD) and heart rate on the Yerkes-Dodson curve.
    private func _classifyArousalState(rmssd: Double?, heartRate: Double?) -> ArousalState {
        guard let rmssd = rmssd else { return .optimal }
        let hr = heartRate ?? _restingHeartRate
        let hrElevation = hr - _restingHeartRate

        // High HRV + low heart rate elevation = under-aroused (bored/drowsy)
        if rmssd > 70 && hrElevation < 10 {
            return .underAroused
        }

        // Low HRV + elevated heart rate = over-aroused (stressed)
        if rmssd < 35 && hrElevation > 15 {
            return .overAroused
        }

        // Moderate HRV = optimal (engaged, flow state)
        return .optimal
    }

    // MARK: - Sleep Preparation Detection (6.4)

    /// Detects sleep prep 30-45 min before bedtime, confirmed by rising RMSSD.
    private func _detectSleepPreparation(currentHour: Int, currentMinute: Int) -> Bool {
        let effectiveBedtimeHour = _circadianManager.currentProfile?.typicalSleepHour ?? _typicalBedtimeHour
        let currentTotalMinutes = currentHour * 60 + currentMinute
        let bedtimeTotalMinutes = effectiveBedtimeHour * 60
        let minutesUntilBedtime = bedtimeTotalMinutes > currentTotalMinutes
            ? bedtimeTotalMinutes - currentTotalMinutes
            : (24 * 60 - currentTotalMinutes) + bedtimeTotalMinutes
        guard minutesUntilBedtime <= sleepPrepLeadMinutes && minutesUntilBedtime >= 0 else { return false }
        let rmssdTrend = _calculateRMSSDTrend()
        return rmssdTrend >= 0.0 || _recentRMSSD.isEmpty
    }

    /// RMSSD trend: positive = rising, negative = falling.
    private func _calculateRMSSDTrend() -> Double {
        guard _recentRMSSD.count >= 3 else { return 0.0 }
        let recent = Array(_recentRMSSD.suffix(5))
        let firstHalf = recent.prefix(recent.count / 2)
        let secondHalf = recent.suffix(recent.count - recent.count / 2)
        let firstAvg = firstHalf.isEmpty ? 0.0 : firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.isEmpty ? 0.0 : secondHalf.reduce(0, +) / Double(secondHalf.count)
        return secondAvg - firstAvg
    }

    // MARK: - Music Need Inference

    /// Infers music need incorporating Yerkes-Dodson arousal optimization.
    private func _inferMusicNeed(arousal: Double, energy: Double, focus: Double,
                                  stress: Double, activityContext: ActivityContext,
                                  arousalState: ArousalState, isSleepPrep: Bool) -> MusicNeed {
        if isSleepPrep { return .calm }
        switch activityContext {
        case .workout: return .energize
        case .deepWork: return .focus
        case .postWorkout: return .calm
        default: break
        }
        switch arousalState {
        case .optimal: return .maintain
        case .underAroused: return .energize
        case .overAroused: return .calm
        }
    }

    // MARK: - Confidence Calculation

    private func _calculateConfidence(from context: AggregatedContext) -> Double {
        var confidence = 0.1 // Minimum with just time-of-day

        if context.biometric?.heartRate != nil { confidence += 0.3 }
        if context.biometric?.hrv != nil { confidence += 0.25 }
        if context.macOS != nil { confidence += 0.2 }
        if context.biometric != nil { confidence += 0.15 }

        return min(confidence, 1.0)
    }

    // MARK: - Helpers

    private func _appendRMSSD(_ value: Double) {
        _recentRMSSD.append(value)
        if _recentRMSSD.count > maxRMSSDSamples {
            _recentRMSSD.removeFirst()
        }
    }

    private func _appendHeartRate(_ value: Double) {
        _recentHeartRates.append(value)
        if _recentHeartRates.count > maxHeartRateSamples {
            _recentHeartRates.removeFirst()
        }
    }

    /// R3: Appends an HR sample to the acceleration tracking buffer.
    private func _appendHRAccelSample(_ value: Double) {
        _hrAccelHistory.append(value)
        if _hrAccelHistory.count > maxHRAccelSamples {
            _hrAccelHistory.removeFirst()
        }
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    // MARK: - Arousal Queries

    /// Recommended tempo adjustment: under=-10, optimal=0, over=+10 BPM.
    public var arousalBPMAdjustment: Double {
        switch arousalState {
        case .underAroused: return 10.0
        case .optimal: return 0.0
        case .overAroused: return -10.0
        }
    }

    /// Recommended complexity multiplier: under=1.2x, optimal=1.0x, over=0.8x.
    public var arousalComplexityMultiplier: Double {
        switch arousalState {
        case .underAroused: return 1.2
        case .optimal: return 1.0
        case .overAroused: return 0.8
        }
    }
}
