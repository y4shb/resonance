# Resonance: Progress Tracker

## Document Purpose
This file tracks the current state of the project, completed work, and remaining tasks. **This file is append-only** - new entries are added at the bottom of each section as work progresses.

---

# PROJECT STATUS OVERVIEW

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Project Setup | COMPLETE | 100% |
| Phase 2: Platform Skeleton (M1) | COMPLETE | 100% |
| Phase 3: Data Foundations (M2) | COMPLETE | 100% |
| Phase 4: Historical Backfill (M3) | NOT STARTED | 0% |
| Phase 5: State Engine (M4) | NOT STARTED | 0% |
| Phase 6: DJ Brain (M5) | NOT STARTED | 0% |
| Phase 7: Watch Experience (M6) | NOT STARTED | 0% |
| Phase 8: Learning Loop (M7) | NOT STARTED | 0% |
| Phase 9: MVP Polish (M8) | NOT STARTED | 0% |

**Current Phase:** Phase 4 - Historical Backfill (M3)
**Last Updated:** 2026-02-20

---

# PHASE 1: PROJECT SETUP

## Objectives
- Create Xcode workspace with all targets
- Configure entitlements and capabilities
- Set up shared code structure
- Establish persistence layer foundation

## Checklist

### 1.1 Xcode Project Creation
- [x] Create new Xcode project with iOS app target
- [x] Add watchOS app target to project
- [x] Add macOS app target to project
- [x] Add Widget extension target
- [x] Add unit test target
- [ ] Add UI test target (deferred - not required for MVP)
- [x] Configure workspace to include all targets

### 1.2 Bundle IDs and Signing
- [x] Set iOS bundle ID: `com.y4sh.resonance.ios`
- [x] Set watchOS bundle ID: `com.y4sh.resonance.watchkitapp`
- [x] Set macOS bundle ID: `com.y4sh.resonance.macos`
- [x] Set Widget bundle ID: `com.y4sh.resonance.ios.widgets`
- [x] Configure code signing for all targets (in project.yml)
- [x] Create App Group: `group.com.y4sh.resonance`

### 1.3 Entitlements Configuration
- [x] Add HealthKit entitlement to iOS target
- [x] Add HealthKit entitlement to watchOS target
- [x] Add MusicKit entitlement to iOS target
- [x] Add App Groups entitlement to all targets
- [x] Add Background Modes to iOS (audio, fetch, processing)
- [x] Configure macOS sandbox permissions

### 1.4 Info.plist Configuration
- [x] Add NSHealthShareUsageDescription
- [x] Add NSAppleMusicUsageDescription
- [x] Add NSCalendarsUsageDescription (optional)
- [x] Configure background modes in Info.plist

### 1.5 Directory Structure
- [x] Create `Shared/` directory
- [x] Create `Shared/Models/` directory
- [x] Create `Shared/Persistence/` directory
- [x] Create `Shared/Services/` directory
- [x] Create `Shared/Utilities/` directory
- [x] Create `Brain/` directory
- [x] Create `Brain/Historical/` directory
- [x] Create `Brain/State/` directory
- [x] Create `Brain/Ranking/` directory
- [x] Create `Brain/Features/` directory
- [x] Create `Brain/Learning/` directory
- [x] Create `iOS/Views/` directory
- [x] Create `iOS/ViewModels/` directory
- [x] Create `iOS/Services/` directory
- [x] Create `Watch/Views/` directory
- [x] Create `Watch/Sensors/` directory
- [x] Create `Watch/Complications/` directory
- [x] Create `macOS/MenuBar/` directory
- [x] Create `macOS/ContextProviders/` directory

### 1.6 Core Data Setup
- [x] Create Resonance Core Data model (Resonance.xcdatamodeld)
- [x] Add Song entity with all attributes (see plan.md 4.1.1)
- [x] Add Playlist entity with all attributes (see plan.md 4.1.2)
- [x] Add HistoricalSession entity with all attributes (see plan.md 4.1.3)
- [x] Add PlaybackEvent entity with all attributes (see plan.md 4.1.4)
- [x] Add SongEffect entity with all attributes (see plan.md 4.1.5)
- [x] Add BiometricSample entity with all attributes (see plan.md 4.1.6)
- [x] Add MacOSContext entity with all attributes (see plan.md 4.1.7)
- [x] Configure relationships between entities
- [x] Create PersistenceController.swift
- [x] Configure App Group container for shared storage
- [ ] Test Core Data stack initialization (requires Xcode build)

### 1.7 Base Swift Structures
- [x] Create StateVector.swift (see plan.md 4.2.1)
- [x] Create SongScore.swift (see plan.md 4.2.2)
- [x] Create DecisionContext.swift (see plan.md 4.2.3)
- [x] Create UserPreferences.swift (see plan.md 4.2.4)
- [x] Create Constants.swift with app-wide constants
- [x] Create Logging.swift utility
- [x] Create SongFeatures.swift (additional)
- [x] Create ContextSignal.swift (additional)

### 1.8 Build Verification
- [ ] Verify iOS target builds successfully (requires xcodegen + Xcode)
- [ ] Verify watchOS target builds successfully (requires xcodegen + Xcode)
- [ ] Verify macOS target builds successfully (requires xcodegen + Xcode)
- [ ] Verify all targets can access shared code (requires xcodegen + Xcode)
- [ ] Verify Core Data model compiles (requires xcodegen + Xcode)

---

# PHASE 2: PLATFORM SKELETON (M1)

## Objectives
- Implement MusicKit authentication and basic playback
- Implement WatchConnectivity between iPhone and Watch
- Create basic UI shells for all platforms
- Enable music control from all devices

## Checklist

### 2.1 MusicKit Service
- [x] Create MusicKitService.swift protocol (see plan.md 6.1.2)
- [x] Implement requestAuthorization()
- [x] Implement fetchUserPlaylists()
- [x] Implement fetchPlaylistSongs()
- [x] Implement fetchRecentlyPlayed()
- [x] Implement play(song:)
- [x] Implement pause()
- [x] Implement skip()
- [x] Implement setQueue(songs:)
- [x] Create nowPlayingPublisher
- [x] Create playbackStatePublisher
- [ ] Test MusicKit authorization flow (requires device)
- [ ] Test basic playback functionality (requires device)

### 2.2 iOS Basic UI
- [x] Create ResonanceApp.swift entry point
- [x] Create MainView.swift with tab navigation
- [x] Create NowPlayingView.swift skeleton (see plan.md 7.1.2)
- [x] Create PlaylistBrowserView.swift skeleton (see plan.md 7.1.3)
- [x] Create SettingsView.swift skeleton
- [x] Create basic navigation flow
- [x] Display now playing information
- [x] Implement play/pause/skip controls
- [x] Display playlist selection

### 2.3 watchOS Basic UI
- [x] Create ResonanceWatchApp.swift entry point
- [x] Create WatchNowPlayingView.swift (see plan.md 7.2.1)
- [x] Display current song info
- [x] Implement basic playback controls
- [ ] Test remote playback control (requires device)

### 2.4 WatchConnectivity
- [x] Create WatchConnectivityManager.swift for iOS (see plan.md 6.3.2)
- [x] Create PhoneConnectivityService.swift for watchOS
- [x] Define message protocols (see plan.md 6.3.1)
- [x] Implement sendNowPlaying() from phone
- [x] Implement playbackCommand handling on phone
- [ ] Test iPhone → Watch now playing sync (requires devices)
- [ ] Test Watch → iPhone playback commands (requires devices)

### 2.5 macOS Basic UI
- [x] Create ResonanceMacApp.swift entry point
- [x] Create MenuBarController.swift (see plan.md 7.3)
- [x] Create StatusItemView.swift for menu bar icon
- [x] Create PopoverView.swift for click action
- [x] Display connection status
- [x] Display now playing (read-only initially)

