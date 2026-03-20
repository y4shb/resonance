//
//  MoodForecastEngine.swift
//  Resonance
//
//  Predicts a mood/energy arc BEFORE a session starts and reorders playlists
//  to match user-modified trajectories. Leverages SessionPlanner arc templates,
//  circadian energy estimation, and current biometric state.
//

#if os(iOS)
import Foundation

// MARK: - Forecast Point

/// A single point in the predicted energy curve.
struct ForecastPoint: Identifiable, Sendable {
    let id: Int
    var energy: Double
    var bpm: Double
    let timestamp: TimeInterval
    var isUserModified = false
}

// MARK: - Mood Forecast

/// A complete predicted energy curve for a session.
struct MoodForecast: Sendable {
    var points: [ForecastPoint]
    let arcTemplate: String
    let sessionDuration: TimeInterval
    let confidence: Double
}

// MARK: - Mood Forecast Engine

/// Generates predicted energy curves and reorders playlists to match them.
///
/// Uses SessionPlanner arc templates for the base shape, applies circadian
/// adjustments from StateEngine research, and incorporates current HRV
/// for baseline calibration.
final class MoodForecastEngine {

    private let sessionPlanner = SessionPlanner()

    // MARK: - Public API

    /// Generates a predicted energy curve for a session.
    ///
    /// - Parameters:
    ///   - intent: The user-selected music need (energize, calm, focus, etc.)
    ///   - timeSlot: Current time of day for circadian adjustment
    ///   - currentHRV: Current HRV reading for baseline arousal (optional)
    ///   - playlistSongs: Songs available for the session
    ///   - sessionDuration: Planned session length in seconds (default 30 min)
    /// - Returns: A `MoodForecast` with 8-12 energy curve points
    func generateForecast(
        intent: MusicNeed,
        timeSlot: TimeSlot,
        currentHRV: Double?,
        playlistSongs: [SongFeatures],
        sessionDuration: TimeInterval = 1800
    ) -> MoodForecast {
        let template = selectArcTemplate(for: intent)
        let pointCount = calculatePointCount(for: sessionDuration)

        // Generate base energy trajectory from the arc template
        let arcPhases = generateArcPhases(template: template, intent: intent)
        var points = interpolateEnergyPoints(
            from: arcPhases,
            pointCount: pointCount,
            sessionDuration: sessionDuration
        )

        // Apply circadian adjustment
        points = applyCircadianAdjustment(points: points, timeSlot: timeSlot)

        // Apply HRV-based starting energy adjustment
        if let hrv = currentHRV {
            points = applyHRVAdjustment(points: points, hrv: hrv)
        }

        // Convert energy values to BPM targets
        let bpmRange = bpmRangeForTemplate(template)
        points = assignBPMTargets(points: points, bpmRange: bpmRange)

        // Calculate confidence based on available data
        let confidence = calculateConfidence(
            hasHRV: currentHRV != nil,
            songCount: playlistSongs.count,
            pointCount: pointCount
        )

        logInfo(
            "MoodForecastEngine: generated \(pointCount)-point forecast, "
            + "template=\(template.rawValue), confidence=\(String(format: "%.2f", confidence))",
            category: .sessionPlanner
        )

        return MoodForecast(
            points: points,
            arcTemplate: template.displayName,
            sessionDuration: sessionDuration,
            confidence: confidence
        )
    }

    /// Reorders playlist songs to match a (potentially user-modified) forecast curve.
    ///
    /// Uses a greedy matching algorithm: for each forecast segment, finds the
    /// best-matching unassigned song based on energy and BPM proximity.
    ///
    /// - Parameters:
    ///   - songs: Available songs to reorder
    ///   - forecast: The target energy curve (may include user modifications)
    /// - Returns: Songs reordered to follow the forecast curve
    func reorderPlaylist(
        songs: [SongFeatures],
        forecast: MoodForecast
    ) -> [SongFeatures] {
        guard !songs.isEmpty, !forecast.points.isEmpty else { return songs }

        // Divide the forecast into segments, one per song (up to available songs)
        let segmentCount = min(songs.count, forecast.points.count)
        let segmentTargets = distributeTargets(
            points: forecast.points,
            segmentCount: segmentCount
        )

        var available = songs
        var ordered: [SongFeatures] = []

        for target in segmentTargets {
            guard !available.isEmpty else { break }

            // Find best matching song for this segment
            let bestIndex = findBestMatch(
                target: target,
                candidates: available
            )

            ordered.append(available[bestIndex])
            available.remove(at: bestIndex)
        }

        // Append any remaining unmatched songs
        ordered.append(contentsOf: available)

        return ordered
    }

