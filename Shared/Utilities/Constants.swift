//
//  Constants.swift
//  Resonance
//
//  App-wide constants and configuration values
//

import Foundation

// MARK: - App Configuration

public enum AppConstants {
    /// App identifier
    public static let appName = "Resonance"
    public static let appIdentifier = "com.y4sh.resonance"

    /// Bundle identifiers
    public enum BundleID {
        public static let iOS = "com.y4sh.resonance.ios"
        public static let watchOS = "com.y4sh.resonance.ios.watchkitapp"
        public static let macOS = "com.y4sh.resonance.macos"
        public static let widgets = "com.y4sh.resonance.ios.widgets"
    }

    /// App Group for shared data
    public static let appGroupIdentifier = "group.com.y4sh.resonance"

    /// Keychain access group
    public static let keychainAccessGroup = "com.y4sh.resonance.keychain"

    /// CloudKit container identifier
    public static let cloudKitContainerIdentifier = "iCloud.com.y4sh.resonance"
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

    /// Tanaka formula intercept for max HR estimation (Tanaka et al., JACC 2001).
    /// Formula: maxHR = 208 - 0.7 * age
    /// Replaces the less accurate traditional 220-age formula which overestimates
    /// maxHR in young adults and underestimates it in older adults (~10 BPM at age 70).
    /// Meta-analysis of 18,712 subjects. See: doi:10.1016/s0735-1097(00)01054-8
    public static let maxHeartRateBase: Double = 208

    /// Tanaka formula age coefficient (0.7 instead of 1.0 from the old 220-age formula).
    public static let maxHeartRateAgeCoefficient: Double = 0.7

    /// Default user age if not available from HealthKit dateOfBirth.
    /// TODO: Read actual age from HKCharacteristicType.dateOfBirth when available.
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
        public static let focus = (min: 70.0, max: 110.0)
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
    /// Biometric update batching interval (seconds).
    /// 10s balances responsiveness with battery life — the flush only sends the
    /// latest packet, so intermediate samples are discarded anyway.
    public static let biometricBatchIntervalSeconds: TimeInterval = 10

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
        public static let playlistSync = "com.y4sh.resonance.playlistSync"
        public static let historicalAnalysis = "com.y4sh.resonance.historicalAnalysis"
        public static let featureUpdate = "com.y4sh.resonance.featureUpdate"
        public static let libraryAnalysis = "com.y4sh.resonance.libraryAnalysis"
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
        public static let small: Double = 50
        public static let medium: Double = 150
        public static let large: Double = 300
        public static let watchCompact: Double = 40
        public static let watchLarge: Double = 80
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

    /// Maximum days of historical data for circadian analysis
    public static let circadianAnalysisMaxDays: Int = 21
}

// MARK: - Circadian Rhythm Constants
// Note: Core CircadianConstants are defined in CircadianProfileTypes.swift.
// Additional integration constants are defined here for cross-module access.

public enum CircadianIntegrationConstants {
    /// Refresh interval for circadian profile during state engine updates (seconds).
    /// Checked every update cycle but only rebuilds if stale (> 24h).
    public static let refreshCheckIntervalSeconds: TimeInterval = 3600

    /// Minimum profile confidence to include circadianProfile in dataSources.
    public static let minimumConfidenceForDataSource: Double = 0.1
}

// MARK: - Backfill Constants

public enum BackfillConstants {
    /// Batch size for processing PlaybackEvents in SongImpactCalculator
    public static let eventBatchSize: Int = 100

    /// Batch size for saving HistoricalSessions in SessionReconstructor
    public static let sessionSaveBatchSize: Int = 50

    /// Learning rate for cold-start songs (first N plays)
    public static let coldStartLearningRate: Double = 0.4

    /// Number of plays before switching from cold-start to steady-state alpha
    public static let coldStartThreshold: Int = 5

    /// Maximum confidence for behavior-only impacts (no biometric data)
    public static let behaviorOnlyMaxConfidence: Double = 0.7

    /// Late skip threshold (listen percentage below which skip is "early")
    public static let earlySkipThreshold: Double = 0.15

    /// Late skip penalty (less severe than early skip)
    public static let lateSkipPenalty: Double = 0.15

    /// Minimum sleep duration in hours to count as substantial (filter naps)
    public static let minimumSubstantialSleepHours: Double = 3.0

    /// Ideal deep sleep percentage (used for normalization)
    public static let idealDeepSleepPercentage: Double = 0.25

    /// Overlap buffer in minutes for incremental session reconstruction
    public static let incrementalOverlapMinutes: Int = 30

    /// Watermark keys for per-step incremental backfill
    public enum WatermarkKey {
        public static let sessionReconstruction = "com.y4sh.resonance.watermark.sessionReconstruction"
        public static let songImpact = "com.y4sh.resonance.watermark.songImpact"
        public static let lastFullBackfill = "com.y4sh.resonance.watermark.lastFullBackfill"
    }
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

// MARK: - Biometric Crossfade Constants

public enum BiometricCrossfadeConstants {
    /// Normalized HR thresholds for zone classification (Karvonen reserve ratio).
    public enum Thresholds {
        /// HR reserve ratio ceiling for resting zone.
        public static let restingCeiling: Double = 0.20
        /// HR reserve ratio ceiling for low-normal zone.
        public static let lowNormalCeiling: Double = 0.40
        /// HR reserve ratio ceiling for normal zone.
        public static let normalCeiling: Double = 0.60
        /// HR reserve ratio ceiling for elevated zone.
        public static let elevatedCeiling: Double = 0.75
        /// HRV-to-baseline ratio below which stress is detected.
        public static let stressHRVRatio: Double = 0.65
        /// HRV-to-baseline ratio for deep stress detection.
        public static let deepStressHRVRatio: Double = 0.50
        /// Minimum HRV quality score to trust stress detection.
        public static let hrvQualityMinimum: Double = 0.7
        /// Minimum sample quality for full biometric-driven crossfade.
        public static let minimumSampleQuality: Double = 0.5
        /// Minimum confidence for applying biometric crossfade in playback.
        public static let minimumConfidence: Double = 0.3
    }