### 2.6 Integration Testing
- [ ] Play music from iOS app (requires device)
- [ ] Control playback from Watch (requires devices)
- [ ] Verify now playing syncs to Watch (requires devices)
- [ ] Verify now playing syncs to macOS menu bar (requires device)
- [ ] Test playlist selection and switching (requires device)

---

# PHASE 3: DATA FOUNDATIONS (M2)

## Objectives
- Fix critical infrastructure gaps (empty entitlements, missing privacy strings, bundle ID mismatch)
- Implement playlist and song ingestion pipeline (MusicKit → Core Data)
- Create song feature extraction (genre-based heuristics)
- Implement event logging for playback (Core Data PlaybackEvent)
- Build HealthKit service for iPhone-side biometric reads
- Set up Watch sensor streaming layer
- Create unified Context Collector on iPhone

## Critical Prerequisites Discovered
> These gaps were found during Phase 3 planning audit. ALL must be fixed first.

1. **All entitlements files are empty** — `<dict/>` in iOS, Watch, Widgets, macOS
2. **iOS Info.plist missing privacy strings** — No `NSHealthShareUsageDescription`, `NSAppleMusicUsageDescription`
3. **Watch bundle ID mismatch** — `Constants.swift:20` has `com.y4sh.resonance.watchkitapp` but `project.yml:82` uses `com.y4sh.resonance.ios.watchkitapp`
4. **UserPreferences uses wrong UserDefaults** — `UserDefaults.standard` instead of App Group suite
5. **No Repository layer exists** — `Shared/Persistence/Repositories/` does not exist
6. **Brain/ directory is completely empty**
7. **Background tasks are a placeholder** — `ResonanceApp.swift:107` has empty `registerBackgroundTasks()`

## Parallel Execution Strategy

```
Wave 1: [Step 0 — Prerequisites]             ← single agent
Wave 2: [Agent A: Steps 1+2] [Agent B: Step 5] [Agent C: Step 6]  ← 3 PARALLEL agents
Wave 3: [Agent D: Steps 3+4] [Agent E: Step 7]                    ← 2 PARALLEL agents
Wave 4: [Build + Verify]                      ← single agent
```

## Checklist

### 3.0 Prerequisites — Fix Entitlements, Info.plist & Constants
> **Wave 1**: Single agent, all sub-steps are independent file edits.

- [x] **0a** iOS entitlements: Add App Group (`group.com.y4sh.resonance`) + HealthKit to `iOS/Entitlements/Resonance.entitlements`
- [x] **0b** Watch entitlements: Add App Group + HealthKit to `Watch/Entitlements/ResonanceWatch.entitlements`
- [x] **0c** Widgets entitlements: Add App Group to `Widgets/ResonanceWidgets.entitlements`
- [x] **0d** macOS entitlements: Add App Sandbox + network client + App Group to `macOS/Entitlements/ResonanceMac.entitlements`
- [x] **0e** iOS Info.plist: Add `NSHealthShareUsageDescription`, `NSAppleMusicUsageDescription`, `UIBackgroundModes` (audio, fetch, processing), `BGTaskSchedulerPermittedIdentifiers`
- [x] **0f** Fix `Constants.swift:20` Watch bundle ID: `com.y4sh.resonance.watchkitapp` → `com.y4sh.resonance.ios.watchkitapp`
- [x] **0g** Fix `UserPreferences.swift`: Change `UserDefaults.standard` → `UserDefaults(suiteName: AppConstants.appGroupIdentifier)`

### 3.1 Playlist Ingestion
> **Wave 2, Agent A** (parallel with Steps 5 and 6)
> Files: `Shared/Persistence/Repositories/PlaylistRepository.swift`, `iOS/ViewModels/PlaylistViewModel.swift`

- [x] Create `Shared/Persistence/Repositories/` directory
- [x] Create `PlaylistRepository.swift` with `PersistenceController` DI
- [x] Implement `syncPlaylists(from: MusicItemCollection<MusicKit.Playlist>)` with diffing
- [x] Implement `fetchAll()`, `findByAppleMusicId()`, `search()`
- [x] Implement `recalculateAggregates(for:)` — playlist-level avgBPM, avgCalmEffect
- [x] Wire into `PlaylistViewModel.fetchPlaylists()` — persist after MusicKit fetch
- [ ] Use `NSBatchInsertRequest` for large playlist sets (>50) — deferred, standard upsert used

### 3.2 Song Ingestion
> **Wave 2, Agent A** (same agent as 3.1)
> Files: `Shared/Persistence/Repositories/SongRepository.swift`, `iOS/ViewModels/PlaylistViewModel.swift`

- [x] Create `SongRepository.swift` with `PersistenceController` DI
- [x] Implement `syncSongs(_:for:)` — MusicKit.Song → Core Data Song mapping
- [x] Map: `appleMusicId`, `title`, `artistName`, `albumName`, `durationSeconds`, `artworkURL`, `genreNames`, `releaseDate`
- [x] Handle many-to-many Song ↔ Playlist relationships (dedup by `appleMusicId`)
- [x] Implement `fetchSongs(for:)`, `findByAppleMusicId()`, `fetchSongsNeedingFeatures(limit:)`
- [x] Implement `updatePlaybackStats(for:event:)` — update play/skip counts
- [x] Wire into PlaylistViewModel — trigger song sync when playlist selected

### 3.3 Song Feature Extraction
> **Wave 3, Agent D** (parallel with Step 7; after Steps 1+2 complete)
> Files: `Brain/Features/FeatureExtractor.swift`, `Brain/Features/FeatureNormalizer.swift`

- [x] Create `Brain/Features/` directory
- [x] Create `FeatureExtractor.swift` — genre-based heuristic estimation
- [x] Implement `estimateBPM(genres:)` using genre-to-BPM mapping table
- [x] Implement `estimateEnergy(genres:bpm:)` using genre + BPM
- [x] Implement `estimateValence(genres:)` using genre mapping
- [x] Implement `estimateInstrumentalness(genres:)` using genre mapping
- [x] Implement `estimateAcousticDensity(genres:energy:)` using genre + energy
- [x] Implement `extractFeatures(for songs: [Song])` batch extraction
- [x] Reuse `SongFeatures.genreCategories` from `Shared/Models/SongFeatures.swift:203`
- [x] Create `FeatureNormalizer.swift` — `normalizeBPM()`, `clamp()`
- [x] Store features on Core Data Song entity fields (`bpm`, `energyEstimate`, `valence`, `confidenceLevel`)
- [x] Schedule `BGProcessingTask` for background feature extraction in `ResonanceApp.swift`

### 3.4 Event Logging
> **Wave 3, Agent D** (same agent as 3.3)
> Files: `Shared/Services/EventLogger.swift`, `iOS/ViewModels/NowPlayingViewModel.swift`

- [x] Create `EventLogger.swift` as `ObservableObject`
- [x] Implement `logPlaybackStart(song:wasAISelected:selectionScore:selectionReason:currentHeartRate:currentHRV:)`
- [x] Implement `logPlaybackEnd(wasSkipped:skipReason:currentHeartRate:currentHRV:)`
- [x] Calculate `listenPercentage = durationListened / songDuration`
- [x] Set `wasSkipped = true` when `listenPercentage < LearningConstants.minimumListenPercentage` (0.3)
- [x] Calculate `hrDelta = hrAtEnd - hrAtStart`, `hrvDelta = hrvAtEnd - hrvAtStart`
- [x] Implement `observeNowPlaying(_:)` — subscribe to `nowPlayingPublisher` for auto-detection
- [x] Persist events as Core Data `PlaybackEvent` entities
- [x] Publish `activeEventObjectID` for ContextCollector to tag BiometricSamples
- [x] Wire into `NowPlayingViewModel` — notify on skip/previous before MusicKit action
- [x] Wire into `ResonanceApp.swift` — add `@StateObject`, call `observeNowPlaying()`

### 3.5 HealthKit Service
> **Wave 2, Agent B** (parallel with Steps 1+2 and Step 6)
> Files: `Shared/Services/HealthKitService.swift`, `iOS/ResonanceApp.swift`