    // MARK: - Arc Template Selection

    /// Maps a MusicNeed to the corresponding ArcTemplate.
    private func selectArcTemplate(for intent: MusicNeed) -> ArcTemplate {
        switch intent {
        case .energize:   return .workoutBuildPeakCool
        case .calm:       return .relaxationDescend
        case .focus:      return .focusSustainPlateau
        case .maintain:   return .commuteEnergize
        case .transition: return .morningRise
        }
    }

    // MARK: - Arc Phase Generation

    /// Generates arc phases for the given template and intent using SessionPlanner logic.
    private func generateArcPhases(
        template: ArcTemplate,
        intent: MusicNeed
    ) -> [ArcPhase] {
        // Build a minimal StateVector with sensible defaults for the intent
        let baseEnergy: Double
        switch intent {
        case .energize:   baseEnergy = 0.5
        case .calm:       baseEnergy = 0.4
        case .focus:      baseEnergy = 0.45
        case .maintain:   baseEnergy = 0.5
        case .transition: baseEnergy = 0.35
        }

        let state = StateVector(
            arousal: baseEnergy,
            energy: baseEnergy,
            focus: 0.5,
            stress: 0.3,
            valence: 0.5,
            context: activityContextForIntent(intent)
        )

        let arc = sessionPlanner.planSession(
            currentState: state,
            targetContext: state.context,
            estimatedDuration: 30
        )

        return arc.phases
    }

    /// Maps a MusicNeed to an ActivityContext for SessionPlanner.
    private func activityContextForIntent(_ intent: MusicNeed) -> ActivityContext {
        switch intent {
        case .energize:   return .workout
        case .calm:       return .relaxation
        case .focus:      return .deepWork
        case .maintain:   return .commute
        case .transition: return .morning
        }
    }

    // MARK: - Energy Interpolation

    /// Interpolates arc phase energy values into evenly-spaced forecast points.
    private func interpolateEnergyPoints(
        from phases: [ArcPhase],
        pointCount: Int,
        sessionDuration: TimeInterval
    ) -> [ForecastPoint] {
        // Build a raw energy trajectory from phases
        var rawEnergies: [Double] = []
        for phase in phases {
            for i in 0..<phase.songCount {
                let progress = phase.songCount > 1
                    ? Double(i) / Double(phase.songCount - 1)
                    : 0.5
                let energy = phase.targetEnergyRange.lowerBound
                    + progress * (phase.targetEnergyRange.upperBound - phase.targetEnergyRange.lowerBound)
                rawEnergies.append(energy)
            }
        }

        guard !rawEnergies.isEmpty else {
            // Fallback: flat moderate energy
            return (0..<pointCount).map { i in
                ForecastPoint(
                    id: i,
                    energy: 0.5,
                    bpm: 100,
                    timestamp: sessionDuration * Double(i) / Double(max(pointCount - 1, 1))
                )
            }
        }

        // Resample to the desired point count
        let timeStep = sessionDuration / Double(max(pointCount - 1, 1))
        return (0..<pointCount).map { i in
            let normalizedPos = Double(i) / Double(max(pointCount - 1, 1))
            let rawIndex = normalizedPos * Double(rawEnergies.count - 1)
            let lowerIndex = Int(rawIndex)
            let upperIndex = min(lowerIndex + 1, rawEnergies.count - 1)
            let fraction = rawIndex - Double(lowerIndex)
            let interpolatedEnergy = rawEnergies[lowerIndex]
                + fraction * (rawEnergies[upperIndex] - rawEnergies[lowerIndex])

            return ForecastPoint(
                id: i,
                energy: clamp(interpolatedEnergy, 0.0, 1.0),
                bpm: 0,
                timestamp: timeStep * Double(i)
            )
        }
    }

    // MARK: - Circadian Adjustment

    /// Adjusts energy values based on time-of-day circadian patterns.
    /// Mirrors the circadian logic in SharedStateEngine._estimateEnergy.
    private func applyCircadianAdjustment(
        points: [ForecastPoint],
        timeSlot: TimeSlot
    ) -> [ForecastPoint] {
        let adjustment: Double
        switch timeSlot {
        case .earlyMorning: adjustment = 0.05
        case .morning:      adjustment = 0.10
        case .midday:       adjustment = 0.08
        case .afternoon:    adjustment = -0.03
        case .evening:      adjustment = -0.05
        case .night:        adjustment = -0.10
        case .unknown:      adjustment = 0.0
        }

        return points.map { point in
            var adjusted = point
            adjusted.energy = clamp(point.energy + adjustment, 0.0, 1.0)
            return adjusted
        }
    }

