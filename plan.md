# AI DJ - Resonance: Complete Technical Implementation Plan

## Document Purpose
This document serves as the complete technical blueprint for building the AI DJ (Resonance) system. It contains all high-level architecture decisions and low-level implementation details necessary for any engineer or agent to build this project from scratch.

---

# PART 1: PROJECT OVERVIEW

## 1.1 What We Are Building
An intelligent music selection system that:
- Picks songs ONLY from user's existing Apple Music playlists
- Uses Apple Watch biometrics (heart rate, HRV, motion) to understand user state
- Incorporates macOS productivity context (focus mode, active apps)
- Learns from historical listening patterns and their physiological effects
- Explains every song selection decision
- Operates across iOS, watchOS, and macOS

## 1.2 What We Are NOT Building
- A music recommendation engine for new music
- A streaming service
- A social music platform
- Cloud-dependent processing (all on-device)

## 1.3 Core User Value Proposition
"The right song from YOUR music, based on how YOU actually feel right now and what has worked for YOU before."

---

# PART 2: HIGH-LEVEL ARCHITECTURE

## 2.1 System Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           APPLE ECOSYSTEM                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────┐     ┌──────────────────┐     ┌─────────────────┐  │
│  │   APPLE WATCH    │     │     iPHONE       │     │     macOS       │  │
│  │                  │     │                  │     │                 │  │
│  │ ┌──────────────┐ │     │ ┌──────────────┐ │     │ ┌─────────────┐ │  │
│  │ │ SensorLayer  │ │────▶│ │ContextCollect│ │◀────│ │ContextAgent│ │  │
│  │ └──────────────┘ │     │ └──────────────┘ │     │ └─────────────┘ │  │
│  │ ┌──────────────┐ │     │        │         │     │        │        │  │
│  │ │ WatchUI      │ │     │        ▼         │     │        │        │  │
│  │ │ Complications│ │     │ ┌──────────────┐ │     │ ┌─────────────┐ │  │
│  │ │ Crown Control│ │     │ │StateEstimator│ │     │ │ MenuBarApp  │ │  │
│  │ └──────────────┘ │     │ └──────────────┘ │     │ └─────────────┘ │  │
│  │        │         │     │        │         │     │                 │  │
│  │        │         │     │        ▼         │     │                 │  │
│  │        │         │     │ ┌──────────────┐ │     │                 │  │
│  │        │         │     │ │DecisionEngine│ │     │                 │  │
│  │        │         │     │ └──────────────┘ │     │                 │  │
│  │        │         │     │        │         │     │                 │  │
│  │        │         │     │        ▼         │     │                 │  │
│  │        │         │     │ ┌──────────────┐ │     │                 │  │
│  │        ◀─────────┼─────│ │ MusicPlayer  │ │     │                 │  │
│  │  (Now Playing)   │     │ └──────────────┘ │     │                 │  │
│  │                  │     │        │         │     │                 │  │
│  │                  │     │        ▼         │     │                 │  │
│  │                  │     │ ┌──────────────┐ │     │                 │  │
│  │                  │     │ │LearningStore │ │     │                 │  │
│  │                  │     │ └──────────────┘ │     │                 │  │
│  └──────────────────┘     └──────────────────┘     └─────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 2.2 Device Responsibility Matrix

| Component | Apple Watch | iPhone | macOS |
|-----------|-------------|--------|-------|
| Sensor Data Collection | PRIMARY | - | - |
| HealthKit Storage | SECONDARY | PRIMARY | - |
| Context Collection | - | PRIMARY | CONTRIBUTOR |
| State Estimation | - | PRIMARY | - |
| Decision Engine | - | PRIMARY | - |
| Music Playback | REMOTE | PRIMARY | - |
| Learning Store | - | PRIMARY | - |
| User Interface | MINIMAL | FULL | MENU BAR |
| Mood Input | PRIMARY | SECONDARY | - |

## 2.3 Data Flow Sequence

```
1. COLLECT (Continuous)
   Watch Sensors → WatchConnectivity → iPhone Context Collector
   macOS Agent → Network/IPC → iPhone Context Collector

2. ESTIMATE (Every 30 seconds)
   Context Collector → State Estimator → StateVector

3. DECIDE (On Song End / User Request)
   StateVector + Playlist Songs + History → Decision Engine → Ranked Songs

4. PLAY
   Top Ranked Song → MusicKit Player → Audio Output

5. LEARN (Post-Playback)
   Playback Events + Biometric Response → Learning Store → Updated Metrics
```

---

# PART 3: PROJECT STRUCTURE

## 3.1 Repository Directory Layout

```
resonance/
├── product.md                    # Product specification (READ ONLY)
├── plan.md                       # This file
├── progress.md                   # Progress tracking
├── project.yml                   # XcodeGen configuration
│
├── Shared/                       # Shared code across all platforms
│   ├── Models/                   # Data models
│   │   ├── StateVector.swift
│   │   ├── SongFeatures.swift
│   │   ├── PlaylistMetadata.swift
│   │   ├── HistoricalSession.swift
│   │   ├── SongEffect.swift
│   │   ├── ContextSignal.swift
│   │   └── UserPreferences.swift
│   │
│   ├── Persistence/              # CoreData / SQLite
│   │   ├── PersistenceController.swift
│   │   ├── Resonance.xcdatamodeld/
│   │   ├── Migrations/
│   │   └── Repositories/
│   │       ├── SongRepository.swift
│   │       ├── PlaylistRepository.swift
│   │       ├── SessionRepository.swift
│   │       └── EffectRepository.swift
│   │
│   ├── Services/                 # Business logic services
│   │   ├── MusicKitService.swift
│   │   ├── HealthKitService.swift
│   │   └── SyncService.swift
│   │
│   └── Utilities/                # Helper functions
│       ├── Constants.swift
│       ├── Extensions/
│       └── Logging.swift
│
├── Brain/                        # Core Intelligence (iPhone)
│   ├── Historical/               # Historical analysis engine
│   │   ├── HistoricalEngine.swift
│   │   ├── SessionReconstructor.swift
│   │   ├── PlaylistImpactCalculator.swift
│   │   └── SongImpactCalculator.swift
│   │
│   ├── State/                    # Real-time state estimation
│   │   ├── StateEngine.swift
│   │   ├── BiometricProcessor.swift
│   │   ├── ContextProcessor.swift
│   │   └── StateVectorBuilder.swift
│   │
│   ├── Ranking/                  # Song selection logic
│   │   ├── DecisionEngine.swift
│   │   ├── SongScorer.swift
│   │   ├── TransitionController.swift
│   │   ├── GuardFilters.swift
│   │   └── ExplanationGenerator.swift
│   │
│   ├── Features/                 # Song feature extraction
│   │   ├── FeatureExtractor.swift
│   │   ├── AudioAnalyzer.swift
│   │   └── FeatureNormalizer.swift
│   │
│   └── Learning/                 # Continuous learning
│       ├── LearningStore.swift
│       ├── SkipPenaltyCalculator.swift
│       ├── ResponseCreditCalculator.swift
│       └── SessionQualityScorer.swift
│
├── iOS/                          # iPhone App
│   ├── ResonanceApp.swift        # App entry point
│   ├── Info.plist
│   ├── Entitlements/
│   │   └── Resonance.entitlements
│   │
│   ├── Views/                    # SwiftUI Views
│   │   ├── MainView.swift
│   │   ├── NowPlayingView.swift
│   │   ├── PlaylistBrowserView.swift
│   │   ├── StateDebugView.swift
│   │   ├── ExplanationView.swift
│   │   ├── SettingsView.swift
│   │   └── Components/
│   │       ├── MoodSlider.swift
│   │       ├── StateIndicator.swift
│   │       ├── SongCard.swift
│   │       └── PlaylistCard.swift
│   │
│   ├── ViewModels/               # MVVM ViewModels
│   │   ├── NowPlayingViewModel.swift
│   │   ├── PlaylistViewModel.swift
│   │   └── SettingsViewModel.swift
│   │
│   ├── Coordinators/             # Navigation
│   │   └── AppCoordinator.swift
│   │
│   └── Services/                 # iOS-specific services
│       ├── WatchConnectivityManager.swift
│       ├── BackgroundTaskManager.swift
│       ├── NotificationManager.swift
│       └── WidgetDataProvider.swift
│
├── Watch/                        # watchOS App
│   ├── ResonanceWatchApp.swift   # App entry point
│   ├── Info.plist
│   ├── Entitlements/
│   │
│   ├── Views/
│   │   ├── WatchNowPlayingView.swift
│   │   ├── MoodInputView.swift
│   │   └── CompactControlView.swift
│   │
│   ├── Complications/
│   │   ├── ComplicationController.swift
│   │   └── ComplicationViews.swift
│   │
│   ├── Sensors/
│   │   ├── HeartRateSensor.swift
│   │   ├── HRVSensor.swift
│   │   ├── MotionSensor.swift
│   │   └── WorkoutDetector.swift
│   │
│   └── Services/
│       ├── PhoneConnectivityService.swift
│       ├── CrownHandler.swift
│       └── HapticFeedbackManager.swift
│
├── macOS/                        # macOS Menu Bar App
│   ├── ResonanceMacApp.swift     # App entry point
│   ├── Info.plist
│   ├── Entitlements/
│   │
│   ├── MenuBar/
│   │   ├── MenuBarController.swift
│   │   ├── StatusItemView.swift
│   │   └── PopoverView.swift
│   │
│   ├── ContextProviders/
│   │   ├── FocusModeProvider.swift
│   │   ├── ActiveAppProvider.swift
│   │   ├── ScreenTimeProvider.swift
│   │   └── CalendarProvider.swift
│   │
│   └── Services/
│       ├── iPhoneConnector.swift
│       └── ContextBroadcaster.swift
│
├── Widgets/                      # iOS/watchOS Widgets
│   ├── NowPlayingWidget.swift
│   ├── StateWidget.swift
│   └── WidgetBundle.swift
│
└── Tests/                        # Unit & Integration Tests
    ├── BrainTests/
    │   ├── StateEngineTests.swift
    │   ├── DecisionEngineTests.swift
    │   └── LearningStoreTests.swift
    │
    ├── ServiceTests/
    │   ├── MusicKitServiceTests.swift
    │   └── HealthKitServiceTests.swift
    │
    └── IntegrationTests/
        └── EndToEndTests.swift
```

---

# PART 4: DATA MODELS (LOW-LEVEL SPECIFICATION)

## 4.1 Core Data Schema

### 4.1.1 Entity: Song

```swift
// CoreData Entity: Song
// Table Name: songs

@objc(Song)
public class Song: NSManagedObject {
    // MARK: - Identifiers
    @NSManaged public var id: UUID                    // Primary key, auto-generated
    @NSManaged public var appleMusicId: String        // Apple Music catalog ID
    @NSManaged public var persistentId: String        // Local library persistent ID

    // MARK: - Metadata (from MusicKit)
    @NSManaged public var title: String
    @NSManaged public var artistName: String
    @NSManaged public var albumName: String
    @NSManaged public var durationSeconds: Double
    @NSManaged public var artworkURL: String?
    @NSManaged public var genreNames: [String]        // Transformable
    @NSManaged public var releaseDate: Date?

    // MARK: - Audio Features (Computed/Extracted)
    @NSManaged public var bpm: Double                 // Beats per minute (0 if unknown)
    @NSManaged public var energyEstimate: Double      // 0.0 - 1.0
    @NSManaged public var acousticDensity: Double     // 0.0 - 1.0 (how "full" the sound is)
    @NSManaged public var valence: Double             // 0.0 - 1.0 (musical positivity)
    @NSManaged public var instrumentalness: Double    // 0.0 - 1.0

    // MARK: - Derived Metrics (from Learning)
    @NSManaged public var calmScore: Double           // Historical calming effect
    @NSManaged public var focusScore: Double          // Historical focus effect
    @NSManaged public var activationScore: Double     // Historical activation effect
    @NSManaged public var familiarityScore: Double    // How often played (normalized)
    @NSManaged public var confidenceLevel: Double     // Confidence in derived scores

    // MARK: - Statistics
    @NSManaged public var totalPlayCount: Int64
    @NSManaged public var totalSkipCount: Int64
    @NSManaged public var lastPlayedAt: Date?
    @NSManaged public var addedToLibraryAt: Date?

    // MARK: - Relationships
    @NSManaged public var playlists: Set<Playlist>    // Many-to-many
    @NSManaged public var playbackEvents: Set<PlaybackEvent>
    @NSManaged public var effects: Set<SongEffect>
}
```

### 4.1.2 Entity: Playlist

```swift
// CoreData Entity: Playlist
// Table Name: playlists

@objc(Playlist)
public class Playlist: NSManagedObject {
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var appleMusicId: String
    @NSManaged public var persistentId: String

    // MARK: - Metadata
    @NSManaged public var name: String
    @NSManaged public var descriptionText: String?
    @NSManaged public var artworkURL: String?
    @NSManaged public var isUserCreated: Bool         // vs. Apple-curated
    @NSManaged public var songCount: Int64

    // MARK: - Derived Metrics
    @NSManaged public var avgCalmEffect: Double       // Average calming effect
    @NSManaged public var avgFocusEffect: Double
    @NSManaged public var avgEnergyEffect: Double
    @NSManaged public var avgBPM: Double
    @NSManaged public var effectConfidence: Double

    // MARK: - Context Associations (JSON stored as Data)
    @NSManaged public var contextAssociations: Data?  // ["workout": 0.8, "sleep": 0.1]

    // MARK: - Timestamps
    @NSManaged public var lastSyncedAt: Date?
    @NSManaged public var lastPlayedAt: Date?
    @NSManaged public var createdAt: Date?

    // MARK: - Relationships
    @NSManaged public var songs: Set<Song>            // Many-to-many (ordered)
    @NSManaged public var sessions: Set<HistoricalSession>
}
```

### 4.1.3 Entity: HistoricalSession

```swift
// CoreData Entity: HistoricalSession
// Table Name: historical_sessions
// Purpose: Captures a listening session for historical analysis

@objc(HistoricalSession)
public class HistoricalSession: NSManagedObject {
    // MARK: - Identifiers
    @NSManaged public var id: UUID

    // MARK: - Session Boundaries
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date
    @NSManaged public var durationMinutes: Double

    // MARK: - Context at Session Start
    @NSManaged public var contextType: String         // "workout", "commute", "work", "relaxation"
    @NSManaged public var locationContext: String?    // "home", "office", "gym", "transit"
    @NSManaged public var timeOfDaySlot: String       // "morning", "afternoon", "evening", "night"
    @NSManaged public var dayOfWeek: Int16            // 1-7 (Sunday = 1)

    // MARK: - Biometric Summary
    @NSManaged public var startingHeartRate: Double
    @NSManaged public var endingHeartRate: Double
    @NSManaged public var avgHeartRate: Double
    @NSManaged public var minHeartRate: Double
    @NSManaged public var maxHeartRate: Double
    @NSManaged public var deltaHeartRate: Double      // end - start

    @NSManaged public var startingHRV: Double         // SDNN in ms
    @NSManaged public var endingHRV: Double
    @NSManaged public var avgHRV: Double
    @NSManaged public var deltaHRV: Double

    @NSManaged public var totalSteps: Int64
    @NSManaged public var motionIntensity: Double     // 0.0 - 1.0

    // MARK: - Workout Info (if applicable)
    @NSManaged public var isWorkoutSession: Bool
    @NSManaged public var workoutType: String?        // "running", "cycling", "strength"
    @NSManaged public var workoutCalories: Double

    // MARK: - Sleep Correlation (next night)
    @NSManaged public var nextNightSleepScore: Double?    // 0.0 - 1.0
    @NSManaged public var nextNightSleepDuration: Double? // hours
    @NSManaged public var nextNightDeepSleepPct: Double?

    // MARK: - Session Quality Metrics
    @NSManaged public var totalSongsPlayed: Int64
    @NSManaged public var totalSkips: Int64
    @NSManaged public var skipRate: Double            // skips / total
    @NSManaged public var avgListenPercentage: Double // How much of each song was heard

    // MARK: - Computed Impact Score
    @NSManaged public var overallImpactScore: Double  // Composite metric

    // MARK: - Relationships
    @NSManaged public var playlist: Playlist?
    @NSManaged public var playbackEvents: Set<PlaybackEvent>
}
```

### 4.1.4 Entity: PlaybackEvent

```swift
// CoreData Entity: PlaybackEvent
// Table Name: playback_events
// Purpose: Individual song play within a session

@objc(PlaybackEvent)
public class PlaybackEvent: NSManagedObject {
    // MARK: - Identifiers
    @NSManaged public var id: UUID

    // MARK: - Timing
    @NSManaged public var startedAt: Date
    @NSManaged public var endedAt: Date?
    @NSManaged public var durationListened: Double    // Actual seconds listened
    @NSManaged public var songDuration: Double        // Total song duration
    @NSManaged public var listenPercentage: Double    // durationListened / songDuration

    // MARK: - Playback Outcome
    @NSManaged public var wasSkipped: Bool
    @NSManaged public var skipReason: String?         // "manual", "timeout", "system"
    @NSManaged public var wasRepeated: Bool           // User hit repeat
    @NSManaged public var volumeAtStart: Double       // 0.0 - 1.0
    @NSManaged public var volumeAtEnd: Double
    @NSManaged public var volumeAdjustments: Int16    // Count of volume changes

    // MARK: - Biometric Snapshot During Playback
    @NSManaged public var hrAtStart: Double
    @NSManaged public var hrAtEnd: Double
    @NSManaged public var hrDelta: Double
    @NSManaged public var hrvAtStart: Double
    @NSManaged public var hrvAtEnd: Double
    @NSManaged public var hrvDelta: Double

    // MARK: - Selection Context
    @NSManaged public var wasAISelected: Bool         // vs manual selection
    @NSManaged public var selectionScore: Double?     // Score when AI selected
    @NSManaged public var selectionReason: String?    // Explanation text

    // MARK: - Relationships
    @NSManaged public var song: Song
    @NSManaged public var session: HistoricalSession?
}
```

### 4.1.5 Entity: SongEffect

