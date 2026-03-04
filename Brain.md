# Resonance Brain: Technical Deep Dive

The Brain is Resonance's on-device intelligence engine. It observes the user's physiological state, behavioral patterns, and environmental context to select the optimal song from the user's own Apple Music playlists. Every computation runs locally on the iPhone --- no data leaves the device.

This document provides an exhaustive technical reference for the Brain's architecture, algorithms, data flows, and design rationale.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [State Subsystem](#2-state-subsystem)
3. [Decision Subsystem](#3-decision-subsystem)
4. [Historical Subsystem](#4-historical-subsystem)
5. [Learning Subsystem](#5-learning-subsystem)
6. [Feature Subsystem](#6-feature-subsystem)
7. [Shared Infrastructure](#7-shared-infrastructure)
8. [Data Flow Diagrams](#8-data-flow-diagrams)
9. [Constants and Tuning Parameters](#9-constants-and-tuning-parameters)
10. [Design Choices and Rationale](#10-design-choices-and-rationale)
11. [On-Device AI and ML](#11-on-device-ai-and-ml)
12. [Possible Enhancements](#12-possible-enhancements)

---

## 1. Architecture Overview

### 1.1 What the Brain Does

The Brain answers one question every time a song ends: **"What song should play next?"**

It does this by:

1. **Sensing** the user's current physiological and contextual state (heart rate, HRV, activity, time of day, macOS app usage)
2. **Estimating** a 5-dimensional internal state vector (arousal, energy, focus, stress, valence)
3. **Inferring** what the user needs from music right now (energize, calm, focus, maintain, transition)
4. **Scoring** every song in the active playlist against that need
5. **Filtering** out songs that violate hard constraints (recently played, same-artist limits, nighttime BPM caps)
6. **Selecting** the best candidate with smooth transition logic
7. **Explaining** why that song was chosen, in human-readable language
8. **Learning** from the outcome (did the user skip? did HRV improve?) to refine future decisions

### 1.2 Directory Structure

```
Brain/
 ├── State/
 │   └── StateEngine.swift              # Real-time state estimation
 ├── Decision/
 │   ├── DecisionEngine.swift           # Orchestrates the selection pipeline
 │   ├── SongScorer.swift               # Multi-factor song scoring
 │   ├── GuardFilters.swift             # Hard pre-scoring filters
 │   ├── TransitionController.swift     # Smooth song-to-song transitions
 │   └── ExplanationGenerator.swift     # Human-readable explanations
 ├── Historical/
 │   ├── HistoricalEngine.swift         # Backfill pipeline orchestrator
 │   ├── SessionReconstructor.swift     # Groups events into sessions
 │   ├── SongImpactCalculator.swift     # Per-song EMA effect scoring
 │   ├── PlaylistImpactCalculator.swift # Playlist-level aggregation
 │   └── ImpactScore.swift             # Per-event impact calculation
 ├── Learning/
 │   ├── LearningStore.swift            # Real-time learning from playback
 │   ├── RealTimeGuardAdjuster.swift    # Dynamic guard adjustments
 │   ├── ResponseCreditCalculator.swift # Biometric response credits
 │   ├── SessionQualityScorer.swift     # Session quality scoring
 │   └── SkipPenaltyCalculator.swift    # Skip penalty calculation
 ├── Features/
 │   ├── FeatureExtractor.swift         # Genre-based feature estimation
 │   └── FeatureNormalizer.swift        # Value normalization utilities
 └── Shared/
     └── SongEffectHelper.swift         # Core Data helpers for SongEffect
```

### 1.3 Platform Constraints

All Brain code is wrapped in `#if os(iOS)` because the Brain runs exclusively on the iPhone. The Apple Watch collects biometric data and sends it via WatchConnectivity. The Mac sends context signals. But all intelligence lives on the iPhone.

### 1.4 Subsystem Relationship Diagram

```
                    ┌─────────────────────┐
                    │   Apple Watch        │
                    │   (HR, HRV, Motion)  │
                    └──────────┬──────────┘
                               │ WatchConnectivity
                               ▼
┌──────────┐     ┌─────────────────────────┐     ┌──────────┐
│  macOS   │────▶│    Context Collector     │◀────│  HealthKit│
│  Agent   │     │    (aggregates signals)  │     │  (resting │
└──────────┘     └──────────┬──────────────┘     │   HR)     │
                            │                     └──────────┘
                            ▼
                 ┌──────────────────────┐
                 │    STATE ENGINE       │ ◀── Manual Mood / Crown Input
                 │    (StateVector)      │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │   DECISION ENGINE     │
                 │   ┌────────────────┐  │
                 │   │ GuardFilters   │  │
                 │   │ SongScorer     │  │
                 │   │ Transition     │  │
                 │   │ Explanation    │  │
                 │   └────────────────┘  │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │   MusicKit Player     │
                 │   (plays the song)    │
                 └──────────┬───────────┘
                            │ PlaybackEvent
                            ▼
              ┌─────────────────────────────┐
              │     LEARNING SUBSYSTEM       │
              │  ┌────────────────────────┐  │
              │  │ LearningStore (real-    │  │
              │  │ time EMA updates)       │  │
              │  │ SkipPenaltyCalculator   │  │
              │  │ ResponseCreditCalc      │  │
              │  │ RealTimeGuardAdjuster   │  │
              │  │ SessionQualityScorer    │  │
              │  └────────────────────────┘  │
              └─────────────┬───────────────┘
                            │ SongEffect updates
                            ▼
              ┌─────────────────────────────┐
              │    HISTORICAL SUBSYSTEM      │
              │  (batch backfill pipeline)   │
              │  SessionReconstructor        │
              │  SongImpactCalculator        │
              │  PlaylistImpactCalculator    │
              └─────────────────────────────┘
```

---

## 2. State Subsystem

**File:** `Brain/State/StateEngine.swift`

The StateEngine is the Brain's sensory cortex. It continuously estimates the user's internal state from raw signals and expresses it as a `StateVector`.

### 2.1 StateVector

The StateVector is a 5-dimensional representation of the user's current state:

| Dimension  | Range   | Meaning                              |
|------------|---------|--------------------------------------|
| `arousal`  | 0.0-1.0 | Physiological activation level       |
| `energy`   | 0.0-1.0 | Composite of arousal + inverse stress|
| `focus`    | 0.0-1.0 | Cognitive engagement level           |
| `stress`   | 0.0-1.0 | Physiological stress (inverse of HRV)|
| `valence`  | 0.0-1.0 | Mood positivity                      |

Plus metadata:
- `context: ActivityContext` (workout, deepWork, work, commute, morning, preSleep, relaxation, social, postWorkout, unknown)
- `inferredNeed: MusicNeed` (energize, calm, focus, maintain, transition)
- `timestamp: Date`
- `confidence: Double` (0.0-1.0)
- `dataSources: Set<DataSource>` (which sensors contributed)

### 2.2 Update Cycle

The StateEngine runs a **30-second update loop** via `Timer.scheduledTimer`. Each cycle:

1. Refreshes resting heart rate from HealthKit (every 30 minutes)
2. Reads aggregated context from `ContextCollector`
3. Calculates arousal from heart rate
4. Calculates stress from HRV
5. Infers activity context
6. Synthesizes the full StateVector
7. Publishes via `@Published currentState`

### 2.3 Arousal Calculation

**Algorithm:** Heart Rate Reserve Method

```
restingHR = HealthKit resting HR ?? 70 BPM (default)
maxHR     = 220 - age (default age: 35 => maxHR = 185)
hrReserve = maxHR - restingHR

arousal = clamp((currentHR - restingHR) / hrReserve, 0.0, 1.0)
```

**Design choice:** The heart rate reserve method normalizes across individuals. Someone with a resting HR of 50 and someone with 80 will both produce arousal = 0.5 at their respective midpoints, rather than using absolute HR thresholds.

**Fallback:** If no heart rate data is available, arousal defaults to 0.5 with confidence 0.0.

### 2.4 Stress Calculation

**Algorithm:** HRV Ratio Method (Inverse)

```
baselineHRV = 50.0 ms (population SDNN average for healthy adults)

ratio  = currentHRV / baselineHRV
stress = clamp(1.0 - (ratio * 0.6), 0.0, 1.0)
```

Mapping:
- HRV 25ms (ratio 0.5) => stress ~0.7 (high stress)
- HRV 50ms (ratio 1.0) => stress ~0.4 (moderate)
- HRV 75ms (ratio 1.5) => stress ~0.1 (relaxed)

**Design choice:** HRV is the gold standard for non-invasive stress measurement. Lower HRV = higher sympathetic nervous system activation = higher stress. The 0.6 scaling factor prevents the stress value from being overly sensitive to small HRV fluctuations.

### 2.5 Derived Dimensions

**Energy:**
```
energy = arousal * 0.6 + (1.0 - stress) * 0.4
```

**Focus:** Context-dependent:
- Deep work: `0.8 - stress * 0.3`
- Work: `0.6 - stress * 0.2`
- Workout: `0.3` (physical, not mental focus)
- Pre-sleep: `0.3 - arousal * 0.2`
- Default: `0.5 - stress * 0.2 + (lowArousalBonus: 0.1 if arousal < 0.4)`

**Valence:**
```
valence = 0.5 - stress * 0.3
```

### 2.6 Manual Mood Input

Users can set mood via iOS slider or Watch 3-tap. The `ManualMoodInput` struct records energy and valence values, then **decays linearly over 15 minutes**:

```
ageMinutes = timeSinceInput / 60.0
weight     = 1.0 - (ageMinutes / 15.0)    // 0.0 after 15 min
```

Manual input blends into the state with **max 70% influence** at peak, decaying to 0%:

```
energy  = blend(computed_energy, manual_energy, weight: moodWeight * 0.5)
valence = blend(computed_valence, manual_valence, weight: moodWeight)
```

**Design choice:** The 15-minute decay prevents stale manual input from dominating. The asymmetric weighting (0.5 for energy, 1.0 for valence) reflects that users are better at judging their mood than their physiological energy.

### 2.7 Crown Adjustment

Watch Digital Crown rotation applies an energy offset that **decays over 5 minutes**:

```
crownDecayFactor = 1.0 - (elapsed / 300.0 seconds)
energy = clamp(energy + crownAdjustment * crownDecayFactor, 0.0, 1.0)
```

Max crown adjustment: +/- 0.5 energy units.

### 2.8 Activity Context Inference

The context inference uses a **priority cascade**:

| Priority | Signal                           | Inferred Context |
|----------|----------------------------------|-------------------|
| 1        | Watch workout flag               | `.workout`        |
| 2        | macOS ongoing meeting            | `.work`           |
| 2        | macOS focus mode (work/DnD)      | `.deepWork`       |
| 2        | macOS deep work state            | `.deepWork`       |
| 2        | macOS entertainment state        | `.relaxation`     |
| 3        | Moving + HR > 130                | `.workout`        |
| 3        | Moving + HR > 100                | `.commute`        |
| 4        | 22:00-5:00                       | `.preSleep`       |
| 4        | 5:00-7:00                        | `.morning`        |
| 4        | 7:00-9:00 weekday               | `.commute`        |
| 4        | 7:00-9:00 weekend               | `.morning`        |
| 4        | 9:00-17:00 weekday              | `.work`           |
| 4        | 9:00-17:00 weekend              | `.relaxation`     |
| 4        | 17:00-19:00 weekday             | `.commute`        |
| 4        | 17:00-19:00 weekend             | `.relaxation`     |
| 4        | 19:00-22:00                      | `.relaxation`     |

**Design choice:** Priority ordering ensures that explicit physiological signals (workout detection) always override time-based heuristics. macOS signals bridge the gap between biometrics and time fallbacks.

### 2.9 Music Need Inference

Once the StateVector is built, `inferMusicNeed` determines what the user needs from music:

```
Context-driven (highest priority):
  workout         => energy < 0.5 ? .energize : .maintain
  postWorkout     => .calm
  preSleep        => .calm
  deepWork        => .focus
  work + focus>0.6 => .focus

State-driven:
  stress > 0.7    => .calm
  energy < 0.3 AND arousal < 0.4 => .energize

Change detection:
  |delta_arousal| + |delta_stress| > 0.4 => .transition

Default:
  .maintain
```

### 2.10 Confidence Scoring

Overall confidence is the average of arousal and stress confidence, plus a bonus for data source count:

```
biometricConfidence = (arousal.confidence + stress.confidence) / 2.0
sourceBonus         = min(0.3, dataSources.count * 0.05)
confidence          = clamp(biometricConfidence + sourceBonus, 0.0, 1.0)
```

Data sources tracked: heartRate, hrv, motion, macOSContext, manualMoodInput, crownInput, timeOfDay.

---

## 3. Decision Subsystem

The Decision subsystem takes the StateVector and selects the optimal song from the active playlist. It consists of five collaborating components.

### 3.1 DecisionEngine (Orchestrator)

**File:** `Brain/Decision/DecisionEngine.swift`

The `DecisionEngine` is the main entry point. Its `selectNextSong` method executes this pipeline:

```
1. Fetch candidate songs from active playlist (Core Data)
2. Apply GuardFilters to remove invalid candidates
3. Score remaining candidates via SongScorer
4. Apply TransitionController for smooth transitions
5. Generate SongExplanation
6. Return DecisionResult
7. Update session tracking (recently played, artist history)
```

**Session tracking:** The engine maintains:
- `sessionSongIds: [UUID]` -- all songs played this session
- `sessionArtists: [String]` -- artist history for same-artist limit
- `recentlyPlayed: [UUID: Date]` -- recency map with 16-hour prune
- Arrays are trimmed at 500 entries to prevent unbounded growth

**Fallback mechanism:** If GuardFilters reject all candidates, `selectFallback` re-scores the full candidate list with recency data cleared and session tracking reset. This ensures the engine always produces a result when songs exist.

### 3.2 SongScorer

**File:** `Brain/Decision/SongScorer.swift`

The SongScorer is a pure computation engine (no side effects, no Core Data writes). It evaluates each candidate song against 7 scoring dimensions:

#### 3.2.1 Weighted Scoring Formula

```
finalScore = (bpmMatch   * w_bpm)
           + (energyMatch * w_energy)
           + (familiarity * w_familiarity)
           + (historical  * w_historical)
           + (context     * w_context)
           - (recency     * 0.5)

finalScore = finalScore * (0.5 + timeOfDay * 0.5)
finalScore = max(0.0, finalScore)
```

Where `w_*` are user-configurable weights from `UserPreferences` (defaults sum to 1.0):
- `bpmWeight`: 0.25
- `energyWeight`: 0.25
- `familiarityWeight`: 0.15
- `historicalWeight`: 0.20
- `contextWeight`: 0.15

#### 3.2.2 Component: BPM Match

**Target BPM calculation:**

```
BPM range per need:
  energize:   120-160 BPM
  calm:       60-90 BPM
  focus:      80-110 BPM
  maintain:   90-130 BPM
  transition: 100-120 BPM

targetBPM = range.min + (state.energy * (range.max - range.min))

// Adjustment: if calming but high arousal, subtract 10 BPM
if need == .calm && arousal > 0.6:
    targetBPM -= 10

// Time caps:
if nighttime: targetBPM = min(targetBPM, preferences.nightMaxBPM)
if morning:   targetBPM = min(targetBPM, preferences.morningMaxBPM)

targetBPM = clamp(targetBPM, 50, 180)
```

**BPM match score:**
```
if songBPM == 0: return 0.5  (unknown BPM => neutral)
bpmDelta = |songBPM - targetBPM|
bpmMatchScore = max(0.0, 1.0 - bpmDelta / 50.0)
```

Tolerance is 50 BPM: songs within 50 BPM of target score linearly from 1.0 (exact) to 0.0 (edge).

#### 3.2.3 Component: Energy Match

```
targetEnergy per need:
  energize:   0.7 + arousal * 0.2  (high)
  calm:       0.3 - stress * 0.1   (low)
  focus:      0.4 + focus * 0.1    (moderate)
  maintain:   state.energy         (match current)
  transition: 0.5                  (middle)

energyMatchScore = max(0.0, 1.0 - |songEnergy - targetEnergy|)
```

#### 3.2.4 Component: Familiarity

```
familiarityScore = song.familiarityScore * boost

boost = 1.0 (default)
if stress > 0.6 AND preferences.preferFamiliarInStress: boost = 1.3
if need == .focus: boost = max(boost, 1.2)

familiarityScore = clamp(score, 0.0, 1.0)
```

Familiarity itself is calculated as: `min(1.0, totalPlayCount / 10.0)`.

**Design choice:** Familiar music is comforting during stress (reduced cognitive load) and helps maintain focus (no novelty distraction). The boost multipliers encode this psychoacoustic principle.

#### 3.2.5 Component: Historical Effect

Looks up the `SongEffect` entity for the song in the current activity context, then maps the appropriate score dimension to the current need:

```
need => score dimension:
  calm       => effect.calmScore
  focus      => effect.focusScore
  energize   => effect.energyScore
  maintain   => avg(calmScore, energyScore)
  transition => effect.moodLiftScore

// Blend with default (0.5) based on confidence
historicalScore = blend(0.5, rawScore, weight: effect.confidenceLevel)
```

Lookup cascade: specific context match > "any" context > highest confidence effect.

**Design choice:** Blending with 0.5 ensures songs with low confidence don't get extreme scores. As confidence grows (more plays), the learned score increasingly dominates.

#### 3.2.6 Component: Context Alignment

Each `ActivityContext` has a distinct fitness function matching songs by audio profile:

| Context     | Preferred Profile                       | Formula                                  |
|-------------|-----------------------------------------|------------------------------------------|
| workout     | High energy, high BPM                   | energyFit * 0.6 + bpmFit * 0.4          |
| deepWork    | Instrumental, moderate energy           | instrumentalFit * 0.5 + energyFit * 0.5 |
| preSleep    | Very low energy, slow, instrumental     | energyFit * 0.4 + bpmFit * 0.3 + instrumental * 0.3 |
| relaxation  | Low energy, calming                     | energyFit * 0.6 + bpmFit * 0.4          |
| morning     | Moderate energy, positive valence       | energyFit * 0.6 + valenceFit * 0.4      |
| commute     | Upbeat, moderate-high energy            | min(1.0, energy / 0.7)                   |
| social      | Popular, positive valence, moderate     | valenceFit * 0.5 + energyFit * 0.5      |
| postWorkout | Moderate energy, calming down           | 1.0 - abs(energy - 0.4)                 |
| unknown     | Neutral                                 | 0.5                                       |

#### 3.2.7 Component: Recency Penalty

```
if song was played within avoidRecentMinutes:
    recencyPenalty = 1.0 - (minutesSincePlayed / avoidRecentMinutes)
else:
    recencyPenalty = 0.0
```

Applied as a subtraction from finalScore with weight 0.5.

#### 3.2.8 Component: Time of Day

Each `TimeSlot` has a `suggestedMaxBPM`. Songs exceeding it receive a gradual penalty:

```
if songBPM <= suggestedMaxBPM: return 1.0
excess = songBPM - suggestedMaxBPM
return max(0.3, 1.0 - excess / 60.0)
```

Applied as a multiplier: `finalScore * (0.5 + timeOfDay * 0.5)`.

### 3.3 GuardFilters

**File:** `Brain/Decision/GuardFilters.swift`

Guard filters are **hard constraints** applied before scoring. A song that fails any filter is completely excluded from consideration.

#### Filter Pipeline:

| Order | Filter             | Logic                                          | Reason                                 |
|-------|--------------------|-------------------------------------------------|----------------------------------------|
| 1     | Valid ID           | `song.id != nil`                                | Corrupt data guard                     |
| 2     | Recency            | Not in `recentlyPlayed` within `avoidRecentMinutes` | Avoid repetition                   |
| 3     | Same-artist limit  | Artist not in last N (`maxSameArtistInRow`) songs | Variety enforcement                  |
| 4     | Night BPM cap      | Only at night/preSleep: `songBPM <= nightMaxBPM + 30` | Physiological appropriateness   |

#### Guard Adjustments:

The `applyWithGuardAdjustments` method adds an additional BPM filter when the `RealTimeGuardAdjuster` detects rising heart rate during calm/focus needs. It only applies if:
- BPM adjustment < -5.0
- Current need is calm or focus
- At least 3 candidates remain after filtering

**Design choice:** The 30 BPM buffer on the night cap and the 3-candidate minimum prevent overly aggressive filtering from leaving the engine with no songs to play.

### 3.4 TransitionController

**File:** `Brain/Decision/TransitionController.swift`

Ensures smooth transitions between consecutive songs by adjusting scores based on how well a candidate follows the previously played song.

#### Transition Score:

```
bpmSmoothness    = max(0.0, 1.0 - |fromBPM - toBPM| / 30.0)
energySmoothness = max(0.0, 1.0 - |fromEnergy - toEnergy| / 0.4)
genreBonus       = sharesGenreCategory ? 0.1 : 0.0

combined = bpmSmoothness * 0.4 + energySmoothness * 0.4 + genreBonus
```

#### Score Adjustment:

```
adjustedScore = candidate.finalScore * (0.7 + transitionScore.combined * 0.3)
```

A perfect transition (combined = 1.0) gives the full base score. A jarring transition (combined = 0.0) reduces the effective score to 70%.

**Design choice:** The 70/30 blend preserves the primary scoring while giving smooth transitions a meaningful tiebreaker effect. Genre comparison uses broad categories (ambient, classical, electronic, etc.) rather than exact genre strings to catch related genres.

**Performance optimization:** Genre categories for the last-played song are precomputed once, and all candidate songs are batch-fetched in a single Core Data query for O(1) lookup.

### 3.5 ExplanationGenerator

**File:** `Brain/Decision/ExplanationGenerator.swift`

Generates human-readable explanations for every song selection. Produces two formats:

- **Full explanation** (iOS): Multi-line with state description, need description, and up to 3 contributing factors sorted by contribution
- **Short explanation** (Watch): ~40 characters, format: `"[Need prefix]: [top factor]"`

Example full explanation:
```
Starting your session with this track.
Looking for music to help you relax.
- BPM closely matches target (72 BPM)
- Energy level is a great fit
- Familiar track (comforting during stress)
```

Example short explanation:
```
"To relax: great tempo match"
```

**Design choice:** Transparency is a core product principle. Users should understand why every song was chosen. This builds trust in the system and gives users confidence that the Brain isn't random.

---

## 4. Historical Subsystem

The Historical subsystem runs as a **batch background pipeline** to learn from past listening behavior. It operates on a different timescale than real-time decisions --- typically running overnight via `BGProcessingTask` or manually from Settings.

### 4.1 HistoricalEngine (Orchestrator)

**File:** `Brain/Historical/HistoricalEngine.swift`

Orchestrates a 3-step pipeline:

```
Step 1: SessionReconstructor.reconstructSessions()
    Groups PlaybackEvents into HistoricalSessions

Step 2: SongImpactCalculator.calculateImpacts()
    Computes per-song per-context EMA scores from events

Step 3: PlaylistImpactCalculator.calculatePlaylistImpacts()
    Aggregates song scores to playlist level
```

**Per-step watermarks:** Each step stores its own watermark date in UserDefaults (via App Group), enabling incremental processing. If a step fails, only that step needs to be re-run from its watermark.

**Cancellation support:** Each step checks `Task.checkCancellation()` between batches, propagating `CancellationError` cleanly when the `BGProcessingTask` expires.

**Guard against concurrent runs:** The `@MainActor` `isRunning` flag prevents multiple backfill instances from overlapping.

### 4.2 SessionReconstructor

**File:** `Brain/Historical/SessionReconstructor.swift`

Groups unprocessed `PlaybackEvent` entities into `HistoricalSession` entities.

#### Grouping Algorithm:

```
Sort events by startedAt ascending
For each consecutive pair:
    gap = event[i].startedAt - event[i-1].endedAt
    if gap > 30 minutes:
        Start new session group
    else:
        Append to current group

Filter out sessions shorter than 5 minutes
```

#### Session Enrichment:

Each session is enriched with 5 data layers:

1. **Core attributes:** startTime, endTime, durationMinutes, totalSongsPlayed, totalSkips, skipRate, avgListenPercentage, dayOfWeek, timeOfDaySlot
2. **Biometric data (HealthKit):** avgHeartRate, minHeartRate, maxHeartRate, startingHeartRate, endingHeartRate, deltaHeartRate, avgHRV, startingHRV, endingHRV, deltaHRV (queried with +/- 5 minute buffer around session boundaries)
3. **Sleep correlation:** nextNightSleepScore, nextNightSleepDuration, nextNightDeepSleepPct (searched within 12 hours after session end, minimum 3 hours duration to filter naps)
4. **Context inference:** Workout overlap check from HealthKit, then weekday/weekend time-based fallback
5. **Playlist linking:** If all events share a common playlist, the session is linked to it

#### Sleep Score Formula:

```
durationScore      = min(1.0, totalSleepHours / 8.0)
deepSleepNormalized = min(1.0, deepSleepPct / 0.25)
sleepScore         = durationScore * 0.6 + deepSleepNormalized * 0.4
```

#### Session Overall Impact Score:

```
skipScore       = 1.0 - skipRate
hrvScore        = clamp(0.5 + deltaHRV / 20.0)
engagementScore = avgListenPercentage
sleepScore      = nextNightSleepScore ?? 0.5

overallImpact = skipScore * 0.25 + hrvScore * 0.30 + engagementScore * 0.25 + sleepScore * 0.20
```

**Design choice:** The 30-minute gap rule matches typical listening behavior. The sleep correlation captures delayed effects --- calming evening playlists may improve sleep quality, and this data feeds back into playlist scoring.

### 4.3 ImpactScore

**File:** `Brain/Historical/ImpactScore.swift`

An intermediate value type that converts a single `PlaybackEvent` into 4 impact dimensions. This is the bridge between raw event data and EMA-updated `SongEffect` scores.

#### Biometric Signal Redistribution:

The calculator handles 4 modes depending on which biometric signals are available:

| Mode            | HR  | HRV | Calm Formula                                    | Energy Formula                          |
|-----------------|-----|-----|-------------------------------------------------|-----------------------------------------|
| Both available  | Yes | Yes | `0.5 + hrvImpact*0.5 + (-hrImpact)*0.3 + bonus` | `0.5 + hrImpact*0.3 + bonus`           |
| HR only         | Yes | No  | `0.5 + (-hrImpact)*0.5 + bonus*1.5`             | `0.5 + hrImpact*0.5 + bonus`           |
| HRV only        | No  | Yes | `0.5 + hrvImpact*0.7 + bonus`                   | `0.5 + bonus*1.5`                      |
| Neither         | No  | No  | `0.5 + bonus*2.0`                               | `0.5 + bonus*2.0`                      |

Where:
- `hrvImpact = hrvDelta / 10.0` (10ms = significant)
- `hrImpact = hrDelta / 10.0` (10 BPM = significant)
- `bonus = (listenPct - 0.5) * 0.2` (completion bonus, -0.1 to +0.1)
- Skip penalty: early (<15%) = -0.3, late (15-30%) = -0.15

**Focus** is always behavior-based: `0.5 + completionBonus + (skipPenalty * 0.5 if skipped)`

**Mood lift** is behavior-driven: `0.5 + completionBonus * 1.5 + skipPenalty`

**Design choice:** The 4-mode redistribution ensures the system degrades gracefully when biometric data is partial. Rather than falling back to zeros, the available signal gets more weight, and behavioral signals (listen completion) fill the gap.

### 4.4 SongImpactCalculator

**File:** `Brain/Historical/SongImpactCalculator.swift`

The batch counterpart to `LearningStore`. Processes all PlaybackEvents that have been grouped into sessions and updates `SongEffect` entities via EMA.

#### Processing Pipeline:

```
1. Fetch events with session != nil AND isImpactProcessed == NO
2. Process in batches of 100
3. For each event:
   a. Compute ImpactScore from event biometrics/behavior
   b. Find or create SongEffect for (song, contextType)
   c. Apply EMA update with two-tier learning rate
   d. Mark event as isImpactProcessed = true
   e. Update Song aggregate scores
   f. Update familiarity
4. Save after each batch
5. Support cooperative cancellation between batches
```

### 4.5 PlaylistImpactCalculator

**File:** `Brain/Historical/PlaylistImpactCalculator.swift`

Aggregates `SongEffect` scores up to the playlist level using **confidence-weighted averaging**:

```
For each playlist:
    For each song with effects:
        songWeight = avg(effect.confidenceLevel across effects)
        songCalm   = confidence-weighted avg of effect.calmScore
        songFocus  = confidence-weighted avg of effect.focusScore
        songEnergy = confidence-weighted avg of effect.energyScore

        Accumulate into playlist totals weighted by songWeight

    playlist.avgCalmEffect     = weightedCalm / totalWeight
    playlist.avgFocusEffect    = weightedFocus / totalWeight
    playlist.avgEnergyEffect   = weightedEnergy / totalWeight
    playlist.avgMoodLiftEffect = weightedMoodLift / totalWeight
    playlist.effectConfidence  = (totalWeight / songsWithEffects) * coverage
```

Context associations are built by grouping linked sessions by context type and computing frequency proportions.

---

## 5. Learning Subsystem

The Learning subsystem provides **real-time feedback** during active listening. While the Historical subsystem runs as a batch job, the Learning subsystem updates song scores immediately after each playback event.

### 5.1 LearningStore

**File:** `Brain/Learning/LearningStore.swift`

The central real-time learning coordinator. When a song finishes or is skipped, `NowPlayingViewModel` calls `processPlaybackEvent(eventObjectID:)`.

#### Processing Steps:

```
1. Fetch PlaybackEvent by ObjectID on background context
2. Calculate SkipPenaltyCalculator.calculate()
3. Calculate ResponseCreditCalculator.calculate()
4. Compute final impact scores:
   calmImpact   = 0.5 + weightedCalmCredit + weightedSkipPenalty
   energyImpact = 0.5 + weightedEnergyCredit + weightedSkipPenalty
   focusImpact  = 0.5 + focusCredit + weightedSkipPenalty
   moodLift     = 0.5 + valenceCredit + weightedSkipPenalty
5. Find or create SongEffect for (song, contextType)
6. Apply EMA update (two-tier learning rate)
7. Update Song aggregates and familiarity
8. Mark event as isImpactProcessed = true (prevents SongImpactCalculator from double-counting)
9. Save context
10. Publish ProcessedImpact on main thread
11. Update RunningSession tracker
```

### 5.2 Exponential Moving Average (EMA)

The core learning algorithm. Used by both `LearningStore` (real-time) and `SongImpactCalculator` (batch).

#### Two-Tier Learning Rate:

```
if sampleCount < 5:    alpha = 0.4  (cold start)
else:                  alpha = 0.2  (steady state, user-configurable)

newScore = (1 - alpha) * oldScore + alpha * impactScore
```

**Why EMA?** It provides several properties ideal for on-device learning:
- **O(1) memory:** Only stores the running average, not all past observations
- **Recency bias:** Recent plays have exponentially more influence than old ones
- **Stability:** Converges after ~20 samples to a stable estimate
- **Adaptability:** Adjusts if user preferences change over time

**Why two-tier?** Cold-start songs (< 5 plays) need to learn fast --- a single great experience should immediately boost the score. After 5 plays, the system has enough data to be more conservative, preventing a single outlier from destroying a good estimate.

### 5.3 Confidence Model

```
maxConfidence = hasBiometricData ? 1.0 : 0.7
confidence    = min(maxConfidence, sampleCount / 20.0)
```

- Songs with < 20 plays have proportionally lower confidence
- Songs with only behavioral data (no biometrics) are capped at 0.7 confidence
- Confidence is used to **blend** historical scores with the default (0.5), so low-confidence songs don't dominate scoring

### 5.4 SkipPenaltyCalculator

**File:** `Brain/Learning/SkipPenaltyCalculator.swift`

Classifies skips and computes penalties:

| Condition                           | Classification  | Penalty |
|-------------------------------------|-----------------|---------|
| Not skipped, listen > 30%           | `.noSkip`       | 0.0     |
| Listen < 30% (auto-detected skip)   | `.earlySkip` or `.lateSkip` | -0.15 to -0.3 |
| Manual skip, listen < 15%           | `.earlySkip`    | -0.3    |
| Manual skip, listen 15-30%          | `.lateSkip`     | -0.15   |
| Manual skip, listen > 30%           | `.nearComplete` | -0.075  |

The final penalty is weighted by `preferences.skipPenaltyWeight`.

**Design choice:** Auto-detected skips (listen < 30% even without manual skip) catch cases where the user switched apps or the song ended prematurely. The two-tier penalty reflects that an immediate skip (< 15%) is a stronger negative signal than a skip after hearing a meaningful portion.

### 5.5 ResponseCreditCalculator

**File:** `Brain/Learning/ResponseCreditCalculator.swift`

Converts biometric changes during playback into credit/penalty scores for each dimension. Uses the same 4-mode redistribution pattern as `ImpactScore`:

- Positive HRV delta (relaxation) => calm credit
- Positive HR delta (activation) => energy credit
- Listen completion => focus and valence credit
- Duration weighting: `min(1.0, listenPct * 1.5)` (full weight at ~67%)

### 5.6 RealTimeGuardAdjuster

**File:** `Brain/Learning/RealTimeGuardAdjuster.swift`

Monitors real-time conditions and produces dynamic adjustments for the next song selection:

#### Trigger 1: Skip Storm (engagement drop)

```
if 3+ skips within 5 minutes:
    Add .increaseFamiliarity adjustment
    magnitude = min(1.0, skipCount / (threshold + 2))
    Effect: up to +0.15 familiarity weight boost
```

#### Trigger 2: Rising Heart Rate During Calm/Focus

```
if HR rises > 15 BPM above baseline during calm/focus need:
    Add .reduceBPM adjustment
    magnitude = min(1.0, hrRise / (15.0 * 2))
    Effect: up to -30 BPM target reduction

    Also add .increaseCalm adjustment
```

#### Adjustment Lifecycle:
- Adjustments expire after 10 minutes
- New adjustments of the same type replace existing ones
- Expired adjustments are pruned on each operation
- Full listens decay the skip counter (remove oldest entry)

**Design choice:** The guard adjuster creates a feedback loop: if the Brain picks songs that cause physiological stress (rising HR) or behavioral rejection (skips), it self-corrects by tightening constraints for the next selection.

### 5.7 SessionQualityScorer

**File:** `Brain/Learning/SessionQualityScorer.swift`

Scores overall session quality for reporting. Maintains a `RunningSession` tracker that accumulates per-song metrics:

```
overallScore = (1 - skipRate) * skipWeight
             + normalizedHRV * hrvWeight
             + avgListenPercentage * listenWeight
             + sleepScore * sleepWeight
```

The `RunningSession` class tracks: totalSongs, totalSkips, skipRate, deltaHRV (first vs last HRV reading), and avgListenPercentage.

---

## 6. Feature Subsystem

### 6.1 FeatureExtractor

**File:** `Brain/Features/FeatureExtractor.swift`

Estimates audio features from genre metadata when Apple Music API data is unavailable. Uses lookup tables mapping genre categories to typical values:

| Genre       | BPM | Energy | Valence | Instrumentalness |
|-------------|-----|--------|---------|-------------------|
| ambient     | 70  | 0.15   | 0.40    | 0.85              |
| classical   | 80  | 0.25   | 0.50    | 0.90              |
| jazz        | 100 | 0.35   | 0.55    | 0.40              |
| pop         | 120 | 0.55   | 0.70    | 0.05              |
| rock        | 130 | 0.70   | 0.50    | 0.15              |
| electronic  | 128 | 0.65   | 0.55    | 0.60              |
| hip-hop     | 90  | 0.50   | 0.45    | 0.05              |
| metal       | 140 | 0.85   | 0.30    | 0.20              |

Derived scores computed from features:
```
calmScore       = (1 - energy) * 0.5 + (1 - bpmNorm) * 0.3 + instrumentalness * 0.2
focusScore      = instrumentalness * 0.4 + (1 - energy) * 0.3 + (1 - acousticDensity) * 0.3
activationScore = energy * 0.5 + bpmNorm * 0.3 + valence * 0.2
```

Initial confidence for genre-based estimates: 0.4 (low --- the system knows these are rough estimates).

**Batch extraction:** Can process all songs missing features via `extractAllMissingFeatures()`, running on a background context with batch saves.

### 6.2 FeatureNormalizer

**File:** `Brain/Features/FeatureNormalizer.swift`

Utility for normalizing values:
- `normalizeBPM(_ bpm, libraryMin: 60, libraryMax: 180)` => 0.0-1.0
- `clamp(_ value)` => clamps to 0.0-1.0
- `normalize(_ value, min, max)` => linear normalization

---

## 7. Shared Infrastructure

### 7.1 SongEffectHelper

**File:** `Brain/Shared/SongEffectHelper.swift`

Shared Core Data helpers used by both `LearningStore` and `SongImpactCalculator`:

**`findOrCreateEffect`:** Finds an existing `SongEffect` for a (song, contextType) pair, or creates one with default scores (0.5 for all dimensions, confidence 0.0). The lookup is keyed on (song, contextType) only --- `timeOfDaySlot` is set but not used for uniqueness.

**`updateSongAggregates`:** Recomputes the song's aggregate scores as a confidence-weighted average across all of its `SongEffect` entities:
```
For each effect with confidence > 0:
    Accumulate weightedCalm, weightedFocus, weightedActivation, weightedMoodLift
    Track maxConfidence

song.calmScore       = weightedCalm / totalWeight
song.focusScore      = weightedFocus / totalWeight
song.activationScore = weightedActivation / totalWeight
song.moodLiftScore   = weightedMoodLift / totalWeight
song.confidenceLevel = maxConfidence
```

If no confident effects exist, scores reset to 0.5 with confidence 0.0.

**`updateFamiliarity`:** `song.familiarityScore = min(1.0, totalPlayCount / 10.0)`

### 7.2 Core Data Entities

The Brain interacts with these Core Data entities:

| Entity            | Purpose                                    | Key Attributes                                           |
|-------------------|--------------------------------------------|----------------------------------------------------------|
| `Song`            | Individual track                           | bpm, energyEstimate, calmScore, focusScore, activationScore, moodLiftScore, familiarityScore, confidenceLevel, totalPlayCount |
| `SongEffect`      | Per-song per-context learned effectiveness | calmScore, focusScore, energyScore, moodLiftScore, sampleCount, confidenceLevel, contextType, timeOfDaySlot |
| `PlaybackEvent`   | Single play/skip event                     | startedAt, endedAt, listenPercentage, wasSkipped, hrvDelta, hrDelta, hrAtStart, hrvAtStart, isImpactProcessed |
| `HistoricalSession` | Group of events forming a session        | avgHeartRate, deltaHRV, skipRate, avgListenPercentage, nextNightSleepScore, contextType |
| `Playlist`        | User playlist with aggregated scores      | avgCalmEffect, avgFocusEffect, avgEnergyEffect, avgMoodLiftEffect, effectConfidence, contextAssociations |

---

## 8. Data Flow Diagrams

### 8.1 Real-Time Song Selection Flow

```
User taps "Play" or song ends
         │
         ▼
DecisionEngine.selectNextSong()
         │
    ┌────┴────┐
    ▼         ▼
Fetch      Read current
candidate  StateVector
songs      from StateEngine
    │         │
    └────┬────┘
         ▼
   GuardFilters.apply()
         │ filtered candidates
         ▼
   SongScorer.scoreAllCandidates()
         │
         │  For each song:
         │  ├── BPM match against target
         │  ├── Energy match against target
         │  ├── Familiarity * stress/focus boost
         │  ├── Historical effect from SongEffect
         │  ├── Context alignment scoring
         │  ├── Recency penalty
         │  └── Time-of-day multiplier
         │
         ▼ sorted [SongScore]
   TransitionController.selectWithTransition()
         │ adjusted for smooth transition
         ▼
   ExplanationGenerator.generate()
         │
         ▼
   DecisionResult returned to UI
```

### 8.2 Real-Time Learning Flow

```
Song finishes or is skipped
         │
         ▼
EventLogger creates PlaybackEvent
         │ (hr/hrv deltas, listen%, wasSkipped)
         ▼
LearningStore.processPlaybackEvent()
    │
    ├── SkipPenaltyCalculator.calculate()
    │       → penalty: -0.3 / -0.15 / 0.0
    │
    ├── ResponseCreditCalculator.calculate()
    │       → calmCredit, energyCredit, focusCredit
    │
    ├── Compute final impacts (0.5 + credits + penalties)
    │
    ├── SongEffectHelper.findOrCreateEffect()
    │
    ├── EMA update: score = (1-α)·old + α·new
    │       α = 0.4 (cold start) or 0.2 (steady)
    │
    ├── SongEffectHelper.updateSongAggregates()
    │
    └── RealTimeGuardAdjuster (if skip/HR rise)
            → may add BPM reduction or familiarity boost
```

### 8.3 Historical Backfill Flow

```
BGProcessingTask fires (or user taps "Run Backfill")
         │
         ▼
HistoricalEngine.runBackfill()
         │
    ┌────┴────────────────────────────┐
    ▼                                 │
Step 1: SessionReconstructor          │
    │ Fetch unprocessed events        │
    │ Group by 30-min gap rule        │
    │ Filter < 5 min sessions         │
    │ Enrich with HealthKit HR/HRV    │
    │ Correlate with sleep data       │
    │ Infer activity context          │
    │ Score session overall impact     │
    │                                 │
    ▼ Update watermark                │
Step 2: SongImpactCalculator          │
    │ Fetch events with sessions      │
    │ Batch process (100 per batch)   │
    │ ImpactScore.calculate(event)    │
    │ EMA update SongEffect           │
    │ Update Song aggregates          │
    │                                 │
    ▼ Update watermark                │
Step 3: PlaylistImpactCalculator      │
    │ Confidence-weighted averages    │
    │ Build context associations      │
    │                                 │
    ▼                                 │
Update lastBackfillDate ◀─────────────┘
```

---

## 9. Constants and Tuning Parameters

All tuning constants are centralized in `Shared/Utilities/Constants.swift`.

### 9.1 State Engine

| Constant                     | Value | Purpose                              |
|------------------------------|-------|--------------------------------------|
| `updateIntervalSeconds`      | 30    | StateVector refresh interval         |
| `biometricWindowMinutes`     | 5     | HR averaging window                  |
| `hrvWindowMinutes`           | 10    | HRV validity window                  |
| `manualMoodDecayMinutes`     | 15    | Manual mood expiry                   |
| `defaultRestingHeartRate`    | 70    | Fallback resting HR                  |
| `maxHeartRateBase`           | 220   | Max HR formula base (220 - age)      |
| `defaultUserAge`             | 35    | Fallback age for HR calculation      |
| `minimumConfidenceThreshold` | 0.3   | Minimum usable confidence            |

### 9.2 Decision Engine

| Constant                   | Value | Purpose                                |
|----------------------------|-------|----------------------------------------|
| `bpmTolerance`             | 50    | BPM match scoring window               |
| `maxBPMTransitionDelta`    | 30    | Max BPM jump for smooth transition     |
| `maxEnergyTransitionDelta` | 0.4   | Max energy jump for smooth transition  |
| `fullConfidenceSampleCount`| 20    | Plays needed for full confidence       |
| `defaultHistoricalScore`   | 0.5   | Default when no effect data exists     |
| Energize BPM range         | 120-160 | Target BPM for energize need         |
| Calm BPM range             | 60-90   | Target BPM for calm need             |
| Focus BPM range            | 80-110  | Target BPM for focus need            |
| `absoluteMinBPM`           | 50    | Hard floor for target BPM              |
| `absoluteMaxBPM`           | 180   | Hard ceiling for target BPM            |

### 9.3 Learning

| Constant                    | Value | Purpose                                 |
|-----------------------------|-------|-----------------------------------------|
| `defaultLearningRate`       | 0.2   | Steady-state EMA alpha                  |
| `coldStartLearningRate`     | 0.4   | Cold-start EMA alpha (first 5 plays)    |
| `coldStartThreshold`        | 5     | Plays before switching to steady alpha  |
| `skipPenaltyMultiplier`     | 0.3   | Early skip penalty magnitude            |
| `lateSkipPenalty`           | 0.15  | Late skip penalty magnitude             |
| `hrvNormalizationFactor`    | 10.0  | HRV delta normalization (10ms = significant) |
| `hrNormalizationFactor`     | 10.0  | HR delta normalization (10 BPM = significant) |
| `minimumListenPercentage`   | 0.3   | Below this, auto-detected as skip       |
| `completionBonusThreshold`  | 0.5   | Completion bonus kicks in above 50%     |
| `behaviorOnlyMaxConfidence` | 0.7   | Max confidence without biometrics       |
| `earlySkipThreshold`        | 0.15  | Below this, classified as early skip    |

### 9.4 Session & Backfill

| Constant                       | Value | Purpose                               |
|--------------------------------|-------|---------------------------------------|
| `sessionGapMinutes`            | 30    | Gap that starts a new session         |
| `minimumSessionMinutes`        | 5     | Sessions shorter than this are dropped|
| `sleepCorrelationWindowHours`  | 12    | Hours after session to look for sleep |
| `eventBatchSize`               | 100   | Events per batch in impact calculation|
| `sessionSaveBatchSize`         | 50    | Sessions per batch save               |
| `minimumSubstantialSleepHours` | 3.0   | Minimum sleep duration (filter naps)  |
| `idealDeepSleepPercentage`     | 0.25  | Deep sleep normalization target       |
| `incrementalOverlapMinutes`    | 30    | Overlap buffer for incremental runs   |

### 9.5 Crown Control

| Constant                    | Value | Purpose                              |
|-----------------------------|-------|--------------------------------------|
| `sensitivityMultiplier`     | 0.5   | Crown rotation sensitivity           |
| `debounceIntervalSeconds`   | 0.3   | Crown update debounce                |
| `adjustmentDecaySeconds`    | 300   | Crown effect duration (5 minutes)    |
| `maxAdjustment`             | 0.5   | Maximum crown energy offset          |

---

## 10. Design Choices and Rationale

### 10.1 Why EMA Over Other Learning Algorithms?

**Considered:** Linear regression, neural networks, collaborative filtering, Bayesian updating.

**Chosen:** Exponential Moving Average.

Rationale:
- **O(1) memory per song-context pair:** No need to store historical observations. Core Data stores only the current score and sample count.
- **Recency bias built in:** Musical preferences change. EMA naturally weights recent experiences more heavily. A song that used to relax you but no longer does will have its calm score drift down.
- **No training required:** No separate training phase, no model retraining, no GPU. Just arithmetic on each observation.
- **Interpretable:** Users and developers can understand "the calm score is 0.73 after 15 plays" far more easily than weights in a neural network.
- **Graceful cold start:** The two-tier alpha (0.4 cold start, 0.2 steady) lets new songs converge quickly while keeping established scores stable.

### 10.2 Why Per-Context SongEffect Entities?

A song that helps you focus during work may not help you relax at night. By keying `SongEffect` on (song, contextType), the system learns distinct effectiveness profiles per context. A jazz track might have:
- `calmScore: 0.8` in "preSleep" context
- `focusScore: 0.7` in "deepWork" context
- `energyScore: 0.4` in "workout" context

### 10.3 Why Weighted Scoring Over Rule-Based Selection?

A pure rule-based system ("always pick the lowest BPM during preSleep") is brittle and can't learn. A pure ML system (neural recommendation) is opaque and requires large datasets. The weighted linear scoring formula offers:
- **Transparency:** Each component's contribution is visible in the explanation
- **Tunability:** Users can adjust weights via preferences
- **Extensibility:** New scoring factors can be added without retraining
- **Predictability:** The system never makes inexplicable choices

### 10.4 Why Guard Filters Separate From Scoring?

Guard filters enforce **hard constraints** that should never be violated regardless of score. Merging them into the scoring formula would risk a song with an extremely high historical score overriding the recency constraint and playing the same song twice in a row. Separation ensures absolute enforcement.

### 10.5 Why On-Device Only?

- **Privacy:** Biometric data (heart rate, HRV, sleep patterns) is among the most sensitive personal data. Sending it to a server for recommendation would be a privacy violation.
- **Latency:** Song selection must happen in under a second. Network round-trips add unacceptable delay.
- **Offline operation:** Users listen to music on planes, in subways, and in areas without connectivity.
- **Apple ecosystem alignment:** Apple strongly encourages on-device processing and provides frameworks (Core ML, HealthKit, Core Data) optimized for it.

### 10.6 Why Blend Manual and Biometric Signals?

Biometrics capture involuntary physiological state but miss subjective experience. A user might have low stress (high HRV) but feel mentally exhausted. Manual mood input captures this gap. The blend weights (70% max manual influence, decaying over 15 minutes) prevent either signal from completely dominating.

### 10.7 Why Sleep Correlation?

Evening listening sessions may have delayed effects on sleep quality. By correlating session data with next-night sleep metrics, the system can learn which playlists and songs genuinely promote better sleep (higher deep sleep percentage, longer duration) versus those that just feel calming in the moment.

---

## 11. On-Device AI and ML

### 11.1 Current AI Approach

Resonance uses **heuristic AI** rather than deep learning. The algorithms are hand-crafted formulas informed by psychoacoustic research and physiological signal processing:

1. **Heart Rate Reserve Method:** Established exercise physiology formula for normalizing heart rate across individuals.
2. **HRV-Stress Inverse Mapping:** Based on autonomic nervous system research showing that reduced HRV correlates with sympathetic dominance (stress).
3. **Exponential Moving Average:** A well-understood online learning algorithm used in signal processing and finance.
4. **Weighted Linear Scoring:** Classic decision analysis approach with interpretable components.
5. **Genre-Based Feature Estimation:** Lookup tables mapping musical genres to typical audio characteristics when API data is unavailable.

### 11.2 Why Not Deep Learning (Yet)?

- **Data sparsity:** A typical user has 200-500 songs across 5-10 playlists. This is far too few for training a meaningful neural network from scratch.
- **Cold start:** New users have zero playback history. The heuristic system works from day one using genre features, time-of-day rules, and BPM matching.
- **Interpretability:** Users can see "BPM closely matches target (72 BPM)" and understand why a song was chosen. Neural network outputs are opaque.
- **Compute budget:** The iPhone's Neural Engine is powerful, but the current approach completes song selection in milliseconds with pure Swift arithmetic. There's no benefit to adding ML inference latency.

### 11.3 Core ML Integration Points

The architecture is designed with Core ML integration in mind. The `product.md` lists Core ML as a technology requirement. Potential integration points:

1. **Feature Extraction:** A Core ML model could replace genre-based estimation with actual audio analysis (MFCCs, spectrograms). Apple's Sound Analysis framework could classify audio characteristics.
2. **State Estimation:** A trained model could produce more nuanced StateVector estimates by learning the relationship between raw biometric sequences and subjective states.
3. **Scoring:** A Core ML model could learn optimal weight combinations per user, replacing static `UserPreferences` weights.

### 11.4 Apple Framework Usage

| Framework      | Usage                                          |
|----------------|------------------------------------------------|
| **HealthKit**  | HR, HRV, sleep analysis, workout detection     |
| **Core Data**  | All persistent storage (songs, effects, events)|
| **MusicKit**   | Playlist access, playback control              |
| **BackgroundTasks** | BGProcessingTask for historical backfill  |
| **WatchConnectivity** | Biometric streaming from Watch          |
| **Combine**    | @Published state propagation                   |
| **SwiftUI**    | Reactive UI driven by Brain state              |

---

## 12. Possible Enhancements

### 12.1 Core ML Song Feature Model

**What:** Train a Create ML Tabular Regressor on song audio features from a labeled dataset, then deploy as a `.mlmodel` that predicts energy, valence, and instrumentalness from genre, duration, and other metadata.

**How it enhances the current system:** Replaces the static genre lookup tables in `FeatureExtractor` with learned predictions. Songs with uncommon genre combinations (e.g., "jazz-electronic fusion") would get more accurate features instead of falling back to defaults.

**Feasibility:** High. Create ML Tabular Regressors are small (< 1MB), inference is < 1ms, and they can be trained in Xcode with a few hundred labeled examples.

### 12.2 Contextual Bandit for Exploration vs. Exploitation

**What:** Replace the deterministic "pick highest score" selection with a Thompson Sampling or Upper Confidence Bound (UCB) bandit that occasionally explores less-played songs.

**How it enhances the current system:** The current system has an exploitation bias --- songs that scored well early get played more, reinforcing their scores, while unexplored songs never get a chance. A bandit algorithm would inject controlled exploration, discovering hidden gems in the user's library.

**Implementation sketch:**
```
For each candidate song:
    sample = Thompson sample from Beta(alpha, beta)
    where alpha = sampleCount * score, beta = sampleCount * (1 - score)
    Pick song with highest sample (not highest mean)
```

**Feasibility:** High. Thompson sampling adds minimal computation and can be implemented in pure Swift with no external dependencies.

### 12.3 Transformer-Based Sequence Model for Next-Song Prediction

**What:** A small transformer model (~1M parameters) trained on the user's listening sequences to predict which song should follow which, learning implicit transition preferences.

**How it enhances the current system:** The current TransitionController uses simple BPM and energy smoothness. A sequence model could learn complex patterns: "after 3 upbeat songs, the user typically wants a ballad" or "this user always follows Artist A with Artist B."

**Feasibility:** Medium. Apple's Neural Engine can run small transformers efficiently. The challenge is gathering enough on-device training data --- a user needs hundreds of sessions before meaningful sequence patterns emerge. The model would need to be tiny (< 5MB) to avoid memory pressure on older devices.

### 12.4 Reinforcement Learning with Biometric Reward

**What:** Frame song selection as a contextual bandit problem where the reward signal is the biometric response (positive HRV change = positive reward, skip = negative reward).

**How it enhances the current system:** Currently, the EMA updates treat all plays equally. An RL approach would learn a policy that maximizes long-term biometric improvement, potentially discovering multi-song sequences that work better together than individually.

**Feasibility:** Medium-high. The reward signal (HRV delta + skip penalty) already exists in `ImpactScore`. The policy could be a simple linear model updated via policy gradient, running entirely on-device.

### 12.5 Federated Learning for Cold-Start Bootstrapping

**What:** Use Apple's on-device ML training infrastructure to train a shared model across users without transmitting personal data. Each device computes gradients locally and only shares anonymized model updates.

**How it enhances the current system:** New users currently start with zero historical data and rely entirely on genre features and time-of-day rules. A federated model could provide population-level priors: "ambient music at 60 BPM tends to reduce stress across users" --- giving the system a better starting point before personal data accumulates.

**Feasibility:** Low-medium. Apple does not publicly offer a general federated learning framework for third-party apps (as of 2025). The concept would require significant infrastructure work.

### 12.6 Waveform-Based Audio Feature Extraction

**What:** Use Apple's Sound Analysis framework (`SNAudioStreamAnalyzer`) or a custom Core ML model to extract audio features (tempo, energy, spectral centroid, loudness) directly from the song's audio stream during playback.

**How it enhances the current system:** Currently, BPM and energy are estimated from genre metadata with confidence 0.4. Waveform analysis could produce high-confidence (0.9+) features for every song, dramatically improving scoring accuracy.

**Feasibility:** High for basic tempo detection (Apple provides built-in APIs). Medium for custom spectral features (requires a trained model and real-time audio buffer access, which MusicKit may restrict for DRM-protected content).

### 12.7 Circadian Rhythm Personalization

**What:** Learn the user's personal circadian patterns from multi-week HR, HRV, and activity data. Build a personalized time-of-day model that replaces the static hour-based context inference.

**How it enhances the current system:** The current system assumes everyone is a "9-to-5 worker." Night-shift workers, students with irregular schedules, and travelers across time zones get incorrect context inferences. A learned circadian model would adapt to any schedule.

**Feasibility:** High. HealthKit already provides multi-week HR trends. The model would be a simple per-hour average that updates daily.

### 12.8 Multi-Song Playlist Generation

**What:** Instead of selecting one song at a time, generate a coherent sequence of 5-10 songs that forms an arc (e.g., gradually reducing energy for pre-sleep, or building energy for a workout).

**How it enhances the current system:** Currently, each song is selected independently. While TransitionController provides adjacent-song smoothness, there's no concept of a session-level trajectory. Multi-song generation could plan: "start at 120 BPM and reduce by 10 BPM per song for the next 6 songs."

**Feasibility:** Medium. Requires dynamic programming or beam search over the candidate pool, which adds complexity. The scoring infrastructure already exists --- the challenge is defining and optimizing for trajectory quality rather than per-song quality.

### 12.9 Emotion Detection from Watch Sensors

**What:** Use the Apple Watch's accelerometer, gyroscope, and skin temperature sensors (Ultra/Series 8+) alongside HR/HRV to detect emotional states more accurately.

**How it enhances the current system:** The current stress/arousal calculations use only HR and HRV. Electrodermal activity, skin temperature changes, and movement patterns provide additional emotional context that could improve state estimation.

**Feasibility:** Medium. Skin temperature is available on newer Apple Watch models. The challenge is building accurate emotion classifiers from these noisy signals without large labeled datasets.

---

*End of Brain Technical Documentation*

*This document covers the implementation as of February 2026.*
*Source: 19 Swift files across 6 Brain subdirectories, plus Constants.swift, plan.md, and product.md.*