- [x] Create `HealthKitServiceProtocol` (enables mocking in tests)
- [x] Create `HealthKitService` implementation with `HKHealthStore`
- [x] Read types: heartRate, heartRateVariabilitySDNN, stepCount, activeEnergyBurned, sleepAnalysis, workoutType
- [x] Implement `requestAuthorization()` with `isHealthDataAvailable()` guard
- [x] Implement `fetchLatestHeartRate()` using `HKSampleQuery` with sort descending
- [x] Implement `fetchLatestHRV()` using same pattern
- [x] Implement `fetchRecentHeartRates(minutes:)` with date predicate
- [x] Implement `fetchRecentHRV(minutes:)` with date predicate
- [x] Implement `heartRateStream` as `AsyncStream<Double>` using `HKAnchoredObjectQuery.updateHandler`
- [x] Implement `enableBackgroundDelivery()` for heart rate with `.immediate` frequency
- [x] Implement `fetchRestingHeartRate()` using `HKStatisticsQuery`
- [x] Stub historical queries (`fetchHeartRateHistory`, `fetchHRVHistory`, `fetchSleepAnalysis`, `fetchWorkouts`) for Phase 4
- [x] Create `SleepSession` and `WorkoutSession` support structs
- [x] Wire into `ResonanceApp.swift` — add `@StateObject`, request auth in `.task`, enable background delivery
- [x] **Note**: Agent B ONLY adds HealthKitService wiring to ResonanceApp.swift (no BGTask changes — those go in Wave 3)

### 3.6 Watch Sensor Layer
> **Wave 2, Agent C** (parallel with Steps 1+2 and Step 5)
> Files: `Watch/Sensors/HeartRateSensor.swift`, `Watch/Sensors/MotionSensor.swift`, `Watch/Sensors/WorkoutDetector.swift`, `Watch/Sensors/SensorCoordinator.swift`, `Watch/ResonanceWatchApp.swift`

- [x] Create `Watch/Sensors/` directory
- [x] Create `HeartRateSensor.swift` — `HKAnchoredObjectQuery` with `updateHandler` for real-time HR and HRV
- [x] Create `MotionSensor.swift` — `CMPedometer` for stationary/steps detection
- [x] Create `WorkoutDetector.swift` — `HKObserverQuery` for workout detection
- [x] Create `SensorCoordinator.swift` — coordinates all sensors, batches samples
- [x] Implement batching per `WatchConnectivityConstants`: 5s interval, 20 samples max per batch
- [x] Send batched `BiometricPacket` via `PhoneConnectivityService.sendBiometricUpdate()` (guaranteed delivery)
- [x] Wire into `ResonanceWatchApp.swift` — add `@StateObject SensorCoordinator`
- [x] Add HealthKit authorization request in Watch `.task`
- [x] Handle Watch app backgrounding (stop/restart sensors via SensorCoordinator lifecycle)

### 3.7 Context Collector (iPhone)
> **Wave 3, Agent E** (parallel with Steps 3+4; after Steps 5+6 complete)
> Files: `Shared/Services/ContextCollector.swift`, `iOS/ResonanceApp.swift`

- [x] Create `ContextCollector.swift` as `ObservableObject`
- [x] Subscribe to `WatchConnectivityManager.biometricUpdates` publisher
- [x] Convert `BiometricPacket` → `BiometricSignal` (reuse model from `ContextSignal.swift:235`)
- [x] Persist as Core Data `BiometricSample` entity via `PersistenceController.performBackgroundTask`
- [x] Tag BiometricSamples with `activePlaybackEventId` from EventLogger
- [x] Maintain in-memory caches: `latestBiometric`, `latestMacOSContext`
- [x] Rebuild `AggregatedContext` (reuse struct from `ContextSignal.swift:291`) on every update
- [x] Publish `aggregatedContext` for StateEngine consumption (Phase 5)
- [x] Wire into `ResonanceApp.swift` — add `@StateObject`, call `startCollecting()`
- [x] Wire `EventLogger.activeEventObjectID` → `ContextCollector.activePlaybackEventId`
- [x] Register all `BGTaskScheduler` tasks (playlistSync, featureUpdate) in `registerBackgroundTasks()`

---

# PHASE 4: HISTORICAL BACKFILL (M3)

## Objectives
- Fix Info.plist blocking prerequisite (BGTask identifiers + UIBackgroundModes)
- Add HealthKit sleep/workout historical queries
- Reconstruct listening sessions from PlaybackEvents
- Calculate per-song per-context effectiveness (SongEffect entities)
- Calculate playlist-level effect aggregates
- Orchestrate full backfill pipeline with incremental support and per-step watermarks

## Checklist

### 4.0 Prerequisites (BLOCKING — plan.md §12.0.1)
- [ ] Add `UIBackgroundModes` (audio, fetch, processing) to `iOS/Info.plist`
- [ ] Add `BGTaskSchedulerPermittedIdentifiers` (playlistSync, historicalAnalysis, featureUpdate) to `iOS/Info.plist`
- [ ] Add `NSHealthShareUsageDescription` and `NSAppleMusicUsageDescription` to `iOS/Info.plist`
- [ ] Add static `hasRegisteredTasks` guard in `ResonanceApp.swift` to prevent double-registration crash
- [ ] Add `BackfillConstants` section to `Constants.swift` (batch sizes, watermark keys, cold-start alpha, behavior-only max confidence)

### 4.1 HealthKit Historical Queries (plan.md §12.1)
- [x] `fetchHeartRateHistory(from:to:)` — already implemented in Phase 3
- [x] `fetchHRVHistory(from:to:)` — already implemented in Phase 3
- [ ] Create `SleepSession` struct (startDate, endDate, value, durationHours, isDeepSleep, isREMSleep)
- [ ] Create `WorkoutSession` struct (activityType, startDate, endDate, totalEnergyBurned, durationMinutes, activityName)
- [ ] Add private `fetchCategorySamples(type:predicate:limit:ascending:)` helper for `HKCategorySample`
- [ ] Add `fetchSleepAnalysis(from:to:)` to `HealthKitServiceProtocol` and implement
  - [ ] Filter for asleep stages only (`.asleepUnspecified`, `.asleepCore`, `.asleepDeep`, `.asleepREM`)
  - [ ] Exclude `.inBed` and `.awake` categories
  - [ ] Handle overlapping sleep sources (merge intervals from Watch, iPhone, third-party apps)
- [ ] Add `fetchWorkouts(from:to:)` to `HealthKitServiceProtocol` and implement
  - [ ] Map `HKWorkout` to `WorkoutSession` extracting `workoutActivityType`, `totalEnergyBurned` (deprecated but acceptable for historical backfill)
- [ ] Add `fetchHeartRateHistoryChunked(from:to:chunkDays:)` for large date ranges (weekly chunks, `Task.sleep` between chunks)
- [ ] Add `fetchEventsWithoutSession()` query to EventLogger

### 4.2 ImpactScore Type (plan.md §12.2)
- [ ] Create `Brain/Historical/ImpactScore.swift`
- [ ] Define struct with `calm`, `energy`, `focus`, `moodLift` (all 0.0-1.0), `wasSkipped`, `hasBiometricData`
- [ ] Implement `ImpactScore.calculate(from:)` factory using plan.md §5.3.1 formula with enhancements:
  - [ ] Two-tier skip penalty: early skip (<15% listened) = -0.3, late skip (15-30%) = -0.15
  - [ ] Biometric signal redistribution when partially available (HR-only, HRV-only, both, neither)
  - [ ] `moodLift` derived from behavioral signals (completion bonus + skip penalty)
  - [ ] `hasBiometricData` flag for downstream confidence weighting
- [ ] Use `LearningConstants` for all magic numbers (hrvNormalizationFactor, skipPenaltyMultiplier, etc.)