```swift
// CoreData Entity: SongEffect
// Table Name: song_effects
// Purpose: Aggregated effect metrics per song per context

@objc(SongEffect)
public class SongEffect: NSManagedObject {
    // MARK: - Identifiers
    @NSManaged public var id: UUID

    // MARK: - Context Scope
    @NSManaged public var contextType: String         // "any", "workout", "focus", "relax"
    @NSManaged public var timeOfDaySlot: String       // "any", "morning", "evening", etc.

    // MARK: - Effect Metrics (0.0 - 1.0)
    @NSManaged public var calmScore: Double
    @NSManaged public var focusScore: Double
    @NSManaged public var energyScore: Double
    @NSManaged public var moodLiftScore: Double

    // MARK: - Confidence
    @NSManaged public var sampleCount: Int64          // Number of plays used
    @NSManaged public var confidenceLevel: Double     // Statistical confidence

    // MARK: - Timestamps
    @NSManaged public var lastUpdatedAt: Date
    @NSManaged public var firstRecordedAt: Date

    // MARK: - Relationships
    @NSManaged public var song: Song
}
```

### 4.1.6 Entity: BiometricSample

```swift
// CoreData Entity: BiometricSample
// Table Name: biometric_samples
// Purpose: Raw biometric data points (high frequency)

@objc(BiometricSample)
public class BiometricSample: NSManagedObject {
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date

    // MARK: - Heart Data
    @NSManaged public var heartRate: Double?          // BPM
    @NSManaged public var heartRateVariability: Double? // SDNN ms

    // MARK: - Motion Data
    @NSManaged public var stepCount: Int64?
    @NSManaged public var isStationary: Bool
    @NSManaged public var activityType: String?       // "walking", "running", "stationary"

    // MARK: - Source
    @NSManaged public var sourceDevice: String        // "watch", "phone"
    @NSManaged public var sampleQuality: Double       // 0.0 - 1.0 confidence

    // MARK: - Context Reference
    @NSManaged public var activePlaybackEventId: UUID?
}
```

### 4.1.7 Entity: MacOSContext

```swift
// CoreData Entity: MacOSContext
// Table Name: macos_context
// Purpose: Context signals from macOS

@objc(MacOSContext)
public class MacOSContext: NSManagedObject {
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date

    // MARK: - Focus Mode
    @NSManaged public var focusModeActive: Bool
    @NSManaged public var focusModeName: String?      // "Do Not Disturb", "Work", etc.

    // MARK: - Active Application
    @NSManaged public var activeAppBundleId: String?
    @NSManaged public var activeAppName: String?
    @NSManaged public var activeAppCategory: String?  // "productivity", "creative", "browser"

    // MARK: - Screen Time (last hour)
    @NSManaged public var productivityMinutes: Double
    @NSManaged public var entertainmentMinutes: Double
    @NSManaged public var socialMinutes: Double

    // MARK: - Calendar
    @NSManaged public var hasOngoingMeeting: Bool
    @NSManaged public var minutesUntilNextEvent: Double?
    @NSManaged public var nextEventType: String?      // "meeting", "focus", "personal"

    // MARK: - Derived Context
    @NSManaged public var inferredWorkState: String   // "deep_work", "meetings", "casual", "idle"
}
```

## 4.2 Swift Data Structures (In-Memory)

### 4.2.1 StateVector

```swift
/// Real-time state estimation of user's current condition
/// Updated every 30 seconds by StateEngine
public struct StateVector: Codable, Equatable {
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

    // MARK: - Types

    public enum ActivityContext: String, Codable, CaseIterable {
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
    }

    public enum MusicNeed: String, Codable, CaseIterable {
        case energize       // Need activation, motivation
        case calm           // Need to reduce stress, relax
        case focus          // Need concentration support
        case maintain       // Current state is good, maintain it
        case transition     // Transitioning between states
    }

    public enum DataSource: String, Codable {
        case heartRate
        case hrv
        case motion
        case macOSContext
        case calendarContext
        case timeOfDay
        case manualMoodInput
        case historicalPattern
    }

    // MARK: - Factory

    public static var empty: StateVector {
        StateVector(
            arousal: 0.5,
            energy: 0.5,
            focus: 0.5,
            stress: 0.5,
            valence: 0.5,
            context: .unknown,
            inferredNeed: .maintain,
            timestamp: Date(),
            confidence: 0.0,
            dataSources: []
        )
    }
}
```

### 4.2.2 SongScore

```swift
/// Ranking result for a song candidate
public struct SongScore: Identifiable, Comparable {
    public let id: UUID
    public let song: Song

    // MARK: - Component Scores (0.0 - 1.0)

    /// How well BPM matches desired energy level
    public let bpmMatchScore: Double

    /// How well song energy matches needed energy
    public let energyMatchScore: Double

    /// Familiarity bonus (known songs reduce cognitive load)
    public let familiarityScore: Double

    /// Historical effectiveness for current context
    public let historicalEffectScore: Double

    /// Alignment with current context (workout, focus, etc.)
    public let contextAlignmentScore: Double

    /// Recency penalty (avoid recently played)
    public let recencyPenalty: Double

    /// Time-of-day appropriateness
    public let timeOfDayScore: Double

    // MARK: - Final Score

    /// Weighted combination of all factors
    public let finalScore: Double

    /// Confidence in this score
    public let confidence: Double

    // MARK: - Explanation

    /// Human-readable explanation of why this song was selected
    public let explanationComponents: [ExplanationComponent]

    public struct ExplanationComponent {
        public let factor: String
        public let contribution: Double
        public let description: String
    }

    // MARK: - Comparable

    public static func < (lhs: SongScore, rhs: SongScore) -> Bool {
        lhs.finalScore < rhs.finalScore
    }
}
```

### 4.2.3 DecisionContext

```swift
/// All context needed to make a song selection decision
public struct DecisionContext {
    /// Current state of the user
    public let stateVector: StateVector

    /// Active playlist to select from
    public let activePlaylist: Playlist

    /// Songs in the playlist with their features
    public let candidateSongs: [Song]

    /// Recently played songs (for recency filtering)
    public let recentlyPlayed: [UUID: Date]  // songId -> lastPlayedAt

    /// Current time for time-of-day rules
    public let currentTime: Date

    /// Session history for transition logic
    public let currentSessionSongs: [Song]

    /// User preferences
    public let preferences: UserPreferences

    /// Whether this is the first song of a session
    public let isSessionStart: Bool
}
```

### 4.2.4 UserPreferences

```swift
/// User-configurable preferences
public struct UserPreferences: Codable {
    // MARK: - Ranking Weights (sum to 1.0)
    public var bpmWeight: Double = 0.15
    public var energyWeight: Double = 0.20
    public var familiarityWeight: Double = 0.15
    public var historicalWeight: Double = 0.25
    public var contextWeight: Double = 0.25

    // MARK: - Behavioral Preferences
    public var avoidRecentMinutes: Int = 60      // Don't repeat within this window
    public var maxSameArtistInRow: Int = 2       // Variety control
    public var preferFamiliarInStress: Bool = true

    // MARK: - Time of Day Rules
    public var morningMaxBPM: Double = 120
    public var nightMaxBPM: Double = 100
    public var nightStartHour: Int = 21          // 9 PM
    public var morningEndHour: Int = 9           // 9 AM

    // MARK: - Learning Sensitivity
    public var skipPenaltyWeight: Double = 0.5
    public var hrvResponseWeight: Double = 0.3

    // MARK: - Privacy
    public var shareAnalytics: Bool = false
    public var backupToiCloud: Bool = true
}
```

---

# PART 5: ALGORITHM SPECIFICATIONS

## 5.1 State Estimation Algorithm

### 5.1.1 Input Processing

```
FUNCTION processHeartRateData(samples: [HeartRateSample]) -> ArousalEstimate:

    // Get recent samples (last 5 minutes)
    recentSamples = samples.filter(age < 5 minutes)

    IF recentSamples.isEmpty:
        RETURN ArousalEstimate(value: 0.5, confidence: 0.0)

    // Calculate metrics
    currentHR = recentSamples.last.value
    avgHR = mean(recentSamples.values)
    restingHR = getUserRestingHR()  // From HealthKit or learned
    maxHR = calculateMaxHR(age)     // 220 - age approximation

    // Normalize to 0-1 scale
    hrReserve = maxHR - restingHR
    normalizedHR = (currentHR - restingHR) / hrReserve
    arousal = clamp(normalizedHR, 0.0, 1.0)

    // Calculate trend
    IF recentSamples.count >= 3:
        trend = linearRegressionSlope(recentSamples)
        // Positive trend = increasing arousal
        arousal = arousal + (trend * 0.1)  // Small trend adjustment

    // Confidence based on sample quality and count
    confidence = min(1.0, recentSamples.count / 10.0) * avgSampleQuality

    RETURN ArousalEstimate(value: arousal, confidence: confidence)
```

### 5.1.2 HRV to Stress Mapping

```
FUNCTION processHRVData(samples: [HRVSample]) -> StressEstimate:

    recentSamples = samples.filter(age < 10 minutes)

    IF recentSamples.isEmpty:
        RETURN StressEstimate(value: 0.5, confidence: 0.0)

    // HRV is inversely correlated with stress
    // Higher HRV = lower stress, more relaxed
    currentHRV = recentSamples.last.value  // SDNN in ms
    baselineHRV = getUserBaselineHRV()     // Personal baseline

    // Normalize: ratio to baseline
    // If current is 80% of baseline, stress is higher
    // If current is 120% of baseline, stress is lower
    ratio = currentHRV / baselineHRV

    // Map ratio to stress (inverse)
    // ratio 0.5 (low HRV) -> stress 0.8
    // ratio 1.0 (baseline) -> stress 0.4
    // ratio 1.5 (high HRV) -> stress 0.1
    stress = clamp(1.0 - (ratio * 0.6), 0.0, 1.0)

    // Adjust for recent trend
    IF recentSamples.count >= 3:
        trend = linearRegressionSlope(recentSamples)
        // Positive HRV trend = decreasing stress
        stress = stress - (trend * 0.05)

    confidence = min(1.0, recentSamples.count / 5.0)

    RETURN StressEstimate(value: stress, confidence: confidence)
```

### 5.1.3 Context Inference

```
FUNCTION inferActivityContext(
    motionData: MotionData,
    macOSContext: MacOSContext?,
    calendarContext: CalendarContext?,
    timeOfDay: TimeOfDay,
    workoutState: WorkoutState?
) -> ActivityContext:

    // Priority 1: Explicit workout detection
    IF workoutState?.isActive:
        RETURN .workout

    IF workoutState?.recentlyEnded (within 15 min):
        RETURN .postWorkout

    // Priority 2: macOS signals
    IF macOSContext != nil:
        IF macOSContext.hasOngoingMeeting:
            RETURN .work

        IF macOSContext.focusModeActive AND focusModeName contains "work":
            RETURN .deepWork

        IF macOSContext.inferredWorkState == "deep_work":
            RETURN .deepWork

    // Priority 3: Motion-based
    IF motionData.isInVehicle:
        RETURN .commute

    // Priority 4: Time-based defaults
    IF timeOfDay.hour < 7:
        RETURN .preSleep OR .morning based on motion

    IF timeOfDay.hour >= 22:
        RETURN .preSleep

    IF timeOfDay.hour >= 6 AND timeOfDay.hour < 10:
        IF motionData.isStationary:
            RETURN .morning

    // Priority 5: Fallback
    IF motionData.isStationary AND lowActivityLast30Min:
        RETURN .relaxation

    RETURN .unknown
```

### 5.1.4 StateVector Synthesis

```
FUNCTION synthesizeStateVector(
    arousal: ArousalEstimate,
    stress: StressEstimate,
    context: ActivityContext,
    manualMood: MoodInput?,
    historicalPatterns: PatternData
) -> StateVector:

    // Start with biometric-derived values
    state = StateVector()
    state.arousal = arousal.value
    state.stress = stress.value

    // Energy estimation (combination of arousal and inverse stress)
    state.energy = (arousal.value * 0.6) + ((1.0 - stress.value) * 0.4)

    // Focus estimation
    // High in deep work context, lower when stressed or high arousal
    IF context == .deepWork:
        state.focus = 0.8 - (stress.value * 0.3)
    ELSE IF context == .workout:
        state.focus = 0.3  // Focus on physical, not mental
    ELSE:
        state.focus = 0.5 - (stress.value * 0.2) + (0.1 if low arousal)

    // Valence (mood positivity)
    // Default to neutral, adjust based on stress
    state.valence = 0.5 - (stress.value * 0.3)

    // Override with manual input if available
    IF manualMood != nil AND manualMood.age < 15 minutes:
        state.valence = blend(state.valence, manualMood.valence, weight: 0.7)
        state.energy = blend(state.energy, manualMood.energy, weight: 0.5)

    // Apply historical pattern adjustments
    // e.g., "User is typically energetic at this time"
    patternAdjustment = historicalPatterns.getAdjustment(
        dayOfWeek: currentDayOfWeek,
        hourOfDay: currentHour
    )
    state.energy = blend(state.energy, patternAdjustment.energy, weight: 0.2)

    // Infer music need
    state.inferredNeed = inferMusicNeed(state, context)

    // Calculate overall confidence
    state.confidence = (arousal.confidence + stress.confidence) / 2.0

    state.context = context
    state.timestamp = Date()
    state.dataSources = collectDataSources()

    RETURN state
```

### 5.1.5 Music Need Inference

```
FUNCTION inferMusicNeed(state: StateVector, context: ActivityContext) -> MusicNeed:

    // Context-driven needs
    IF context == .workout:
        IF state.energy < 0.5:
            RETURN .energize
        ELSE:
            RETURN .maintain

    IF context == .postWorkout:
        RETURN .calm

    IF context == .preSleep:
        RETURN .calm

    IF context == .deepWork:
        RETURN .focus

    // State-driven needs
    IF state.stress > 0.7:
        RETURN .calm  // High stress -> need calming

    IF state.energy < 0.3 AND state.arousal < 0.4:
        RETURN .energize  // Low energy and calm -> need boost

    IF state.focus > 0.6 AND context == .work:
        RETURN .focus  // Already focused, support it

    // Check for state transitions
    IF significantStateChange(lastState, state):
        RETURN .transition

    RETURN .maintain
```

## 5.2 Song Ranking Algorithm

### 5.2.1 Score Calculation

```
FUNCTION calculateSongScore(
    song: Song,
    state: StateVector,
    context: DecisionContext
) -> SongScore:

    weights = context.preferences

    // Component 1: BPM Match
    targetBPM = calculateTargetBPM(state)
    bpmDelta = abs(song.bpm - targetBPM)
    bpmMatchScore = max(0, 1.0 - (bpmDelta / 50.0))  // 50 BPM tolerance

    // Component 2: Energy Match
    targetEnergy = calculateTargetEnergy(state)
    energyDelta = abs(song.energyEstimate - targetEnergy)
    energyMatchScore = 1.0 - energyDelta

    // Component 3: Familiarity
    // Higher familiarity preferred when stressed or for focus
    familiarityBoost = 1.0
    IF state.stress > 0.6 AND context.preferences.preferFamiliarInStress:
        familiarityBoost = 1.3
    IF state.inferredNeed == .focus:
        familiarityBoost = 1.2
    familiarityScore = song.familiarityScore * familiarityBoost

    // Component 4: Historical Effect
    effect = getEffectForContext(song, state.context)
    historicalEffectScore = SWITCH state.inferredNeed:
        .calm    -> effect.calmScore
        .focus   -> effect.focusScore
        .energize -> effect.energyScore
        .maintain -> (effect.calmScore + effect.energyScore) / 2
        DEFAULT  -> 0.5

    // Apply confidence weighting
    historicalEffectScore = blend(0.5, historicalEffectScore, weight: effect.confidence)

    // Component 5: Context Alignment
    contextAlignmentScore = calculateContextAlignment(song, state.context)

    // Component 6: Recency Penalty
    lastPlayed = context.recentlyPlayed[song.id]
    IF lastPlayed != nil:
        minutesSince = minutesBetween(lastPlayed, now)
        IF minutesSince < context.preferences.avoidRecentMinutes:
            recencyPenalty = 1.0 - (minutesSince / avoidRecentMinutes)
        ELSE:
            recencyPenalty = 0.0
    ELSE:
        recencyPenalty = 0.0

    // Component 7: Time of Day
    timeOfDayScore = calculateTimeOfDayScore(song, context.currentTime)

    // Final weighted score
    finalScore =
        (bpmMatchScore * weights.bpmWeight) +
        (energyMatchScore * weights.energyWeight) +
        (familiarityScore * weights.familiarityWeight) +
        (historicalEffectScore * weights.historicalWeight) +
        (contextAlignmentScore * weights.contextWeight) -
        (recencyPenalty * 0.5)  // Recency always applies

    // Time of day as multiplier
    finalScore = finalScore * (0.5 + timeOfDayScore * 0.5)

    // Generate explanation
    explanations = generateExplanations(
        bpmMatchScore, energyMatchScore, familiarityScore,
        historicalEffectScore, contextAlignmentScore, state
    )

    RETURN SongScore(
        song: song,
        bpmMatchScore: bpmMatchScore,
        energyMatchScore: energyMatchScore,
        familiarityScore: familiarityScore,
        historicalEffectScore: historicalEffectScore,
        contextAlignmentScore: contextAlignmentScore,
        recencyPenalty: recencyPenalty,
        timeOfDayScore: timeOfDayScore,
        finalScore: finalScore,
        confidence: calculateConfidence(song, state),
        explanationComponents: explanations
    )
```

### 5.2.2 Target BPM Calculation

```
FUNCTION calculateTargetBPM(state: StateVector) -> Double:

    // Base BPM ranges by need
    bpmRange = SWITCH state.inferredNeed:
        .energize  -> (120, 160)
        .calm      -> (60, 90)
        .focus     -> (80, 110)
        .maintain  -> (90, 130)
        .transition -> (100, 120)

    // Interpolate within range based on energy level
    (minBPM, maxBPM) = bpmRange
    targetBPM = minBPM + (state.energy * (maxBPM - minBPM))

    // Adjust for arousal
    // If already high arousal but need to calm, target lower BPM
    IF state.inferredNeed == .calm AND state.arousal > 0.6:
        targetBPM = targetBPM - 10

    // Time of day caps
    hour = currentHour()
    IF hour >= 21 OR hour < 6:
        targetBPM = min(targetBPM, 100)  // Night cap

    RETURN clamp(targetBPM, 50, 180)
```

### 5.2.3 Transition Control