    // MARK: - HRV Adjustment

    /// Adjusts starting energy based on current HRV reading.
    /// Higher HRV indicates parasympathetic dominance (relaxed); lower indicates stress.
    private func applyHRVAdjustment(
        points: [ForecastPoint],
        hrv: Double
    ) -> [ForecastPoint] {
        // Normalize HRV: 20-100ms range -> 0.0-1.0
        let normalizedHRV = clamp((hrv - 20.0) / 80.0, 0.0, 1.0)

        // High HRV = relaxed baseline, low HRV = elevated baseline
        // Adjust primarily the first few points (fades out over the arc)
        return points.enumerated().map { index, point in
            var adjusted = point
            let fadeout = max(0.0, 1.0 - Double(index) / Double(max(points.count - 1, 1)))
            let hrvShift = (normalizedHRV - 0.5) * -0.15 * fadeout
            adjusted.energy = clamp(point.energy + hrvShift, 0.0, 1.0)
            return adjusted
        }
    }

    // MARK: - BPM Assignment

    /// Returns the BPM range associated with an arc template.
    private func bpmRangeForTemplate(_ template: ArcTemplate) -> (min: Double, max: Double) {
        switch template {
        case .workoutBuildPeakCool:   return (100, 170)
        case .relaxationDescend:      return (70, 100)
        case .focusSustainPlateau:    return (70, 110)
        case .sleepWindDown:          return (60, 80)
        case .morningRise:            return (70, 120)
        case .commuteEnergize:        return (90, 130)
        }
    }

    /// Assigns BPM targets to forecast points based on their energy levels.
    private func assignBPMTargets(
        points: [ForecastPoint],
        bpmRange: (min: Double, max: Double)
    ) -> [ForecastPoint] {
        points.map { point in
            var updated = point
            updated.bpm = bpmRange.min + point.energy * (bpmRange.max - bpmRange.min)
            return updated
        }
    }

    // MARK: - Playlist Matching

    /// Distributes forecast points into segment targets for song matching.
    private func distributeTargets(
        points: [ForecastPoint],
        segmentCount: Int
    ) -> [(energy: Double, bpm: Double)] {
        guard segmentCount > 0 else { return [] }

        if segmentCount >= points.count {
            return points.map { ($0.energy, $0.bpm) }
        }

        // Average points within each segment
        let segmentSize = Double(points.count) / Double(segmentCount)
        return (0..<segmentCount).map { seg in
            let start = Int(Double(seg) * segmentSize)
            let end = min(Int(Double(seg + 1) * segmentSize), points.count)
            let slice = points[start..<end]
            let avgEnergy = slice.map(\.energy).reduce(0, +) / Double(slice.count)
            let avgBPM = slice.map(\.bpm).reduce(0, +) / Double(slice.count)
            return (avgEnergy, avgBPM)
        }
    }

    /// Finds the index of the best-matching song for a target energy/BPM.
    private func findBestMatch(
        target: (energy: Double, bpm: Double),
        candidates: [SongFeatures]
    ) -> Int {
        var bestIndex = 0
        var bestScore = Double.greatestFiniteMagnitude

        for (index, song) in candidates.enumerated() {
            let energyDiff = abs(song.energy - target.energy)
            let bpmDiff = song.bpm > 0 ? abs(song.bpm - target.bpm) / 200.0 : 0.3
            let score = energyDiff + bpmDiff

            if score < bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestIndex
    }

    // MARK: - Helpers

    /// Determines the number of forecast points based on session duration.
    private func calculatePointCount(for duration: TimeInterval) -> Int {
        let minutes = duration / 60.0
        return Int(clamp(minutes / 3.0, 6.0, 12.0))
    }

    /// Calculates forecast confidence from available data quality.
    private func calculateConfidence(
        hasHRV: Bool,
        songCount: Int,
        pointCount: Int
    ) -> Double {
        var confidence = 0.4 // Base confidence from arc template
        if hasHRV { confidence += 0.25 }
        if songCount >= pointCount { confidence += 0.2 }
        if songCount >= pointCount * 2 { confidence += 0.15 }
        return min(confidence, 1.0)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
#endif