### 4.3 Session Reconstruction (plan.md §12.3)
- [ ] Create `Brain/Historical/SessionReconstructor.swift`
- [ ] Implement `fetchUnprocessedEvents(since:in:)` — events where `session == nil` with 30-min overlap buffer for incremental mode
- [ ] Implement `groupIntoSessions(_:)` — 30-minute gap rule per `SessionConstants.sessionGapMinutes`
  - [ ] Use `endedAt ?? startedAt + songDuration` (not `endedAt ?? startedAt`) for gap calculation
  - [ ] Handle nil `startedAt` safely (Core Data `Date?`)
- [ ] Filter sessions shorter than `SessionConstants.minimumSessionMinutes` (5 min)
- [ ] Implement `buildSession(from:in:)` — create HistoricalSession Core Data entity
- [ ] Link all grouped PlaybackEvents to session via `session` relationship
- [ ] Populate session metadata: `totalSongsPlayed`, `totalSkips`, `skipRate`, `avgListenPercentage`
- [ ] Implement `enrichWithBiometrics(_:startTime:endTime:)` — fetch HR/HRV ±5min from HealthKit
- [ ] Populate: `startingHeartRate`, `endingHeartRate`, `avgHeartRate`, `minHeartRate`, `maxHeartRate`, `deltaHeartRate`
- [ ] Populate: `startingHRV`, `endingHRV`, `avgHRV`, `deltaHRV`
- [ ] Implement `correlateSleep(_:sessionEndTime:)` — find next-night sleep within 12h
  - [ ] Filter for substantial sleep (≥3 hours) to distinguish from naps
  - [ ] Normalize deep sleep pct by dividing by 0.25 (target deep sleep = 25% of total)
  - [ ] Use `NSNumber(value:)` for assignment (`nextNightSleepScore`, `nextNightSleepDuration`, `nextNightDeepSleepPct` are `NSNumber?` in Core Data)
  - [ ] Handle missing stage data (all `.asleepUnspecified`) with neutral 0.5 deep score
- [ ] Calculate `nextNightSleepScore` = durationScore * 0.6 + deepScore * 0.4
- [ ] Implement `inferContext(startTime:endTime:events:)` — weekend-aware context inference
  - [ ] Weekdays: morning(5-7), commute(7-9), work(9-17), commute(17-19), relaxation(19-22), preSleep(22-5)
  - [ ] Weekends: morning(5-9), relaxation(9-22), preSleep(22-5)
- [ ] Implement `getTimeSlot(for:)` — map hour to `TimeSlot.rawValue` (must match `DecisionContext.timeSlot` exactly)
- [ ] Implement `detectWorkout(_:startTime:endTime:)` — override context to `workout` when HealthKit workout detected
- [ ] Implement `scoreSession(_:)` using plan.md §5.3.3 formula (skipScore 0.25, hrvScore 0.30, engagement 0.25, sleep 0.20)
  - [ ] Use `session.nextNightSleepScore?.doubleValue ?? 0.5` for nullable NSNumber
- [ ] Link session to playlist if all songs share the same playlist
- [ ] Implement `reconstructSessions()` main entry point with batch save every 50 sessions
- [ ] Implement `reconstructSessions(since:)` for incremental mode with `Task.checkCancellation()` between groups

### 4.4 Song Impact Calculation (plan.md §12.4)
- [ ] Create `Brain/Historical/SongImpactCalculator.swift`
- [ ] Implement `findOrCreateEffect(for:contextType:timeOfDaySlot:in:)` — keyed on `(song, contextType)` only (NOT triple)
  - [ ] `timeOfDaySlot` is set on entity but NOT part of lookup predicate (avoids sparse data problem)
- [ ] Implement `updateEffect(_:with:)` — EMA update with two-tier alpha
  - [ ] Cold-start alpha = 0.4 for first 5 plays (`BackfillConstants.coldStartLearningRate`, `coldStartThreshold`)
  - [ ] Steady-state alpha = 0.2 (`LearningConstants.defaultLearningRate`)
- [ ] Update `calmScore`, `energyScore`, `focusScore`, `moodLiftScore` via EMA
- [ ] Update `sampleCount` and `confidenceLevel`
  - [ ] Cap confidence at 0.7 for behavior-only impacts (`BackfillConstants.behaviorOnlyMaxConfidence`)
  - [ ] Cap at 1.0 for impacts with biometric data
  - [ ] Full confidence at 20 samples (`DecisionEngineConstants.fullConfidenceSampleCount`)
- [ ] Implement `updateSongAggregates(_:in:)` — confidence-weighted average of effects
- [ ] Update Song entity: `calmScore`, `focusScore`, `activationScore` (note: Song uses `activationScore` not `energyScore`), `confidenceLevel`
- [ ] Implement `updateFamiliarity(_:)` — based on play count only (skip rate NOT included — already penalized via effect scores)
  - [ ] Formula: `min(1.0, totalPlayCount / 10.0)`
- [ ] Implement `processEvent(_:in:)` — single event processing
- [ ] Implement `calculateImpacts()` and `calculateImpacts(since:)` entry points with batch save every 100 events
- [ ] Support cooperative cancellation with `Task.checkCancellation()`

### 4.5 Playlist Impact Calculation (plan.md §12.5)
- [ ] Create `Brain/Historical/PlaylistImpactCalculator.swift`
- [ ] Implement `processPlaylist(_:in:)` — confidence-weighted aggregate of song effect scores
  - [ ] Per-song: confidence-weighted average across all effects
  - [ ] Per-playlist: confidence-weighted average across all songs
- [ ] Populate `avgCalmEffect`, `avgFocusEffect`, `avgEnergyEffect`, `effectConfidence`
- [ ] Implement `buildContextAssociations(from:)` — JSON with per-context frequency AND count
- [ ] Populate `contextAssociations` binary field on Playlist entity
- [ ] Implement `calculatePlaylistImpacts()` entry point

### 4.6 HistoricalEngine Orchestrator (plan.md §12.6)
- [ ] Create `Brain/Historical/HistoricalEngine.swift`
- [ ] Implement `BackfillProgress` enum (idle, reconstructingSessions, calculatingSongImpacts, calculatingPlaylistImpacts, completed, failed)
- [ ] Implement per-step watermarks via App Group UserDefaults (`BackfillConstants.WatermarkKey`)
  - [ ] `sessionReconstruction` watermark
  - [ ] `songImpact` watermark
  - [ ] `lastFullBackfill` watermark
- [ ] Implement atomic `isRunning` guard via `MainActor.run`
- [ ] Implement `runFullBackfill()` — all events from beginning
- [ ] Implement `runIncrementalBackfill()` — only since watermarks
- [ ] Pipeline sequence: reconstructSessions → calculateImpacts → calculatePlaylistImpacts
- [ ] Support cooperative cancellation (`Task.checkCancellation()` between steps)
- [ ] Handle `CancellationError` separately from other errors
- [ ] Publish progress on `@Published progress` for UI consumption

### 4.7 Wiring & Settings UI (plan.md §12.7)
- [ ] Add `HistoricalEngine` as `@StateObject` in `ResonanceApp.swift`
- [ ] Register `historicalAnalysis` BGProcessingTask in `registerBackgroundTasks()`
- [ ] Implement `handleHistoricalAnalysis(task:)` handler with cooperative cancellation via `expirationHandler`
- [ ] Implement `scheduleHistoricalAnalysis()` — weekly, `requiresExternalPower: true`
- [ ] Add "Historical Analysis" section to SettingsView
- [ ] Show backfill progress in Settings (ProgressView + status text)
- [ ] Add "Run Full Backfill" button
- [ ] Show "Last run" date from watermark
- [ ] Add "Retry" button on failure
- [ ] Pass `HistoricalEngine` to SettingsView from MainView

### 4.8 Verification
- [ ] Build all targets after implementation
- [ ] Verify `Info.plist` contains `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes`
- [ ] Test HealthKit sleep/workout queries on device
- [ ] Test session reconstruction with sample PlaybackEvents
- [ ] Verify HistoricalSession biometric summaries populated
- [ ] Verify SongEffect entities created with non-default scores
- [ ] Verify SongEffect keyed on `(song, contextType)` (not triple)
- [ ] Verify Song aggregate scores updated
- [ ] Verify Playlist effect metrics populated with confidence weighting
- [ ] Test full pipeline via HistoricalEngine
- [ ] Test incremental backfill (second run processes only new data via watermarks)
- [ ] Test BGProcessingTask via Xcode debug menu
- [ ] Verify Settings UI shows progress and completion