```
FUNCTION selectWithTransition(
    candidates: [SongScore],
    sessionHistory: [Song],
    transitionRules: TransitionRules
) -> Song:

    IF sessionHistory.isEmpty:
        // First song - pick highest score
        RETURN candidates.max(by: score).song

    lastSong = sessionHistory.last

    // Calculate transition scores
    transitionScores = candidates.map { candidate in
        transitionScore = calculateTransitionScore(lastSong, candidate.song)
        adjustedScore = candidate.finalScore * (0.7 + transitionScore * 0.3)
        RETURN (candidate, adjustedScore)
    }

    RETURN transitionScores.max(by: adjustedScore).candidate.song

FUNCTION calculateTransitionScore(from: Song, to: Song) -> Double:

    // BPM transition smoothness
    bpmDelta = abs(from.bpm - to.bpm)
    bpmSmoothness = max(0, 1.0 - (bpmDelta / 30.0))  // Prefer < 30 BPM jump

    // Energy transition smoothness
    energyDelta = abs(from.energyEstimate - to.energyEstimate)
    energySmoothness = max(0, 1.0 - (energyDelta / 0.4))  // Prefer < 0.4 jump

    // Genre compatibility (if available)
    genreBonus = IF sharesGenre(from, to) THEN 0.1 ELSE 0.0

    RETURN (bpmSmoothness * 0.4) + (energySmoothness * 0.4) + genreBonus
```

## 5.3 Learning Algorithm

### 5.3.1 Playback Event Processing

```
FUNCTION processPlaybackEvent(event: PlaybackEvent):

    song = event.song

    // Calculate immediate impact
    impact = calculateImmediateImpact(event)

    // Update song effect scores
    updateSongEffect(song, event, impact)

    // Update playlist metrics if in a session
    IF event.session != nil:
        updatePlaylistMetrics(event.session.playlist, event)

    // Update familiarity
    song.totalPlayCount += 1
    IF event.wasSkipped:
        song.totalSkipCount += 1
    updateFamiliarityScore(song)

FUNCTION calculateImmediateImpact(event: PlaybackEvent) -> ImpactScore:

    // HRV response (primary indicator)
    // Positive HRV delta during song = calming effect
    hrvImpact = event.hrvDelta / 10.0  // Normalize (10ms is significant)

    // HR response
    // For calming: negative HR delta is good
    // For energizing: positive HR delta is good
    hrImpact = event.hrDelta / 10.0  // Normalize

    // Skip penalty
    skipPenalty = IF event.wasSkipped THEN -0.3 ELSE 0.0

    // Listen completion bonus
    completionBonus = (event.listenPercentage - 0.5) * 0.2  // Bonus for >50%

    // Calculate directional impacts
    calmImpact = (hrvImpact * 0.5) + (-hrImpact * 0.3) + completionBonus + skipPenalty
    energyImpact = (hrImpact * 0.3) + completionBonus + skipPenalty

    RETURN ImpactScore(
        calm: clamp(0.5 + calmImpact, 0, 1),
        energy: clamp(0.5 + energyImpact, 0, 1),
        focus: 0.5 + completionBonus,  // Completion suggests focus
        skip: event.wasSkipped
    )
```

### 5.3.2 Effect Score Update

```
FUNCTION updateSongEffect(song: Song, event: PlaybackEvent, impact: ImpactScore):

    // Get or create effect for current context
    context = event.session?.contextType ?? "any"
    effect = getSongEffect(song, context) ?? createNewEffect(song, context)

    // Exponential moving average update
    // Weight recent observations more
    alpha = 0.2  // Learning rate

    effect.calmScore = (1 - alpha) * effect.calmScore + alpha * impact.calm
    effect.energyScore = (1 - alpha) * effect.energyScore + alpha * impact.energy
    effect.focusScore = (1 - alpha) * effect.focusScore + alpha * impact.focus

    // Update confidence
    effect.sampleCount += 1
    effect.confidenceLevel = min(1.0, effect.sampleCount / 20.0)  // Max at 20 samples

    effect.lastUpdatedAt = Date()

    save(effect)
```

### 5.3.3 Session Quality Scoring

```
FUNCTION scoreSession(session: HistoricalSession) -> Double:

    // Component 1: Skip rate (lower is better)
    skipScore = 1.0 - session.skipRate

    // Component 2: Biometric response
    // Positive HRV change is good
    hrvScore = clamp(0.5 + (session.deltaHRV / 20.0), 0, 1)

    // Component 3: Listen engagement
    engagementScore = session.avgListenPercentage

    // Component 4: Sleep correlation (if available)
    sleepScore = session.nextNightSleepScore ?? 0.5

    // Weighted combination
    qualityScore =
        (skipScore * 0.25) +
        (hrvScore * 0.30) +
        (engagementScore * 0.25) +
        (sleepScore * 0.20)

    RETURN qualityScore
```

## 5.4 Historical Backfill Algorithm

### 5.4.1 Session Reconstruction

```
FUNCTION reconstructHistoricalSessions(
    playHistory: [PlayHistoryItem],
    healthData: [HealthDataPoint]
) -> [HistoricalSession]:

    sessions = []
    currentSession = nil

    FOR item IN playHistory.sorted(by: timestamp):

        IF currentSession == nil:
            // Start new session
            currentSession = createSession(startTime: item.timestamp)
        ELSE IF item.timestamp - currentSession.lastEventTime > 30 minutes:
            // Gap too large, end current session and start new
            finalizeSession(currentSession, healthData)
            sessions.append(currentSession)
            currentSession = createSession(startTime: item.timestamp)

        // Add item to current session
        currentSession.addPlaybackEvent(item)
        currentSession.lastEventTime = item.endTime

    // Finalize last session
    IF currentSession != nil:
        finalizeSession(currentSession, healthData)
        sessions.append(currentSession)

    RETURN sessions

FUNCTION finalizeSession(session: HistoricalSession, healthData: [HealthDataPoint]):

    // Extract biometric data for session window
    sessionHealthData = healthData.filter(
        timestamp >= session.startTime - 5.minutes AND
        timestamp <= session.endTime + 5.minutes
    )

    // Calculate biometric summaries
    hrSamples = sessionHealthData.filter(type == .heartRate)
    session.startingHeartRate = hrSamples.first(within: 5.min of start)?.value ?? 0
    session.endingHeartRate = hrSamples.last(within: 5.min of end)?.value ?? 0
    session.avgHeartRate = mean(hrSamples.values)
    session.deltaHeartRate = session.endingHeartRate - session.startingHeartRate

    // Similar for HRV
    hrvSamples = sessionHealthData.filter(type == .hrv)
    session.startingHRV = hrvSamples.first(within: 5.min of start)?.value ?? 0
    session.endingHRV = hrvSamples.last(within: 5.min of end)?.value ?? 0
    session.avgHRV = mean(hrvSamples.values)
    session.deltaHRV = session.endingHRV - session.startingHRV

    // Correlate with next night's sleep
    nextNightSleep = findNextNightSleep(session.endTime, healthData)
    IF nextNightSleep != nil:
        session.nextNightSleepScore = calculateSleepScore(nextNightSleep)
        session.nextNightSleepDuration = nextNightSleep.duration

    // Infer context
    session.contextType = inferContextFromTime(session.startTime)
    session.timeOfDaySlot = getTimeSlot(session.startTime)

    // Calculate impact score
    session.overallImpactScore = scoreSession(session)
```

---

# PART 6: API SPECIFICATIONS

## 6.1 MusicKit Integration

### 6.1.1 Required Entitlements

```xml
<!-- iOS Entitlements -->
<key>com.apple.developer.musickit</key>
<true/>

<!-- Capabilities in Xcode -->
- MusicKit
- Background Modes: Audio
```

### 6.1.2 MusicKitService Interface

```swift
protocol MusicKitServiceProtocol {
    // Authorization
    func requestAuthorization() async throws -> MusicAuthorization.Status
    var authorizationStatus: MusicAuthorization.Status { get }

    // Library Access
    func fetchUserPlaylists() async throws -> [Playlist]
    func fetchPlaylistSongs(playlistId: String) async throws -> [Song]
    func fetchRecentlyPlayed(limit: Int) async throws -> [PlayHistoryItem]

    // Playback Control
    func play(song: Song) async throws
    func pause() async
    func skip() async
    func setQueue(songs: [Song]) async throws

    // Playback State
    var nowPlaying: Song? { get }
    var playbackState: MusicPlayer.PlaybackStatus { get }
    var currentPlaybackTime: TimeInterval { get }

    // Publishers
    var nowPlayingPublisher: AnyPublisher<Song?, Never> { get }
    var playbackStatePublisher: AnyPublisher<MusicPlayer.PlaybackStatus, Never> { get }
}
```

### 6.1.3 Implementation Notes

```swift
// Key MusicKit classes to use:
// - MusicAuthorization: For permission requests
// - MusicLibrary: For accessing user's library
// - MusicPlayer: For playback control (ApplicationMusicPlayer)
// - MusicCatalogResourceRequest: For fetching metadata

// IMPORTANT: MusicKit requires iOS 15.0+ / macOS 12.0+ / watchOS 8.0+

// Example: Fetching playlists
func fetchUserPlaylists() async throws -> [Playlist] {
    var request = MusicLibraryRequest<MusicKit.Playlist>()
    request.sort(by: \.lastPlayedDate, ascending: false)

    let response = try await request.response()

    return response.items.map { musicKitPlaylist in
        Playlist(
            appleMusicId: musicKitPlaylist.id.rawValue,
            name: musicKitPlaylist.name,
            // ... map other properties
        )
    }
}

// Example: Playing a song
func play(song: Song) async throws {
    let player = ApplicationMusicPlayer.shared

    // Create queue with single song
    let musicItem = try await MusicCatalogResourceRequest<MusicKit.Song>(
        matching: \.id,
        equalTo: MusicItemID(song.appleMusicId)
    ).response().items.first

    guard let musicItem else { throw MusicKitError.songNotFound }

    player.queue = [musicItem]
    try await player.play()
}
```

## 6.2 HealthKit Integration

### 6.2.1 Required Permissions

```swift
// HealthKit data types to request
let readTypes: Set<HKObjectType> = [
    HKObjectType.quantityType(forIdentifier: .heartRate)!,
    HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
    HKObjectType.quantityType(forIdentifier: .stepCount)!,
    HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
    HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
    HKObjectType.workoutType()
]

// No write permissions needed - we only read
let writeTypes: Set<HKSampleType> = []
```

### 6.2.2 HealthKitService Interface

```swift
protocol HealthKitServiceProtocol {
    // Authorization
    func requestAuthorization() async throws
    var isAuthorized: Bool { get }

    // Real-time Queries (for current state)
    func fetchLatestHeartRate() async throws -> Double?
    func fetchLatestHRV() async throws -> Double?
    func fetchRecentHeartRates(minutes: Int) async throws -> [HeartRateSample]
    func fetchRecentHRV(minutes: Int) async throws -> [HRVSample]

    // Historical Queries (for backfill)
    func fetchHeartRateHistory(from: Date, to: Date) async throws -> [HeartRateSample]
    func fetchHRVHistory(from: Date, to: Date) async throws -> [HRVSample]
    func fetchSleepAnalysis(from: Date, to: Date) async throws -> [SleepSession]
    func fetchWorkouts(from: Date, to: Date) async throws -> [WorkoutSession]

    // Background Delivery
    func enableBackgroundDelivery(for types: [HKSampleType]) async throws

    // Workout Detection
    var isInWorkout: Bool { get }
    var activeWorkoutType: HKWorkoutActivityType? { get }
    var workoutStatePublisher: AnyPublisher<WorkoutState, Never> { get }

    // User Metrics
    func fetchRestingHeartRate() async throws -> Double?
    func fetchUserAge() async throws -> Int?
}
```

### 6.2.3 Implementation Notes

```swift
// Key HealthKit patterns:

// 1. HKAnchoredObjectQuery for continuous updates
func observeHeartRate() -> AsyncStream<HeartRateSample> {
    AsyncStream { continuation in
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { query, samples, deletedObjects, anchor, error in
            // Handle initial batch
        }

        query.updateHandler = { query, samples, deleted, anchor, error in
            // Handle continuous updates
            samples?.compactMap { $0 as? HKQuantitySample }
                .forEach { sample in
                    let hr = sample.quantity.doubleValue(for: .beatsPerMinute())
                    continuation.yield(HeartRateSample(value: hr, timestamp: sample.startDate))
                }
        }

        healthStore.execute(query)
    }
}

// 2. HKStatisticsCollectionQuery for aggregated historical data
func fetchDailyHRVAverages(months: Int) async throws -> [DailyHRVAverage] {
    // Use statistics collection for efficient aggregation
}

// 3. Background delivery for real-time updates
func enableBackgroundDelivery() {
    healthStore.enableBackgroundDelivery(
        for: heartRateType,
        frequency: .immediate
    ) { success, error in
        // Handle result
    }
}
```

## 6.3 WatchConnectivity Integration

### 6.3.1 Message Protocol

```swift
// Message types between Watch and iPhone

enum WatchMessage: Codable {
    // Watch -> Phone
    case biometricUpdate(BiometricPacket)
    case moodInput(MoodPacket)
    case playbackCommand(PlaybackCommand)
    case crownAdjustment(CrownAdjustment)

    // Phone -> Watch
    case nowPlayingUpdate(NowPlayingPacket)
    case stateUpdate(StatePacket)
    case complicationUpdate(ComplicationData)
}

struct BiometricPacket: Codable {
    let heartRate: Double?
    let hrv: Double?
    let isStationary: Bool
    let isInWorkout: Bool
    let workoutType: String?
    let timestamp: Date
}

struct MoodPacket: Codable {
    let moodLevel: Int        // 1-5 scale
    let energyLevel: Int      // 1-5 scale
    let timestamp: Date
}

struct PlaybackCommand: Codable {
    enum Command: String, Codable {
        case play, pause, skip, previous
    }
    let command: Command
}

struct CrownAdjustment: Codable {
    let delta: Double         // -1.0 to 1.0
    let adjustmentType: String // "intensity", "energy"
}

struct NowPlayingPacket: Codable {
    let songTitle: String
    let artistName: String
    let artworkData: Data?    // Compressed thumbnail
    let isPlaying: Bool
    let progress: Double      // 0.0 - 1.0
    let explanation: String?  // Why this song was chosen
}
```

### 6.3.2 WatchConnectivityManager Interface

```swift
protocol WatchConnectivityManagerProtocol {
    // Setup
    func activate()
    var isReachable: Bool { get }
    var isPaired: Bool { get }

    // Sending (Phone -> Watch)
    func sendNowPlaying(_ packet: NowPlayingPacket)
    func sendStateUpdate(_ packet: StatePacket)
    func updateComplication(_ data: ComplicationData)

    // Receiving (Watch -> Phone)
    var biometricUpdates: AnyPublisher<BiometricPacket, Never> { get }
    var moodInputs: AnyPublisher<MoodPacket, Never> { get }
    var playbackCommands: AnyPublisher<PlaybackCommand, Never> { get }
    var crownAdjustments: AnyPublisher<CrownAdjustment, Never> { get }

    // Application Context (persistent)
    func updateApplicationContext(_ context: [String: Any]) throws
    var receivedApplicationContext: [String: Any] { get }

    // User Info Transfer (queued)
    func transferUserInfo(_ userInfo: [String: Any])
}
```

### 6.3.3 Implementation Notes

```swift
// WCSession patterns:

// 1. Use sendMessage for real-time when reachable
if WCSession.default.isReachable {
    WCSession.default.sendMessage(message, replyHandler: nil)
}

// 2. Use updateApplicationContext for persistent state
// This survives app restarts and is the primary sync mechanism
try WCSession.default.updateApplicationContext([
    "nowPlaying": nowPlayingPacket.encoded,
    "lastState": statePacket.encoded
])

// 3. Use transferUserInfo for queued, guaranteed delivery
// Good for biometric batches that must not be lost
WCSession.default.transferUserInfo([
    "biometricBatch": samples.encoded
])

// 4. Complications require transferCurrentComplicationUserInfo
WCSession.default.transferCurrentComplicationUserInfo([
    "currentSong": songTitle,
    "stateEmoji": stateEmoji
])
```

## 6.4 macOS Context Provider

### 6.4.1 Context Data Sources

```swift
// macOS APIs for context collection

// 1. Focus Mode (Notification Center)
// Uses private APIs or observes system preferences

// 2. Active Application
// NSWorkspace.shared.frontmostApplication

// 3. Screen Time (not directly accessible)
// Infer from app usage patterns

// 4. Calendar
// EventKit framework
```

### 6.4.2 iPhoneConnector Interface (macOS side)

```swift
protocol iPhoneConnectorProtocol {
    // Connection
    func connect() async throws
    var isConnected: Bool { get }

    // Sending context updates
    func sendContextUpdate(_ context: MacOSContext) async throws

    // Communication method options:
    // 1. Local network (Bonjour/MultipeerConnectivity)
    // 2. Shared CloudKit container
    // 3. Shared App Group (if using Catalyst)
}
```

### 6.4.3 Implementation Options

```
Option A: MultipeerConnectivity
- Pros: Real-time, no network needed
- Cons: Complex, requires nearby devices

Option B: CloudKit
- Pros: Works anywhere, Apple infrastructure
- Cons: Latency, requires network

Option C: Local Network Bonjour
- Pros: Fast, works on same network
- Cons: Network required, firewall issues

RECOMMENDATION: Start with CloudKit for simplicity,
optimize to MultipeerConnectivity if latency is an issue.
```

---

# PART 7: USER INTERFACE SPECIFICATIONS

## 7.1 iOS App Views

### 7.1.1 MainView (Tab-based Navigation)

```
┌─────────────────────────────────────────┐
│ [Status Bar]                            │
├─────────────────────────────────────────┤
│                                         │
│          [Now Playing View]             │
│               OR                        │
│          [Playlist Browser]             │
│               OR                        │
│          [Insights View]                │
│               OR                        │
│          [Settings View]                │
│                                         │
├─────────────────────────────────────────┤
│ [🎵 Now] [📋 Playlists] [📊 Insights] [⚙️]│
└─────────────────────────────────────────┘
```

### 7.1.2 NowPlayingView

