# Resonance: Progress Tracker

## Document Purpose
This file tracks the current state of the project, completed work, and remaining tasks. **This file is append-only** - new entries are added at the bottom of each section as work progresses.

---

# PROJECT STATUS OVERVIEW

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Project Setup | COMPLETE | 100% |
| Phase 2: Platform Skeleton (M1) | COMPLETE | 100% |
| Phase 3: Data Foundations (M2) | NOT STARTED | 0% |
| Phase 4: Historical Backfill (M3) | NOT STARTED | 0% |
| Phase 5: State Engine (M4) | NOT STARTED | 0% |
| Phase 6: DJ Brain (M5) | NOT STARTED | 0% |
| Phase 7: Watch Experience (M6) | NOT STARTED | 0% |
| Phase 8: Learning Loop (M7) | NOT STARTED | 0% |
| Phase 9: MVP Polish (M8) | NOT STARTED | 0% |

**Current Phase:** Phase 3 - Data Foundations (M2)
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
- Implement playlist and song ingestion pipeline
- Create song feature store
- Implement event logging for playback
- Set up Watch sensor streaming

## Checklist

### 3.1 Playlist Ingestion
- [ ] Create PlaylistRepository.swift
- [ ] Implement syncPlaylists() - fetch from MusicKit and store
- [ ] Implement diffing logic (detect added/removed playlists)
- [ ] Handle playlist artwork download and caching
- [ ] Schedule background playlist sync task
- [ ] Test initial playlist import
- [ ] Test incremental playlist updates

### 3.2 Song Ingestion
- [ ] Create SongRepository.swift
- [ ] Implement syncSongsForPlaylist()
- [ ] Map MusicKit Song to CoreData Song entity
- [ ] Store song metadata (title, artist, album, duration)
- [ ] Handle song-playlist relationships
- [ ] Test song import for playlist

### 3.3 Song Feature Extraction
- [ ] Create FeatureExtractor.swift
- [ ] Extract BPM from MusicKit metadata (if available)
- [ ] Estimate energy from genre + tempo
- [ ] Estimate valence from genre
- [ ] Create default features for unknown songs
- [ ] Implement FeatureNormalizer.swift
- [ ] Store features in Song entity
- [ ] Create background task for feature extraction

### 3.4 Event Logging
- [ ] Create EventLogger.swift
- [ ] Log playback start event
- [ ] Log playback end event (with duration)
- [ ] Log skip event (with timestamp)
- [ ] Log volume change events
- [ ] Persist events to PlaybackEvent entity
- [ ] Capture biometric snapshot at events (if available)

### 3.5 HealthKit Service
- [ ] Create HealthKitService.swift protocol (see plan.md 6.2.2)
- [ ] Implement requestAuthorization()
- [ ] Implement fetchLatestHeartRate()
- [ ] Implement fetchLatestHRV()
- [ ] Implement fetchRecentHeartRates(minutes:)
- [ ] Implement fetchRecentHRV(minutes:)
- [ ] Enable background delivery for heart rate
- [ ] Create heart rate observer query
- [ ] Test HealthKit authorization
- [ ] Test real-time heart rate fetch

### 3.6 Watch Sensor Layer
- [ ] Create HeartRateSensor.swift
- [ ] Create HRVSensor.swift
- [ ] Create MotionSensor.swift
- [ ] Create WorkoutDetector.swift
- [ ] Stream sensor data via WatchConnectivity
- [ ] Define BiometricPacket structure
- [ ] Buffer samples on Watch for batching
- [ ] Send batched updates to iPhone
- [ ] Handle Watch app backgrounding

### 3.7 Context Collector (iPhone)
- [ ] Create ContextCollector.swift
- [ ] Receive biometric updates from Watch
- [ ] Store BiometricSample entities
- [ ] Maintain current sensor state cache
- [ ] Publish sensor state changes
- [ ] Test Watch → iPhone biometric flow

---

# PHASE 4: HISTORICAL BACKFILL (M3)

## Objectives
- Import HealthKit historical data
- Align with playlist listening history
- Build PlaylistImpact and SongImpact metrics

## Checklist

### 4.1 HealthKit Historical Import
- [ ] Implement fetchHeartRateHistory(from:to:)
- [ ] Implement fetchHRVHistory(from:to:)
- [ ] Implement fetchSleepAnalysis(from:to:)
- [ ] Implement fetchWorkouts(from:to:)
- [ ] Handle pagination for large datasets
- [ ] Store historical data efficiently
- [ ] Create progress indicator for import

### 4.2 Listening History Import
- [ ] Implement fetchRecentlyPlayed(limit:) for all history
- [ ] Create PlayHistoryItem model
- [ ] Store listening history timestamps
- [ ] Handle missing/incomplete data

### 4.3 Session Reconstruction
- [ ] Create SessionReconstructor.swift
- [ ] Implement reconstructHistoricalSessions() (see plan.md 5.4.1)
- [ ] Define session boundary rules (30 min gap)
- [ ] Group playback events into sessions
- [ ] Link sessions to playlists
- [ ] Calculate session biometric summaries
- [ ] Correlate with next-night sleep data
- [ ] Store HistoricalSession entities

### 4.4 Impact Calculation
- [ ] Create PlaylistImpactCalculator.swift
- [ ] Calculate avgCalmEffect per playlist
- [ ] Calculate avgFocusEffect per playlist
- [ ] Calculate avgEnergyEffect per playlist
- [ ] Build context associations
- [ ] Store playlist effect metrics

- [ ] Create SongImpactCalculator.swift
- [ ] Calculate per-song calm score
- [ ] Calculate per-song focus score
- [ ] Calculate per-song energy score
- [ ] Factor in skip behavior
- [ ] Factor in listen percentage
- [ ] Factor in biometric response
- [ ] Store SongEffect entities
- [ ] Calculate confidence levels

### 4.5 Backfill Execution
- [ ] Create BackfillManager.swift
- [ ] Run backfill as background processing task
- [ ] Show progress in Settings UI
- [ ] Handle partial completion
- [ ] Support incremental backfill (new data only)
- [ ] Test full backfill flow
- [ ] Verify impact scores are reasonable

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

*No active blockers*

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
| Swift Files | 26 |
| Lines of Code | ~5,600 |
| Test Coverage | 0% |
| CoreData Entities | 7 |

*Last updated: 2026-02-20*

---

*End of Progress Tracker*