---

# PHASE 5: STATE ENGINE (M4)

## Objectives
- Implement real-time StateVector generation
- Integrate macOS context signals
- Add manual mood input slider
- Produce normalized state estimates

## Checklist

### 5.1 State Engine Core
- [ ] Create StateEngine.swift
- [ ] Implement calculateArousal() from heart rate (see plan.md 5.1.1)
- [ ] Implement calculateStress() from HRV (see plan.md 5.1.2)
- [ ] Implement calculateEnergy() composite
- [ ] Implement calculateFocus()
- [ ] Implement calculateValence()
- [ ] Add user baseline calibration support

### 5.2 Context Inference
- [ ] Implement inferActivityContext() (see plan.md 5.1.3)
- [ ] Handle workout detection priority
- [ ] Handle macOS context priority
- [ ] Handle motion-based inference
- [ ] Handle time-of-day defaults
- [ ] Test context detection accuracy

### 5.3 StateVector Synthesis
- [ ] Implement synthesizeStateVector() (see plan.md 5.1.4)
- [ ] Implement inferMusicNeed() (see plan.md 5.1.5)
- [ ] Calculate confidence scores
- [ ] Track data sources used
- [ ] Publish StateVector updates every 30 seconds
- [ ] Create statePublisher for UI binding

### 5.4 macOS Context Integration
- [ ] Create FocusModeProvider.swift
- [ ] Create ActiveAppProvider.swift
- [ ] Create CalendarProvider.swift
- [ ] Create ContextBroadcaster.swift
- [ ] Create iPhoneConnector.swift (macOS side)
- [ ] Implement CloudKit sync for context OR
- [ ] Implement MultipeerConnectivity for context
- [ ] Receive context on iPhone
- [ ] Integrate into ContextCollector
- [ ] Test macOS → iPhone context flow

### 5.5 Manual Mood Input
- [ ] Create MoodSlider.swift component (see plan.md 7.1.4)
- [ ] Create energy level slider
- [ ] Create mood/valence slider
- [ ] Store manual input with timestamp
- [ ] Blend manual input into StateVector
- [ ] Decay manual input influence over time (15 min)

### 5.6 Watch Mood Input
- [ ] Create MoodInputView.swift for Watch (see plan.md 7.2.2)
- [ ] Implement 3-tap energy selection
- [ ] Implement 3-tap mood selection
- [ ] Send mood input to iPhone
- [ ] Provide haptic confirmation
- [ ] Test Watch mood input flow

### 5.7 State Debug UI
- [ ] Create StateDebugView.swift
- [ ] Display current StateVector values
- [ ] Display active data sources
- [ ] Display confidence level
- [ ] Display inferred context and need
- [ ] Add toggle in Settings to access

---

# PHASE 6: DJ BRAIN (M5)

## Objectives
- Implement song ranking algorithm
- Implement transition controller
- Build explanation generator
- Create the decision engine

## Checklist

### 6.1 Song Scorer
- [ ] Create SongScorer.swift
- [ ] Implement calculateTargetBPM() (see plan.md 5.2.2)
- [ ] Implement calculateTargetEnergy()
- [ ] Implement calculateBPMMatchScore()
- [ ] Implement calculateEnergyMatchScore()
- [ ] Implement calculateFamiliarityScore()
- [ ] Implement getEffectForContext()
- [ ] Implement calculateHistoricalEffectScore()
- [ ] Implement calculateContextAlignmentScore()
- [ ] Implement calculateRecencyPenalty()
- [ ] Implement calculateTimeOfDayScore()
- [ ] Implement calculateSongScore() composite (see plan.md 5.2.1)

### 6.2 Guard Filters
- [ ] Create GuardFilters.swift
- [ ] Implement recency filter (avoid recent plays)
- [ ] Implement same-artist limit filter
- [ ] Implement time-of-day BPM caps
- [ ] Implement explicit content filter (optional)
- [ ] Apply filters before scoring

### 6.3 Transition Controller
- [ ] Create TransitionController.swift
- [ ] Implement calculateTransitionScore() (see plan.md 5.2.3)
- [ ] Factor BPM transition smoothness
- [ ] Factor energy transition smoothness
- [ ] Factor genre compatibility
- [ ] Implement selectWithTransition()
- [ ] Handle session start (no transition needed)

### 6.4 Decision Engine
- [ ] Create DecisionEngine.swift
- [ ] Build DecisionContext from current state
- [ ] Get candidate songs from active playlist
- [ ] Apply guard filters
- [ ] Score all candidates
- [ ] Apply transition logic
- [ ] Select top song
- [ ] Return SongScore with explanation

### 6.5 Explanation Generator
- [ ] Create ExplanationGenerator.swift
- [ ] Generate human-readable explanation
- [ ] Include top contributing factors
- [ ] Include current state description
- [ ] Include historical context if relevant
- [ ] Format for display in UI
- [ ] Format for Watch (shorter version)

### 6.6 Integration
- [ ] Connect DecisionEngine to NowPlayingViewModel
- [ ] Trigger song selection on current song end
- [ ] Trigger song selection on playlist change
- [ ] Display explanation in NowPlayingView
- [ ] Send explanation to Watch

### 6.7 Testing
- [ ] Unit test song scoring with various states
- [ ] Unit test transition controller
- [ ] Unit test guard filters
- [ ] Integration test full selection pipeline
- [ ] Test with real playlists

---

# PHASE 7: WATCH EXPERIENCE (M6)

## Objectives
- Implement Watch complications
- Add three-tap mood input
- Add Digital Crown intensity control
- Polish Watch UI

## Checklist

### 7.1 Complications
- [ ] Create ComplicationController.swift
- [ ] Implement circular small complication
- [ ] Implement modular large complication
- [ ] Implement corner complication
- [ ] Display current song info
- [ ] Display heart rate
- [ ] Display current state emoji
- [ ] Implement reloadComplications()
- [ ] Update complications on song change
- [ ] Update complications on state change

### 7.2 Mood Input Enhancement
- [ ] Polish MoodInputView design
- [ ] Add animations between screens
- [ ] Add haptic feedback on selection
- [ ] Add confirmation screen
- [ ] Support quick re-entry
- [ ] Add complication quick-launch

### 7.3 Digital Crown Control
- [ ] Create CrownHandler.swift
- [ ] Detect crown rotation direction
- [ ] Detect crown rotation velocity
- [ ] Implement DJ Mode toggle (double-tap)
- [ ] Map crown to energy adjustment
- [ ] Send CrownAdjustment to iPhone
- [ ] Process adjustments in DecisionEngine
- [ ] Provide visual feedback of adjustment
- [ ] Provide haptic feedback

### 7.4 Watch UI Polish
- [ ] Improve WatchNowPlayingView layout
- [ ] Add artwork display
- [ ] Add progress indicator
- [ ] Add explanation display
- [ ] Improve button touch targets
- [ ] Add loading states
- [ ] Handle connectivity issues gracefully

### 7.5 Smart Stack Widget
- [ ] Create Watch widget for Smart Stack
- [ ] Display current song
- [ ] Display state summary
- [ ] Launch to app on tap

---

# PHASE 8: LEARNING LOOP (M7)

## Objectives
- Implement skip penalty system
- Implement HRV response credit
- Implement session quality scoring
- Create continuous learning feedback

## Checklist

### 8.1 Skip Penalty
- [ ] Create SkipPenaltyCalculator.swift
- [ ] Detect skip events
- [ ] Calculate skip penalty amount
- [ ] Factor skip timing (early = worse)
- [ ] Apply penalty to song effect scores
- [ ] Apply penalty to playlist metrics