```
┌─────────────────────────────────────────┐
│ AI DJ                          [Debug] ↗│
├─────────────────────────────────────────┤
│                                         │
│        ┌───────────────────────┐        │
│        │                       │        │
│        │    [Album Artwork]    │        │
│        │       300x300         │        │
│        │                       │        │
│        └───────────────────────┘        │
│                                         │
│          Song Title                     │
│          Artist Name                    │
│                                         │
│  ────────────●─────────────────  2:34   │
│  0:00                           4:12    │
│                                         │
│     [⏮️]    [⏸️/▶️]    [⏭️]              │
│                                         │
├─────────────────────────────────────────┤
│ Why this song?                          │
│ ┌─────────────────────────────────────┐ │
│ │ "Your heart rate is elevated.       │ │
│ │  This track has helped you calm     │ │
│ │  down in similar situations before."│ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Current State:                          │
│ [🔴 Energy: 72%] [💚 Calm: 45%]         │
│ [🧠 Focus: 60%]  [💗 HR: 85]            │
│                                         │
├─────────────────────────────────────────┤
│ Active Playlist: Chill Vibes ▼          │
│ [Change Playlist]                       │
└─────────────────────────────────────────┘
```

### 7.1.3 PlaylistBrowserView

```
┌─────────────────────────────────────────┐
│ Your Playlists              [Refresh] ↻ │
├─────────────────────────────────────────┤
│ [🔍 Search playlists...]                │
├─────────────────────────────────────────┤
│                                         │
│ Recently Played                         │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │ Art  │ │ Art  │ │ Art  │   →          │
│ │ work │ │ work │ │ work │              │
│ └──────┘ └──────┘ └──────┘              │
│ Chill    Workout  Focus                 │
│ Vibes    Mix      Flow                  │
│                                         │
│ Best for Current State                  │
│ ┌───────────────────────────────────┐   │
│ │ [Art] Calm Evening                │   │
│ │       12 songs • 87% match        │ → │
│ └───────────────────────────────────┘   │
│ ┌───────────────────────────────────┐   │
│ │ [Art] Stress Relief               │   │
│ │       8 songs • 82% match         │ → │
│ └───────────────────────────────────┘   │
│                                         │
│ All Playlists                           │
│ ┌───────────────────────────────────┐   │
│ │ [Art] Morning Energy              │   │
│ │       24 songs                    │ → │
│ └───────────────────────────────────┘   │
│ ┌───────────────────────────────────┐   │
│ │ [Art] Late Night                  │   │
│ │       15 songs                    │ → │
│ └───────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

### 7.1.4 MoodSlider Component

```
┌─────────────────────────────────────────┐
│ How are you feeling?                    │
│                                         │
│ Energy                                  │
│ 😴 ──────────●────────── 🔥            │
│ Low                           High      │
│                                         │
│ Mood                                    │
│ 😔 ────────────●──────── 😊            │
│ Down                          Great     │
│                                         │
│ [Apply]                [Auto-detect]    │
└─────────────────────────────────────────┘
```

## 7.2 watchOS App Views

### 7.2.1 WatchNowPlayingView

```
┌─────────────────────┐
│ AI DJ               │
├─────────────────────┤
│    [Album Art]      │
│      80x80          │
│                     │
│   Song Title...     │
│   Artist Name       │
│                     │
│  ──────●──────      │
│                     │
│  [⏮️] [⏸️] [⏭️]     │
│                     │
│ "Calming you down"  │
└─────────────────────┘
```

### 7.2.2 MoodInputView (3-Tap Design)

```
Screen 1: Energy
┌─────────────────────┐
│ Energy Level?       │
│                     │
│   [😴]   [😐]   [🔥] │
│   Low   Med   High  │
│                     │
└─────────────────────┘

Screen 2: Mood
┌─────────────────────┐
│ Current Mood?       │
│                     │
│   [😔]   [😐]   [😊] │
│  Down  Okay  Great  │
│                     │
└─────────────────────┘

Screen 3: Confirm
┌─────────────────────┐
│ Got it!             │
│                     │
│ Energy: Medium      │
│ Mood: Great         │
│                     │
│ [✓ Confirm]         │
└─────────────────────┘
```

### 7.2.3 Complication Views

```
Circular Small:
┌─────┐
│ 🎵  │
│ 85♡ │  <- Current song + HR
└─────┘

Modular Large:
┌───────────────────┐
│ 🎵 Song Title     │
│    Artist Name    │
│ ♡85  Energy: High │
└───────────────────┘

Corner:
┌───┐
│🎵 │
└───┘
```

### 7.2.4 Crown Interaction

```
Crown Rotation Behavior:

Default Mode: Volume Control
- Standard system behavior

DJ Mode (when Now Playing active):
- Crown UP: Increase energy target
  - System selects higher BPM songs
  - Visual feedback: Energy meter rises

- Crown DOWN: Decrease energy target
  - System selects calmer songs
  - Visual feedback: Energy meter falls

Activation:
- Double-tap crown to toggle DJ Mode
- Haptic feedback confirms mode change
```

## 7.3 macOS Menu Bar App

### 7.3.1 Menu Bar Icon States

```
Normal: 🎵 (musical note)
Playing: 🎵▶ (note with play indicator)
Syncing: 🎵↻ (note with sync)
Disconnected: 🎵✕ (note with X)
```

### 7.3.2 Popover View

```
┌─────────────────────────────────┐
│ AI DJ                    [Gear]│
├─────────────────────────────────┤
│                                 │
│ [Album Art]  Song Title         │
│   50x50      Artist Name        │
│              ───●─────── 2:34   │
│                                 │
├─────────────────────────────────┤
│ Context Sending:                │
│ ✓ Focus Mode: Work              │
│ ✓ Active App: Xcode             │
│ ✓ Deep Work Detected            │
│                                 │
├─────────────────────────────────┤
│ iPhone: Connected ✓             │
│ Last sync: Just now             │
│                                 │
│ [Open iPhone App]               │
│ [Quit]                          │
└─────────────────────────────────┘
```

---

# PART 8: BACKGROUND PROCESSING

## 8.1 iOS Background Tasks

### 8.1.1 Required Background Modes

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>           <!-- Music playback -->
    <string>fetch</string>           <!-- Periodic data fetch -->
    <string>processing</string>      <!-- Background processing -->
    <string>remote-notification</string>
</array>
```

### 8.1.2 Background Task Registration

```swift
// In AppDelegate or App init

func registerBackgroundTasks() {
    // 1. Playlist Sync Task (daily)
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.aidj.playlistSync",
        using: nil
    ) { task in
        self.handlePlaylistSync(task: task as! BGAppRefreshTask)
    }

    // 2. Historical Analysis Task (weekly)
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.aidj.historicalAnalysis",
        using: nil
    ) { task in
        self.handleHistoricalAnalysis(task: task as! BGProcessingTask)
    }

    // 3. Song Feature Update Task (as needed)
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.aidj.featureUpdate",
        using: nil
    ) { task in
        self.handleFeatureUpdate(task: task as! BGProcessingTask)
    }
}

// Scheduling
func schedulePlaylistSync() {
    let request = BGAppRefreshTaskRequest(identifier: "com.aidj.playlistSync")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours

    try? BGTaskScheduler.shared.submit(request)
}

func scheduleHistoricalAnalysis() {
    let request = BGProcessingTaskRequest(identifier: "com.aidj.historicalAnalysis")
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = true  // Only when charging
    request.earliestBeginDate = Date(timeIntervalSinceNow: 7 * 24 * 60 * 60) // Weekly

    try? BGTaskScheduler.shared.submit(request)
}
```

### 8.1.3 HealthKit Background Delivery

```swift
// Enable background delivery for heart rate updates

func setupHealthKitBackgroundDelivery() {
    let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!

    healthStore.enableBackgroundDelivery(
        for: heartRateType,
        frequency: .immediate
    ) { success, error in
        if success {
            print("Background delivery enabled for heart rate")
        }
    }

    // Set up observer query
    let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) {
        query, completionHandler, error in

        // New heart rate data available
        self.fetchLatestHeartRate()
        completionHandler()
    }

    healthStore.execute(query)
}
```

## 8.2 watchOS Background Considerations

### 8.2.1 Workout Session (Extended Runtime)

```swift
// During workouts, watch app can run continuously

class WorkoutManager: NSObject, HKWorkoutSessionDelegate {
    var workoutSession: HKWorkoutSession?

    func startWorkoutMonitoring() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other  // Generic activity
        configuration.locationType = .unknown

        do {
            workoutSession = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
            workoutSession?.delegate = self
            workoutSession?.startActivity(with: Date())
        } catch {
            print("Failed to start workout session: \(error)")
        }
    }
}
```

### 8.2.2 Background App Refresh

```swift
// Schedule background refresh for watch
WKApplication.shared().scheduleBackgroundRefresh(
    withPreferredDate: Date(timeIntervalSinceNow: 15 * 60),
    userInfo: nil
) { error in
    if let error = error {
        print("Failed to schedule refresh: \(error)")
    }
}
```

## 8.3 Complication Updates

```swift
// Update complications with current state

class ComplicationController: NSObject, CLKComplicationDataSource {

    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        let template = createTemplate(for: complication.family)
        let entry = CLKComplicationTimelineEntry(
            date: Date(),
            complicationTemplate: template
        )
        handler(entry)
    }

    func createTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        switch family {
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallStackImage(
                line1ImageProvider: CLKImageProvider(onePieceImage: musicNoteImage),
                line2TextProvider: CLKSimpleTextProvider(text: "\(currentHR)♡")
            )
        // ... other families
        default:
            fatalError("Unsupported complication family")
        }
    }

    // Called when new data available
    func reloadComplications() {
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }
    }
}
```

---

# PART 9: TESTING STRATEGY

## 9.1 Unit Tests

### 9.1.1 State Engine Tests

```swift
class StateEngineTests: XCTestCase {
    var sut: StateEngine!

    override func setUp() {
        sut = StateEngine()
    }

    // Test heart rate to arousal mapping
    func test_heartRateToArousal_atResting_returnsLowArousal() {
        let restingHR = 60.0
        let result = sut.calculateArousal(heartRate: restingHR, restingHR: 60, maxHR: 180)
        XCTAssertEqual(result, 0.0, accuracy: 0.1)
    }

    func test_heartRateToArousal_atMax_returnsHighArousal() {
        let maxHR = 180.0
        let result = sut.calculateArousal(heartRate: maxHR, restingHR: 60, maxHR: 180)
        XCTAssertEqual(result, 1.0, accuracy: 0.1)
    }

    // Test HRV to stress mapping
    func test_hrvToStress_highHRV_returnsLowStress() {
        let highHRV = 80.0  // ms
        let baselineHRV = 50.0
        let result = sut.calculateStress(hrv: highHRV, baselineHRV: baselineHRV)
        XCTAssertLessThan(result, 0.3)
    }

    // Test context inference
    func test_inferContext_duringWorkout_returnsWorkout() {
        let context = sut.inferContext(
            isInWorkout: true,
            workoutType: .running,
            timeOfDay: .afternoon,
            macOSContext: nil
        )
        XCTAssertEqual(context, .workout)
    }

    func test_inferContext_deepFocusModeActive_returnsDeepWork() {
        let macOSContext = MacOSContext(
            focusModeActive: true,
            focusModeName: "Work",
            inferredWorkState: "deep_work"
        )
        let context = sut.inferContext(
            isInWorkout: false,
            workoutType: nil,
            timeOfDay: .afternoon,
            macOSContext: macOSContext
        )
        XCTAssertEqual(context, .deepWork)
    }
}
```

### 9.1.2 Decision Engine Tests

```swift
class DecisionEngineTests: XCTestCase {
    var sut: DecisionEngine!
    var mockSongs: [Song]!

    override func setUp() {
        sut = DecisionEngine()
        mockSongs = createMockSongs()
    }

    func test_selectSong_highStress_prefersLowBPM() {
        let state = StateVector(
            arousal: 0.7,
            energy: 0.5,
            focus: 0.3,
            stress: 0.8,  // High stress
            valence: 0.4,
            context: .work,
            inferredNeed: .calm,
            timestamp: Date(),
            confidence: 0.8,
            dataSources: [.heartRate, .hrv]
        )

        let context = DecisionContext(
            stateVector: state,
            candidateSongs: mockSongs,
            // ...
        )

        let result = sut.selectSong(context: context)
        XCTAssertLessThan(result.song.bpm, 100)  // Should pick calm song
    }

    func test_selectSong_recentlyPlayed_avoidsRepeat() {
        let recentlyPlayed = [mockSongs[0].id: Date()]  // Just played

        let context = DecisionContext(
            // ...
            recentlyPlayed: recentlyPlayed,
            // ...
        )

        let result = sut.selectSong(context: context)
        XCTAssertNotEqual(result.song.id, mockSongs[0].id)
    }

    func test_transitionScore_smoothBPMTransition_scoresHigher() {
        let fromSong = Song(bpm: 100)
        let toSong1 = Song(bpm: 110)  // Small jump
        let toSong2 = Song(bpm: 160)  // Large jump

        let score1 = sut.calculateTransitionScore(from: fromSong, to: toSong1)
        let score2 = sut.calculateTransitionScore(from: fromSong, to: toSong2)

        XCTAssertGreaterThan(score1, score2)
    }
}
```

### 9.1.3 Learning Store Tests

```swift
class LearningStoreTests: XCTestCase {
    var sut: LearningStore!
    var persistenceController: PersistenceController!

    override func setUp() {
        persistenceController = PersistenceController(inMemory: true)
        sut = LearningStore(context: persistenceController.viewContext)
    }

    func test_processPlayback_skipped_decreasesCalmScore() {
        let song = createMockSong(initialCalmScore: 0.7)
        let event = PlaybackEvent(
            song: song,
            wasSkipped: true,
            listenPercentage: 0.2,
            hrvDelta: -5
        )

        let initialScore = song.calmScore
        sut.processPlaybackEvent(event)

        XCTAssertLessThan(song.calmScore, initialScore)
    }

    func test_processPlayback_fullListen_positiveHRV_increasesCalmScore() {
        let song = createMockSong(initialCalmScore: 0.5)
        let event = PlaybackEvent(
            song: song,
            wasSkipped: false,
            listenPercentage: 0.95,
            hrvDelta: 10  // Positive = calming
        )

        let initialScore = song.calmScore
        sut.processPlaybackEvent(event)

        XCTAssertGreaterThan(song.calmScore, initialScore)
    }
}
```

## 9.2 Integration Tests

### 9.2.1 End-to-End Song Selection

```swift
class EndToEndTests: XCTestCase {

    func test_fullSelectionPipeline_withMockData() async throws {
        // Setup
        let mockHealthKit = MockHealthKitService()
        let mockMusicKit = MockMusicKitService()
        let brain = AIDJBrain(
            healthKit: mockHealthKit,
            musicKit: mockMusicKit
        )

        // Simulate user state
        mockHealthKit.setHeartRate(95)
        mockHealthKit.setHRV(35)  // Low HRV = stressed

        // Set available playlist
        let playlist = createMockPlaylist(songs: 20)
        mockMusicKit.setActivePlaylist(playlist)

        // Run selection
        let selectedSong = try await brain.selectNextSong()

        // Verify selection makes sense for stressed user
        XCTAssertLessThan(selectedSong.bpm, 100)  // Calming
        XCTAssertGreaterThan(selectedSong.calmScore, 0.5)
    }
}
```

## 9.3 Mock Objects

### 9.3.1 MockHealthKitService

```swift
class MockHealthKitService: HealthKitServiceProtocol {
    private var heartRate: Double = 72
    private var hrv: Double = 50
    private var isInWorkout: Bool = false

    func setHeartRate(_ hr: Double) { heartRate = hr }
    func setHRV(_ value: Double) { hrv = value }
    func setWorkoutState(_ active: Bool) { isInWorkout = active }

    func fetchLatestHeartRate() async throws -> Double? { heartRate }
    func fetchLatestHRV() async throws -> Double? { hrv }
    var isInWorkout: Bool { _isInWorkout }

    // ... implement other protocol methods with mock data
}
```

---

# PART 10: SECURITY & PRIVACY

## 10.1 Data Protection

### 10.1.1 Encryption at Rest

```swift
// CoreData encryption using Data Protection

// In PersistenceController setup:
let storeDescription = NSPersistentStoreDescription(url: storeURL)
storeDescription.setOption(
    FileProtectionType.complete as NSObject,
    forKey: NSPersistentStoreFileProtectionKey
)

// This ensures database is encrypted when device is locked
```

### 10.1.2 Keychain for Sensitive Data

```swift
// Store sensitive preferences in Keychain

struct KeychainService {
    static func saveUserToken(_ token: String) throws {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "userMusicKitToken",
            kSecAttrService as String: "com.aidj.tokens",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }
}
```

## 10.2 Privacy Considerations

### 10.2.1 No Cloud Sync of Health Data

```swift
// Health data NEVER leaves device
// Only sync:
// - Playlist metadata
// - Song effect scores (no biometric data)
// - User preferences

struct SyncPayload: Codable {
    // OK to sync
    let playlistIds: [String]
    let songEffectScores: [String: Double]  // songId -> score only
    let userPreferences: UserPreferences

    // NEVER sync
    // - Raw heart rate values
    // - HRV values
    // - Location data
    // - Session biometric details
}
```

### 10.2.2 Privacy Policy Requirements

```
Required disclosures:
1. HealthKit data collection (heart rate, HRV, workouts, sleep)
2. Purpose: Music selection personalization
3. Storage: On-device only
4. Sharing: None (no cloud upload of health data)
5. Retention: Until user deletes app
6. User control: Can delete all data in Settings
```

---

# PART 11: BUILD CONFIGURATION

## 11.1 Xcode Project Setup

### 11.1.1 Target Configuration

```
Targets:
1. Resonance (iOS App)
   - iOS 16.0+
   - Architectures: arm64
   - Bundle ID: com.y4sh.resonance.ios

2. ResonanceWatch (watchOS App)
   - watchOS 9.0+
   - Bundle ID: com.y4sh.resonance.watchkitapp

3. ResonanceMac (macOS App)
   - macOS 13.0+
   - Bundle ID: com.y4sh.resonance.macos

4. ResonanceTests (Unit Tests)
5. ResonanceUITests (UI Tests)
6. ResonanceWidgets (Widget Extension)
```

### 11.1.2 App Groups

```
App Group ID: group.com.y4sh.resonance

Shared between:
- iOS App
- Watch App
- Widgets
- (macOS if using Catalyst, otherwise use CloudKit)
```

### 11.1.3 Entitlements

