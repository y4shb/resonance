//
//  StateVector.swift
//  Resonance
//
//  Real-time state estimation of user's current condition
//  Updated every 30 seconds by StateEngine
//

import Foundation

/// Real-time state estimation of user's current condition
public struct StateVector: Codable, Equatable, Sendable {
    // MARK: - Core Dimensions (0.0 - 1.0)

    /// Physiological arousal level (heart rate derived)
    /// 0.0 = very calm, resting
    /// 1.0 = highly activated, stressed or exercising
    public var arousal: Double

    /// Available energy level
    /// 0.0 = exhausted, fatigued
    /// 1.0 = fully energized, ready for activity
    public var energy: Double

    /// Cognitive focus level
    /// 0.0 = distracted, unfocused
    /// 1.0 = deep concentration
    public var focus: Double

    /// Stress/tension level
    /// 0.0 = completely relaxed
    /// 1.0 = highly stressed
    public var stress: Double

    /// Emotional valence (mood positivity)
    /// 0.0 = negative mood
    /// 1.0 = positive mood
    public var valence: Double

    // MARK: - Context

    /// Current activity context
    public var context: ActivityContext

    /// Inferred need based on state
    public var inferredNeed: MusicNeed

    // MARK: - Metadata

    /// When this vector was computed
    public var timestamp: Date

    /// Confidence in this estimation (0.0 - 1.0)
    public var confidence: Double

    /// Data sources that contributed
    public var dataSources: Set<DataSource>

    // MARK: - Initialization

    public init(
        arousal: Double = 0.5,
        energy: Double = 0.5,
        focus: Double = 0.5,
        stress: Double = 0.5,
        valence: Double = 0.5,
        context: ActivityContext = .unknown,
        inferredNeed: MusicNeed = .maintain,
        timestamp: Date = Date(),
        confidence: Double = 0.0,
        dataSources: Set<DataSource> = []
    ) {
        self.arousal = arousal
        self.energy = energy
        self.focus = focus
        self.stress = stress
        self.valence = valence
        self.context = context
        self.inferredNeed = inferredNeed
        self.timestamp = timestamp
        self.confidence = confidence
        self.dataSources = dataSources
    }

    // MARK: - Factory

    public static var empty: StateVector {
        StateVector()
    }
}

// MARK: - Supporting Types

public enum ActivityContext: String, Codable, CaseIterable, Sendable {
    case workout
    case postWorkout
    case work
    case deepWork
    case commute
    case relaxation
    case preSleep
    case morning
    case social
    case unknown

    public var displayName: String {
        switch self {
        case .workout: return "Workout"
        case .postWorkout: return "Post-Workout"
        case .work: return "Work"
        case .deepWork: return "Deep Work"
        case .commute: return "Commute"
        case .relaxation: return "Relaxation"
        case .preSleep: return "Pre-Sleep"
        case .morning: return "Morning"
        case .social: return "Social"
        case .unknown: return "Unknown"
        }
    }
}

public enum MusicNeed: String, Codable, CaseIterable, Sendable {
    case energize       // Need activation, motivation
    case calm           // Need to reduce stress, relax
    case focus          // Need concentration support
    case maintain       // Current state is good, maintain it
    case transition     // Transitioning between states

    public var displayName: String {
        switch self {
        case .energize: return "Energize"
        case .calm: return "Calm"
        case .focus: return "Focus"
        case .maintain: return "Maintain"
        case .transition: return "Transition"
        }
    }

    public var description: String {
        switch self {
        case .energize: return "Need activation and motivation"
        case .calm: return "Need to reduce stress and relax"
        case .focus: return "Need concentration support"
        case .maintain: return "Current state is good"
        case .transition: return "Transitioning between states"
        }
    }
}

public enum DataSource: String, Codable, CaseIterable, Sendable {
    case heartRate
    case hrv
    case motion
    case macOSContext
    case calendarContext
    case timeOfDay
    case manualMoodInput
    case historicalPattern

    public var displayName: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .hrv: return "HRV"
        case .motion: return "Motion"
        case .macOSContext: return "macOS Context"
        case .calendarContext: return "Calendar"
        case .timeOfDay: return "Time of Day"
        case .manualMoodInput: return "Manual Input"
        case .historicalPattern: return "Historical Pattern"
        }
    }
}

// MARK: - StateVector Extensions

extension StateVector {
    /// Returns a human-readable summary of the current state
    public var summary: String {
        let contextDesc = context.displayName
        let needDesc = inferredNeed.displayName
        let confidencePercent = Int(confidence * 100)

        return "\(contextDesc) - Need: \(needDesc) (\(confidencePercent)% confidence)"
    }

    /// Returns the dominant characteristic of the current state
    public var dominantCharacteristic: String {
        let characteristics: [(String, Double)] = [
            ("High Energy", energy),
            ("Stressed", stress),
            ("Focused", focus),
            ("Relaxed", 1.0 - stress),
            ("Alert", arousal)
        ]

        return characteristics.max(by: { $0.1 < $1.1 })?.0 ?? "Balanced"
    }
}