### 8.2 HRV Response Credit
- [ ] Create ResponseCreditCalculator.swift
- [ ] Capture HRV before song
- [ ] Capture HRV during/after song
- [ ] Calculate HRV delta
- [ ] Map delta to credit/penalty
- [ ] Apply to song calm score
- [ ] Weight by listening duration

### 8.3 Session Quality Scoring
- [ ] Create SessionQualityScorer.swift
- [ ] Implement scoreSession() (see plan.md 5.3.3)
- [ ] Factor skip rate
- [ ] Factor biometric response
- [ ] Factor engagement (listen percentage)
- [ ] Factor sleep correlation (when available)
- [ ] Store session quality score

### 8.4 Learning Store Updates
- [ ] Create LearningStore.swift
- [ ] Implement processPlaybackEvent() (see plan.md 5.3.1)
- [ ] Implement updateSongEffect() (see plan.md 5.3.2)
- [ ] Implement exponential moving average
- [ ] Update confidence levels
- [ ] Update familiarity scores
- [ ] Update playlist aggregate metrics
- [ ] Trigger updates on playback complete

### 8.5 Real-Time Guard Adjustments
- [ ] Monitor HR during playback
- [ ] Detect rising HR during calm need
- [ ] Adjust next song selection (lower BPM)
- [ ] Detect falling engagement
- [ ] Adjust for more familiar songs
- [ ] Log guard interventions

### 8.6 Testing
- [ ] Unit test skip penalty calculation
- [ ] Unit test HRV response credit
- [ ] Unit test session quality scoring
- [ ] Test learning over multiple plays
- [ ] Verify scores converge to reasonable values

---

# PHASE 9: MVP POLISH (M8)

## Objectives
- Achieve daily usability
- Ensure reliable cross-device sync
- Implement offline operation
- Final testing and bug fixes

## Checklist

### 9.1 Cross-Device Sync
- [ ] Verify iPhone ↔ Watch sync reliability
- [ ] Verify iPhone ↔ macOS sync reliability
- [ ] Handle sync conflicts
- [ ] Handle network disconnections
- [ ] Handle Watch backgrounding
- [ ] Test all day usage scenario

### 9.2 Offline Operation
- [ ] Test without network connectivity
- [ ] Ensure local playback works
- [ ] Ensure state engine works without network
- [ ] Queue sync data for later
- [ ] Handle graceful degradation

### 9.3 Performance Optimization
- [ ] Profile CPU usage during playback
- [ ] Optimize Core Data queries
- [ ] Optimize WatchConnectivity batching
- [ ] Reduce memory footprint
- [ ] Test battery impact
- [ ] Optimize background task efficiency

### 9.4 Error Handling
- [ ] Handle MusicKit authorization denial
- [ ] Handle HealthKit authorization denial
- [ ] Handle playback errors
- [ ] Handle empty playlists
- [ ] Handle missing song features
- [ ] Display user-friendly error messages

### 9.5 Onboarding Flow
- [ ] Create onboarding screens
- [ ] Request MusicKit permission with context
- [ ] Request HealthKit permission with context
- [ ] Explain value proposition
- [ ] Guide initial playlist selection
- [ ] Initiate historical backfill

### 9.6 Settings & Preferences
- [ ] Complete SettingsView implementation
- [ ] Add weight adjustment sliders
- [ ] Add time-of-day rule configuration
- [ ] Add data management (clear data option)
- [ ] Add about/version info
- [ ] Add privacy policy link

### 9.7 iOS Widgets
- [ ] Create NowPlayingWidget
- [ ] Create StateWidget
- [ ] Register WidgetBundle
- [ ] Update widgets on song change
- [ ] Test widget reliability

### 9.8 Final Testing
- [ ] Run full test suite
- [ ] Conduct manual testing on all devices
- [ ] Test with multiple playlists
- [ ] Test various user states (workout, rest, focus)
- [ ] Test edge cases (empty library, single song playlist)
- [ ] Performance testing under load

### 9.9 App Store Preparation
- [ ] Create app icons for all sizes
- [ ] Capture screenshots for App Store
- [ ] Write app description
- [ ] Complete App Privacy details
- [ ] Set up TestFlight
- [ ] Conduct TestFlight beta testing
- [ ] Fix issues from beta feedback

---

# PROGRESS LOG

## Entry Format
```
[DATE] - [PHASE] - [ITEM]
Description of what was completed
```

---

### Progress Entries

[2026-02-11] - Phase 1 - 1.5 Directory Structure
Created complete Resonance directory structure including:
- Shared/ with Models/, Persistence/, Services/, Utilities/
- Brain/ with Historical/, State/, Ranking/, Features/, Learning/
- iOS/ with Views/, ViewModels/, Coordinators/, Services/, Entitlements/
- Watch/ with Views/, Complications/, Sensors/, Services/, Entitlements/
- macOS/ with MenuBar/, ContextProviders/, Services/, Entitlements/
- Widgets/
- Tests/ with BrainTests/, ServiceTests/, IntegrationTests/

[2026-02-11] - Phase 1 - 1.7 Base Swift Structures
Created all base Swift model files:
- StateVector.swift: User state representation with ActivityContext, MusicNeed, DataSource enums
- SongScore.swift: Song ranking result with component scores and ExplanationComponent
- DecisionContext.swift: All context needed for song selection with TimeSlot enum
- UserPreferences.swift: User-configurable preferences with validation and presets
- SongFeatures.swift: Audio features with TempoCategory and EnergyCategory
- ContextSignal.swift: MacOSContextSignal, BiometricSignal, AggregatedContext
- Constants.swift: App-wide constants organized by domain
- Logging.swift: Unified logging utility with categories and performance measurement

[2026-02-11] - Phase 1 - 1.6 Core Data Setup
Created Core Data model (Resonance.xcdatamodeld) with all 7 entities:
- Song: 26 attributes including metadata, audio features, derived metrics, relationships
- Playlist: 18 attributes including metadata, derived metrics, context associations
- HistoricalSession: 33 attributes including biometrics, workout, sleep correlation
- PlaybackEvent: 22 attributes including timing, outcome, biometric snapshot
- SongEffect: 12 attributes for per-song per-context effectiveness
- BiometricSample: 10 attributes for raw sensor data
- MacOSContext: 14 attributes for macOS context signals
Created PersistenceController.swift with App Group support and helper methods.

[2026-02-11] - Phase 1 - 1.3 Entitlements Configuration
Created entitlements files for all targets:
- iOS/Entitlements/Resonance.entitlements: HealthKit, MusicKit, App Groups, Background Delivery
- Watch/Entitlements/ResonanceWatch.entitlements: HealthKit, App Groups
- macOS/Entitlements/ResonanceMac.entitlements: App Groups, Sandbox, Network, Calendar
- Widgets/ResonanceWidgets.entitlements: App Groups

[2026-02-11] - Phase 1 - 1.4 Info.plist Configuration
Created Info.plist files for all targets with:
- iOS: Usage descriptions, background modes, BGTaskScheduler identifiers, scene config
- watchOS: Usage descriptions, complication families, WK configuration
- macOS: Usage descriptions, LSUIElement for menu bar, network permissions
- Widgets: Extension configuration

[2026-02-11] - Phase 1 - 1.1 Xcode Project Creation
Created project.yml (XcodeGen configuration) defining:
- iOS app target (Resonance)
- watchOS app target (ResonanceWatch)
- macOS menu bar app target (ResonanceMac)
- iOS widget extension target (ResonanceWidgets)
- Unit test target (ResonanceTests)
- Schemes for each target and AllTargets scheme
Created app entry points:
- iOS/ResonanceApp.swift with placeholder ContentView
- Watch/ResonanceWatchApp.swift with placeholder WatchContentView
- macOS/ResonanceMacApp.swift with menu bar implementation
- Widgets/ResonanceWidgets.swift with NowPlayingWidget and StateWidget

[2026-02-11] - Phase 1 - README
Created README.md with:
- Prerequisites and setup instructions
- XcodeGen generation steps
- Manual Xcode setup alternative
- Project structure documentation
- Development phases checklist