```xml
<!-- iOS Entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <!-- HealthKit -->
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array>
        <string>health-records</string>
    </array>

    <!-- MusicKit -->
    <key>com.apple.developer.musickit</key>
    <true/>

    <!-- App Groups -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.aidj</string>
    </array>

    <!-- Background Modes -->
    <key>com.apple.developer.associated-domains</key>
    <array/>
</dict>
</plist>
```

## 11.2 Dependencies

### 11.2.1 Swift Package Dependencies

```swift
// Package.swift or via Xcode SPM

dependencies: [
    // None required - using Apple frameworks only
    // Optional for development/testing:
    // .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
]
```

### 11.2.2 Framework Dependencies

```
Required Apple Frameworks:
- SwiftUI
- MusicKit
- HealthKit
- CoreData
- WatchConnectivity
- BackgroundTasks
- WidgetKit
- ClockKit (watchOS)
- AppKit (macOS)
- EventKit (calendar access)
```

---

# PART 12: DEPLOYMENT CHECKLIST

## 12.1 App Store Requirements

### 12.1.1 Required Assets

```
iOS App:
- App Icon: 1024x1024 (App Store), various sizes for device
- Screenshots: 6.7", 6.5", 5.5" (iPhone), 12.9", 11" (iPad)
- Privacy Policy URL
- Support URL

Watch App:
- Complication icons
- App icon for Watch

macOS App:
- App icon: 512x512@2x
- Screenshots for App Store
```

### 12.1.2 Info.plist Keys

```xml
<!-- Required Usage Descriptions -->
<key>NSHealthShareUsageDescription</key>
<string>AI DJ uses your heart rate and HRV to select music that matches your current state.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>AI DJ does not write health data.</string>

<key>NSAppleMusicUsageDescription</key>
<string>AI DJ needs access to your Apple Music library to play and select songs from your playlists.</string>

<key>NSCalendarsUsageDescription</key>
<string>AI DJ uses your calendar to provide context-aware music selection.</string>
```

## 12.2 TestFlight Preparation

```
1. Create App Store Connect record
2. Configure:
   - App Information
   - Pricing and Availability
   - App Privacy questionnaire
3. Upload build
4. Configure TestFlight:
   - Internal testers
   - External testers (requires review)
   - Beta App Description
```

---

# APPENDIX A: GLOSSARY

| Term | Definition |
|------|------------|
| HRV | Heart Rate Variability - variation in time between heartbeats, indicates stress/recovery |
| SDNN | Standard Deviation of NN intervals - primary HRV metric |
| BPM | Beats Per Minute - tempo of music |
| StateVector | Real-time estimation of user's physiological and emotional state |
| Decision Engine | Component that ranks and selects songs |
| Learning Store | Component that stores and updates effectiveness metrics |
| Effect Score | Measured impact of a song on user's state |
| Transition Controller | Logic ensuring smooth song-to-song transitions |

---

# APPENDIX B: REFERENCE IMPLEMENTATIONS

## B.1 StateVector Calculation Example

```swift
// Complete example of calculating StateVector from raw inputs

func calculateStateVector(
    heartRateSamples: [HeartRateSample],
    hrvSamples: [HRVSample],
    macOSContext: MacOSContext?,
    manualMood: MoodInput?,
    workoutState: WorkoutState?
) -> StateVector {

    // 1. Calculate arousal from heart rate
    let recentHR = heartRateSamples.filter { $0.age < 300 }  // 5 min
    let currentHR = recentHR.last?.value ?? 72
    let restingHR = userProfile.restingHeartRate ?? 60
    let maxHR = 220 - Double(userProfile.age ?? 30)

    let arousal = min(1.0, max(0.0,
        (currentHR - restingHR) / (maxHR - restingHR)
    ))

    // 2. Calculate stress from HRV
    let recentHRV = hrvSamples.filter { $0.age < 600 }  // 10 min
    let currentHRV = recentHRV.last?.value ?? 50
    let baselineHRV = userProfile.baselineHRV ?? 50

    let hrvRatio = currentHRV / baselineHRV
    let stress = min(1.0, max(0.0, 1.0 - (hrvRatio * 0.6)))

    // 3. Calculate energy
    let energy = (arousal * 0.6) + ((1.0 - stress) * 0.4)

    // 4. Infer context
    let context: ActivityContext
    if workoutState?.isActive == true {
        context = .workout
    } else if macOSContext?.inferredWorkState == "deep_work" {
        context = .deepWork
    } else {
        context = inferFromTimeOfDay()
    }

    // 5. Calculate focus
    let focus: Double
    switch context {
    case .deepWork:
        focus = 0.8 - (stress * 0.3)
    case .workout:
        focus = 0.3
    default:
        focus = 0.5 - (stress * 0.2)
    }

    // 6. Calculate valence
    var valence = 0.5 - (stress * 0.3)
    if let mood = manualMood, mood.age < 900 {  // 15 min
        valence = (valence * 0.3) + (mood.valence * 0.7)
    }

    // 7. Infer music need
    let need: MusicNeed
    if context == .workout && energy < 0.5 {
        need = .energize
    } else if stress > 0.7 {
        need = .calm
    } else if context == .deepWork {
        need = .focus
    } else {
        need = .maintain
    }

    // 8. Calculate confidence
    let hasRecentHR = !recentHR.isEmpty
    let hasRecentHRV = !recentHRV.isEmpty
    let confidence = (hasRecentHR ? 0.5 : 0.0) + (hasRecentHRV ? 0.5 : 0.0)

    return StateVector(
        arousal: arousal,
        energy: energy,
        focus: focus,
        stress: stress,
        valence: valence,
        context: context,
        inferredNeed: need,
        timestamp: Date(),
        confidence: confidence,
        dataSources: collectSources(hasRecentHR, hasRecentHRV, macOSContext, manualMood)
    )
}
```

---

---

# PART 11: PHASE 3 IMPLEMENTATION PLAN — DATA FOUNDATIONS

> **Added: 2026-02-20**
> This section contains the detailed, step-by-step implementation plan for Phase 3.

## 11.0 Context

Phase 1 (Project Setup) and Phase 2 (Platform Skeleton) are complete. Resonance has a polished UI shell with working MusicKit playback, WatchConnectivity bidirectional sync, and a macOS menu bar companion — but **no data pipeline** connects the Core Data schema to the running app. The 7 Core Data entities (Song, Playlist, HistoricalSession, PlaybackEvent, SongEffect, BiometricSample, MacOSContext) are defined but unused. There is no HealthKit service, no song ingestion, no event logging, no watch sensor streaming, and no context collection.

Phase 3 builds the data foundation that every subsequent phase depends on.

### Critical Gaps Discovered During Audit

1. **All entitlements files are empty** — `iOS/Entitlements/Resonance.entitlements` and `Watch/Entitlements/ResonanceWatch.entitlements` contain `<dict/>`. No App Group, no HealthKit capability.
2. **Info.plist missing privacy strings** — No `NSHealthShareUsageDescription`, no `NSAppleMusicUsageDescription` in iOS Info.plist.
3. **Watch bundle ID mismatch in Constants.swift** — `Constants.swift:20` has `com.y4sh.resonance.watchkitapp` but `project.yml:82` uses `com.y4sh.resonance.ios.watchkitapp`.
4. **UserPreferences uses standard UserDefaults** — `UserPreferences.swift` uses `UserDefaults.standard` instead of App Group suite.
5. **No Repository layer exists** — `Shared/Persistence/Repositories/` directory does not exist.
6. **Brain/ directory is completely empty**.
7. **Background tasks are a placeholder** — `ResonanceApp.swift:107` has empty `registerBackgroundTasks()`.

---

## 11.1 Step 0: Fix Entitlements, Info.plist & Constants (Prerequisites)

These are blocking issues that must be resolved before any Phase 3 code can work.

### 0a. iOS Entitlements
**File**: `iOS/Entitlements/Resonance.entitlements`

Replace the empty `<dict/>` with:
```xml
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.y4sh.resonance</string>
    </array>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
```

### 0b. watchOS Entitlements
**File**: `Watch/Entitlements/ResonanceWatch.entitlements`

Replace the empty `<dict/>` with:
```xml
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.y4sh.resonance</string>
    </array>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
```

### 0c. Widgets Entitlements
**File**: `Widgets/ResonanceWidgets.entitlements`

```xml
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.y4sh.resonance</string>
    </array>
</dict>
```

### 0d. macOS Entitlements
**File**: `macOS/Entitlements/ResonanceMac.entitlements`

```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.y4sh.resonance</string>
    </array>
</dict>
```

### 0e. iOS Info.plist Privacy Strings
**File**: `iOS/Info.plist`

Add inside `<dict>`:
```xml
<key>NSHealthShareUsageDescription</key>
<string>Resonance reads heart rate and HRV data to understand your current state and select the right music for you.</string>
<key>NSAppleMusicUsageDescription</key>
<string>Resonance accesses your Apple Music library to play songs from your playlists.</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
    <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.y4sh.resonance.playlistSync</string>
    <string>com.y4sh.resonance.historicalAnalysis</string>
    <string>com.y4sh.resonance.featureUpdate</string>
</array>
```

### 0f. Fix Constants.swift Bundle ID
**File**: `Shared/Utilities/Constants.swift:20`

```swift
// Before
public static let watchOS = "com.y4sh.resonance.watchkitapp"
// After
public static let watchOS = "com.y4sh.resonance.ios.watchkitapp"
```

### 0g. Fix UserPreferences to Use App Group Suite
**File**: `Shared/Models/UserPreferences.swift`

Change all `UserDefaults.standard` references to:
```swift
private static let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
```

---

## 11.2 Step 1: Playlist Ingestion (PlaylistRepository)

**New file**: `Shared/Persistence/Repositories/PlaylistRepository.swift`

```swift
final class PlaylistRepository {
    private let persistence: PersistenceController
    init(persistence: PersistenceController = .shared)

    func syncPlaylists(from musicKitPlaylists: MusicItemCollection<MusicKit.Playlist>) async throws
    func fetchAll() -> [Playlist]
    func findByAppleMusicId(_ id: String) -> Playlist?
    func search(query: String) -> [Playlist]
    func recalculateAggregates(for playlist: Playlist) async
}
```

Key details:
- Use `persistence.performBackgroundTask` for all writes
- Diffing: fetch existing by `appleMusicId`, compare name/songCount, update only changed
- Set `lastSyncedAt = Date()` on each synced playlist
- Use `NSBatchInsertRequest` if > 50 playlists
- Reuse `PersistenceController.shared` (at `Shared/Persistence/PersistenceController.swift:16`)

Wire into `PlaylistViewModel.fetchPlaylists()` to persist after MusicKit fetch.

---

## 11.3 Step 2: Song Ingestion (SongRepository)

**New file**: `Shared/Persistence/Repositories/SongRepository.swift`

```swift
final class SongRepository {
    private let persistence: PersistenceController
    init(persistence: PersistenceController = .shared)

    func syncSongs(_ musicKitSongs: MusicItemCollection<MusicKit.Song>, for playlist: Playlist) async throws
    func fetchSongs(for playlist: Playlist) -> [Song]
    func findByAppleMusicId(_ id: String) -> Song?
    func fetchSongsNeedingFeatures(limit: Int) -> [Song]
    func updatePlaybackStats(for song: Song, event: PlaybackEvent)
}
```

MusicKit → Core Data mapping:
```swift
song.appleMusicId = mkSong.id.rawValue
song.title = mkSong.title
song.artistName = mkSong.artistName
song.albumName = mkSong.albumTitle ?? ""
song.durationSeconds = mkSong.duration ?? 0
song.artworkURL = mkSong.artwork?.url(width: 300, height: 300)?.absoluteString
song.genreNames = mkSong.genreNames  // Transformable attribute
song.releaseDate = mkSong.releaseDate
song.addedToLibraryAt = mkSong.libraryAddedDate
```

---

## 11.4 Step 3: Song Feature Extraction

**New file**: `Brain/Features/FeatureExtractor.swift`

Genre-based heuristic estimation using mapping tables:
```swift
static let genreBPM: [String: Double] = [
    "ambient": 70, "classical": 80, "jazz": 100,
    "pop": 120, "rock": 130, "electronic": 128,
    "hip-hop": 90, "metal": 140
]
```

Reuses `SongFeatures.genreCategories` from `Shared/Models/SongFeatures.swift:203`.

**New file**: `Brain/Features/FeatureNormalizer.swift` — BPM normalization and clamping.

Background task registered via `BGProcessingTask` with identifier `BackgroundTaskConstants.TaskIdentifier.featureUpdate`.

---

## 11.5 Step 4: Event Logging (EventLogger)

**New file**: `Shared/Services/EventLogger.swift`

```swift
final class EventLogger: ObservableObject {
    @Published private(set) var activeEvent: PlaybackEvent?

    func logPlaybackStart(song:wasAISelected:selectionScore:selectionReason:currentHeartRate:currentHRV:)
    func logPlaybackEnd(wasSkipped:skipReason:currentHeartRate:currentHRV:)
    func observeMusicService(_ musicService: MusicKitService)
    func fetchRecentEvents(since: Date) -> [PlaybackEvent]
    func fetchEvents(for song: Song) -> [PlaybackEvent]
}
```

Key formulas:
- `listenPercentage = durationListened / songDuration`
- `wasSkipped = listenPercentage < LearningConstants.minimumListenPercentage` (0.3)
- `hrDelta = hrAtEnd - hrAtStart`
- `hrvDelta = hrvAtEnd - hrvAtStart`

Wire into `NowPlayingViewModel` to notify on skip/previous before MusicKit action.

---

## 11.6 Step 5: HealthKit Service

**New file**: `Shared/Services/HealthKitService.swift`

Protocol + implementation. Read types: heartRate, heartRateVariabilitySDNN, stepCount, activeEnergyBurned, sleepAnalysis, workoutType.

Key APIs:
- `requestAuthorization()` — with `isHealthDataAvailable()` guard
- `fetchLatestHeartRate()` / `fetchLatestHRV()` — `HKSampleQuery` with sort descending
- `heartRateStream` — `AsyncStream<Double>` via `HKAnchoredObjectQuery.updateHandler`
- `enableBackgroundDelivery()` — `.immediate` frequency for heart rate
- Historical queries stubbed for Phase 4

Wire into `ResonanceApp.swift` as `@StateObject`.

---

## 11.7 Step 6: Watch Sensor Layer

**New files** in `Watch/Sensors/`:
- `HeartRateSensor.swift` — `HKAnchoredObjectQuery` with `updateHandler`
- `MotionSensor.swift` — `CMMotionManager` + `CMPedometer`
- `WorkoutDetector.swift` — `HKWorkoutSessionDelegate`
- `SensorCoordinator.swift` — coordinates sensors, batches samples

Batching per `WatchConnectivityConstants` (`Constants.swift:132-133`):
- Collect every 5 seconds
- Send when 20 samples accumulated OR 5s elapsed
- Use `PhoneConnectivityService.sendBiometricUpdate()` (guaranteed via `transferUserInfo`)

Wire into `ResonanceWatchApp.swift` with HealthKit auth in `.task`.

---

## 11.8 Step 7: Context Collector (iPhone)

**New file**: `Shared/Services/ContextCollector.swift`

Subscribes to `WatchConnectivityManager.biometricUpdates`, converts `BiometricPacket` → `BiometricSignal` (model at `ContextSignal.swift:235`), persists as Core Data `BiometricSample`, tags with `activePlaybackEventId`, rebuilds `AggregatedContext` (struct at `ContextSignal.swift:291`).

Wire into `ResonanceApp.swift` — final wiring pass adding EventLogger, ContextCollector, and BGTask registration.

---

## 11.9 Parallel Execution Strategy

```
                    ┌──────────┐
                    │  Step 0  │  Fix entitlements, Info.plist, Constants
                    │ (prereq) │  ← Single agent
                    └────┬─────┘
                         │
            ┌────────────┼────────────────┐
            │            │                │
            ▼            ▼                ▼
     ┌──────────┐  ┌──────────┐    ┌──────────┐
     │  Step 1  │  │  Step 5  │    │  Step 6  │
     │ Playlist │  │ HealthKit│    │  Watch   │
     │ +Step 2  │  │ Service  │    │ Sensors  │
     │ Song Repo│  │          │    │          │
     └────┬─────┘  └────┬─────┘    └────┬─────┘
          │              │               │
          │              └───────┬───────┘
     ┌────┴────┐                 │
     │         │                 ▼
     ▼         ▼          ┌──────────┐
┌────────┐ ┌────────┐    │  Step 7  │
│ Step 3 │ │ Step 4 │    │ Context  │
│Feature │ │ Event  │    │Collector │
│Extract │ │ Logger │    │          │
└────────┘ └────────┘    └──────────┘
```

### Wave 1: Prerequisites (single agent)
Step 0 — all 7 sub-steps.

### Wave 2: SPAWN 3 AGENTS IN PARALLEL
| Agent | Steps | Files |
|-------|-------|-------|
| Agent A | 1 + 2 | `Shared/Persistence/Repositories/`, `iOS/ViewModels/PlaylistViewModel.swift` |
| Agent B | 5 | `Shared/Services/HealthKitService.swift`, `iOS/ResonanceApp.swift` (HealthKit only) |
| Agent C | 6 | `Watch/Sensors/*`, `Watch/ResonanceWatchApp.swift` |

### Wave 3: SPAWN 2 AGENTS IN PARALLEL
| Agent | Steps | Files |
|-------|-------|-------|
| Agent D | 3 + 4 | `Brain/Features/*`, `Shared/Services/EventLogger.swift`, `iOS/ViewModels/NowPlayingViewModel.swift` |
| Agent E | 7 + final wiring | `Shared/Services/ContextCollector.swift`, `iOS/ResonanceApp.swift` (final) |

### Wave 4: Build verification (single agent)
`xcodegen generate` → Build all schemes → Fix compilation errors → Run verification checklist.

---

## 11.10 Files Summary

### New Files (11)
| File | Purpose |
|---|---|
| `Shared/Persistence/Repositories/PlaylistRepository.swift` | Playlist CRUD + MusicKit sync |
| `Shared/Persistence/Repositories/SongRepository.swift` | Song CRUD + MusicKit mapping |
| `Brain/Features/FeatureExtractor.swift` | Genre-based feature estimation |
| `Brain/Features/FeatureNormalizer.swift` | Value normalization |
| `Shared/Services/EventLogger.swift` | Playback event capture |
| `Shared/Services/HealthKitService.swift` | HealthKit reads (iPhone) |
| `Watch/Sensors/HeartRateSensor.swift` | Watch HR monitoring |
| `Watch/Sensors/MotionSensor.swift` | Watch motion/pedometer |
| `Watch/Sensors/WorkoutDetector.swift` | Workout detection |
| `Watch/Sensors/SensorCoordinator.swift` | Batched sensor streaming |
| `Shared/Services/ContextCollector.swift` | Unified context aggregation |

