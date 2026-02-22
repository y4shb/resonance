<p align="center">
  <br/>
  <strong style="font-size: 2em;">R E S O N A N C E</strong>
  <br/>
  <br/>
</p>

<h3 align="center">Music that adapts to you.</h3>

<p align="center">
An intelligent DJ that selects songs from your Apple Music library<br/>
based on your biometrics, context, and what has worked for you before.
</p>

<p align="center">
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-5.9-F05138?style=flat&logo=swift&logoColor=white" alt="Swift 5.9">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/iOS-26.0+-000000?style=flat&logo=apple&logoColor=white" alt="iOS 26.0+">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/watchOS-26.0+-000000?style=flat&logo=apple&logoColor=white" alt="watchOS 26.0+">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/macOS-26.0+-000000?style=flat&logo=apple&logoColor=white" alt="macOS 26.0+">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/On--Device-AI-7C3AED?style=flat" alt="On-Device AI">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/Lines-16.3k-blue?style=flat" alt="Lines of Code">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/Tests-87-brightgreen?style=flat" alt="Tests">
  </a>
</p>

---

> **Biometric Sensing** · **State Estimation** · **Adaptive Song Selection** · **Real-Time Learning** · **Cross-Device Sync**

---

## The Idea

You already have great music in your library. The problem is picking the right song at the right moment.

Resonance reads your heart rate and HRV from Apple Watch, knows whether you're in a workout or deep work session, understands what time of day it is, and remembers which songs actually calmed you down or gave you energy in the past. It uses all of this to pick the next song -- from your own playlists, not from an algorithm's recommendation feed.

Every selection is explained. Every response is learned from. No data ever leaves your device.

## How It Works

```
Apple Watch                    iPhone                         Mac
─────────────                  ──────                         ───
Heart Rate ──────┐
HRV ─────────────┤
Motion ──────────┤        ┌─── Context Collector ◄──────── Focus Mode
Workout State ───┘        │         │                      Active Apps
       │                  │         ▼                      Calendar
       └──────────────────┘    State Engine
                                    │
                               ┌────▼────┐
                               │ Decision │──── Guard Filters
                               │ Engine   │──── Song Scorer
                               └────┬────┘──── Transition Controller
                                    │
                               ┌────▼────┐
                               │ Learning │──── Skip Penalty
                               │ Store    │──── HRV Response Credit
                               └─────────┘──── Session Quality
```

**State Engine** reads biometrics from your Watch, context from your Mac, and time-of-day signals to estimate what you need right now: energy, calm, focus, or mood lift.

**Decision Engine** scores every song in your active playlist against your current state, applies guard filters (no repeats, artist variety, nighttime BPM caps), and picks the best match.

**Learning Store** watches what happens after each song plays. Did your HRV improve? Did you skip it? Did you listen all the way through? These signals update per-song effectiveness scores so future selections improve over time.

## Features

- [x] AI-powered song selection from your own Apple Music playlists
- [x] Real-time state estimation from Apple Watch biometrics (HR, HRV, motion)
- [x] macOS context awareness (Focus Mode, active apps, calendar meetings)
- [x] Continuous learning loop with skip penalties and biometric response credits
- [x] Explainable selections -- every song choice comes with a reason
- [x] Digital Crown DJ Mode on Apple Watch for manual energy adjustment
- [x] Watch complications (circular, rectangular, corner, inline)
- [x] iOS home screen widgets (Now Playing, Current State)
- [x] Manual mood input on both iPhone (sliders) and Watch (3-tap: 😊 😐 😔)
- [x] Historical session reconstruction with sleep correlation
- [x] Guided onboarding with permission requests
- [x] Full settings for ranking weights, time-of-day rules, behavioral preferences
- [x] Entirely on-device -- zero cloud dependencies for processing

## Architecture

Resonance is structured as five targets sharing code through two common modules:

| Target | Platform | Role |
|--------|----------|------|
| **Resonance** | iOS | Main app -- playback, AI engine, state estimation, learning |
| **ResonanceWatch** | watchOS | Sensor streaming, playback controls, mood input, complications |
| **ResonanceMac** | macOS | Menu bar companion -- broadcasts Focus Mode and calendar context |
| **ResonanceWidgets** | iOS | Home screen widgets for Now Playing and Current State |
| **ResonanceWatchComplications** | watchOS | WidgetKit complications for watch faces |