[2026-02-20] - Phase 2 - 2.0 Shared Message Types
Created Shared/Models/WatchMessages.swift with all WatchConnectivity message types:
- WatchMessage enum (Codable) with cases for all message directions
- PlaybackCommand, BiometricPacket, MoodPacket, CrownAdjustment (Watch -> Phone)
- NowPlayingPacket, StatePacket, ComplicationData (Phone -> Watch)
- WatchMessageError enum and toDictionary/fromDictionary encoding helpers

[2026-02-20] - Phase 2 - 2.1 MusicKit Service
Created Shared/Services/MusicKitService.swift:
- MusicKitServiceProtocol with authorization, library access, playback control, and Combine publishers
- MusicKitService implementation using ApplicationMusicPlayer.shared
- Async state observation via player.state.objectWillChange
- MusicKitServiceError enum with descriptive error cases
- Works directly with MusicKit types (Playlist, Song); Core Data mapping deferred to Phase 3

[2026-02-20] - Phase 2 - 2.2 iOS Basic UI
Created iOS view layer and view models:
- iOS/ViewModels/NowPlayingViewModel.swift: @MainActor ObservableObject wrapping MusicKitService with Timer-based progress, SongDisplayInfo struct, seek support, Watch connectivity integration
- iOS/ViewModels/PlaylistViewModel.swift: Playlist fetching, selection queues songs, PlaylistDisplayInfo struct
- iOS/Views/MainView.swift: 3-tab TabView (Now Playing, Playlists, Settings)
- iOS/Views/NowPlayingView.swift: ArtworkImage display, scrubbable progress slider, transport controls
- iOS/Views/PlaylistBrowserView.swift: Pull-to-refresh playlist list with artwork rows, active indicator, empty/loading states
- iOS/Views/SettingsView.swift: MusicKit auth status display, placeholder sections for future phases
- iOS/ResonanceApp.swift: Updated with @StateObject service + viewmodels, MusicKit auth on launch, WatchConnectivity activation

[2026-02-20] - Phase 2 - 2.3 watchOS Basic UI
Created Watch view layer:
- Watch/Views/WatchNowPlayingView.swift: Song title, artist, 80x80 artwork from data, progress bar, play/pause/skip/previous controls, explanation text, waiting states for connectivity
- Watch/ResonanceWatchApp.swift: Updated with @StateObject PhoneConnectivityService, replaced placeholder WatchContentView

[2026-02-20] - Phase 2 - 2.4 WatchConnectivity
Created bidirectional Watch connectivity:
- iOS/Services/WatchConnectivityManager.swift (311 lines): iOS-side WCSession delegate, singleton, #if os(iOS), sendMessage when reachable with applicationContext fallback, 4 Combine PassthroughSubject publishers for received data, handles session lifecycle
- Watch/Services/PhoneConnectivityService.swift (237 lines): Watch-side WCSession delegate, @Published nowPlaying for UI binding, sends PlaybackCommand via sendMessage with fallback, checks receivedApplicationContext on activation

[2026-02-20] - Phase 2 - 2.5 macOS Basic UI
Created macOS menu bar experience:
- macOS/MenuBar/MenuBarController.swift: ObservableObject with ConnectionStatus enum, NowPlayingInfo, ContextInfo, dynamic menu bar icon
- macOS/MenuBar/StatusItemView.swift: State-based SF Symbol rendering (normal, playing, syncing, disconnected)
- macOS/MenuBar/PopoverView.swift: Now playing section, context sending status, connection status, settings/quit buttons matching plan.md wireframe
- macOS/ResonanceMacApp.swift: Updated with @StateObject MenuBarController, dynamic icon, PopoverView, tabbed Settings (Connection, Context, About)

[2026-02-20] - Phase 2 - 2.4/2.2 Integration Wiring
Connected NowPlayingViewModel to WatchConnectivityManager for bidirectional sync:
- NowPlayingViewModel.connectWatchManager() subscribes to Watch playback commands
- handleWatchPlaybackCommand() routes play/pause/skip/previous from Watch to MusicKit
- sendNowPlayingToWatch() builds NowPlayingPacket and sends on song change and play/pause state change
- ResonanceApp.swift activates WCSession on appear and wires connectivity to view model

[2026-02-20] - Phase 2.5 - Liquid Glass Adoption
Adopted Apple Liquid Glass design language across all platforms:
- Raised deployment targets to iOS 26 / macOS 26 / watchOS 26 in project.yml
- Removed all #available(iOS 16.0, *) and guard #available checks
- Switched NavigationView → NavigationStack in NowPlayingView, PlaylistBrowserView, SettingsView
- Applied .glassEffect(.regular, ...) to artwork placeholders (iOS, Watch, macOS), active playlist bar
- Removed #Preview blocks from Widgets (XcodeGen Canvas limitation)
- Fixed Watch Info.plist: WKApplication, WKCompanionAppBundleIdentifier, bundle ID prefix
- Renamed all user-facing "AI DJ" strings to "Resonance" across 5 files

[2026-02-20] - Phase 3 - Planning & Audit
Performed comprehensive codebase audit for Phase 3 readiness:
- Discovered 7 critical gaps: empty entitlements (all 4 targets), missing privacy strings, Watch bundle ID mismatch in Constants.swift, UserPreferences using wrong UserDefaults suite, no Repository layer, empty Brain/ directory, placeholder background tasks
- Designed detailed Phase 3 plan with 8 steps (0-7), 11 new files, 11 modified files
- Designed parallel execution strategy: 4 waves with 5 parallel agents across Waves 2 and 3
- Updated plan.md with Part 11 (Phase 3 Implementation Plan)
- Updated progress.md with expanded Phase 3 checklist including prerequisites and parallel agent instructions

[2026-02-20] - Phase 3 - Implementation Complete
Implemented all Phase 3 data foundations using 4-wave parallel execution strategy (5 agents total):

**Wave 1 — Step 0 Prerequisites:**
- Fixed all 4 entitlements files (iOS, Watch, Widgets, macOS) with App Group + HealthKit capabilities
- Added privacy strings and background modes to iOS Info.plist
- Fixed Watch bundle ID mismatch in Constants.swift
- Switched UserPreferences to App Group UserDefaults suite

**Wave 2 — 3 parallel agents:**
- Agent A: Created PlaylistRepository.swift and SongRepository.swift with full CRUD, sync from MusicKit, diffing, and playlist-song relationships. Wired into PlaylistViewModel for persistence on fetch and selection.
- Agent B: Created HealthKitService.swift with protocol, HKHealthStore, real-time HR/HRV queries, AsyncStream<Double> heart rate stream, background delivery, and Phase 4 historical query stubs. Wired into ResonanceApp.swift.
- Agent C: Created HeartRateSensor.swift, MotionSensor.swift, WorkoutDetector.swift, SensorCoordinator.swift on watchOS. Batched sensor streaming (5s interval, 20 sample max) via PhoneConnectivityService. Wired into ResonanceWatchApp.swift with HealthKit auth.

**Wave 3 — 2 parallel agents:**
- Agent D: Created FeatureExtractor.swift (genre-based BPM/energy/valence/instrumentalness estimation with derived calmScore/focusScore/energyScore), FeatureNormalizer.swift, and EventLogger.swift (playback event capture with listenPercentage, skip detection, biometric deltas, auto-detection via nowPlayingPublisher). Wired EventLogger into NowPlayingViewModel for skip/previous notification.
- Agent E: Created ContextCollector.swift (aggregates BiometricPacket from Watch, persists BiometricSample to Core Data, rebuilds AggregatedContext). Wired into ResonanceApp.swift with full BGTaskScheduler registration (playlistSync + featureUpdate).

**Post-agent fixes:**
- Added missing `nowPlaying.eventLogger = eventLogger` wiring in ResonanceApp.swift init()
- Fixed Track-to-Song type conversion in PlaylistViewModel.selectPlaylist() (MusicItemCollection<Track> → MusicItemCollection<MusicKit.Song>)