### Modified Files (11)
| File | Changes |
|---|---|
| `iOS/Entitlements/Resonance.entitlements` | App Group + HealthKit |
| `Watch/Entitlements/ResonanceWatch.entitlements` | App Group + HealthKit |
| `Widgets/ResonanceWidgets.entitlements` | App Group |
| `macOS/Entitlements/ResonanceMac.entitlements` | App Group + sandbox |
| `iOS/Info.plist` | Privacy strings + background modes + BGTask IDs |
| `Shared/Utilities/Constants.swift` | Fix Watch bundle ID |
| `Shared/Models/UserPreferences.swift` | App Group UserDefaults suite |
| `iOS/ResonanceApp.swift` | HealthKit, EventLogger, ContextCollector, BGTasks |
| `iOS/ViewModels/PlaylistViewModel.swift` | Core Data persistence after MusicKit fetch |
| `iOS/ViewModels/NowPlayingViewModel.swift` | EventLogger notifications |
| `Watch/ResonanceWatchApp.swift` | SensorCoordinator, HealthKit auth |

---

## 11.11 Verification

1. **Build all targets**: `xcodegen generate` → Build Resonance, ResonanceWatch, ResonanceMac, ResonanceWidgets
2. **Entitlements**: Open each `.entitlements` in Xcode → verify App Group + HealthKit
3. **Playlist ingestion**: Launch app → playlists appear → Core Data has Playlist rows
4. **Song ingestion**: Select playlist → songs sync → `fetchSongsNeedingFeatures()` returns songs with `bpm == 0`
5. **Feature extraction**: Run extraction → `bpm`, `energyEstimate`, `valence` populated on Songs
6. **Event logging**: Play → PlaybackEvent created; Skip → `wasSkipped = true`; Complete → `listenPercentage ≈ 1.0`
7. **HealthKit** (device): Permission dialog → `fetchLatestHeartRate()` returns value
8. **Watch sensors** (device pair): HealthKit permission → `BiometricPacket` received on iPhone → BiometricSample in Core Data
9. **Context collector**: `aggregatedContext` updates on biometric arrival; BiometricSamples tagged with `activePlaybackEventId`
10. **Background tasks**: Xcode debug menu "Simulate Background Fetch" → playlist sync completes

---

# PART 12: PHASE 4 IMPLEMENTATION PLAN — HISTORICAL BACKFILL

## 12.0 Context & Goals

Phase 3 built the data pipeline: playlists and songs are ingested from MusicKit into Core Data, playback events are captured with biometric snapshots (HR/HRV deltas), Watch sensor data streams to the iPhone, and BiometricSamples are persisted. However, all this data is **unprocessed** — PlaybackEvents have no session grouping, songs have no learned effect scores, and playlists have no aggregate effect metrics.

Phase 4 transforms raw event data into the learned knowledge that Phase 5 (StateEngine) and Phase 6 (DecisionEngine) require:

1. **Session Reconstruction** — Group PlaybackEvents into HistoricalSession entities using the 30-minute gap rule, populate biometric summaries per session, and correlate with next-night sleep data.
2. **Song Impact Calculation** — Compute per-song, per-context effectiveness (calm/energy/focus/moodLift scores) from biometric response and listening behavior, stored as SongEffect entities.
3. **Playlist Impact Calculation** — Aggregate SongEffect scores across playlists, populate `avgCalmEffect`, `avgFocusEffect`, `avgEnergyEffect`, `effectConfidence`, and `contextAssociations`.
4. **HealthKit Historical Import** — Add sleep analysis and workout queries to HealthKitService for session context enrichment.
5. **Backfill Orchestration** — A HistoricalEngine that runs the full pipeline as a BGProcessingTask, supports incremental runs via per-step watermarks, and publishes progress for the Settings UI.

### What Phase 4 Does NOT Do

- Does NOT implement the StateEngine (Phase 5) or DecisionEngine (Phase 6)
- Does NOT implement real-time song scoring — only historical data processing
- Does NOT require network connectivity — all processing is on-device from Core Data + HealthKit

### Key Data Flow

```
PlaybackEvents (Phase 3)     HealthKit History
        │                          │
        ▼                          ▼
┌──────────────────┐    ┌─────────────────────┐
│ SessionRecon-    │    │ HealthKitService     │
│ structor         │───▶│ fetchSleep/Workouts  │
│ (30-min gap rule)│    └─────────────────────┘
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ HistoricalSession│  ← Core Data entity populated
│ (biometric       │
│  summaries)      │
└────────┬─────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌──────────────────┐
│ Song   │ │ Playlist         │
│ Impact │ │ Impact           │
│ Calc   │ │ Calculator       │
└───┬────┘ └────────┬─────────┘
    │               │
    ▼               ▼
┌────────┐ ┌──────────────────┐
│Song    │ │Playlist          │
│Effect  │ │avgCalm/Focus/    │
│entities│ │Energy + context  │
└────────┘ └──────────────────┘
```

---

## 12.0.1 Step 0: Fix Info.plist BGTask Identifiers (BLOCKING PREREQUISITE)

**CRITICAL**: The iOS `Info.plist` is missing `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes`. Without these entries, `BGTaskScheduler.shared.register()` crashes at runtime. The existing Phase 3 BGTasks (`playlistSync`, `featureUpdate`) are also affected — they silently fail. Neither `Info.plist` nor `project.yml` contain these entries.

**File**: `iOS/Info.plist`

Add inside `<dict>`:
```xml
<key>NSHealthShareUsageDescription</key>
<string>Resonance reads heart rate and HRV data to understand your current state and select the right music for you.</string>
<key>NSAppleMusicUsageDescription</key>
<string>Resonance accesses your Apple Music library to play songs from your playlists.</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
    <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.y4sh.resonance.playlistSync</string>
    <string>com.y4sh.resonance.historicalAnalysis</string>
    <string>com.y4sh.resonance.featureUpdate</string>
</array>
```

**File**: `iOS/ResonanceApp.swift`

Add static guard against double-registration crashes:
```swift
private static var hasRegisteredTasks = false

private func registerBackgroundTasks() {
    guard !Self.hasRegisteredTasks else { return }
    Self.hasRegisteredTasks = true
    // ... existing registrations
}
```

**File**: `Shared/Utilities/Constants.swift`

Add new constants section:
```swift
public enum BackfillConstants {
    public static let eventBatchSize: Int = 100
    public static let sessionSaveBatchSize: Int = 50

    public enum WatermarkKey {
        public static let sessionReconstruction = "com.y4sh.resonance.backfill.sessionWatermark"
        public static let songImpact = "com.y4sh.resonance.backfill.songImpactWatermark"
        public static let lastFullBackfill = "com.y4sh.resonance.backfill.lastFullBackfillDate"
    }

    /// Cold-start learning rate for first N observations
    public static let coldStartLearningRate: Double = 0.4
    public static let coldStartThreshold: Int = 5

    /// Maximum confidence for behavior-only impacts (no biometric data)
    public static let behaviorOnlyMaxConfidence: Double = 0.7
}
```

---

## 12.1 Step 1: HealthKit Historical Queries (Sleep + Workouts)

### 12.1.1 Add Sleep and Workout Types to HealthKitService

**File**: `Shared/Services/HealthKitService.swift`

The protocol already declares `fetchHeartRateHistory` and `fetchHRVHistory` (fully implemented). Phase 4 needs two additional methods and their supporting types.

**Add to `HealthKitServiceProtocol`:**
```swift
/// Returns sleep analysis sessions in the given date range.
/// Overlapping samples from multiple sources are merged into contiguous sessions.
func fetchSleepAnalysis(from: Date, to: Date) async throws -> [SleepSession]

/// Returns workout sessions in the given date range.
func fetchWorkouts(from: Date, to: Date) async throws -> [WorkoutSession]
```

**New types** (add in same file, below the `HealthKitServiceError` enum):
```swift
/// Represents a sleep analysis session from HealthKit.
struct SleepSession {
    let startDate: Date
    let endDate: Date
    let value: HKCategoryValueSleepAnalysis

    /// Duration in hours.
    var durationHours: Double {
        endDate.timeIntervalSince(startDate) / 3600.0
    }

    /// True if this sample represents deep sleep stage.
    var isDeepSleep: Bool {
        value == .asleepDeep
    }

    /// True if this sample represents REM sleep stage.
    var isREMSleep: Bool {
        value == .asleepREM
    }
}

/// Represents a workout session from HealthKit.
struct WorkoutSession {
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let totalEnergyBurned: Double  // kcal
    let durationMinutes: Double

    /// Human-readable activity name for logging/debug.
    var activityName: String {
        switch activityType {
        case .running:          return "Running"
        case .walking:          return "Walking"
        case .cycling:          return "Cycling"
        case .yoga:             return "Yoga"
        case .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        default:                return "Workout"
        }
    }
}
```

**Implementation details:**

`fetchSleepAnalysis(from:to:)`:
- Use a private `fetchCategorySamples(type:predicate:)` helper (see below) to query `HKCategoryType(.sleepAnalysis)`
- Use `HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)`
- Filter for `HKCategoryValueSleepAnalysis.asleepUnspecified`, `.asleepCore`, `.asleepDeep`, `.asleepREM` (not `.inBed` or `.awake`)
- **Overlapping source merging**: Multiple sources (Apple Watch, iPhone, third-party apps) may report overlapping sleep intervals. Sort all samples by `startDate`, then merge any samples whose `startDate` falls within a prior sample's `endDate` range, keeping the more specific sleep stage (deep > REM > core > unspecified).
- Map each `HKCategorySample` to a `SleepSession`
- Sort by `startDate` ascending

`fetchWorkouts(from:to:)`:
- Query `HKObjectType.workoutType()` using `HKSampleQuery`
- Map each `HKWorkout` to `WorkoutSession` extracting `workoutActivityType`, `startDate`, `endDate`, `totalEnergyBurned`
- Sort by `startDate` ascending

**Private helper** (reuses the continuation pattern from existing `fetchHeartRateHistory`):
```swift
/// Generic helper for fetching HKCategorySample arrays via async/await.
private func fetchCategorySamples(
    type: HKCategoryType,
    predicate: NSPredicate,
    limit: Int = HKObjectQueryNoLimit,
    sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
) async throws -> [HKCategorySample]
```

**Also add HealthKit chunked pagination helper:**
```swift
/// Fetches heart rate samples in chunks to handle large date ranges.
/// Splits the range into weekly chunks, fetches each with historicalQueryLimit,
/// and yields results incrementally. Includes `Task.sleep(nanoseconds:)` between
/// chunks to avoid overwhelming HealthKit.
func fetchHeartRateHistoryChunked(
    from: Date,
    to: Date,
    chunkDays: Int = 7
) -> AsyncStream<[(value: Double, date: Date)]>
```

This addresses the gap where `historicalQueryLimit` (10,000) may be insufficient for users with years of Apple Watch data. Each chunk pauses for 50ms via `try? await Task.sleep(nanoseconds: 50_000_000)` to yield to cooperative scheduling.

### 12.1.2 Add readTypes for Sleep

**File**: `Shared/Services/HealthKitService.swift`

The current `readTypes` set (line 89-108) already includes `HKCategoryType(.sleepAnalysis)` and `HKObjectType.workoutType()`. No changes needed to authorization.

---

## 12.2 Step 2: ImpactScore Value Type

**New file**: `Brain/Historical/ImpactScore.swift`

```swift
/// Intermediate value type representing the immediate biometric/behavioral
/// impact of a single playback event. Used by SongImpactCalculator to
/// EMA-update SongEffect records.
///
/// All values range from 0.0 to 1.0, centered at 0.5.
struct ImpactScore {
    /// Calming effect: higher means the song induced relaxation
    /// (positive HRV delta, negative HR delta, completed listen)
    let calm: Double

    /// Energizing effect: higher means the song induced activation
    /// (positive HR delta, completed listen)
    let energy: Double

    /// Focus effect: higher means the song held attention
    /// (high listen percentage)
    let focus: Double

    /// Mood lift effect: composite of calm, energy, and engagement
    let moodLift: Double

    /// Whether the song was skipped
    let wasSkipped: Bool

    /// Whether this score was computed with biometric data (HR/HRV).
    /// When false, only behavioral signals (skip, listen%) were used,
    /// and confidence should be capped at `BackfillConstants.behaviorOnlyMaxConfidence`.
    let hasBiometricData: Bool

    /// Clamps a value to [0.0, 1.0].
    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}
```

**Calculation formula** (enhanced from plan.md §5.3.1):
```swift
static func calculate(from event: PlaybackEvent) -> ImpactScore {
    let hasHR = event.hrDelta != 0.0
    let hasHRV = event.hrvDelta != 0.0
    let hasBiometric = hasHR || hasHRV

    let hrvImpact = event.hrvDelta / LearningConstants.hrvNormalizationFactor  // 10.0
    let hrImpact = event.hrDelta / LearningConstants.hrNormalizationFactor      // 10.0

    // Two-tier skip penalty: early skip (<15% listened) is harsher than late skip
    let skipPenalty: Double
    if event.wasSkipped {
        skipPenalty = event.listenPercentage < 0.15
            ? -0.3   // Strong rejection signal
            : -0.15  // Mild — user heard most of the song
    } else {
        skipPenalty = 0.0
    }

    let completionBonus = (event.listenPercentage - LearningConstants.completionBonusThreshold) * 0.2  // (pct - 0.5) * 0.2

    // Biometric signal redistribution:
    // When only HR is available, redistribute HRV weight to HR.
    // When only HRV is available, redistribute HR weight to HRV.
    // When neither is available, use only behavioral signals.
    var calmRaw: Double
    var energyRaw: Double
    if hasHR && hasHRV {
        calmRaw = 0.5 + (hrvImpact * 0.5) + (-hrImpact * 0.3) + completionBonus + skipPenalty
        energyRaw = 0.5 + (hrImpact * 0.3) + completionBonus + skipPenalty
    } else if hasHRV {
        // HRV only — redistribute HR weight to HRV
        calmRaw = 0.5 + (hrvImpact * 0.8) + completionBonus + skipPenalty
        energyRaw = 0.5 + completionBonus + skipPenalty
    } else if hasHR {
        // HR only — redistribute HRV weight to HR
        calmRaw = 0.5 + (-hrImpact * 0.8) + completionBonus + skipPenalty
        energyRaw = 0.5 + (hrImpact * 0.6) + completionBonus + skipPenalty
    } else {
        // Behavior only
        calmRaw = 0.5 + completionBonus + skipPenalty
        energyRaw = 0.5 + completionBonus + skipPenalty
    }

    let focusRaw = 0.5 + completionBonus
    let moodLiftRaw = (calmRaw * 0.4 + energyRaw * 0.3 + focusRaw * 0.3)

    return ImpactScore(
        calm: clamp(calmRaw),
        energy: clamp(energyRaw),
        focus: clamp(focusRaw),
        moodLift: clamp(moodLiftRaw),
        wasSkipped: event.wasSkipped,
        hasBiometricData: hasBiometric
    )
}
```

---

## 12.3 Step 3: SessionReconstructor

**New file**: `Brain/Historical/SessionReconstructor.swift`

### 12.3.1 Responsibilities

1. Fetch all `PlaybackEvent` records not yet assigned to a session (`session == nil`)
2. Sort by `startedAt` ascending
3. Group into sessions using the 30-minute gap rule (`SessionConstants.sessionGapMinutes`)
4. Skip sessions shorter than `SessionConstants.minimumSessionMinutes` (5 min)
5. For each session:
   a. Create a `HistoricalSession` Core Data entity
   b. Link all grouped PlaybackEvents to it
   c. Populate biometric summaries (HR, HRV) from HealthKit data within the session window +/- 5 minutes
   d. Populate session metadata (contextType, timeOfDaySlot, dayOfWeek, totalSongsPlayed, totalSkips, skipRate, avgListenPercentage)
   e. Correlate with next-night sleep (within `SessionConstants.sleepCorrelationWindowHours` hours = 12h)
   f. Calculate `overallImpactScore` using `scoreSession()` formula from plan.md §5.3.3
   g. Link to playlist if all songs share the same playlist
6. Support cooperative cancellation via `Task.checkCancellation()` between session batches

### 12.3.2 Interface

```swift
#if os(iOS)

import Foundation
import CoreData

/// Reconstructs HistoricalSession entities from unprocessed PlaybackEvents.
/// Groups events by time proximity (30-minute gap rule), enriches with
/// biometric data from HealthKit, and correlates with sleep.
final class SessionReconstructor {

    private let persistence: PersistenceController
    private let healthKitService: HealthKitService

    init(
        persistence: PersistenceController = .shared,
        healthKitService: HealthKitService
    )

    // MARK: - Main Entry Point

    /// Reconstructs sessions from all unprocessed PlaybackEvents.
    /// Returns the number of sessions created.
    /// Throws `CancellationError` if the parent task is cancelled.
    @discardableResult
    func reconstructSessions() async throws -> Int

    /// Reconstructs sessions only for events after the given date.
    /// Used for incremental backfill.
    @discardableResult
    func reconstructSessions(since: Date) async throws -> Int

    // MARK: - Session Building (Private)

    /// Fetches PlaybackEvents without a session, sorted by startedAt ascending.
    /// Batched by `BackfillConstants.eventBatchSize` (100) to limit memory.
    private func fetchUnprocessedEvents(
        since: Date?,
        in context: NSManagedObjectContext
    ) throws -> [PlaybackEvent]

    /// Groups events into session clusters using the gap rule.
    /// Uses `endedAt ?? startedAt + songDuration` for gap calculation.
    private func groupIntoSessions(
        _ events: [PlaybackEvent]
    ) -> [[PlaybackEvent]]

    /// Creates a HistoricalSession from a cluster of events, enriches with biometrics.
    private func buildSession(
        from events: [PlaybackEvent],
        in context: NSManagedObjectContext
    ) async throws -> HistoricalSession

    // MARK: - Biometric Enrichment

    /// Fetches HR/HRV data for the session window from HealthKit.
    private func enrichWithBiometrics(
        _ session: HistoricalSession,
        startTime: Date,
        endTime: Date
    ) async throws

    // MARK: - Sleep Correlation

    /// Finds the next night's sleep after the session and scores it.
    private func correlateSleep(
        _ session: HistoricalSession,
        sessionEndTime: Date
    ) async throws

    /// Calculates a normalized sleep score from sleep sessions.
    /// Score based on total duration and deep sleep percentage.
    /// Filters out naps (< 3 hours) for the "substantial sleep" metric.
    private func calculateSleepScore(
        _ sleepSessions: [SleepSession]
    ) -> (score: Double, duration: Double, deepPct: Double)

    // MARK: - Context Inference

    /// Infers ActivityContext from time of day, day of week, and workout state.
    /// Weekend-aware: weekday 9-17 maps to `.work`, weekend 9-17 maps to `.relaxation`.
    private func inferContext(
        startTime: Date,
        events: [PlaybackEvent]
    ) async -> String  // Returns ActivityContext.rawValue

    /// Maps hour to TimeSlot.rawValue.
    private func getTimeSlot(for date: Date) -> String

    // MARK: - Session Scoring

    /// Scores a completed session using the formula from plan.md §5.3.3.
    private func scoreSession(_ session: HistoricalSession) -> Double
}

#endif
```