```
resonance/
├── Shared/                    # Cross-platform code
│   ├── Models/                # StateVector, SongScore, WatchMessages, UserPreferences
│   ├── Persistence/           # Core Data stack + repositories (Song, Playlist)
│   ├── Services/              # MusicKit, HealthKit, EventLogger, WidgetDataStore
│   └── Utilities/             # Constants, Logging
│
├── Brain/                     # Intelligence layer (iOS only)
│   ├── State/                 # StateEngine -- biometric + context → state vector
│   ├── Decision/              # DecisionEngine, SongScorer, GuardFilters, TransitionController
│   ├── Learning/              # LearningStore, SkipPenalty, ResponseCredit, SessionQuality
│   ├── Historical/            # SessionReconstructor, SongImpactCalculator, HistoricalEngine
│   └── Features/              # Genre-based BPM/energy/valence estimation
│
├── iOS/                       # iPhone app
│   ├── Views/                 # NowPlaying, Playlists, Settings, Onboarding, MoodInput
│   ├── ViewModels/            # NowPlayingViewModel, PlaylistViewModel
│   └── Services/              # WatchConnectivityManager
│
├── Watch/                     # Apple Watch app
│   ├── Views/                 # NowPlaying, MoodInput, CrownHandler
│   ├── Sensors/               # HeartRate, Motion, Workout, SensorCoordinator
│   ├── Complications/         # WidgetKit complications + data store
│   └── Services/              # PhoneConnectivityService
│
├── macOS/                     # Menu bar companion
│   ├── MenuBar/               # StatusItem, Popover, Controller
│   └── ContextProviders/      # FocusMode, ActiveApp, Calendar, Broadcaster
│
├── Widgets/                   # iOS home screen widgets
└── Tests/                     # Unit tests (87 test methods)
```

## Key Algorithms

<details>
<summary><strong>State Estimation</strong></summary>
<br/>

The State Engine produces a 5-dimensional `StateVector` every 30 seconds:

| Dimension | Source | Method |
|-----------|--------|--------|
| **Arousal** | Heart rate | HR reserve method against resting HR baseline (refreshed every 30 min from HealthKit) |
| **Stress** | HRV | Inverse ratio to 50ms population baseline -- low HRV indicates high stress |
| **Energy** | Composite | Arousal * 0.6 + (1 - Stress) * 0.4 |
| **Focus** | Context-dependent | Deep work: 0.8 base; workout: 0.3 fixed; pre-sleep: arousal-penalized |
| **Valence** | Stress-adjusted | Blended with manual mood input (15-min linear decay, 70% max weight) |

Activity context is inferred through a 5-level priority cascade: Watch workout detection, macOS signals (Focus Mode, active apps), motion state, time-of-day patterns (weekend-aware), and fallback defaults.

</details>

<details>
<summary><strong>Song Scoring</strong></summary>
<br/>

Each candidate song receives a weighted composite score from 7 components:

| Component | Weight Source | What It Measures |
|-----------|-------------|------------------|
| BPM Match | `bpmWeight` | How close the song's tempo is to the target BPM for the current need |
| Energy Match | `energyWeight` | How close the song's energy estimate is to the target |
| Familiarity | `familiarityWeight` | Play count normalized to [0, 1]; boosted during high stress or focus |
| Historical Effect | `historicalWeight` | Per-song per-context effectiveness from SongEffect entities (EMA-updated) |
| Context Alignment | `contextWeight` | How well the song fits the activity context (workout, deep work, pre-sleep, etc.) |
| Recency Penalty | Fixed | Penalizes recently played songs (configurable avoidance window) |
| Time-of-Day | Fixed | BPM cap enforcement for morning and nighttime |

Guard filters run before scoring: nil-ID rejection, recency filter, same-artist limit, nighttime BPM hard cap. A transition controller then blends 70% base score with 30% transition smoothness (BPM and energy continuity from the previous song).

</details>

<details>
<summary><strong>Learning Loop</strong></summary>
<br/>

After each song plays, three calculators run:

- **SkipPenaltyCalculator**: Two-tier penalty -- early skip (<15% listened) = -0.3, late skip (15-30%) = -0.15. Auto-detects non-manual skips via listen percentage threshold.
- **ResponseCreditCalculator**: Maps HRV delta to calm credit and HR delta to energy credit. Confidence scales from 0.7 (no biometrics) to 1.0 (full biometrics). Weighted by listen percentage.
- **SessionQualityScorer**: Composite of skip rate (0.25), HRV response (0.30), engagement (0.25), and next-night sleep correlation (0.20).

Song effect scores are updated via exponential moving average with two-tier alpha: 0.4 for cold start (first 5 plays), 0.2 for steady state. Effects are keyed on `(song, context)` to avoid sparse data problems.

