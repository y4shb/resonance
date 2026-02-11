//
//  ContextSignal.swift
//  AIDJ
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

        let mappings: [String: AppCategory] = [
            // Development
            "xcode": .development,
            "com.apple.dt.xcode": .development,
            "vscode": .development,
            "com.microsoft.vscode": .development,
            "terminal": .development,
            "com.apple.terminal": .development,
            "iterm": .development,

            // Productivity
            "pages": .productivity,
            "numbers": .productivity,
            "keynote": .productivity,
            "word": .productivity,
            "excel": .productivity,
            "notion": .productivity,

            // Creative
            "photoshop": .creative,
            "illustrator": .creative,
            "figma": .creative,
            "sketch": .creative,
            "logic": .creative,
            "garageband": .creative,
            "final cut": .creative,

            // Communication
            "mail": .communication,
            "slack": .communication,
            "zoom": .communication,
            "teams": .communication,
            "messages": .communication,

            // Browsers
            "safari": .browser,
            "chrome": .browser,
            "firefox": .browser,
            "arc": .browser,

            // Entertainment
            "music": .entertainment,
            "spotify": .entertainment,
            "netflix": .entertainment,
            "youtube": .entertainment,

            // Social
            "twitter": .social,
            "facebook": .social,
            "instagram": .social,
            "discord": .social
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
        sourceDevice: String = "watch"
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

    public init(
        timestamp: Date = Date(),
        biometric: BiometricSignal? = nil,
        macOS: MacOSContextSignal? = nil
    ) {
        self.timestamp = timestamp
        self.biometric = biometric
        self.macOS = macOS

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        self.dayOfWeek = calendar.component(.weekday, from: timestamp)
        self.isWeekend = dayOfWeek == 1 || dayOfWeek == 7

        switch hour {
        case 5..<9: self.timeSlot = .earlyMorning
        case 9..<12: self.timeSlot = .morning
        case 12..<14: self.timeSlot = .midday
        case 14..<17: self.timeSlot = .afternoon
        case 17..<21: self.timeSlot = .evening
        default: self.timeSlot = .night
        }
    }
}