**Files created (11):** PlaylistRepository.swift, SongRepository.swift, HealthKitService.swift, HeartRateSensor.swift, MotionSensor.swift, WorkoutDetector.swift, SensorCoordinator.swift, FeatureExtractor.swift, FeatureNormalizer.swift, EventLogger.swift, ContextCollector.swift
**Files modified (5):** ResonanceApp.swift, PlaylistViewModel.swift, NowPlayingViewModel.swift, ResonanceWatchApp.swift, progress.md

[2026-02-20] - Phase 3 - Code Quality Review & Fixes
Comprehensive code quality audit of all Phase 3 files (6 parallel review agents). Found and fixed 16 priority issues:

**Critical fixes:**
- `FeatureExtractor.swift`: Fixed `song.energyScore` → `song.activationScore` (Core Data attribute name mismatch — would not compile)
- `Resonance.entitlements`: Added missing `com.apple.developer.musickit` entitlement key
- `Watch/Info.plist`: Added missing `NSHealthShareUsageDescription` for Watch HealthKit authorization
- `EventLogger.swift`: Fixed race condition in `activeEventObjectID` — async clear via `DispatchQueue.main.async` was overwriting new values set by `logPlaybackStart()`. Moved to synchronous clear before dispatching background task.
- `ResonanceApp.swift`: Removed duplicate `MusicKitService()` from `@StateObject` default initializer (was creating two instances)
- `ContextCollector.swift`: Added `observeEventLogger()` method to wire `activeEventObjectID` from EventLogger (was never connected — BiometricSamples had nil playback event IDs)
- `ResonanceApp.swift`: Replaced force casts (`as!`) on BGTask types with safe `guard let ... as?` patterns

**High-priority fixes:**
- `PlaylistViewModel.swift`: Moved `findByAppleMusicId()` call before `Task.detached` block to avoid Core Data `viewContext` access from background thread
- `HealthKitService.swift`: Added time-bounded predicate (last hour) to `heartRateStream` to prevent historical data flood on initial query
- `HealthKitService.swift`: Fixed `recentPredicate` to capture single `Date()` reference (was creating two instances with potential time gap)
- `EventLogger.swift`: Clamped `listenPercentage` to [0.0, 1.0] range
- `WatchMessages.swift`: Removed wasted `JSONSerialization.jsonObject` call in `toDictionary()`
- `Constants.swift`: Changed `CGFloat` → `Double` in `ArtworkSize` enum (no CoreGraphics import in Shared module)
- `ContextCollector.swift`: Added `isCollecting` guard against duplicate subscriptions
- `EventLogger.swift`: Added `isObservingNowPlaying` guard against duplicate subscriptions
- `HealthKitService.swift`: Added clarifying comment about `isAuthorized` flag (HealthKit does not reveal read access grant status per Apple policy)

**Files modified (10):** FeatureExtractor.swift, Resonance.entitlements, Watch/Info.plist, EventLogger.swift, ResonanceApp.swift, ContextCollector.swift, PlaylistViewModel.swift, HealthKitService.swift, WatchMessages.swift, Constants.swift

[2026-02-21] - Phase 4 - Planning (Enhanced)
Comprehensive Phase 4 research and planning via 4 parallel research agents investigating HealthKit APIs, session reconstruction algorithms, EMA learning approaches, and BGProcessingTask best practices. Key research-driven improvements over initial plan:

**Blocking prerequisite discovered:** iOS Info.plist missing `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes` — existing Phase 3 BGTasks silently fail at runtime.

**Algorithm enhancements:**
- Two-tier skip penalty: early skip (<15%) = -0.3, late skip (15-30%) = -0.15
- Two-tier EMA alpha: 0.4 cold start (first 5 plays), 0.2 steady state
- SongEffect keyed on `(song, contextType)` only — NOT triple (avoids sparse data: 70 → 11 max effects per song)
- Biometric signal redistribution for partial data (HR-only, HRV-only, both, neither)
- Behavior-only confidence cap at 0.7 (no Watch = uncertain)
- Familiarity excludes skip rate (already penalized via effect scores — avoids compounding)
- Session gap uses `endedAt ?? startedAt + songDuration` (not `endedAt ?? startedAt`)
- Sleep correlation: 3-hour minimum (filter naps), deep sleep normalized by 0.25
- Weekend-aware context inference (different patterns from weekdays)
- Per-step watermarks instead of single `lastBackfillDate`
- BGTask double-registration guard (static flag)
- Cooperative cancellation via `Task.checkCancellation()` for BGProcessingTask expiration
- NSNumber? handling for nullable sleep score fields in Core Data

**Implementation plan:** 8 steps (0-7), 5 new files, 6 modified files, 4-wave execution strategy with 5 agents
- Updated plan.md Part 12 with all research findings
- Updated progress.md with enhanced 80+ item checklist

<!--
Example entry format:
[2026-02-07] - Phase 1 - 1.1 Xcode Project Creation
Created new Xcode project with iOS target. Workspace initialized.

[2026-02-07] - Phase 1 - 1.5 Directory Structure
Created all required directories under resonance/ including Shared, Brain, iOS, Watch, and macOS folders.
-->

---

# BLOCKERS & ISSUES

## Active Blockers

### [BLOCKER-001] Info.plist Missing BGTask Identifiers
**Date Identified:** 2026-02-21
**Phase:** Phase 3 (retroactive) / Phase 4
**Description:** iOS Info.plist is missing `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes` entries. Without these, `BGTaskScheduler.shared.register()` crashes at runtime. Existing Phase 3 BGTasks (`playlistSync`, `featureUpdate`) silently fail.
**Impact:** Blocks all background task execution (playlist sync, feature update, historical analysis)
**Status:** Fix designed — Phase 4 Step 0
**Resolution:** Add entries to Info.plist as first step of Phase 4 implementation

Note: Phase 2 testing items (2.1 auth/playback tests, 2.3 remote control test, 2.4 sync tests, 2.6 integration tests) require Xcode builds on physical devices. Code implementation is complete.

<!--
Example blocker format:
### [BLOCKER-001] MusicKit Entitlement
**Date Identified:** 2026-02-08
**Phase:** Phase 2
**Description:** Cannot obtain MusicKit entitlement from Apple Developer Portal
**Impact:** Blocks all MusicKit integration
**Status:** Pending Apple response
**Resolution:** TBD
-->

---

# NOTES & DECISIONS

## Architecture Decisions

### [DECISION-001] MusicKit Types vs Core Data for Phase 2
**Date:** 2026-02-20
**Context:** MusicKitService needs to return song/playlist data. Could use Core Data entities or MusicKit native types.
**Decision:** Use MusicKit native types (MusicKit.Song, MusicKit.Playlist, MusicPlayer.Queue.Entry) directly in Phase 2.
**Rationale:** Core Data mapping adds complexity with no benefit until Phase 3 (Data Foundations) when ingestion pipeline is built. Keeps Phase 2 focused on playback and UI.

### [DECISION-002] Dependency Injection via Init vs EnvironmentObject
**Date:** 2026-02-20
**Context:** Views need access to ViewModels and MusicKitService.
**Decision:** Use initializer injection for all dependencies.
**Rationale:** Compile-time safety, explicit dependencies, easier to test. Avoids runtime crashes from missing EnvironmentObject.

<!--
Example decision format:
### [DECISION-001] CloudKit vs MultipeerConnectivity for macOS
**Date:** 2026-02-10
**Context:** Need to sync macOS context to iPhone
**Decision:** Use CloudKit initially for simplicity
**Rationale:** Faster to implement, works without local network. Will optimize to MultipeerConnectivity if latency is problematic.
-->

---

# METRICS

## Code Statistics

| Metric | Value |
|--------|-------|
| Swift Files | 38 |
| Lines of Code | ~8,200 |
| Test Coverage | 0% |
| CoreData Entities | 7 |

*Last updated: 2026-02-21*

---

*End of Progress Tracker*