### 12.3.3 Key Implementation Details

**Gap rule grouping** (uses `endedAt ?? startedAt + songDuration` for accurate gap calculation):
```swift
private func groupIntoSessions(_ events: [PlaybackEvent]) -> [[PlaybackEvent]] {
    guard !events.isEmpty else { return [] }

    var groups: [[PlaybackEvent]] = []
    var currentGroup: [PlaybackEvent] = [events[0]]

    for i in 1..<events.count {
        // Use endedAt if available, otherwise estimate from song duration
        let previousEnd = events[i-1].endedAt
            ?? events[i-1].startedAt.addingTimeInterval(events[i-1].song?.durationSeconds ?? 180)
        let gap = events[i].startedAt.timeIntervalSince(previousEnd)

        if gap > Double(SessionConstants.sessionGapMinutes) * 60 {
            // Gap too large — finalize current group, start new
            groups.append(currentGroup)
            currentGroup = [events[i]]
        } else {
            currentGroup.append(events[i])
        }
    }
    groups.append(currentGroup)

    // Filter out sessions shorter than minimum duration
    return groups.filter { group in
        guard let first = group.first?.startedAt else { return false }
        let lastEnd = group.last?.endedAt
            ?? group.last?.startedAt.addingTimeInterval(group.last?.song?.durationSeconds ?? 180)
            ?? first.addingTimeInterval(180)
        let durationMinutes = lastEnd.timeIntervalSince(first) / 60.0
        return durationMinutes >= Double(SessionConstants.minimumSessionMinutes)
    }
}
```

**Cooperative cancellation** between session batches:
```swift
// Inside reconstructSessions():
for (index, group) in sessionGroups.enumerated() {
    try Task.checkCancellation()  // Bail if BGTask expired
    let session = try await buildSession(from: group, in: context)
    sessionsCreated += 1

    // Save in batches to avoid memory pressure
    if index % BackfillConstants.sessionSaveBatchSize == 0 {
        try context.save()
    }
}
```

**Biometric enrichment:**
- Fetch HR via `healthKitService.fetchHeartRateHistory(from: startTime - 300, to: endTime + 300)`
- Fetch HRV via `healthKitService.fetchHRVHistory(from: startTime - 300, to: endTime + 300)`
- `startingHeartRate` = first HR sample within 5 min of start
- `endingHeartRate` = last HR sample within 5 min of end
- `avgHeartRate` = mean of all HR samples in window
- `minHeartRate`/`maxHeartRate` = min/max of all HR samples
- `deltaHeartRate` = ending - starting
- Same pattern for HRV

**Sleep correlation** (with 3-hour minimum for substantial sleep):
- After session ends, look for sleep data within `SessionConstants.sleepCorrelationWindowHours` (12h)
- `fetchSleepAnalysis(from: sessionEndTime, to: sessionEndTime + 12h)`
- **Filter out naps**: Only consider sleep sessions totaling >= 3 hours for the "next night" metric
- Calculate: `nextNightSleepDuration` = total hours of qualifying asleep sessions
- `nextNightDeepSleepPct` = deep sleep hours / total sleep hours, **normalized by 0.25** (i.e., `deepSleepHours / totalSleepHours / 0.25` clamped to 1.0, since 25% deep sleep is considered ideal)
- Use `NSNumber(value:)` for sleep score fields:
  ```swift
  session.nextNightSleepDuration = NSNumber(value: totalSleepHours)
  session.nextNightDeepSleepPct = NSNumber(value: deepPct)
  session.nextNightSleepScore = NSNumber(value: sleepScore)
  ```
- `nextNightSleepScore` = normalized composite: `min(1.0, totalSleepHours / 8.0) * 0.6 + normalizedDeepPct * 0.4`

**Session scoring** (plan.md §5.3.3):
```swift
private func scoreSession(_ session: HistoricalSession) -> Double {
    let skipScore = 1.0 - session.skipRate
    let hrvScore = min(max(0.5 + (session.deltaHRV / 20.0), 0.0), 1.0)
    let engagementScore = session.avgListenPercentage
    let sleepScore = session.nextNightSleepScore  // 0.5 if unavailable

    return (skipScore * 0.25) +
           (hrvScore * 0.30) +
           (engagementScore * 0.25) +
           (sleepScore * 0.20)
}
```

**Context inference** (weekend-aware, with HealthKit workout detection):
```swift
private func inferContext(startTime: Date, events: [PlaybackEvent]) async -> String {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: startTime)
    let isWeekend = calendar.isDateInWeekend(startTime)

    // Check HealthKit for a workout overlapping this session
    let sessionEnd = events.last?.endedAt ?? startTime.addingTimeInterval(3600)
    if let workouts = try? await healthKitService.fetchWorkouts(
        from: startTime.addingTimeInterval(-300),
        to: sessionEnd.addingTimeInterval(300)
    ), !workouts.isEmpty {
        return StateVector.ActivityContext.workout.rawValue
    }

    switch hour {
    case 5..<7:   return StateVector.ActivityContext.morning.rawValue
    case 7..<9:   return isWeekend
                    ? StateVector.ActivityContext.morning.rawValue
                    : StateVector.ActivityContext.commute.rawValue
    case 9..<17:  return isWeekend
                    ? StateVector.ActivityContext.relaxation.rawValue
                    : StateVector.ActivityContext.work.rawValue
    case 17..<19: return isWeekend
                    ? StateVector.ActivityContext.relaxation.rawValue
                    : StateVector.ActivityContext.commute.rawValue
    case 19..<22: return StateVector.ActivityContext.relaxation.rawValue
    case 22..<24, 0..<5: return StateVector.ActivityContext.preSleep.rawValue
    default:      return StateVector.ActivityContext.unknown.rawValue
    }
}
```

---

## 12.4 Step 4: SongImpactCalculator

**New file**: `Brain/Historical/SongImpactCalculator.swift`

### 12.4.1 Responsibilities

1. Iterate all PlaybackEvents that have a linked HistoricalSession
2. For each event, compute an `ImpactScore`
3. Find-or-create a `SongEffect` entity for the **(song, contextType) pair** (not a triple — `timeOfDaySlot` is no longer part of the lookup key to avoid sparse matrices)
4. EMA-update the effect scores using two-tier alpha (plan.md §5.3.2):
   - **Cold start** (first `BackfillConstants.coldStartThreshold` = 5 plays): alpha = `BackfillConstants.coldStartLearningRate` (0.4)
   - **Steady state** (6+ plays): alpha = `LearningConstants.defaultLearningRate` (0.2)
5. Cap confidence at `BackfillConstants.behaviorOnlyMaxConfidence` (0.7) when `ImpactScore.hasBiometricData == false`
6. Update the Song entity's aggregate scores (`calmScore`, `focusScore`, `activationScore`, `familiarityScore`, `confidenceLevel`)
7. **Batch save** every `BackfillConstants.eventBatchSize` (100) events to avoid memory pressure

### 12.4.2 Interface

```swift
#if os(iOS)

import Foundation
import CoreData

/// Calculates per-song, per-context effectiveness scores from PlaybackEvent data.
/// Creates and updates SongEffect entities using exponential moving average.
final class SongImpactCalculator {

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared)

    // MARK: - Main Entry Point

    /// Processes all PlaybackEvents that have sessions but whose SongEffects
    /// haven't been updated since the event occurred.
    /// Returns the number of events processed.
    @discardableResult
    func calculateImpacts() async throws -> Int

    /// Processes only events since the given date.
    @discardableResult
    func calculateImpacts(since: Date) async throws -> Int

    // MARK: - Per-Event Processing

    /// Processes a single PlaybackEvent: computes ImpactScore, updates SongEffect.
    private func processEvent(
        _ event: PlaybackEvent,
        in context: NSManagedObjectContext
    ) throws

    // MARK: - SongEffect CRUD

    /// Finds or creates a SongEffect for the given (song, contextType) pair.
    private func findOrCreateEffect(
        for song: Song,
        contextType: String,
        in context: NSManagedObjectContext
    ) throws -> SongEffect

    // MARK: - EMA Update

    /// Updates a SongEffect using exponential moving average.
    /// Two-tier alpha: 0.4 for cold start (first 5 plays), 0.2 for steady state.
    private func updateEffect(
        _ effect: SongEffect,
        with impact: ImpactScore
    )

    // MARK: - Song Aggregate Update

    /// Updates the Song entity's aggregate scores from its SongEffect records.
    /// calmScore = weighted average of all effects' calmScore
    /// Same for focusScore, activationScore.
    /// Weights by effect.confidenceLevel.
    private func updateSongAggregates(
        _ song: Song,
        in context: NSManagedObjectContext
    ) throws

    // MARK: - Familiarity

    /// Updates familiarityScore based on total play count only.
    /// Formula: familiarityScore = min(1.0, totalPlayCount / 10.0)
    private func updateFamiliarity(_ song: Song)
}

#endif
```

### 12.4.3 Key Implementation Details

**SongEffect find-or-create** (keyed by (song, contextType) pair):
```swift
private func findOrCreateEffect(
    for song: Song,
    contextType: String,
    in context: NSManagedObjectContext
) throws -> SongEffect {
    let request = NSFetchRequest<SongEffect>(entityName: "SongEffect")
    request.predicate = NSPredicate(
        format: "song == %@ AND contextType == %@",
        song, contextType
    )
    request.fetchLimit = 1

    if let existing = try context.fetch(request).first {
        return existing
    }

    // Create new effect with defaults
    let effect = NSEntityDescription.insertNewObject(
        forEntityName: "SongEffect", into: context
    ) as! SongEffect
    effect.id = UUID()
    effect.song = song
    effect.contextType = contextType
    effect.calmScore = 0.5
    effect.focusScore = 0.5
    effect.energyScore = 0.5
    effect.moodLiftScore = 0.5
    effect.sampleCount = 0
    effect.confidenceLevel = 0.0
    effect.firstRecordedAt = Date()
    effect.lastUpdatedAt = Date()

    return effect
}
```

**EMA update** (two-tier alpha, plan.md §5.3.2):
```swift
private func updateEffect(_ effect: SongEffect, with impact: ImpactScore) {
    // Two-tier alpha: faster learning for cold start
    let alpha: Double = effect.sampleCount < BackfillConstants.coldStartThreshold
        ? BackfillConstants.coldStartLearningRate   // 0.4
        : LearningConstants.defaultLearningRate     // 0.2

    effect.calmScore = (1.0 - alpha) * effect.calmScore + alpha * impact.calm
    effect.energyScore = (1.0 - alpha) * effect.energyScore + alpha * impact.energy
    effect.focusScore = (1.0 - alpha) * effect.focusScore + alpha * impact.focus
    effect.moodLiftScore = (1.0 - alpha) * effect.moodLiftScore + alpha * impact.moodLift

    effect.sampleCount += 1

    // Confidence: cap at 0.7 if no biometric data for this observation
    let rawConfidence = min(1.0, Double(effect.sampleCount) / Double(DecisionEngineConstants.fullConfidenceSampleCount))  // 20
    if !impact.hasBiometricData {
        effect.confidenceLevel = min(rawConfidence, BackfillConstants.behaviorOnlyMaxConfidence)  // 0.7
    } else {
        effect.confidenceLevel = rawConfidence
    }
    effect.lastUpdatedAt = Date()
}
```

**Batch save** (every 100 events):
```swift
// Inside calculateImpacts():
for (index, event) in events.enumerated() {
    try Task.checkCancellation()
    try processEvent(event, in: context)

    if index % BackfillConstants.eventBatchSize == 0, index > 0 {
        try context.save()
    }
}
try context.save()  // Final save for remaining events
```

**Song aggregate update:**
```swift
private func updateSongAggregates(_ song: Song, in context: NSManagedObjectContext) throws {
    guard let effects = song.effects?.allObjects as? [SongEffect], !effects.isEmpty else { return }

    // Confidence-weighted average across all context-specific effects
    let totalConfidence = effects.reduce(0.0) { $0 + $1.confidenceLevel }
    guard totalConfidence > 0 else { return }

    var weightedCalm = 0.0, weightedFocus = 0.0, weightedEnergy = 0.0
    for effect in effects {
        let w = effect.confidenceLevel / totalConfidence
        weightedCalm += effect.calmScore * w
        weightedFocus += effect.focusScore * w
        weightedEnergy += effect.energyScore * w
    }

    song.calmScore = weightedCalm
    song.focusScore = weightedFocus
    song.activationScore = weightedEnergy
    song.confidenceLevel = min(1.0, totalConfidence / Double(effects.count))
}
```

**Familiarity update** (based on play count only):
```swift
private func updateFamiliarity(_ song: Song) {
    song.familiarityScore = min(1.0, Double(song.totalPlayCount) / 10.0)
}
```

---

## 12.5 Step 5: PlaylistImpactCalculator

**New file**: `Brain/Historical/PlaylistImpactCalculator.swift`

### 12.5.1 Responsibilities

1. For each Playlist that has sessions, aggregate song-level effect scores using **confidence-weighted averaging**
2. Compute `avgCalmEffect`, `avgFocusEffect`, `avgEnergyEffect`
3. Compute `effectConfidence` from session count and song effect confidence
4. Build `contextAssociations` — a JSON blob mapping activity contexts to usage frequency **and per-context average effect scores**

### 12.5.2 Interface

```swift
#if os(iOS)

import Foundation
import CoreData

/// Aggregates SongEffect scores across playlists to populate playlist-level
/// effect metrics and context associations.
final class PlaylistImpactCalculator {

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared)

    // MARK: - Main Entry Point

    /// Calculates impact metrics for all playlists that have linked sessions.
    /// Returns the number of playlists updated.
    @discardableResult
    func calculatePlaylistImpacts() async throws -> Int

    // MARK: - Per-Playlist Processing

    /// Updates effect metrics for a single playlist using confidence-weighted averaging.
    private func processPlaylist(
        _ playlist: Playlist,
        in context: NSManagedObjectContext
    ) throws

    // MARK: - Context Associations

    /// Builds a context association map with per-context effect scores:
    /// { "workout": { "frequency": 0.4, "avgCalm": 0.3, "avgEnergy": 0.8, ... }, ... }
    /// Based on how often the playlist's sessions occur in each context
    /// and the average effect scores for songs played in that context.
    private func buildContextAssociations(
        from sessions: [HistoricalSession],
        songs: [Song]
    ) -> [String: [String: Double]]
}

#endif
```

### 12.5.3 Key Implementation Details

**Playlist effect aggregation** (confidence-weighted):
```swift
private func processPlaylist(_ playlist: Playlist, in context: NSManagedObjectContext) throws {
    let songs = (playlist.songs?.allObjects as? [Song]) ?? []
    guard !songs.isEmpty else { return }

    // Confidence-weighted average effect scores across all songs with effects
    var weightedCalm = 0.0, weightedFocus = 0.0, weightedEnergy = 0.0
    var totalWeight = 0.0

    for song in songs {
        guard let effects = song.effects?.allObjects as? [SongEffect], !effects.isEmpty else { continue }

        // Per-song: confidence-weighted average across contexts
        let songTotalConf = effects.reduce(0.0) { $0 + $1.confidenceLevel }
        guard songTotalConf > 0 else { continue }

        var songCalm = 0.0, songFocus = 0.0, songEnergy = 0.0
        for effect in effects {
            let w = effect.confidenceLevel / songTotalConf
            songCalm += effect.calmScore * w
            songFocus += effect.focusScore * w
            songEnergy += effect.energyScore * w
        }

        // Weight this song by its average confidence
        let songWeight = songTotalConf / Double(effects.count)
        weightedCalm += songCalm * songWeight
        weightedFocus += songFocus * songWeight
        weightedEnergy += songEnergy * songWeight
        totalWeight += songWeight
    }

    guard totalWeight > 0 else { return }

    playlist.avgCalmEffect = weightedCalm / totalWeight
    playlist.avgFocusEffect = weightedFocus / totalWeight
    playlist.avgEnergyEffect = weightedEnergy / totalWeight
    playlist.effectConfidence = min(1.0, totalWeight / Double(songs.count))

    // Build context associations from sessions with per-context effect scores
    if let sessions = playlist.sessions?.allObjects as? [HistoricalSession], !sessions.isEmpty {
        let associations = buildContextAssociations(from: sessions, songs: songs)
        playlist.contextAssociations = try? JSONSerialization.data(
            withJSONObject: associations, options: []
        )
    }
}
```

**Context associations** (with per-context effect scores):
```swift
private func buildContextAssociations(
    from sessions: [HistoricalSession],
    songs: [Song]
) -> [String: [String: Double]] {
    var contextCounts: [String: Int] = [:]
    for session in sessions {
        let ctx = session.contextType
        contextCounts[ctx, default: 0] += 1
    }
    let total = Double(sessions.count)

    var result: [String: [String: Double]] = [:]
    for (ctx, count) in contextCounts {
        // Per-context average effect scores from songs that have effects for this context
        var calmSum = 0.0, energySum = 0.0, focusSum = 0.0
        var matchCount = 0
        for song in songs {
            guard let effects = song.effects?.allObjects as? [SongEffect] else { continue }
            if let ctxEffect = effects.first(where: { $0.contextType == ctx }) {
                calmSum += ctxEffect.calmScore
                energySum += ctxEffect.energyScore
                focusSum += ctxEffect.focusScore
                matchCount += 1
            }
        }
        var entry: [String: Double] = ["frequency": Double(count) / total]
        if matchCount > 0 {
            entry["avgCalm"] = calmSum / Double(matchCount)
            entry["avgEnergy"] = energySum / Double(matchCount)
            entry["avgFocus"] = focusSum / Double(matchCount)
        }
        result[ctx] = entry
    }
    return result
}
```

