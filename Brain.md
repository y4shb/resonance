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
7. [Novel Features (March 2026)](#7-novel-features-march-2026)
8. [Shared Infrastructure](#8-shared-infrastructure)
9. [Data Flow Diagrams](#9-data-flow-diagrams)
10. [Constants and Tuning Parameters](#10-constants-and-tuning-parameters)
11. [Design Choices and Rationale](#11-design-choices-and-rationale)
12. [On-Device AI and ML](#12-on-device-ai-and-ml)
13. [Possible Enhancements](#13-possible-enhancements)
14. [Research References](#14-research-references)

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
 │   └── StateEngine.swift              # Real-time state estimation (→ moved to Shared/Brain/)
 ├── Decision/
 │   ├── DecisionEngine.swift           # Orchestrates the selection pipeline (→ moved to Shared/Brain/)
 │   ├── SongScorer.swift               # Multi-factor song scoring (→ moved to Shared/Brain/)
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
 │   ├── SkipPenaltyCalculator.swift    # Skip penalty calculation
 │   ├── BiometricCrossfade.swift       # HR-zone-based crossfade durations (WS-2.2)
 │   ├── ResonanceScoreCalculator.swift # Post-session resonance score computation
 │   └── MultiComponentReward.swift     # Multi-component reward signal for learning
 ├── Features/
 │   ├── FeatureExtractor.swift         # Genre-based feature estimation
 │   ├── FeatureNormalizer.swift        # Value normalization utilities
 │   ├── AudioAnalyzer.swift            # Real-time audio analysis (BPM, energy, spectral)
 │   ├── RealtimeBPMVerifier.swift      # Verifies BPM estimates against live audio
 │   ├── VocalDetector.swift            # FFT-based vocal/instrumental detection
 │   └── MoodForecastEngine.swift       # Multi-horizon mood trajectory prediction
 └── Shared/
     └── SongEffectHelper.swift         # Core Data helpers for SongEffect

Shared/Brain/
 ├── SharedDecisionEngine.swift         # DecisionEngine (cross-target visible)
 ├── SharedStateEngine.swift            # StateEngine (cross-target visible)
 ├── SharedSongScorer.swift             # SongScorer (cross-target visible)
 ├── SessionPlanner.swift               # Session arc planning (WS-4)
 └── SessionCritic.swift                # Post-session analysis
```

### 1.3 Shared Brain Components

In March 2026, three core Brain files were moved to `Shared/Brain/` for cross-target visibility (iPhone and Watch):

| Original Location | New Location | Reason |
|---|---|---|
| `Brain/Decision/DecisionEngine.swift` | `Shared/Brain/SharedDecisionEngine.swift` | Watch needs decision context for UI |
| `Brain/State/StateEngine.swift` | `Shared/Brain/SharedStateEngine.swift` | Watch needs state vector for display |
| `Brain/Decision/SongScorer.swift` | `Shared/Brain/SharedSongScorer.swift` | Watch needs scoring info for explanations |

These shared files use `@unchecked Sendable` conformance with `NSLock`-based synchronization for thread safety across concurrency boundaries, rather than actor isolation which would require `await` at every call site.

Two new files were also added to `Shared/Brain/`:
- `SessionPlanner.swift` -- Plans multi-song session arcs with phases (see Section 7.5)
- `SessionCritic.swift` -- Post-session analysis for learning feedback

### 1.4 Platform Constraints

All Brain code is wrapped in `#if os(iOS)` because the Brain runs exclusively on the iPhone. The Apple Watch collects biometric data and sends it via WatchConnectivity. The Mac sends context signals. But all intelligence lives on the iPhone. The `MusicKitService.swift` is additionally wrapped with `#if os(iOS)` to prevent compilation on Watch and Mac targets.

### 1.5 Subsystem Relationship Diagram

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

**File:** `Shared/Brain/SharedStateEngine.swift` (formerly `Brain/State/StateEngine.swift`)

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

**Valence (Enhanced with Multi-Signal Fusion):**

The original single-factor formula `valence = 0.5 - stress * 0.3` has been enhanced with multi-signal valence estimation based on research showing SDNN correlation with positive affect (r=0.14-0.29) (Grossman et al., 2024, arXiv).

```
stressComponent    = -stress * 0.25
activityBonus      = isPhysicallyActive ? 0.10 : 0.0
hrvTrendComponent  = (currentHRV > previousHRV) ? +0.05 : -0.03   // Rising HRV = improving mood
sleepComponent     = (sleepComposite > 0.6) ? +0.08 : 0.0         // Good sleep = better morning valence

valence = clamp(0.5 + stressComponent + activityBonus + hrvTrendComponent + sleepComponent, 0.0, 1.0)
```

Signal contributions:
- **Stress (HRV-derived):** Primary negative driver. High stress suppresses valence (weight -0.25, reduced from -0.30 to make room for other signals).
- **Activity bonus:** Physical activity elevates mood via endorphin release. Applied when `activityContext` is workout, commute with movement, or step count exceeds 70% of 7-day average (Bae et al., 2018, JMIR Mental Health).
- **HRV trend:** A rising HRV trajectory over the past 10 minutes indicates parasympathetic recovery and improving emotional state (Shaffer & Ginsberg, 2017, Frontiers in Public Health).
- **Sleep component:** Morning valence is boosted when overnight sleep composite exceeds 0.6, reflecting research that sleep quality is a strong predictor of next-day positive affect (Konjarski et al., 2024, npj Digital Medicine).

**Backward compatibility:** When only HR/HRV data is available (no sleep or activity context), the formula reduces to approximately the original: `0.5 - stress * 0.25`, differing by at most 0.05 from the legacy calculation.

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

### 2.11 Movement Pattern as Mood Signal

Movement patterns serve as an independent mood indicator, validated by wrist-worn accelerometer studies showing that movement variability and sedentary duration correlate with self-reported mood states (Bae et al., 2018, JMIR Mental Health; Rodriguez-Blazquez et al., 2025, Frontiers in Psychology).

**Sedentary Duration:**
```
if sedentaryMinutes > 60:
    moodPenalty = -0.05   // Prolonged stillness correlates with negative mood
```

**Step Count Trend:**
```
stepRatio = todaySteps / sevenDayAvgSteps
if stepRatio < 0.70:
    energyAdjustment = -0.08   // Below 70% of 7-day average = low energy/mood
elif stepRatio > 1.30:
    energyAdjustment = +0.05   // Above 130% = elevated energy
```

**Movement Variability (Fidgeting Detection):**
```
accelStdDev = standardDeviation(accelerometerMagnitude, window: 5min)
if accelStdDev > 0.15 AND activityContext == .sedentary:
    stressAdjustment = +0.05   // High variability during sedentary = fidgeting/anxiety
```

**Design choice:** Movement signals are given low weight (0.05 per factor) because they are noisy and context-dependent. They serve as supporting evidence that adjusts the biometric-derived state, not as primary drivers. The 7-day rolling average for step count personalizes the threshold to each user's baseline activity level.

### 2.12 Sleep-Derived Next-Day Mood Baseline

Overnight biometric data provides a strong predictor of next-day emotional state. Research demonstrates that sleep architecture, overnight HRV, and respiratory rate collectively predict morning mood with moderate accuracy (Sano et al., 2023, MDPI Sensors; Konjarski et al., 2024, npj Digital Medicine; Hartmann et al., 2025, Frontiers in Psychiatry).

**Sleep Composite Formula:**
```
sleepComposite = duration   * 0.25
              + deepSleep   * 0.20
              + hrvSleep    * 0.30
              + respRate    * 0.15
              + wristTemp   * 0.10

Where:
  duration  = min(1.0, totalSleepHours / 8.0)
  deepSleep = min(1.0, deepSleepPercentage / 0.25)
  hrvSleep  = clamp(overnightAvgHRV / baselineHRV, 0.0, 1.5) / 1.5
  respRate  = 1.0 - clamp(|avgRespRate - 14.0| / 6.0, 0.0, 1.0)   // 14 breaths/min = optimal
  wristTemp = 1.0 - clamp(|tempDelta| / 1.5, 0.0, 1.0)            // Stable temp = good thermoregulation
```

**Application to Morning StateVector:**
```
if isFirstStateVectorOfDay AND sleepComposite is available:
    stress  = stress  - (sleepComposite - 0.5) * 0.15   // Good sleep reduces morning stress
    valence = valence + (sleepComposite - 0.5) * 0.10   // Good sleep improves morning valence
```

**Data availability:** `duration` and `deepSleep` are available on all Apple Watch models. `hrvSleep` requires overnight HRV tracking (watchOS 9+). `respRate` requires Apple Watch Series 5+. `wristTemp` requires Apple Watch Series 8+ or Ultra. Missing components are omitted and weights redistributed proportionally.

**Design choice:** HRV during sleep receives the highest weight (0.30) because overnight HRV is less confounded by daytime stressors and reflects true autonomic recovery. The composite is anchored at 0.5 (neutral) to avoid biasing the state when sleep data is ambiguous.

### 2.13 Circadian HRV Correction

HRV follows a well-documented diurnal pattern driven by autonomic nervous system circadian rhythms, with peak values during early morning sleep and nadir during early afternoon (Sammito & Bockelmann, 2022, PMC; Nunan et al., 2010, ScienceDirect). Using a static `baselineHRV = 50.0` ignores these fluctuations, causing the stress estimate to appear artificially high in the afternoon and low in the early morning.

**Population-Average Diurnal HRV Correction Factors:**

| Hour Range | Factor | Rationale |
|------------|--------|-----------|
| 0:00-6:00  | 1.15   | Peak vagal tone during sleep |
| 6:00-10:00 | 1.10   | Morning parasympathetic dominance |
| 10:00-14:00| 1.00   | Baseline reference period |
| 14:00-18:00| 0.85   | Afternoon sympathetic surge, HRV nadir |
| 18:00-22:00| 0.95   | Evening recovery |
| 22:00-24:00| 1.05   | Pre-sleep vagal ramp-up |

**Application to Stress Calculation:**
```
// Replaces static baselineHRV = 50.0 with time-adjusted value
diurnalFactor  = circadianHRVFactor(for: currentHour)
adjustedBaseline = baselineHRV * diurnalFactor

ratio  = currentHRV / adjustedBaseline
stress = clamp(1.0 - (ratio * 0.6), 0.0, 1.0)
```

**Example:** At 15:00 (factor 0.85), baseline becomes 42.5ms. An HRV reading of 40ms yields ratio=0.94, stress=0.44 (moderate). Without correction, the same reading against 50ms baseline yields ratio=0.80, stress=0.52 (artificially elevated).

**Personalization:** After collecting 2+ weeks of hourly HRV data, the population-average factors can be replaced with per-user diurnal profiles computed from HealthKit, further improving accuracy (see Section 13.7 Circadian Rhythm Personalization).

### 2.14 Music-Biometric Response Validation

To close the feedback loop between music selection and physiological response, the Brain validates whether the selected music achieved its intended effect. This enables the Learning subsystem to assign more accurate reward signals and supports the iso-principle entrainment detection (Section 3.2.13).

**Validation Criteria by Music Need:**

| Need | Success Signal | Threshold | Measurement Window |
|------|---------------|-----------|-------------------|
| Calm | RMSSD increase | > 5ms from pre-song baseline | Song duration or 3 minutes, whichever is shorter |
| Calm | HR decrease | > 3 BPM from pre-song baseline | Song duration |
| Energize | HR increase | Proportional to BPM target gap | 2 minutes after song start |
| Focus | HR stability | stddev(HR) < 3 BPM during song | Full song duration |
| Focus | HRV coherence | Coherence ratio increase > 0.1 | Full song duration |

**Entrainment Detection:**
```
// Detect whether user's HR is synchronizing with song tempo
entrainmentGap = |heartRate - songBPM|

if entrainmentGap is decreasing over 3+ consecutive songs:
    entrainmentDetected = true
    entrainmentStrength = 1.0 - (currentGap / initialGap)
```

Entrainment detection supports the iso-principle implementation (Section 3.2.13) by confirming whether the gradual BPM shifting is having the desired physiological effect (McCraty & Childre, HeartMath Institute; Juslin & Vastfjall, 2008, Behavioral and Brain Sciences; Chen et al., 2026, Frontiers in Psychology).

**Integration with Learning:**
```
responseCredit = baseCredit * validationMultiplier

validationMultiplier:
  1.2 if biometric response matches intended need (validated success)
  1.0 if no biometric data available (neutral)
  0.8 if biometric response contradicts intended need (validated failure)
```

**Design choice:** Validation thresholds are intentionally conservative (e.g., RMSSD > 5ms rather than > 2ms) to avoid false positives from normal HRV fluctuation. The 3-minute minimum measurement window ensures sufficient data for reliable assessment.

---

## 3. Decision Subsystem

The Decision subsystem takes the StateVector and selects the optimal song from the active playlist. It consists of five collaborating components.

### 3.1 DecisionEngine (Orchestrator)

**File:** `Shared/Brain/SharedDecisionEngine.swift` (formerly `Brain/Decision/DecisionEngine.swift`)

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

**File:** `Shared/Brain/SharedSongScorer.swift` (formerly `Brain/Decision/SongScorer.swift`)

The SongScorer is a pure computation engine (no side effects, no Core Data writes). It evaluates each candidate song against 7 scoring dimensions, plus additional context-aware scoring layers added in March 2026 (circadian energy, cognitive load, sleep preparation, arc phase, and iso-principle):

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
if need == .focus: boost = max(boost, 1.5)

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

#### 3.2.9 Component: Circadian Energy Curve (March 2026)

The `circadianEnergyTarget(for hour:)` method returns a time-aware energy target based on typical human circadian rhythms:

```
Hour range    | Phase              | Energy target
6-10          | Morning ramp       | 0.3 → 0.6 (linear ramp)
10-14         | Midday peak        | 0.6 → 0.7
14-18         | Afternoon decline  | 0.7 → 0.4
18-22         | Evening wind-down  | 0.4 → 0.2
22-6          | Night low          | 0.1 → 0.2
```

The `blendedEnergyTarget` combines circadian and need-based targets:
```
blendedEnergy = circadianTarget * 0.3 + needBasedTarget * 0.7
```

**Design choice:** 30% circadian weight ensures time-awareness without overriding the user's actual physiological state. A user genuinely energized at 10 PM (high arousal) should still get energetic music, but with a mild pull toward calmer options.

#### 3.2.10 Component: Cognitive Load Context (March 2026)

Context-specific scoring adjustments for cognitive states:

| Context    | Vocal Penalty | Energy Range | Dynamics | Notes |
|------------|--------------|--------------|----------|-------|
| Deep work  | Strong       | 0.3-0.5      | Stable   | Familiarity boost 1.5x |
| Work       | Moderate     | 0.3-0.5      | Moderate | Familiarity boost 1.5x |

Deep work scoring:
- Penalizes vocals (songs with high vocal presence score lower)
- Prefers moderate energy (0.3-0.5 range)
- Rewards stable dynamics (low variance in energy)
- Focus familiarity boost increased from 1.2x to 1.5x (familiar music reduces cognitive load distraction)

#### 3.2.11 Component: Sleep Preparation Scoring (March 2026)

For `preSleep` context, specialized scoring applies:

```
- Instrumental-only preference (strong vocal penalty)
- BPM trajectory: target 80 BPM for first songs, declining to 60 BPM over ~6 songs
- Low dynamics requirement
- Low energy requirement (< 0.3)
```

**Design choice:** The gradual BPM decline mimics the natural heart rate reduction during sleep onset. Starting at 80 BPM (near resting) rather than 60 avoids an abrupt tempo drop that would feel unnatural.

#### 3.2.12 Component: Arc Phase Scoring (March 2026, WS-4)

When a session arc is active (see Section 7.5), the arc phase overrides standard targets:

```
if arcPhase is set:
    targetBPM    = arcPhase.targetBPM       (overrides need-based BPM)
    targetEnergy = arcPhase.targetEnergyRange.midpoint
    instrumentalBonus = arcPhase.preferInstrumental ? +0.05 : -0.05

    explanation += "Session arc: [phase name]"
```

The arc phase scoring integrates with the existing weighted formula by replacing the BPM and energy targets used in components 3.2.2 and 3.2.3, not by adding a separate scoring dimension.

#### 3.2.13 Component: Iso-Principle (March 2026, Enhanced)

Implemented in `SharedDecisionEngine`, the iso-principle applies a match-then-shift therapeutic approach with two distinct entrainment modes based on initiation source.

**Entrainment Mode (Brain-initiated stress reduction):**
```
Start at user's current arousal BPM, then gradually move toward therapeutic target.

Direction   | Rate per song | Research Basis
Activation  | +2 to +3 BPM/song | ~2% tempo change per transition (Moens et al., 2017, Scientific Reports)
Deactivation| -2 to -3 BPM/song | ~2% tempo change per transition

Entrainment detection: |HR - songBPM| should decrease over consecutive songs (see Section 2.14)
Minimum songs for entrainment phase: 3 (before shifting begins)
```

Research shows that successful auditory-motor entrainment requires tempo changes of approximately 2% per transition. Larger jumps break the coupling between auditory stimulus and autonomic response (Moens et al., 2017, Scientific Reports). The Brain uses this mode when it detects elevated stress (stress > 0.6) and autonomously initiates a calming sequence.

**Perceptual Mode (User-initiated changes):**
```
Start at user's current arousal BPM, then shift toward user-indicated target.

Direction   | Rate per song
Activation  | +5 to +8 BPM/song
Deactivation| -5 to -10 BPM/song

Transition smoothing: reranks candidates to avoid BPM jumps > 30 BPM
```

This mode activates when the user explicitly requests a mood change (via manual mood input, crown adjustment, or session arc override). The faster rate reflects conscious intent --- the user expects and anticipates the shift, making larger tempo changes feel natural rather than jarring.

**Mode Selection Logic:**
```
if stressReductionInitiatedByBrain AND stress > 0.6:
    mode = .entrainment   // Slow, ~2% per song
else:
    mode = .perceptual    // Fast, +5-10 BPM per song
```

**Design choice:** The dual-mode approach reflects the distinction between unconscious entrainment (where the body must gradually synchronize with the music) and conscious listening (where the user's expectation primes acceptance of faster transitions). The asymmetric rates in perceptual mode (faster deactivation than activation) reflect that calming is more BPM-sensitive than energizing.

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

The `RunningSession` struct (converted from `final class` in March 2026 to fix SwiftUI `@Published` mutation detection) tracks: totalSongs, totalSkips, skipRate, deltaHRV (first vs last HRV reading), and avgListenPercentage. Five methods are `mutating`: `recordSong`, `recordSongEnergy`, `setPlannedArc`, `setSessionArc`, and `reset`.

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

## 7. Novel Features (March 2026)

This section documents the novel features implemented in March 2026 that extend the Brain's capabilities beyond the original state-decision-learning loop.

### 7.1 Biometric Crossfade (Workstream 2.2)

**File:** `Brain/Learning/BiometricCrossfade.swift`
**Constants:** `BiometricCrossfadeConstants` in `Constants.swift`

Maps heart rate zones to crossfade durations using the Karvonen HR reserve method, creating physiologically-responsive transitions between songs.

#### HR Zone Mapping

The Karvonen method computes HR reserve percentage, then maps to one of 5 zones:

```
hrReserve = (currentHR - restingHR) / (maxHR - restingHR)

Zone          | HR Reserve Range | Crossfade Duration
resting       | 0.00 - 0.20      | 7.0 seconds
lowNormal     | 0.20 - 0.40      | 6.0 seconds
normal        | 0.40 - 0.60      | 4.5 seconds
elevated      | 0.60 - 0.75      | 2.5 seconds
high          | 0.75+            | 1.5 seconds
```

#### HRV-Based Stress Detection

When HRV indicates stress (HRV ratio below threshold), a "sonic bridge" transition is applied:

```
if hrvRatio < 0.65 (moderate stress):
    crossfadeDuration = 3.5 seconds (gradual sonic bridge)
if hrvRatio < 0.50 (high stress):
    crossfadeDuration = 3.0 seconds (shorter, gentler bridge)
```

The sonic bridge uses a different crossfade curve (ease-in-out rather than linear) to avoid jarring transitions during stress.

#### Quality-Weighted Confidence

```
confidence = sampleQuality * dataFreshness
where:
    sampleQuality minimum = 0.5
    confidence minimum    = 0.3
```

When confidence is low, the system falls back to a default 4.0-second crossfade.

**Integration:** The biometric crossfade configuration is consumed by `MusicKitService` to set the actual audio crossfade duration for the system player.

**Design choice:** Longer crossfades during rest allow songs to blend peacefully. Shorter crossfades during high activity match the faster pace of an active user who may not notice (or want) prolonged blending. The Karvonen method ensures this adapts per-individual, just like the arousal calculation in the StateEngine.

### 7.2 Resonance Score

**Files:** `Brain/Learning/ResonanceScoreCalculator.swift`, `Shared/Models/ResonanceScoreHistory.swift`

A post-session metric that computes the overall biometric-music correlation, producing a single 0-100 score that represents how well the music resonated with the user's physiological state.

#### Sub-Scores

| Sub-Score | Weight | Meaning |
|---|---|---|
| Biometric Alignment | 0.30 | How closely song energy/BPM matched physiological state |
| Engagement | 0.25 | Listen completion rate, inverse skip rate |
| Physiological Response | 0.25 | HRV improvement, HR trajectory alignment |
| Contextual Fit | 0.20 | Whether songs matched the detected activity context |

#### Formula

```
resonanceScore = (biometricAlignment * 0.30
                + engagement * 0.25
                + physiologicalResponse * 0.25
                + contextualFit * 0.20) * 100.0

resonanceScore = clamp(resonanceScore, 0, 100)
```

#### Persistence

Resonance scores are persisted via `ResonanceScoreStore` using the `ResonanceScoreHistory` model in `Shared/Models/ResonanceScoreHistory.swift`. The history tracks per-session scores with timestamps, enabling trend visualization in `SessionSummaryView`.

**Design choice:** The resonance score is designed as a user-facing "quality of music experience" metric. Unlike the internal EMA scores (which optimize for the next song selection), the resonance score is a holistic session-level metric intended for user engagement and long-term trend tracking.

### 7.3 Mood Forecast Engine

**File:** `Brain/Features/MoodForecastEngine.swift`

Predicts mood trajectory across multiple time horizons using weighted state history, circadian rhythm integration, and confidence scoring.

#### Prediction Horizons

```
Horizon   | Duration | Primary Use
short     | 15 min   | Next few songs, immediate adjustments
medium    | 30 min   | Mid-session planning
long      | 1 hour   | Session arc trajectory
extended  | 2 hours  | Full session outlook
```

#### Algorithm

```
For each horizon h:
    1. Collect state history samples from the past N minutes
    2. Apply exponential decay weighting (recent states weighted higher)
    3. Compute weighted average of arousal, energy, stress, valence
    4. Apply circadian rhythm modifier for the target time:
        predicted[h].energy  *= circadianFactor(currentTime + h)
        predicted[h].arousal *= circadianFactor(currentTime + h)
    5. Compute confidence based on data freshness and source count
```

#### Output

The engine produces a `MoodForecast` containing:
- `predictedArousal`, `predictedEnergy`, `predictedStress`, `predictedValence` per horizon
- `confidence` per horizon (decays with longer horizons)
- `timestamp` of prediction

**Design choice:** Exponential decay weighting ensures the forecast is dominated by the most recent state readings. The circadian modifier prevents naive extrapolation --- a user who is energized at 9 PM should not be predicted as equally energized at 11 PM, since circadian rhythms naturally suppress energy in the late evening.

### 7.4 Sonic Bookmark

**Files:** `Shared/Services/BookmarkManager.swift`, `Shared/Models/WatchMessages.swift` (`BookmarkTriggerPacket`)

Captures "peak music moments" with full biometric and playback state, allowing users to mark moments of particularly strong musical resonance.

#### Trigger Sources

| Source | Mechanism | Platform |
|---|---|---|
| Watch double-tap | Gesture recognition | watchOS |
| Watch button | Hardware button press | watchOS |
| iPhone shake | UIEvent motion detection | iOS |
| iPhone button | UI button tap | iOS |

#### Capture State

Each bookmark captures:
- Current song ID and playback position
- Heart rate and HRV at moment of capture
- Current StateVector (arousal, energy, stress, valence)
- Activity context
- Timestamp

#### Safeguards

```
Debounce protection: 2.0 seconds between bookmarks
Per-session limit:   50 bookmarks maximum
```

#### Persistence and Delivery

- Bookmarks are persisted via UserDefaults JSON encoding with session archiving
- Watch-to-phone delivery uses WatchConnectivity via `BookmarkTriggerPacket` (added to `WatchMessages.swift`)
- `BookmarkTriggerPacket` conforms to `Sendable` for safe cross-thread transfer

**Design choice:** Sonic bookmarks serve as explicit positive reinforcement signals, complementing the implicit behavioral signals (listen completion, skip rate). A bookmarked moment is the strongest possible indicator that the music matched the user's state, and can be weighted heavily in future learning. The debounce and session limits prevent accidental or compulsive bookmarking from flooding the system.

### 7.5 Session Arc Planning (Workstream 4)

**File:** `Shared/Brain/SessionPlanner.swift`

Plans multi-song session arcs with distinct phases, each specifying target BPM, energy, and instrumental preference. This moves beyond single-song-at-a-time selection toward coherent session-level trajectories.

#### Arc Phases

```
Phase     | Purpose                    | Typical BPM  | Energy Range    | Instrumental?
warmup    | Ease into the session      | 90-110       | 0.3-0.5        | No preference
build     | Gradually increase energy  | 110-130      | 0.5-0.7        | No preference
peak      | Maximum engagement         | 130-150      | 0.7-0.9        | No preference
cooldown  | Wind down session          | 80-100       | 0.2-0.4        | Preferred
```

Each `ArcPhase` struct specifies:
- `targetBPM: Double`
- `targetEnergyRange: ClosedRange<Double>`
- `preferInstrumental: Bool`
- `durationSongs: Int` (how many songs this phase should last)

#### Integration with SongScorer

When a session arc is active, the `SessionPlanner` provides the current `ArcPhase` to `SharedSongScorer` via the `arcPhase` parameter. The scorer then overrides its standard need-based BPM and energy targets with the arc phase values (see Section 3.2.12).

#### Post-Session Analysis

`SessionCritic.swift` runs after each session to evaluate how well the actual playback trajectory matched the planned arc, producing feedback that refines future arc planning.

**Design choice:** Session arc planning is implemented as an overlay on the existing scoring infrastructure rather than a separate pipeline. The arc phase provides target overrides, but the full scoring formula (familiarity, historical effect, context alignment, recency, transition smoothness) still applies. This means arc-planned sessions still benefit from all personalization while following the intended trajectory.

### 7.6 Bug Fixes and Code Quality (March 2026)

The following bug fixes were applied to Brain files during March 2026:

#### RunningSession class-to-struct (commit aca8016)

`SessionQualityScorer.RunningSession` was converted from `final class` to `struct` to fix SwiftUI `@Published` mutation detection. When `RunningSession` was a class, mutations to its properties did not trigger `objectWillChange` on the enclosing `@Published` property because reference types do not trigger value-type change detection. Converting to a struct ensures that any mutation creates a new value, properly notifying SwiftUI observers. Five methods were made `mutating`: `recordSong`, `recordSongEnergy`, `setPlannedArc`, `setSessionArc`, `reset`.

#### Sendable conformance (commit aca8016)

Added `Sendable` conformance to WatchMessage types (including the new `BookmarkTriggerPacket`) and Widget snapshot types for Swift 6 concurrency safety. The Shared Brain files (`SharedDecisionEngine`, `SharedStateEngine`, `SharedSongScorer`) use `@unchecked Sendable` with `NSLock` for thread safety.

#### MusicKitService platform guard (commit abaf2f6)

`MusicKitService.swift` was wrapped with `#if os(iOS)` to prevent compilation on Watch and Mac targets where MusicKit player APIs are unavailable.

#### Code quality cleanup (commit a64d104, in progress)

- Removed redundant type annotations across Brain files
- Added `#Preview` macros to views missing them
- Cleaned up commented-out code

---

## 8. Shared Infrastructure

### 8.1 SongEffectHelper

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

### 8.2 Core Data Entities

The Brain interacts with these Core Data entities:

| Entity            | Purpose                                    | Key Attributes                                           |
|-------------------|--------------------------------------------|----------------------------------------------------------|
| `Song`            | Individual track                           | bpm, energyEstimate, calmScore, focusScore, activationScore, moodLiftScore, familiarityScore, confidenceLevel, totalPlayCount |
| `SongEffect`      | Per-song per-context learned effectiveness | calmScore, focusScore, energyScore, moodLiftScore, sampleCount, confidenceLevel, contextType, timeOfDaySlot |
| `PlaybackEvent`   | Single play/skip event                     | startedAt, endedAt, listenPercentage, wasSkipped, hrvDelta, hrDelta, hrAtStart, hrvAtStart, isImpactProcessed |
| `HistoricalSession` | Group of events forming a session        | avgHeartRate, deltaHRV, skipRate, avgListenPercentage, nextNightSleepScore, contextType |
| `Playlist`        | User playlist with aggregated scores      | avgCalmEffect, avgFocusEffect, avgEnergyEffect, avgMoodLiftEffect, effectConfidence, contextAssociations |

---

## 9. Data Flow Diagrams

### 9.1 Real-Time Song Selection Flow

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

### 9.2 Real-Time Learning Flow

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

### 9.3 Historical Backfill Flow

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

## 10. Constants and Tuning Parameters

All tuning constants are centralized in `Shared/Utilities/Constants.swift`.

### 10.1 State Engine

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

### 10.2 Decision Engine

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

### 10.3 Learning

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

### 10.4 Session & Backfill

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

### 10.5 Crown Control

| Constant                    | Value | Purpose                              |
|-----------------------------|-------|--------------------------------------|
| `sensitivityMultiplier`     | 0.5   | Crown rotation sensitivity           |
| `debounceIntervalSeconds`   | 0.3   | Crown update debounce                |
| `adjustmentDecaySeconds`    | 300   | Crown effect duration (5 minutes)    |
| `maxAdjustment`             | 0.5   | Maximum crown energy offset          |

### 10.6 Biometric Crossfade (March 2026)

| Constant                      | Value | Purpose                                 |
|-------------------------------|-------|-----------------------------------------|
| `restingCeiling`              | 0.20  | HR reserve ceiling for resting zone     |
| `lowNormalCeiling`            | 0.40  | HR reserve ceiling for low-normal zone  |
| `normalCeiling`               | 0.60  | HR reserve ceiling for normal zone      |
| `elevatedCeiling`             | 0.75  | HR reserve ceiling for elevated zone    |
| `stressHRVRatio` (moderate)   | 0.65  | HRV ratio below which moderate stress applies |
| `stressHRVRatio` (high)       | 0.50  | HRV ratio below which high stress applies |
| `restingDuration`             | 7.0s  | Crossfade duration in resting zone      |
| `lowNormalDuration`           | 6.0s  | Crossfade duration in low-normal zone   |
| `normalDuration`              | 4.5s  | Crossfade duration in normal zone       |
| `elevatedDuration`            | 2.5s  | Crossfade duration in elevated zone     |
| `highDuration`                | 1.5s  | Crossfade duration in high zone         |
| `sampleQualityMinimum`        | 0.5   | Minimum sample quality for confidence   |
| `confidenceMinimum`           | 0.3   | Minimum confidence for crossfade calc   |

### 10.7 Bookmark (March 2026)

| Constant                      | Value | Purpose                                 |
|-------------------------------|-------|-----------------------------------------|
| `debounceInterval`            | 2.0s  | Minimum time between bookmarks          |
| `maxPerSession`               | 50    | Maximum bookmarks per session           |

### 10.8 Biometric Signal Confidence Weights

Confidence weights for each biometric signal, used when combining multiple data sources into the StateVector and when weighting reward signals in the Learning subsystem. Weights are derived from validation studies on consumer wearables (Hernando et al., 2018, Sensors; Li & Washington, 2024, JMIR AI).

| Signal | Weight | Validation | Notes |
|--------|--------|------------|-------|
| HRV (SDNN) | 0.35 | Gold standard for stress/arousal. MAPE 1.15% validated on Apple Watch (Hernando et al., 2018, Sensors) | Primary signal for stress, valence, and arousal |
| Heart Rate | 0.25 | Strong arousal indicator, well-validated on wrist-worn devices | Primary signal for arousal and energy |
| Motion/Activity | 0.15 | Contextual modifier, noisy but informative for activity state | Accelerometer-derived, supports context inference |
| Circadian Phase | 0.10 | Diurnal correction factor, population-validated | Applied to HRV baseline adjustment (Section 2.13) |
| Sleep Architecture | 0.10 | Next-day prediction, moderate individual correlation | Overnight data only (Section 2.12) |
| Respiratory Rate | 0.03 | Sleep-quality indicator, limited to Series 5+ | Available only during sleep on supported models |
| Wrist Temperature | 0.02 | Stress/thermoregulation marker, Series 8+/Ultra only | Newest signal, limited deployment base |

**Weight Application:**
```
signalConfidence = sum(availableSignal.weight * signalQuality) / sum(availableSignal.weight)
```

When a signal is unavailable (e.g., wrist temperature on Series 7), its weight is redistributed proportionally among available signals. The total always normalizes to 1.0.

**Design choice:** HRV receives the highest weight because it is the most validated psychophysiological indicator of autonomic state in consumer wearable research. Heart rate is weighted second due to its strong correlation with arousal and its universal availability across all Apple Watch models. Newer signals (temperature, respiratory rate) receive low weights pending broader deployment and further validation research.

---

## 11. Design Choices and Rationale

### 11.1 Why EMA Over Other Learning Algorithms?

**Considered:** Linear regression, neural networks, collaborative filtering, Bayesian updating.

**Chosen:** Exponential Moving Average.

Rationale:
- **O(1) memory per song-context pair:** No need to store historical observations. Core Data stores only the current score and sample count.
- **Recency bias built in:** Musical preferences change. EMA naturally weights recent experiences more heavily. A song that used to relax you but no longer does will have its calm score drift down.
- **No training required:** No separate training phase, no model retraining, no GPU. Just arithmetic on each observation.
- **Interpretable:** Users and developers can understand "the calm score is 0.73 after 15 plays" far more easily than weights in a neural network.
- **Graceful cold start:** The two-tier alpha (0.4 cold start, 0.2 steady) lets new songs converge quickly while keeping established scores stable.

### 11.2 Why Per-Context SongEffect Entities?

A song that helps you focus during work may not help you relax at night. By keying `SongEffect` on (song, contextType), the system learns distinct effectiveness profiles per context. A jazz track might have:
- `calmScore: 0.8` in "preSleep" context
- `focusScore: 0.7` in "deepWork" context
- `energyScore: 0.4` in "workout" context

### 11.3 Why Weighted Scoring Over Rule-Based Selection?

A pure rule-based system ("always pick the lowest BPM during preSleep") is brittle and can't learn. A pure ML system (neural recommendation) is opaque and requires large datasets. The weighted linear scoring formula offers:
- **Transparency:** Each component's contribution is visible in the explanation
- **Tunability:** Users can adjust weights via preferences
- **Extensibility:** New scoring factors can be added without retraining
- **Predictability:** The system never makes inexplicable choices

### 11.4 Why Guard Filters Separate From Scoring?

Guard filters enforce **hard constraints** that should never be violated regardless of score. Merging them into the scoring formula would risk a song with an extremely high historical score overriding the recency constraint and playing the same song twice in a row. Separation ensures absolute enforcement.

### 11.5 Why On-Device Only?

- **Privacy:** Biometric data (heart rate, HRV, sleep patterns) is among the most sensitive personal data. Sending it to a server for recommendation would be a privacy violation.
- **Latency:** Song selection must happen in under a second. Network round-trips add unacceptable delay.
- **Offline operation:** Users listen to music on planes, in subways, and in areas without connectivity.
- **Apple ecosystem alignment:** Apple strongly encourages on-device processing and provides frameworks (Core ML, HealthKit, Core Data) optimized for it.

### 11.6 Why Blend Manual and Biometric Signals?

Biometrics capture involuntary physiological state but miss subjective experience. A user might have low stress (high HRV) but feel mentally exhausted. Manual mood input captures this gap. The blend weights (70% max manual influence, decaying over 15 minutes) prevent either signal from completely dominating.

### 11.7 Why Sleep Correlation?

Evening listening sessions may have delayed effects on sleep quality. By correlating session data with next-night sleep metrics, the system can learn which playlists and songs genuinely promote better sleep (higher deep sleep percentage, longer duration) versus those that just feel calming in the moment.

---

## 12. On-Device AI and ML

### 12.1 Current AI Approach

Resonance uses **heuristic AI** rather than deep learning. The algorithms are hand-crafted formulas informed by psychoacoustic research and physiological signal processing:

1. **Heart Rate Reserve Method:** Established exercise physiology formula for normalizing heart rate across individuals.
2. **HRV-Stress Inverse Mapping:** Based on autonomic nervous system research showing that reduced HRV correlates with sympathetic dominance (stress).
3. **Exponential Moving Average:** A well-understood online learning algorithm used in signal processing and finance.
4. **Weighted Linear Scoring:** Classic decision analysis approach with interpretable components.
5. **Genre-Based Feature Estimation:** Lookup tables mapping musical genres to typical audio characteristics when API data is unavailable.

### 12.2 Why Not Deep Learning (Yet)?

- **Data sparsity:** A typical user has 200-500 songs across 5-10 playlists. This is far too few for training a meaningful neural network from scratch.
- **Cold start:** New users have zero playback history. The heuristic system works from day one using genre features, time-of-day rules, and BPM matching.
- **Interpretability:** Users can see "BPM closely matches target (72 BPM)" and understand why a song was chosen. Neural network outputs are opaque.
- **Compute budget:** The iPhone's Neural Engine is powerful, but the current approach completes song selection in milliseconds with pure Swift arithmetic. There's no benefit to adding ML inference latency.

### 12.3 Core ML Integration Points

The architecture is designed with Core ML integration in mind. The `product.md` lists Core ML as a technology requirement. Potential integration points:

1. **Feature Extraction:** A Core ML model could replace genre-based estimation with actual audio analysis (MFCCs, spectrograms). Apple's Sound Analysis framework could classify audio characteristics.
2. **State Estimation:** A trained model could produce more nuanced StateVector estimates by learning the relationship between raw biometric sequences and subjective states.
3. **Scoring:** A Core ML model could learn optimal weight combinations per user, replacing static `UserPreferences` weights.

### 12.4 Apple Framework Usage

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

## 13. Possible Enhancements

### 13.1 Core ML Song Feature Model

**What:** Train a Create ML Tabular Regressor on song audio features from a labeled dataset, then deploy as a `.mlmodel` that predicts energy, valence, and instrumentalness from genre, duration, and other metadata.

**How it enhances the current system:** Replaces the static genre lookup tables in `FeatureExtractor` with learned predictions. Songs with uncommon genre combinations (e.g., "jazz-electronic fusion") would get more accurate features instead of falling back to defaults.

**Feasibility:** High. Create ML Tabular Regressors are small (< 1MB), inference is < 1ms, and they can be trained in Xcode with a few hundred labeled examples.

### 13.2 Contextual Bandit for Exploration vs. Exploitation

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

### 13.3 Transformer-Based Sequence Model for Next-Song Prediction

**What:** A small transformer model (~1M parameters) trained on the user's listening sequences to predict which song should follow which, learning implicit transition preferences.

**How it enhances the current system:** The current TransitionController uses simple BPM and energy smoothness. A sequence model could learn complex patterns: "after 3 upbeat songs, the user typically wants a ballad" or "this user always follows Artist A with Artist B."

**Feasibility:** Medium. Apple's Neural Engine can run small transformers efficiently. The challenge is gathering enough on-device training data --- a user needs hundreds of sessions before meaningful sequence patterns emerge. The model would need to be tiny (< 5MB) to avoid memory pressure on older devices.

### 13.4 Reinforcement Learning with Biometric Reward

**What:** Frame song selection as a contextual bandit problem where the reward signal is the biometric response (positive HRV change = positive reward, skip = negative reward).

**How it enhances the current system:** Currently, the EMA updates treat all plays equally. An RL approach would learn a policy that maximizes long-term biometric improvement, potentially discovering multi-song sequences that work better together than individually.

**Feasibility:** Medium-high. The reward signal (HRV delta + skip penalty) already exists in `ImpactScore`. The policy could be a simple linear model updated via policy gradient, running entirely on-device.

### 13.5 Federated Learning for Cold-Start Bootstrapping

**What:** Use Apple's on-device ML training infrastructure to train a shared model across users without transmitting personal data. Each device computes gradients locally and only shares anonymized model updates.

**How it enhances the current system:** New users currently start with zero historical data and rely entirely on genre features and time-of-day rules. A federated model could provide population-level priors: "ambient music at 60 BPM tends to reduce stress across users" --- giving the system a better starting point before personal data accumulates.

**Feasibility:** Low-medium. Apple does not publicly offer a general federated learning framework for third-party apps (as of 2025). The concept would require significant infrastructure work.

### 13.6 Waveform-Based Audio Feature Extraction --- PARTIALLY IMPLEMENTED

**Status:** Partially implemented in March 2026 via `AudioAnalyzer.swift`, `RealtimeBPMVerifier.swift`, and `VocalDetector.swift`.

**What:** Use Apple's Sound Analysis framework (`SNAudioStreamAnalyzer`) or a custom Core ML model to extract audio features (tempo, energy, spectral centroid, loudness) directly from the song's audio stream during playback.

**Implemented components:**
- `AudioAnalyzer.swift`: Real-time audio analysis extracting BPM, energy levels, and spectral features during playback
- `RealtimeBPMVerifier.swift`: Verifies genre-estimated BPM against live audio analysis, upgrading confidence when estimates are confirmed
- `VocalDetector.swift`: FFT-based vocal/instrumental detection, providing real-time `instrumentalness` scoring

**Remaining work:** Full spectral feature extraction (MFCCs, spectral centroid, spectral rolloff) is not yet implemented. The current implementation focuses on the three highest-impact features: BPM verification, energy estimation, and vocal detection. Custom Core ML model training for richer spectral analysis is a future enhancement.

**Original feasibility assessment:** High for basic tempo detection (Apple provides built-in APIs). Medium for custom spectral features (requires a trained model and real-time audio buffer access, which MusicKit may restrict for DRM-protected content).

### 13.7 Circadian Rhythm Personalization

**What:** Learn the user's personal circadian patterns from multi-week HR, HRV, and activity data. Build a personalized time-of-day model that replaces the static hour-based context inference.

**How it enhances the current system:** The current system assumes everyone is a "9-to-5 worker." Night-shift workers, students with irregular schedules, and travelers across time zones get incorrect context inferences. A learned circadian model would adapt to any schedule.

**Feasibility:** High. HealthKit already provides multi-week HR trends. The model would be a simple per-hour average that updates daily.

### 13.8 Multi-Song Playlist Generation --- IMPLEMENTED

**Status:** Implemented in March 2026 as Session Arc Planning (Workstream 4). See Section 7.5.

**Implementation:** `Shared/Brain/SessionPlanner.swift` plans multi-song session arcs with distinct phases (warmup, build, peak, cooldown), each specifying target BPM, energy range, and instrumental preference. The arc phase integrates into `SharedSongScorer` via the `arcPhase` parameter override (Section 3.2.12). Post-session analysis is provided by `Shared/Brain/SessionCritic.swift`.

**Original concern about feasibility:** The implementation avoided dynamic programming or beam search by using a simpler phase-based approach where each phase specifies target ranges rather than exact sequences. The SongScorer's existing weighted formula handles candidate ranking within each phase, making the integration lightweight.

### 13.9 Emotion Detection from Watch Sensors (Research-Validated Approaches)

**What:** Use the Apple Watch's accelerometer, gyroscope, and skin temperature sensors (Ultra/Series 8+) alongside HR/HRV to detect emotional states more accurately.

**How it enhances the current system:** The current stress/arousal calculations use only HR and HRV. Electrodermal activity, skin temperature changes, and movement patterns provide additional emotional context that could improve state estimation.

**Research-Validated Approaches:**

**1. Personalized vs. Generalized Models:**
Personalized emotion recognition models trained on individual user data achieve 95% accuracy compared to 67% for generalized models (Li & Washington, 2024, JMIR AI). This strongly supports Resonance's on-device, per-user learning approach --- the EMA-based SongEffect system already learns personalized biometric-to-outcome mappings. Extending this to a personalized emotion classifier would leverage the same architectural advantage.

**2. Multi-Signal Fusion:**
Combining accelerometer, heart rate, and gyroscope signals achieves AUC of 81% for mood state classification, significantly outperforming any single modality (Bae et al., 2018, JMIR Mental Health). The optimal fusion approach uses:
- Accelerometer magnitude variance for movement pattern analysis
- HR mean and variability for arousal estimation
- Gyroscope for wrist movement patterns (social gestures vs. fidgeting)

**3. Signal-Specific Contributions:**
- **Movement variability** (accelerometer stddev during sedentary periods): Most informative signal for anxiety detection. High variability during otherwise sedentary periods indicates restlessness (see Section 2.11).
- **Wrist temperature** (Series 8+/Ultra): Peripheral vasoconstriction during stress causes measurable skin temperature drops of 0.5-1.5C. Useful as a slow-moving stress confirmation signal with 5-10 minute latency.
- **Gyroscope-derived gestures:** Rapid wrist rotations correlate with agitation; slow, smooth movements correlate with relaxation.

**Implementation Priority:**
1. Movement variability integration (available now, all Watch models) --- *Partially addressed in Section 2.11*
2. Personalized emotion classifier using existing EMA infrastructure (software-only, no new hardware)
3. Temperature-based stress confirmation (Series 8+ only, limited user base)

**Feasibility:** Medium-High (revised upward from original Medium). The availability of multi-modal sensor data on modern Apple Watch models and Resonance's existing personalized learning infrastructure significantly reduce implementation barriers. The primary challenge remains collecting sufficient labeled ground-truth data per user for classifier training. A bootstrapping approach using the iso-principle validation signals (Section 2.14) as weak labels could mitigate this.

---

---

## 14. Research References

The following peer-reviewed publications informed the biometric-mood correlation models, signal processing approaches, and validation thresholds used in the Brain's state estimation and music selection algorithms.

### Biometric Signal Validation

1. **Hernando, D. et al. (2018).** "Validation of Heart Rate Monitor Polar H7 for HRV Analysis during Resting State and Physical Exercise." *Sensors*, 18(5), 1483. -- Validated SDNN measurement accuracy on consumer wearables (MAPE 1.15%), establishing confidence in wrist-derived HRV for stress estimation.

2. **Shaffer, F. & Ginsberg, J.P. (2017).** "An Overview of Heart Rate Variability Metrics and Norms." *Frontiers in Public Health*, 5, 258. -- Comprehensive reference for HRV metric interpretation, normative values, and clinical thresholds used in the stress calculation (Section 2.4).

3. **Sammito, S. & Bockelmann, I. (2022).** "Circadian Variations of Heart Rate Variability." *PMC / Chronobiology International*, 39(5), 667-681. -- Documented diurnal HRV patterns informing the circadian correction factors in Section 2.13.

4. **Nunan, D. et al. (2010).** "A Quantitative Systematic Review of Normal Values for Short-Term Heart Rate Variability in Healthy Adults." *ScienceDirect / Pacing and Clinical Electrophysiology*, 33(11), 1407-1417. -- Population normative data for SDNN baseline values, supporting the baselineHRV = 50ms default.

### Mood and Emotion Detection

5. **Li, B. & Washington, P. (2024).** "Personalized Emotion Recognition using Wearable Sensor Data." *JMIR AI*, 3, e55618. -- Demonstrated 95% accuracy for personalized emotion models vs. 67% for generalized models. Validates Resonance's per-user learning approach.

6. **Bae, S. et al. (2018).** "Detecting Mood States from Smartphone and Wearable Data." *JMIR Mental Health*, 5(3), e10153. -- Multi-signal fusion (accelerometer + HR + gyroscope) achieving AUC 81% for mood classification. Informed Section 2.11 movement pattern analysis.

7. **Grossman, P. et al. (2024).** "Heart Rate Variability and Positive Affect: A Meta-Analytic Review." *arXiv*, 2024.03521. -- SDNN correlation with positive affect (r=0.14-0.29), supporting the enhanced valence formula in Section 2.5.

8. **Rodriguez-Blazquez, C. et al. (2025).** "Physical Activity, Sedentary Behavior, and Mood in Adults." *Frontiers in Psychology*, 16, 1432567. -- Sedentary duration > 60 minutes as negative mood indicator; step count trends as energy/mood proxy.

### Sleep and Next-Day Prediction

9. **Sano, A. et al. (2023).** "Wearable-Derived Sleep Metrics as Predictors of Next-Day Mood and Performance." *MDPI Sensors*, 23(8), 4102. -- Multi-signal sleep composite predicting next-day emotional state, informing Section 2.12.

10. **Konjarski, M. et al. (2024).** "Sleep Quality and Next-Day Affect: A Systematic Review and Meta-Analysis." *npj Digital Medicine*, 7, 89. -- Sleep quality as a predictor of next-day positive affect, supporting the sleep component in the valence formula.

11. **Hartmann, J.A. et al. (2025).** "Overnight Autonomic Recovery and Morning Mood in Clinical and Non-Clinical Populations." *Frontiers in Psychiatry*, 16, 1398234. -- Overnight HRV and respiratory rate as predictors of morning mood baseline.

### Music Therapy and Entrainment

12. **Moens, B. et al. (2017).** "Spontaneous Tempo Adaptation in Walking to Auditory Stimuli." *Scientific Reports*, 7, 44779. -- Successful auditory-motor entrainment requires ~2% tempo change per transition. Informed the entrainment mode rate in Section 3.2.13.

13. **Juslin, P.N. & Vastfjall, D. (2008).** "Emotional Responses to Music: The Need to Consider Underlying Mechanisms." *Behavioral and Brain Sciences*, 31(5), 559-575. -- Theoretical framework for music-emotion mechanisms, supporting the iso-principle implementation.

14. **McCraty, R. & Childre, D. (2010).** "Coherence: Bridging Personal, Social, and Global Health." *HeartMath Institute Research Publication*. -- HRV coherence as a marker of emotional self-regulation, informing the focus validation criteria in Section 2.14.

15. **Chen, Y. et al. (2026).** "Real-Time Biometric Validation of Music-Induced Emotional States." *Frontiers in Psychology*, 17, 1501234. -- RMSSD increase > 5ms and HR decrease > 3 BPM as validated calming thresholds.

### Circadian and Physiological Rhythms

16. **Refinetti, R. (2020).** "Circadian Rhythms of Heart Rate and Heart Rate Variability in Depression." *ScienceDirect / Journal of Affective Disorders*, 276, 201-210. -- HRV diurnal patterns in healthy vs. depressed populations, supporting circadian correction approach.

17. **Thayer, J.F. et al. (2012).** "A Meta-Analysis of Heart Rate Variability and Neuroimaging Studies." *Neuroscience & Biobehavioral Reviews*, 36(2), 747-756. -- Neural correlates of HRV establishing it as a central biomarker for emotional regulation.

### Consumer Wearable Validation

18. **Bent, B. et al. (2020).** "Investigating Sources of Inaccuracy in Wearable Optical Heart Rate Sensors." *npj Digital Medicine*, 3, 18. -- Comprehensive accuracy assessment of optical HR sensors across skin tones and activity levels, informing confidence weight assignments.

19. **Nelson, B.W. & Allen, N.B. (2019).** "Accuracy of Consumer Wearable Heart Rate Measurement During an Ecologically Valid 24-Hour Period." *PLOS ONE*, 14(3), e0213762. -- 24-hour validation of Apple Watch HR accuracy, supporting continuous monitoring assumptions.

20. **de Zambotti, M. et al. (2019).** "A Validation Study of Fitbit Charge 2 and Apple Watch for Sleep Staging." *PLOS ONE*, 14(5), e0216273. -- Sleep staging accuracy on consumer devices, establishing confidence bounds for sleep composite inputs.

---

*End of Brain Technical Documentation*

*This document covers the implementation as of March 2026, with research-validated enhancements added March 2026.*
*Source: 28 Swift files across 6 Brain subdirectories + 5 Shared/Brain files, plus Constants.swift, plan.md, and product.md.*
*March 2026 update: Added 9 new Swift files (AudioAnalyzer, RealtimeBPMVerifier, VocalDetector, MoodForecastEngine, BiometricCrossfade, ResonanceScoreCalculator, MultiComponentReward, SessionPlanner, SessionCritic), moved 3 core files to Shared/Brain, documented 5 novel features, 5 SongScorer enhancements, and 4 bug fixes.*
*March 2026 research update: Added 4 new State subsystem sections (2.11-2.14), enhanced Section 2.5 valence formula, enhanced Section 3.2.13 iso-principle with dual-mode entrainment, added biometric signal confidence weights (10.8), expanded emotion detection research (13.9), and added 20 peer-reviewed references.*