A **RealTimeGuardAdjuster** monitors heart rate during playback and dynamically lowers the BPM ceiling when HR rises during a calm-need session, or boosts familiarity preference after consecutive skips.

</details>

## Tech Stack

| Layer | Frameworks |
|-------|-----------|
| UI | SwiftUI |
| Music | MusicKit (authorization, library, playback) |
| Health | HealthKit (HR, HRV, sleep, workouts, step count) |
| Persistence | Core Data (7 entities, App Group shared container) |
| Reactivity | Combine (publishers, subscribers, async streams) |
| Watch Sync | WatchConnectivity (bidirectional message passing) |
| Mac Sync | CloudKit (private database, context signal records) |
| Widgets | WidgetKit (iOS home screen + watchOS complications) |
| Sensors | CoreMotion (pedometer, stationary detection) |
| Calendar | EventKit (meeting detection on macOS) |
| Background | BGTaskScheduler (playlist sync, feature extraction, historical analysis) |
| Project | XcodeGen (project.yml-driven Xcode project generation) |

## Data Model

Seven Core Data entities form the persistence layer:

```
Song ←──────── PlaybackEvent ──────── HistoricalSession
  │                  │
  ├── SongEffect     ├── BiometricSample
  │
  └── Playlist                         MacOSContext
```

| Entity | Purpose | Key Fields |
|--------|---------|------------|
| **Song** | Library track with extracted features | BPM, energy, valence, calm/focus/activation scores, familiarity |
| **Playlist** | User playlist with aggregate metrics | Avg calm/focus/energy effect, context associations |
| **PlaybackEvent** | Single song play with outcome | Listen %, was skipped, HR/HRV at start and end, deltas |
| **HistoricalSession** | Group of consecutive plays | Skip rate, biometric summary, sleep correlation score |
| **SongEffect** | Per-song per-context effectiveness | Calm/energy/focus/mood scores (EMA-updated), sample count |
| **BiometricSample** | Raw Watch sensor reading | HR, HRV, stationary flag, workout flag |
| **MacOSContext** | Mac environment snapshot | Focus mode, active app category, meeting status |

All data stays on-device in an App Group container shared between the app, widgets, and Watch.

## Getting Started

### Prerequisites

- Xcode 26.0 or later
- Apple Developer account (for HealthKit and MusicKit entitlements)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An Apple Watch paired with your iPhone (for biometric features)

### Setup

```bash
# Clone the repository
git clone https://github.com/y4sh/resonance.git
cd resonance

# Set your development team in project.yml
# Look for DEVELOPMENT_TEAM and replace with your team ID

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open Resonance.xcodeproj
```

### Configuration

1. **Apple Developer Portal**: Create App Group `group.com.y4sh.resonance` and enable it for all targets
2. **MusicKit**: Register your app for MusicKit access
3. **Signing**: Select your development team in Xcode for all 5 targets
4. **Build**: Select the `Resonance` scheme and run on an iOS device or simulator

### Running Tests

```bash
xcodebuild test \
  -scheme Resonance \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Requirements

| Platform | Minimum | Xcode | Swift |
|----------|---------|-------|-------|
| iOS | 26.0+ | 26.0 | 5.9+ |
| watchOS | 26.0+ | 26.0 | 5.9+ |
| macOS | 26.0+ | 26.0 | 5.9+ |

## Project Stats

| Metric | Count |
|--------|-------|
| Swift source files | 73 |
| Lines of code | ~16,300 |
| Unit test methods | 87 |
| Core Data entities | 7 |
| Build targets | 6 (iOS, watchOS, macOS, Widgets, Complications, Tests) |
| Implementation phases | 9/9 complete |

## Privacy

Resonance is built on a strict privacy-first architecture:

- **All processing happens on-device.** No song data, biometrics, or listening history is sent to any server.
- **No cloud ML.** State estimation, song scoring, and learning all run locally.
- **No tracking.** No analytics SDKs, no telemetry, no third-party dependencies.
- **Your data stays yours.** Core Data is stored in a local App Group container. iCloud backup is optional and user-controlled.
- **Biometrics are ephemeral.** Raw sensor data is used for real-time state estimation and discarded. Only aggregated session summaries are persisted.

The only network usage is optional CloudKit sync for macOS context signals (Focus Mode, active apps) to the user's own private iCloud database.

## License

This project is proprietary software. All rights reserved.

---

<p align="center">
  <sub>Built with Swift, SwiftUI, MusicKit, HealthKit, and Core Data.</sub>
  <br/>
  <sub>The right song from your music, based on how you actually feel right now.</sub>
</p>
