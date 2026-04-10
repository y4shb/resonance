//
//  ContextSignal.swift
//  Resonance
//
//  Context signals from various sources (macOS, calendar, location)
//

import Foundation

/// Context signal from macOS
public struct MacOSContextSignal: Codable, Sendable {
    // MARK: - Identifiers

    public let id: UUID
    public let timestamp: Date

    // MARK: - Focus Mode

    /// Whether a Focus mode is currently active
    public var focusModeActive: Bool

    /// Name of the active Focus mode (e.g., "Do Not Disturb", "Work")
    public var focusModeName: String?

    // MARK: - Active Application

    /// Bundle ID of the frontmost application
    public var activeAppBundleId: String?

    /// Display name of the frontmost application
    public var activeAppName: String?

    /// Category of the frontmost application
    public var activeAppCategory: AppCategory?

    // MARK: - Screen Time (last hour)

    /// Minutes spent in productivity apps
    public var productivityMinutes: Double

    /// Minutes spent in entertainment apps
    public var entertainmentMinutes: Double

    /// Minutes spent in social apps
    public var socialMinutes: Double

    // MARK: - Calendar

    /// Whether there's an ongoing calendar event/meeting
    public var hasOngoingMeeting: Bool

    /// Minutes until the next calendar event
    public var minutesUntilNextEvent: Double?

    /// Type of the next calendar event
    public var nextEventType: CalendarEventType?

    // MARK: - Derived Context

    /// Inferred work state based on signals
    public var inferredWorkState: WorkState

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        focusModeActive: Bool = false,
        focusModeName: String? = nil,
        activeAppBundleId: String? = nil,
        activeAppName: String? = nil,
        activeAppCategory: AppCategory? = nil,
        productivityMinutes: Double = 0,
        entertainmentMinutes: Double = 0,
        socialMinutes: Double = 0,
        hasOngoingMeeting: Bool = false,
        minutesUntilNextEvent: Double? = nil,
        nextEventType: CalendarEventType? = nil,
        inferredWorkState: WorkState = .idle
    ) {
        self.id = id
        self.timestamp = timestamp
        self.focusModeActive = focusModeActive
        self.focusModeName = focusModeName
        self.activeAppBundleId = activeAppBundleId
        self.activeAppName = activeAppName
        self.activeAppCategory = activeAppCategory
        self.productivityMinutes = productivityMinutes
        self.entertainmentMinutes = entertainmentMinutes
        self.socialMinutes = socialMinutes
        self.hasOngoingMeeting = hasOngoingMeeting
        self.minutesUntilNextEvent = minutesUntilNextEvent
        self.nextEventType = nextEventType
        self.inferredWorkState = inferredWorkState
    }
}

// MARK: - Supporting Types

public enum AppCategory: String, Codable, CaseIterable, Sendable {
    case productivity = "productivity"
    case creative = "creative"
    case development = "development"
    case communication = "communication"
    case browser = "browser"
    case entertainment = "entertainment"
    case social = "social"
    case utilities = "utilities"
    case system = "system"
    case unknown = "unknown"

    public var displayName: String {
        rawValue.capitalized
    }

    /// Maps common bundle IDs to categories
    public static func categorize(bundleId: String?) -> AppCategory {
        guard let bundleId = bundleId?.lowercased() else { return .unknown }

        // Ordered array for deterministic matching; more specific matches first
        let mappings: [(String, AppCategory)] = [
            // Development (specific bundle IDs first)
            ("com.apple.dt.xcode", .development),
            ("com.microsoft.vscode", .development),
            ("com.apple.terminal", .development),
            ("xcode", .development),
            ("vscode", .development),
            ("terminal", .development),
            ("iterm", .development),

            // Productivity
            ("pages", .productivity),
            ("numbers", .productivity),
            ("keynote", .productivity),
            ("word", .productivity),
            ("excel", .productivity),
            ("notion", .productivity),

            // Creative
            ("photoshop", .creative),
            ("illustrator", .creative),
            ("figma", .creative),
            ("sketch", .creative),
            ("logic", .creative),
            ("garageband", .creative),
            ("final cut", .creative),

            // Communication
            ("mail", .communication),
            ("slack", .communication),
            ("zoom", .communication),
            ("teams", .communication),
            ("messages", .communication),

            // Browsers
            ("safari", .browser),
            ("chrome", .browser),
            ("firefox", .browser),
            ("arc", .browser),

            // Entertainment
            ("music", .entertainment),
            ("spotify", .entertainment),
            ("netflix", .entertainment),
            ("youtube", .entertainment),

            // Social
            ("twitter", .social),
            ("facebook", .social),
            ("instagram", .social),
            ("discord", .social),
        ]

        for (keyword, category) in mappings {
            if bundleId.contains(keyword) {
                return category
            }
        }

        return .unknown
    }
}

public enum CalendarEventType: String, Codable, CaseIterable, Sendable {
    case meeting = "meeting"
    case focus = "focus"
    case personal = "personal"
    case reminder = "reminder"
    case allDay = "all_day"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .meeting: return "Meeting"
        case .focus: return "Focus Time"
        case .personal: return "Personal"
        case .reminder: return "Reminder"
        case .allDay: return "All Day"
        case .unknown: return "Event"
        }
    }
}

