//
//  Constants.swift
//  AIDJ
//
//  App-wide constants and configuration values
//

import Foundation

// MARK: - App Configuration

public enum AppConstants {
    /// App identifier
    public static let appName = "AI DJ"
    public static let appIdentifier = "com.aidj"

    /// Bundle identifiers
    public enum BundleID {
        public static let iOS = "com.aidj.ios"
        public static let watchOS = "com.aidj.watchkitapp"
        public static let macOS = "com.aidj.macos"
        public static let widgets = "com.aidj.widgets"
    }

    /// App Group for shared data
    public static let appGroupIdentifier = "group.com.aidj"

    /// Keychain access group
    public static let keychainAccessGroup = "com.aidj.keychain"
}

// MARK: - State Engine Constants

public enum StateEngineConstants {
    /// How often to update the StateVector (in seconds)
    public static let updateIntervalSeconds: TimeInterval = 30

    /// How long to keep biometric samples for averaging (in minutes)
    public static let biometricWindowMinutes: Int = 5

    /// How long HRV samples are considered valid (in minutes)
    public static let hrvWindowMinutes: Int = 10

    /// How long manual mood input remains active (in minutes)
    public static let manualMoodDecayMinutes: Int = 15

    /// Default resting heart rate if not available from HealthKit
    public static let defaultRestingHeartRate: Double = 70

    /// Default maximum heart rate formula: 220 - age
    public static let maxHeartRateBase: Double = 220

    /// Default user age if not available
    public static let defaultUserAge: Int = 35

    /// Minimum confidence threshold for state estimation
    public static let minimumConfidenceThreshold: Double = 0.3
}

// MARK: - Decision Engine Constants

public enum DecisionEngineConstants {
    /// BPM tolerance for matching (songs within this range are considered good matches)
    public static let bpmTolerance: Double = 50

    /// Maximum BPM change for smooth transitions
    public static let maxBPMTransitionDelta: Double = 30

    /// Maximum energy change for smooth transitions
    public static let maxEnergyTransitionDelta: Double = 0.4

    /// Number of samples needed for full confidence in song effects
    public static let fullConfidenceSampleCount: Int = 20

    /// Default score when no historical data available
    public static let defaultHistoricalScore: Double = 0.5

    // MARK: - BPM Ranges by Music Need

    public enum BPMRange {
        public static let energize = (min: 120.0, max: 160.0)
        public static let calm = (min: 60.0, max: 90.0)
        public static let focus = (min: 80.0, max: 110.0)
        public static let maintain = (min: 90.0, max: 130.0)
        public static let transition = (min: 100.0, max: 120.0)
    }

    /// Absolute BPM limits
    public static let absoluteMinBPM: Double = 50
    public static let absoluteMaxBPM: Double = 180
}

// MARK: - Learning Constants

public enum LearningConstants {
    /// Default learning rate (alpha) for exponential moving average
    public static let defaultLearningRate: Double = 0.2

    /// Skip penalty multiplier
    public static let skipPenaltyMultiplier: Double = 0.3

    /// HRV normalization factor (10ms is considered significant)
    public static let hrvNormalizationFactor: Double = 10.0

    /// Heart rate normalization factor
    public static let hrNormalizationFactor: Double = 10.0

    /// Minimum listen percentage to count as a valid play
    public static let minimumListenPercentage: Double = 0.3

    /// Completion bonus threshold (bonus for listening > 50%)
    public static let completionBonusThreshold: Double = 0.5
}

// MARK: - Session Constants

public enum SessionConstants {
    /// Gap in minutes to consider as session boundary
    public static let sessionGapMinutes: Int = 30

    /// Minimum session duration to track (in minutes)
    public static let minimumSessionMinutes: Int = 5

    /// Window for correlating with sleep data (hours after session)
    public static let sleepCorrelationWindowHours: Int = 12
}

// MARK: - WatchConnectivity Constants

public enum WatchConnectivityConstants {
    /// Biometric update batching interval (seconds)
    public static let biometricBatchIntervalSeconds: TimeInterval = 5

    /// Maximum biometric samples per batch
    public static let maxSamplesPerBatch: Int = 20

    /// Complication update throttle (seconds)
    public static let complicationUpdateThrottleSeconds: TimeInterval = 60

    /// Message retry count
    public static let messageRetryCount: Int = 3

    /// Message keys
    public enum MessageKey {
        public static let type = "messageType"
        public static let payload = "payload"
        public static let timestamp = "timestamp"
    }
}

// MARK: - Background Task Constants

public enum BackgroundTaskConstants {
    /// Background task identifiers
    public enum TaskIdentifier {
        public static let playlistSync = "com.aidj.playlistSync"
        public static let historicalAnalysis = "com.aidj.historicalAnalysis"
        public static let featureUpdate = "com.aidj.featureUpdate"
    }

    /// Playlist sync interval (hours)
    public static let playlistSyncIntervalHours: Int = 24

    /// Historical analysis interval (days)
    public static let historicalAnalysisIntervalDays: Int = 7

    /// Feature update interval (hours)
    public static let featureUpdateIntervalHours: Int = 12
}

// MARK: - UI Constants

public enum UIConstants {
    /// Animation durations
    public enum Animation {
        public static let quick: Double = 0.15
        public static let standard: Double = 0.3
        public static let slow: Double = 0.5
    }

    /// Album artwork sizes
    public enum ArtworkSize {
        public static let small: CGFloat = 50
        public static let medium: CGFloat = 150
        public static let large: CGFloat = 300
        public static let watchCompact: CGFloat = 40
        public static let watchLarge: CGFloat = 80
    }

    /// State indicator colors (as hex strings for cross-platform)
    public enum StateColor {
        public static let energy = "#FF6B6B"
        public static let calm = "#4ECDC4"
        public static let focus = "#45B7D1"
        public static let stress = "#FF8C42"
        public static let neutral = "#95A5A6"
    }
}

// MARK: - HealthKit Constants

public enum HealthKitConstants {
    /// Minimum iOS version for HealthKit
    public static let minimumIOSVersion = 15.0

    /// Query limit for historical data
    public static let historicalQueryLimit: Int = 10000

    /// Batch size for processing large datasets
    public static let processingBatchSize: Int = 500
}

// MARK: - MusicKit Constants

public enum MusicKitConstants {
    /// Minimum iOS version for MusicKit
    public static let minimumIOSVersion = 15.0

    /// Maximum playlists to fetch
    public static let maxPlaylistFetch: Int = 100

    /// Maximum songs per playlist to fetch
    public static let maxSongsPerPlaylist: Int = 500

    /// Recently played fetch limit
    public static let recentlyPlayedLimit: Int = 50

    /// Artwork thumbnail compression quality
    public static let artworkCompressionQuality: Double = 0.7
}