---

## 12.6 Step 6: HistoricalEngine (Orchestrator)

**New file**: `Brain/Historical/HistoricalEngine.swift`

### 12.6.1 Responsibilities

1. Orchestrates the full backfill pipeline in the correct order
2. Manages **per-step watermarks** via UserDefaults (session reconstruction, song impact, last full backfill)
3. Publishes progress for Settings UI consumption
4. Called by `BGProcessingTask` handler in ResonanceApp.swift
5. Called manually from Settings "Run Backfill Now" button
6. **Atomic `isRunning` guard** via `@MainActor` to prevent concurrent runs
7. **Cooperative cancellation support** — propagates `CancellationError` cleanly

### 12.6.2 Interface

```swift
#if os(iOS)

import Foundation
import Combine

/// Orchestrates the full historical backfill pipeline.
/// Coordinates SessionReconstructor, SongImpactCalculator, and PlaylistImpactCalculator
/// in sequence, tracks progress, and supports incremental runs.
@MainActor
final class HistoricalEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRunning = false
    @Published private(set) var progress: BackfillProgress = .idle

    enum BackfillProgress: Equatable {
        case idle
        case reconstructingSessions(processed: Int, total: Int)
        case calculatingSongImpacts(processed: Int, total: Int)
        case calculatingPlaylistImpacts(processed: Int, total: Int)
        case completed(sessionsCreated: Int, eventsProcessed: Int, playlistsUpdated: Int)
        case failed(String)
    }

    // MARK: - Dependencies

    private let sessionReconstructor: SessionReconstructor
    private let songImpactCalculator: SongImpactCalculator
    private let playlistImpactCalculator: PlaylistImpactCalculator
    private let persistence: PersistenceController

    // MARK: - Per-Step Watermarks

    /// Watermark for session reconstruction step.
    var sessionWatermark: Date? {
        get {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            return defaults.object(forKey: BackfillConstants.WatermarkKey.sessionReconstruction) as? Date
        }
        set {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            defaults.set(newValue, forKey: BackfillConstants.WatermarkKey.sessionReconstruction)
        }
    }

    /// Watermark for song impact calculation step.
    var songImpactWatermark: Date? {
        get {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            return defaults.object(forKey: BackfillConstants.WatermarkKey.songImpact) as? Date
        }
        set {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            defaults.set(newValue, forKey: BackfillConstants.WatermarkKey.songImpact)
        }
    }

    /// Date of last full backfill completion (all steps succeeded).
    var lastBackfillDate: Date? {
        get {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            return defaults.object(forKey: BackfillConstants.WatermarkKey.lastFullBackfill) as? Date
        }
        set {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            defaults.set(newValue, forKey: BackfillConstants.WatermarkKey.lastFullBackfill)
        }
    }

    // MARK: - Initialization

    init(
        healthKitService: HealthKitService,
        persistence: PersistenceController = .shared
    ) {
        self.persistence = persistence
        self.sessionReconstructor = SessionReconstructor(
            persistence: persistence,
            healthKitService: healthKitService
        )
        self.songImpactCalculator = SongImpactCalculator(persistence: persistence)
        self.playlistImpactCalculator = PlaylistImpactCalculator(persistence: persistence)
    }

    // MARK: - Entry Points

    /// Runs the full backfill pipeline (for first-time or "Run Full Backfill" button).
    func runFullBackfill() async {
        guard !isRunning else {
            logWarning("HistoricalEngine: backfill already running", category: .background)
            return
        }
        await runBackfill(since: nil)
    }

    /// Runs an incremental backfill since the last watermark.
    func runIncrementalBackfill() async {
        guard !isRunning else { return }
        await runBackfill(since: lastBackfillDate)
    }

    // MARK: - Pipeline

    private func runBackfill(since: Date?) async {
        isRunning = true

        do {
            // Step 1: Reconstruct sessions (uses per-step watermark for incremental)
            progress = .reconstructingSessions(processed: 0, total: 0)
            let sessionSince = since ?? sessionWatermark ?? .distantPast
            let sessionsCreated = try await sessionReconstructor.reconstructSessions(since: sessionSince)
            sessionWatermark = Date()
            logInfo("HistoricalEngine: created \(sessionsCreated) sessions", category: .background)

            // Step 2: Calculate song impacts
            progress = .calculatingSongImpacts(processed: 0, total: 0)
            let songSince = since ?? songImpactWatermark ?? .distantPast
            let eventsProcessed = try await songImpactCalculator.calculateImpacts(since: songSince)
            songImpactWatermark = Date()
            logInfo("HistoricalEngine: processed \(eventsProcessed) events for song impacts", category: .background)

            // Step 3: Calculate playlist impacts (always full — it's fast)
            progress = .calculatingPlaylistImpacts(processed: 0, total: 0)
            let playlistsUpdated = try await playlistImpactCalculator.calculatePlaylistImpacts()
            logInfo("HistoricalEngine: updated \(playlistsUpdated) playlists", category: .background)

            // Update full-run watermark
            lastBackfillDate = Date()

            progress = .completed(
                sessionsCreated: sessionsCreated,
                eventsProcessed: eventsProcessed,
                playlistsUpdated: playlistsUpdated
            )
            isRunning = false

            logInfo(
                "HistoricalEngine: backfill complete — " +
                "\(sessionsCreated) sessions, \(eventsProcessed) events, \(playlistsUpdated) playlists",
                category: .background
            )
        } catch is CancellationError {
            progress = .failed("Cancelled by system")
            isRunning = false
            logInfo("HistoricalEngine: backfill cancelled (BGTask expired or user cancelled)", category: .background)
        } catch {
            progress = .failed(error.localizedDescription)
            isRunning = false
            logError("HistoricalEngine: backfill failed", error: error, category: .background)
        }
    }
}

#endif
```

---

## 12.7 Step 7: Wire into ResonanceApp + Background Tasks

### 12.7.1 Add HistoricalEngine to ResonanceApp

**File**: `iOS/ResonanceApp.swift`

Add `HistoricalEngine` as a `@StateObject`:
```swift
@StateObject private var historicalEngine: HistoricalEngine

// In init():
let historicalEngine = HistoricalEngine(healthKitService: healthKitService)
_historicalEngine = StateObject(wrappedValue: historicalEngine)
```

Pass to SettingsView for the "Run Backfill" button and progress display.

### 12.7.2 Register historicalAnalysis BGProcessingTask

**File**: `iOS/ResonanceApp.swift`

Add the `hasRegisteredTasks` guard (from Step 0) and the historical analysis registration to `registerBackgroundTasks()`:
```swift
private static var hasRegisteredTasks = false

private func registerBackgroundTasks() {
    guard !Self.hasRegisteredTasks else { return }
    Self.hasRegisteredTasks = true

    // ... existing playlistSync and featureUpdate registrations ...

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: BackgroundTaskConstants.TaskIdentifier.historicalAnalysis,
        using: nil
    ) { task in
        guard let processingTask = task as? BGProcessingTask else {
            task.setTaskCompleted(success: false)
            return
        }
        self.handleHistoricalAnalysis(task: processingTask)
    }

    scheduleHistoricalAnalysis()
}
```

Add handler with cooperative cancellation:
```swift
private func handleHistoricalAnalysis(task: BGProcessingTask) {
    let analysisTask = Task {
        await historicalEngine.runIncrementalBackfill()
    }
    task.expirationHandler = {
        // Cancelling the task triggers CancellationError in SessionReconstructor
        // and SongImpactCalculator via Task.checkCancellation()
        analysisTask.cancel()
    }
    Task {
        await analysisTask.value
        task.setTaskCompleted(success: true)
        scheduleHistoricalAnalysis()
    }
}

private func scheduleHistoricalAnalysis() {
    let request = BGProcessingTaskRequest(
        identifier: BackgroundTaskConstants.TaskIdentifier.historicalAnalysis
    )
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = true  // Only when charging
    request.earliestBeginDate = Date(timeIntervalSinceNow:
        Double(BackgroundTaskConstants.historicalAnalysisIntervalDays) * 86400
    )
    do {
        try BGTaskScheduler.shared.submit(request)
        logDebug("Historical analysis scheduled", category: .background)
    } catch {
        logError("Failed to schedule historical analysis", error: error, category: .background)
    }
}
```

### 12.7.3 Add EventLogger Query for Session Reconstruction

**File**: `Shared/Services/EventLogger.swift`

Add a method to fetch all events chronologically for session reconstruction:
```swift
/// Fetches all PlaybackEvents not yet assigned to a session, ordered chronologically.
func fetchEventsWithoutSession() -> [PlaybackEvent] {
    let request = NSFetchRequest<PlaybackEvent>(entityName: "PlaybackEvent")
    request.predicate = NSPredicate(format: "session == nil")
    request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]

    do {
        return try persistence.viewContext.fetch(request)
    } catch {
        logError("EventLogger: failed to fetch events without session", error: error, category: .persistence)
        return []
    }
}
```

### 12.7.4 Settings UI for Backfill

**File**: `iOS/Views/SettingsView.swift`

Add a section to SettingsView showing backfill status and a manual trigger button:
```swift
Section("Historical Analysis") {
    switch historicalEngine.progress {
    case .idle:
        Text("Last run: \(historicalEngine.lastBackfillDate?.formatted() ?? "Never")")
        Button("Run Full Backfill") {
            Task { await historicalEngine.runFullBackfill() }
        }
    case .reconstructingSessions(let processed, _):
        ProgressView("Reconstructing sessions... (\(processed))")
    case .calculatingSongImpacts(let processed, _):
        ProgressView("Calculating song impacts... (\(processed))")
    case .calculatingPlaylistImpacts(let processed, _):
        ProgressView("Calculating playlist impacts... (\(processed))")
    case .completed(let sessions, let events, let playlists):
        Text("Complete: \(sessions) sessions, \(events) events, \(playlists) playlists")
    case .failed(let message):
        Text("Failed: \(message)").foregroundColor(.red)
        Button("Retry") {
            Task { await historicalEngine.runFullBackfill() }
        }
    }
}
```

---

## 12.8 Files Summary

### New Files (5)

| File | Purpose |
|---|---|
| `Brain/Historical/ImpactScore.swift` | Intermediate value type for biometric impact calculation |
| `Brain/Historical/SessionReconstructor.swift` | Groups PlaybackEvents into HistoricalSessions, enriches with biometrics |
| `Brain/Historical/SongImpactCalculator.swift` | Per-song per-context EMA effect scoring, SongEffect CRUD |
| `Brain/Historical/PlaylistImpactCalculator.swift` | Playlist-level effect aggregation + context associations |
| `Brain/Historical/HistoricalEngine.swift` | Orchestrator: pipeline sequencing, progress, per-step watermarks |

### Modified Files (6)

| File | Changes |
|---|---|
| `iOS/Info.plist` | Add `UIBackgroundModes` (audio, fetch, processing), `BGTaskSchedulerPermittedIdentifiers` (playlistSync, historicalAnalysis, featureUpdate), usage description strings |
| `Shared/Utilities/Constants.swift` | Add `BackfillConstants` enum with batch sizes, watermark keys, cold-start thresholds, behavior-only confidence cap |
| `Shared/Services/HealthKitService.swift` | Add `fetchSleepAnalysis()`, `fetchWorkouts()`, `SleepSession`, `WorkoutSession` types, `fetchCategorySamples()` helper, chunked pagination helper |
| `Shared/Services/EventLogger.swift` | Add `fetchEventsWithoutSession()` query |
| `iOS/ResonanceApp.swift` | Add `HistoricalEngine` StateObject, `hasRegisteredTasks` guard, register `historicalAnalysis` BGProcessingTask, add handler with cooperative cancellation + scheduler |
| `iOS/Views/SettingsView.swift` | Add Historical Analysis section with progress display and manual trigger |

---

## 12.9 Parallel Execution Strategy

### Dependency Graph

```
┌──────────────┐
│  Step 0       │  Info.plist + Constants.swift (BLOCKING)
│ (Prerequisite)│
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Step 1       │  HealthKit sleep/workout queries
│ (HealthKit)   │
└──────┬───────┘
       │
       ├──────────────────┐
       │                  │
       ▼                  ▼
┌──────────┐       ┌──────────────┐
│  Step 2  │       │ Step 7a      │
│ Impact   │       │ EventLogger  │
│ Score    │       │ query        │
└────┬─────┘       └──────────────┘
     │
     ▼
┌──────────┐
│  Step 3  │
│ Session  │
│ Recon    │
└────┬─────┘
     │
     ├──────────────────┐
     │                  │
     ▼                  ▼
┌──────────┐     ┌──────────────┐
│  Step 4  │     │  Step 5      │
│ Song     │     │ Playlist     │
│ Impact   │     │ Impact       │
└────┬─────┘     └──────┬───────┘
     │                  │
     └────────┬─────────┘
              │
              ▼
       ┌──────────┐
       │  Step 6  │
       │ Historical│
       │ Engine   │
       └────┬─────┘
            │
            ▼
       ┌──────────┐
       │  Step 7  │
       │ Wiring + │
       │ Settings │
       └──────────┘
```

### Wave 0: Prerequisite (MUST COMPLETE FIRST)

| Agent | Steps | Files Modified |
|-------|-------|-----------------------|
| **Agent P** | Step 0 (Info.plist + Constants) | `iOS/Info.plist`, `Shared/Utilities/Constants.swift` |

**Why first:** Without `BGTaskSchedulerPermittedIdentifiers` in Info.plist, all BGTask registrations crash. Without `BackfillConstants`, Steps 3-6 cannot reference batch sizes and watermark keys. This is a blocking prerequisite.

### Wave 1: Sequential agents

After Wave 0 completes:

| Agent | Steps | Files Created/Modified |
|-------|-------|-----------------------|
| **Agent A** | Step 1 (HealthKit queries) + Step 2 (ImpactScore) + Step 7a (EventLogger query) | `Shared/Services/HealthKitService.swift`, `Brain/Historical/ImpactScore.swift`, `Shared/Services/EventLogger.swift` |
| **Agent B** | Step 3 (SessionReconstructor) — **after Agent A completes** | `Brain/Historical/SessionReconstructor.swift` |

**Why sequential:** Agent B's SessionReconstructor uses `SleepSession` and `WorkoutSession` types defined by Agent A. Agent A must complete first so these types exist.

### Wave 2: Two parallel agents (SPAWN 2 AGENTS IN PARALLEL)

After Wave 1 completes:

| Agent | Steps | Files Created/Modified |
|-------|-------|-----------------------|
| **Agent C** | Step 4 (SongImpactCalculator) | `Brain/Historical/SongImpactCalculator.swift` |
| **Agent D** | Step 5 (PlaylistImpactCalculator) | `Brain/Historical/PlaylistImpactCalculator.swift` |

**Why parallel:** These are independent calculators that both read from Core Data but write to different entity types. No file conflicts.

### Wave 3: Single agent

After Wave 2 completes:

| Agent | Steps | Files Created/Modified |
|-------|-------|-----------------------|
| **Agent E** | Step 6 (HistoricalEngine) + Step 7 (Wiring + Settings UI) | `Brain/Historical/HistoricalEngine.swift`, `iOS/ResonanceApp.swift`, `iOS/Views/SettingsView.swift` |

**Why sequential:** HistoricalEngine references all three calculators. Wiring modifies ResonanceApp.swift which must be done after all dependencies exist.

### Execution Timeline

```
Time -->
Wave 0: [Agent P: Step 0 (Info.plist + Constants)]
Wave 1: [Agent A: Steps 1+2+7a] --> [Agent B: Step 3]    <-- sequential
Wave 2:                              [Agent C: Step 4] [Agent D: Step 5]  <-- 2 parallel
Wave 3:                                                [Agent E: Steps 6+7]
```

Total: 4 waves, 6 agents, with 2 parallel in Wave 2.

---

## 12.10 Verification

1. **Build all targets**: `xcodegen generate` → Build Resonance scheme
2. **HealthKit sleep/workout queries** (device only):
   - Call `fetchSleepAnalysis(from: weekAgo, to: now)` — verify SleepSession array returned
   - Call `fetchWorkouts(from: weekAgo, to: now)` — verify WorkoutSession array returned
3. **Session reconstruction**:
   - Ensure at least 3-5 PlaybackEvents exist from Phase 3 testing
   - Run `sessionReconstructor.reconstructSessions()`
   - Verify HistoricalSession entities created in Core Data
   - Verify events grouped correctly (check `session` relationship on PlaybackEvent)
   - Verify biometric summaries populated (avgHeartRate, deltaHRV, etc.)
   - Verify context/timeOfDay inferred correctly
4. **Song impact calculation**:
   - Run `songImpactCalculator.calculateImpacts()`
   - Verify SongEffect entities created for songs with events
   - Check that calmScore/focusScore/energyScore are not all 0.5 (default)
   - Verify sampleCount > 0 and confidenceLevel > 0
   - Verify Song entity aggregate scores updated
5. **Playlist impact calculation**:
   - Run `playlistImpactCalculator.calculatePlaylistImpacts()`
   - Verify Playlist `avgCalmEffect`, `avgFocusEffect`, `avgEnergyEffect` are populated
   - Verify `contextAssociations` contains valid JSON
6. **Full pipeline (HistoricalEngine)**:
   - Run `historicalEngine.runFullBackfill()`
   - Verify progress updates arrive on `@Published progress`
   - Verify watermark set in UserDefaults
   - Run again → verify incremental (only new events processed)
7. **Background task**:
   - Use Xcode debug menu "Simulate Background Processing" for `com.y4sh.resonance.historicalAnalysis`
   - Verify incremental backfill runs and completes
8. **Settings UI**:
   - Open Settings → verify "Historical Analysis" section visible
   - Tap "Run Full Backfill" → verify progress displayed
   - After completion → verify "Last run" date updated

---

*End of Part 12*

---

*End of Plan Document*

*Version: 1.3*
*Last Updated: 2026-02-21*