public enum WorkState: String, Codable, CaseIterable, Sendable {
    case deepWork = "deep_work"
    case meetings = "meetings"
    case casual = "casual"
    case idle = "idle"
    case entertainment = "entertainment"

    public var displayName: String {
        switch self {
        case .deepWork: return "Deep Work"
        case .meetings: return "In Meetings"
        case .casual: return "Casual Work"
        case .idle: return "Idle"
        case .entertainment: return "Entertainment"
        }
    }

    /// Suggested music focus for this work state
    public var suggestedMusicNeed: MusicNeed {
        switch self {
        case .deepWork: return .focus
        case .meetings: return .maintain
        case .casual: return .maintain
        case .idle: return .maintain
        case .entertainment: return .energize
        }
    }
}

// MARK: - Biometric Signal

/// Biometric signal from Apple Watch
public struct BiometricSignal: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date

    /// Heart rate in BPM (nil if not available)
    public var heartRate: Double?

    /// Heart rate variability (SDNN) in milliseconds
    public var hrv: Double?

    /// Whether the user is stationary
    public var isStationary: Bool

    /// Whether the user is in an active workout
    public var isInWorkout: Bool

    /// Type of workout if active
    public var workoutType: String?

    /// Step count in the last sampling period
    public var stepCount: Int?

    /// Quality of the sensor readings (0.0 - 1.0)
    public var sampleQuality: Double

    /// Source device identifier
    public var sourceDevice: String

    /// Accelerometer magnitude (0.0 = stationary, 1.0+ = vigorous motion).
    /// Used by motion-aware reward gating (Workstream 2.2).
    public var accelerometerMagnitude: Double

    /// HRV measurement quality score (0.0 - 1.0).
    /// Derived from motion context and R-R interval consistency (Workstream 2.4).
    /// 1.0 = high quality stationary reading, < 0.8 = degraded by motion or noise.
    public var hrvQuality: Double

    /// Overnight respiratory rate in breaths/min (Workstream 3.3).
    /// Nil if not available or not yet fetched today.
    public var respiratoryRate: Double?

    /// Whether an irregular heart rhythm notification has been detected recently
    /// (Workstream 3.8). When true, biometric reliability should be reduced.
    public var hasRecentIrregularRhythm: Bool

    // MARK: - Emotion Detection Fields

    /// RMS of user acceleration magnitude (g) from Watch motion sensor.
    public var movementMagnitude: Double?

    /// Standard deviation of acceleration magnitude.
    public var movementVariability: Double?

    /// Shannon entropy of acceleration magnitude.
    public var movementEntropy: Double?

    /// RMS of gyroscope rotation rate (rad/s).
    public var rotationMagnitude: Double?

    /// Acceleration peaks per second above threshold.
    public var gestureFrequency: Double?

    /// Watch-side classified emotional state.
    public var emotionalState: EmotionalState?

    /// Confidence of the emotion classification (0.0 - 1.0).
    public var emotionConfidence: Double?

    /// Watch sensor capability tier.
    public var capabilityTier: WatchCapabilityTier?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        heartRate: Double? = nil,
        hrv: Double? = nil,
        isStationary: Bool = true,
        isInWorkout: Bool = false,
        workoutType: String? = nil,
        stepCount: Int? = nil,
        sampleQuality: Double = 1.0,
        sourceDevice: String = "watch",
        accelerometerMagnitude: Double = 0.0,
        hrvQuality: Double = 1.0,
        respiratoryRate: Double? = nil,
        hasRecentIrregularRhythm: Bool = false,
        movementMagnitude: Double? = nil,
        movementVariability: Double? = nil,
        movementEntropy: Double? = nil,
        rotationMagnitude: Double? = nil,
        gestureFrequency: Double? = nil,
        emotionalState: EmotionalState? = nil,
        emotionConfidence: Double? = nil,
        capabilityTier: WatchCapabilityTier? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrv = hrv
        self.isStationary = isStationary
        self.isInWorkout = isInWorkout
        self.workoutType = workoutType
        self.stepCount = stepCount
        self.sampleQuality = sampleQuality
        self.sourceDevice = sourceDevice
        self.accelerometerMagnitude = accelerometerMagnitude
        self.hrvQuality = hrvQuality
        self.respiratoryRate = respiratoryRate
        self.hasRecentIrregularRhythm = hasRecentIrregularRhythm
        self.movementMagnitude = movementMagnitude
        self.movementVariability = movementVariability
        self.movementEntropy = movementEntropy
        self.rotationMagnitude = rotationMagnitude
        self.gestureFrequency = gestureFrequency
        self.emotionalState = emotionalState
        self.emotionConfidence = emotionConfidence
        self.capabilityTier = capabilityTier
    }
}

// MARK: - Aggregated Context

/// Aggregated context from all signal sources
public struct AggregatedContext: Sendable {
    public let timestamp: Date

    /// Latest biometric signal
    public var biometric: BiometricSignal?

    /// Latest macOS context
    public var macOS: MacOSContextSignal?

