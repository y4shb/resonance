//
//  StateEngine.swift
//  Resonance
//
//  Processes biometric signals and context to produce a StateVector.
//  Includes Yerkes-Dodson arousal optimization (6.5) and sleep preparation
//  detection (6.4).
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
    private var _typicalBedtimeHour: Int
    private let sleepPrepLeadMinutes: Int = 45

    // MARK: - State

    private var _currentState: StateVector
    private var _arousalState: ArousalState = .optimal
    private var _isSleepPrepActive: Bool = false
    private var _recentRMSSD: [Double] = []
    private let maxRMSSDSamples: Int = 10
    private var _recentHeartRates: [Double] = []
    private let maxHeartRateSamples: Int = 10

    // MARK: - Thread-Safe Accessors

    public var currentState: StateVector { lock.withLock { _currentState } }
    public var arousalState: ArousalState { lock.withLock { _arousalState } }
    public var isSleepPrepActive: Bool { lock.withLock { _isSleepPrepActive } }

    // MARK: - Initialization

    public init(
        restingHeartRate: Double = StateEngineConstants.defaultRestingHeartRate,
        userAge: Int = StateEngineConstants.defaultUserAge,
        typicalBedtimeHour: Int = 23
    ) {
        self._restingHeartRate = restingHeartRate
        self._maxHeartRate = StateEngineConstants.maxHeartRateBase - Double(userAge)
        self._typicalBedtimeHour = typicalBedtimeHour
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
            let valence = _estimateValence(from: context, stress: stress)
            let activityContext = _inferActivityContext(from: context)
            let confidence = _calculateConfidence(from: context)

            // Track biometric history
            if let hrv = context.biometric?.hrv {
                _appendRMSSD(hrv)
            }
            if let hr = context.biometric?.heartRate {
                _appendHeartRate(hr)
            }

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
        switch hour {
        case 6..<10: energy += 0.1
        case 10..<14: energy += 0.15
        case 14..<16: energy -= 0.05
        case 22..<24, 0..<6: energy -= 0.15
        default: break
        }
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

    private func _estimateStress(from context: AggregatedContext) -> Double {
        var stress = 0.3
        if let hrv = context.biometric?.hrv {
            if hrv < 25 { stress += 0.35 }
            else if hrv < 40 { stress += 0.2 }
            else if hrv < 60 { stress += 0.05 }
            else if hrv > 80 { stress -= 0.15 }
        }
        if let hr = context.biometric?.heartRate {
            let hrElevation = hr - _restingHeartRate
            if hrElevation > 30 && context.biometric?.isInWorkout != true { stress += 0.2 }
        }
        return clamp(stress, 0.0, 1.0)
    }

    private func _estimateValence(from context: AggregatedContext, stress: Double) -> Double {
        var valence = 0.5
        valence -= (stress - 0.5) * 0.4
        if context.biometric?.isInWorkout == true { valence += 0.15 }
        if context.macOS?.inferredWorkState == .entertainment { valence += 0.1 }
        return clamp(valence, 0.0, 1.0)
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

        // Time-based fallbacks
        let hour = Calendar.current.component(.hour, from: context.timestamp)
        switch hour {
        case 6..<9: return .morning
        case 22..<24, 0..<6: return .preSleep
        default: return .unknown
        }
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

    /// Detects sleep prep mode 30-45 min before bedtime, confirmed by rising RMSSD.
    private func _detectSleepPreparation(currentHour: Int, currentMinute: Int) -> Bool {
        // Calculate minutes until bedtime
        let currentTotalMinutes = currentHour * 60 + currentMinute
        let bedtimeTotalMinutes = _typicalBedtimeHour * 60

        let minutesUntilBedtime: Int
        if bedtimeTotalMinutes > currentTotalMinutes {
            minutesUntilBedtime = bedtimeTotalMinutes - currentTotalMinutes
        } else {
            // Handle midnight crossing
            minutesUntilBedtime = (24 * 60 - currentTotalMinutes) + bedtimeTotalMinutes
        }

        // Only activate within 45-minute window before bedtime
        guard minutesUntilBedtime <= sleepPrepLeadMinutes && minutesUntilBedtime >= 0 else {
            return false
        }

        // Physiological confirmation: check for rising RMSSD trend
        // (parasympathetic activation = body winding down)
        let rmssdTrend = _calculateRMSSDTrend()

        // Activate if within time window AND RMSSD is rising (or we have no data)
        return rmssdTrend >= 0.0 || _recentRMSSD.isEmpty
    }

    /// RMSSD trend: positive = rising, negative = falling.
    private func _calculateRMSSDTrend() -> Double {
        guard _recentRMSSD.count >= 3 else { return 0.0 }
        let recent = Array(_recentRMSSD.suffix(5))
        let firstHalf = recent.prefix(recent.count / 2)
        let secondHalf = recent.suffix(recent.count / 2)
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        return secondAvg - firstAvg
    }

    // MARK: - Music Need Inference

    /// Infers music need incorporating Yerkes-Dodson arousal optimization.
    private func _inferMusicNeed(
        arousal: Double,
        energy: Double,
        focus: Double,
        stress: Double,
        activityContext: ActivityContext,
        arousalState: ArousalState,
        isSleepPrep: Bool
    ) -> MusicNeed {
        // Sleep preparation overrides everything
        if isSleepPrep {
            return .calm
        }

        // Context-specific overrides
        switch activityContext {
        case .workout:
            return .energize
        case .deepWork:
            return .focus
        case .postWorkout:
            return .calm
        default:
            break
        }

        // Yerkes-Dodson: optimal->maintain, under->energize, over->calm
        switch arousalState {
        case .optimal:
            return .maintain
        case .underAroused:
            return .energize
        case .overAroused:
            return .calm
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

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

// MARK: - SharedStateEngine Arousal Queries

extension SharedStateEngine {
    /// Returns the current arousal state's recommended tempo adjustment.
    /// - underAroused: increase tempo/complexity (+5 to +15 BPM)
    /// - optimal: no change (0 BPM)
    /// - overAroused: decrease tempo/complexity (-5 to -15 BPM)
    public var arousalBPMAdjustment: Double {
        switch arousalState {
        case .underAroused: return 10.0
        case .optimal: return 0.0
        case .overAroused: return -10.0
        }
    }

    /// Returns the recommended energy complexity multiplier.
    /// - underAroused: increase complexity (1.2x)
    /// - optimal: maintain (1.0x)
    /// - overAroused: decrease complexity (0.8x)
    public var arousalComplexityMultiplier: Double {
        switch arousalState {
        case .underAroused: return 1.2
        case .optimal: return 1.0
        case .overAroused: return 0.8
        }
    }
}