    /// Crossfade durations (seconds) per zone.
    public enum Durations {
        /// Resting HR zone: meditative blend.
        public static let resting: TimeInterval = 7.0
        /// Low-normal HR zone: extended blend.
        public static let lowNormal: TimeInterval = 6.0
        /// Normal HR zone: standard crossfade.
        public static let normal: TimeInterval = 4.5
        /// Elevated HR zone: quick transition.
        public static let elevated: TimeInterval = 2.5
        /// High HR zone: punchy cut.
        public static let high: TimeInterval = 1.5
        /// Stress-detected sonic bridge.
        public static let stressBridge: TimeInterval = 3.0
        /// Deep stress sonic bridge.
        public static let deepStressBridge: TimeInterval = 3.5
        /// Absolute minimum crossfade duration.
        public static let minimum: TimeInterval = 1.0
        /// Absolute maximum crossfade duration.
        public static let maximum: TimeInterval = 8.0
    }
}

// MARK: - Bookmark Constants

public enum BookmarkConstants {
    /// Minimum interval between bookmarks (seconds)
    public static let debounceInterval: TimeInterval = 2.0

    /// Maximum bookmarks allowed per session
    public static let maxPerSession: Int = 50
}

// MARK: - Emotion Detection Constants

public enum EmotionDetectionConstants {
    /// Window duration for motion feature extraction (seconds).
    public static let motionWindowSeconds: TimeInterval = 5.0

    /// Sliding window size for HR/HRV rate-of-change (number of samples).
    public static let rateOfChangeWindowSize: Int = 6

    /// Hysteresis hold time before emotion state can change (seconds).
    public static let emotionHoldSeconds: TimeInterval = 60.0

    /// Number of consecutive classifications required before switching state.
    public static let emotionDebounceCount: Int = 3

    /// Minimum confidence threshold for emotion classification.
    public static let minimumEmotionConfidence: Double = 0.3

    /// Peak detection threshold for gesture frequency (g).
    public static let gesturePeakThreshold: Double = 0.3

    /// Temperature deviation threshold for notable change (Celsius).
    public static let temperatureDeviationThreshold: Double = 0.3

    /// Temperature deviation threshold for significant change (Celsius).
    public static let temperatureSignificantDeviation: Double = 0.5

    /// Number of nights for temperature baseline computation.
    public static let temperatureBaselineNights: Int = 7

    /// Duration for temperature prior decay (seconds, 12 hours).
    public static let temperaturePriorDecaySeconds: TimeInterval = 43200
}

// MARK: - R5: Biometric Signal Confidence Hierarchy
// Research-backed signal reliability weights for multi-signal state estimation.
// Used to weight biometric inputs when computing stress, valence, and arousal.
// Reference: Castaldo et al., Front. Physiol. 2019; Hernando et al., Sensors 2018

public enum BiometricSignalWeights {
    /// HRV (RMSSD/SDNN): Gold standard for stress detection (MAPE 1.15%)
    /// Highest reliability for autonomic nervous system state inference.
    /// Reference: Castaldo et al., Front. Physiol. 2019
    public static let hrv: Double = 0.35

    /// Heart rate: Strong indicator of physiological arousal.
    /// Less specific than HRV but more robust to noise.
    /// Reference: Kreibig, Cognition & Emotion 2010
    public static let heartRate: Double = 0.25

    /// Motion/accelerometry: Good for activity context detection.
    /// Disambiguates exercise-induced HR elevation from stress.
    /// Reference: Gjoreski et al., Sensors 2017
    public static let motion: Double = 0.15

    /// Circadian phase: Corrects diurnal variation in biometric baselines.
    /// Reference: Boudreau et al., PMC 2022
    public static let circadian: Double = 0.10

    /// Sleep quality: Predicts next-day mood and stress susceptibility.
    /// Reference: de Zambotti et al., MDPI Sensors 2023
    public static let sleep: Double = 0.10

    /// Respiratory rate: Most useful during sleep analysis.
    /// Limited value during waking hours on wrist-worn devices.
    /// Reference: Natarajan et al., npj Digital Medicine 2021
    public static let respiratory: Double = 0.03

    /// Skin temperature: Available on Apple Watch Series 8+.
    /// Marginal contribution to acute state estimation.
    /// Reference: Smarr et al., Temperature 2020
    public static let temperature: Double = 0.02
}

// MARK: - Crown Control Constants

public enum CrownConstants {
    /// Sensitivity multiplier for crown rotation
    public static let sensitivityMultiplier: Double = 0.5
    /// Debounce interval before sending adjustment to iPhone (seconds)
    public static let debounceIntervalSeconds: Double = 0.3
    /// How long a crown adjustment influences state (seconds)
    public static let adjustmentDecaySeconds: Double = 300 // 5 minutes
    /// Maximum accumulated crown adjustment
    public static let maxAdjustment: Double = 0.5
}