    /// Time of day slot
    public var timeSlot: TimeSlot

    /// Day of week (1 = Sunday, 7 = Saturday)
    public var dayOfWeek: Int

    /// Whether it's a weekend
    public var isWeekend: Bool

    /// Whether the user appears to be driving (Workstream 3.5).
    /// True when audio route is carAudio or CarPlay is active.
    public var isDriving: Bool

    /// Current audio output route (Workstream 3.4).
    public var audioRoute: AudioRoute

    /// Whether an iOS Focus mode is currently active (Workstream 3.6).
    public var isFocusModeActive: Bool

    /// Sleep baseline for morning energy adjustment (Workstream 3.2).
    public var sleepBaseline: SleepBaseline?

    // MARK: - Weather Context (E4: Weather-Responsive Mixing)

    /// Current weather condition string (e.g., "rain", "sunny", "cloudy")
    public var weatherCondition: String?

    /// Weather-derived valence modifier (-1.0 to 1.0)
    public var weatherValenceModifier: Double

    /// Weather-derived energy modifier (-1.0 to 1.0)
    public var weatherEnergyModifier: Double

    /// Weather-derived tempo modifier (-1.0 to 1.0)
    public var weatherTempoModifier: Double

    public init(
        timestamp: Date = Date(),
        biometric: BiometricSignal? = nil,
        macOS: MacOSContextSignal? = nil,
        isDriving: Bool = false,
        audioRoute: AudioRoute = .unknown,
        isFocusModeActive: Bool = false,
        sleepBaseline: SleepBaseline? = nil,
        weatherCondition: String? = nil,
        weatherValenceModifier: Double = 0,
        weatherEnergyModifier: Double = 0,
        weatherTempoModifier: Double = 0
    ) {
        self.timestamp = timestamp
        self.biometric = biometric
        self.macOS = macOS
        self.isDriving = isDriving
        self.audioRoute = audioRoute
        self.isFocusModeActive = isFocusModeActive
        self.sleepBaseline = sleepBaseline
        self.weatherCondition = weatherCondition
        self.weatherValenceModifier = weatherValenceModifier
        self.weatherEnergyModifier = weatherEnergyModifier
        self.weatherTempoModifier = weatherTempoModifier

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        self.dayOfWeek = calendar.component(.weekday, from: timestamp)
        self.isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        self.timeSlot = TimeSlot(hour: hour)
    }
}

// MARK: - Audio Route (Workstream 3.4)

/// Detected audio output route for contextual awareness.
public enum AudioRoute: String, Codable, Sendable {
    case builtInSpeaker = "built_in_speaker"
    case headphones = "headphones"
    case bluetoothA2DP = "bluetooth_a2dp"
    case carAudio = "car_audio"
    case airPlay = "airplay"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .builtInSpeaker: return "Speaker"
        case .headphones: return "Headphones"
        case .bluetoothA2DP: return "Bluetooth"
        case .carAudio: return "Car Audio"
        case .airPlay: return "AirPlay"
        case .unknown: return "Unknown"
        }
    }

    /// Whether this route suggests private listening (headphones/earbuds).
    public var isPrivateListening: Bool {
        switch self {
        case .headphones, .bluetoothA2DP: return true
        default: return false
        }
    }
}

// MARK: - Sleep Baseline (Workstream 3.2)

/// Sleep baseline derived from last night's sleep analysis.
/// Used to adjust morning energy estimates in the StateEngine.
public struct SleepBaseline: Codable, Sendable {
    /// Total hours of sleep last night.
    public let totalSleepHours: Double

    /// Percentage of sleep that was deep sleep (0.0 - 1.0).
    public let deepSleepPercentage: Double

    /// Percentage of sleep that was REM sleep (0.0 - 1.0).
    public let remSleepPercentage: Double

    /// When this baseline was computed.
    public let computedAt: Date

    /// Energy modifier for the morning state (-0.3 to +0.2).
    /// Negative values indicate poor sleep; positive values indicate restorative sleep.
    public var morningEnergyModifier: Double {
        var modifier: Double = 0.0

        // Sleep duration factor: 7-9 hours is ideal
        if totalSleepHours < 5.0 {
            modifier -= 0.3
        } else if totalSleepHours < 6.0 {
            modifier -= 0.2
        } else if totalSleepHours < 7.0 {
            modifier -= 0.1
        } else if totalSleepHours >= 7.5 && totalSleepHours <= 9.0 {
            modifier += 0.1
        }

        // Deep sleep factor: 15-25% is ideal
        if deepSleepPercentage >= 0.20 {
            modifier += 0.1
        } else if deepSleepPercentage < 0.10 {
            modifier -= 0.1
        }

        return max(-0.3, min(0.2, modifier))
    }

    public init(
        totalSleepHours: Double,
        deepSleepPercentage: Double,
        remSleepPercentage: Double,
        computedAt: Date = Date()
    ) {
        self.totalSleepHours = totalSleepHours
        self.deepSleepPercentage = deepSleepPercentage
        self.remSleepPercentage = remSleepPercentage
        self.computedAt = computedAt
    }
}
