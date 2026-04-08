# Resonance: Next Wave Feature Roadmap

> **Generated:** 2026-04-08
> **Research basis:** 7 parallel Opus research agents covering competitive landscape, Reddit sentiment, blog/trend analysis, social media sentiment, adjacent-industry innovation, UX/product design, and growth/monetization strategy. Cross-referenced against full codebase analysis (167 Swift files, 45K LOC, 34 AgentDB entries).

---

## Executive Summary

**Resonance occupies a genuinely unoccupied market niche.** No existing product combines real-time biometric data from a wearable with music selection from the user's own library. Every competitor either generates its own audio (Endel, Brain.fm, Mubert) or curates from a streaming catalog based on manual preferences (Spotify AI DJ, Apple Music). This is Resonance's moat.

The research identified **3 tiers** of opportunities:
1. **Refinements** — Existing features that need UX polish to unlock their full value
2. **Extensions** — Natural additions that build on the existing Brain/State/Learning architecture
3. **Moonshots** — Novel features that would make Resonance truly unprecedented

Each feature below is scored on:
- **Relevance** (1-5): How naturally it fits the current product architecture
- **Feasibility** (1-5): Can it be built with existing frameworks (SwiftUI, MusicKit, HealthKit, CoreML, AVAudioEngine)?
- **Impact** (1-5): User delight and market differentiation potential
- **Priority**: Ship-now / Next-cycle / Future

---

## PART 1: REFINEMENTS — Existing Features That Need to Shine

These features are already built but aren't reaching their potential. Fixing these first creates the strongest foundation for everything else.

---

### R1. AI Explanation Bar Redesign
**Problem:** The explanation bar in NowPlayingView is described as "nearly invisible" in the UX audit. It exists at line 376-414 of NowPlayingView.swift as a collapsible `.caption`-sized text with `.secondary` foreground — easy to miss entirely.

**Current state:** Functional `explanationBar` with expand/collapse, shows `viewModel.currentExplanation` string.

**Required change:** Redesign as a tappable glass-material card positioned between transport controls and the HRV zone bar. Default state: one-line warm language ("Picked for your settling heart rate + evening calm"). Expanded state: show top 3-4 scoring factors with small horizontal weight bars (BPM Match: 40%, Energy: 35%, History: 25%). Use `ResonanceColors.accent` for the wand icon and warm, first-person language throughout.

**What to modify:**
- `NowPlayingView.swift` — Redesign `explanationBar` computed property
- `ExplanationGenerator.swift` — Return structured factor weights, not just a string
- `SongExplanation` model — Add `factors: [(name: String, weight: Double)]` field

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 5 | 5 | Ship-now |

---

### R2. Queue / Up-Next View
**Problem:** No queue or up-next view exists anywhere in the app. Users cannot see what the AI plans to play next. This is a top UX audit finding (NP-02) and the #2 most-requested feature in music app UX research.

**Current state:** `DecisionEngine.swift` selects one song at a time. No pre-computed queue.

**Required change:** Add a `QueueView` accessible via upward drag from NowPlayingView bottom or a queue icon in the toolbar. Show next 5-8 AI-planned tracks with:
- Album art thumbnail
- Song title / artist
- One-line AI reasoning per track (e.g., "Matches your descending heart rate")
- Drag-to-reorder handles
- Swipe-to-remove

**What to modify:**
- New `QueueView.swift` in iOS/Views/Components/
- `DecisionEngine.swift` — Add `precomputeQueue(count: Int)` method that scores top N candidates
- `NowPlayingView.swift` — Add queue sheet presentation
- `NowPlayingViewModel.swift` — Expose pre-computed queue

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Ship-now |

---

### R3. Shuffle/Repeat as AI-Aware Controls
**Problem:** No shuffle or repeat controls (UX audit NP-01). But traditional shuffle/repeat don't make sense for an AI DJ — they're legacy music player concepts.

**Current state:** No controls exist.

**Required change:** Replace traditional shuffle/repeat with two AI-native toggles:
- **"Surprise Me" mode** (wider song selection variance, more exploration, less biometric adherence) — maps to increasing `EffectivenessLearner` exploration parameter
- **"Stay in the Zone" mode** (tighter biometric alignment, favor proven tracks) — maps to exploitation-heavy scoring
These are more coherent with the AI DJ concept than legacy buttons.

**What to modify:**
- `NowPlayingView.swift` — Add toggle controls near transport
- `UserPreferences.swift` — Add `explorationBias: Double` (0 = zone, 1 = surprise)
- `EffectivenessLearner.swift` — Accept external exploration bias override
- `SongScorer.swift` — Factor bias into scoring weights

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 5 | 4 | Ship-now |

---

### R4. HeartPulseRing Enhancement — Three Distinct States
**Problem:** HeartPulseRing (HeartPulseRing.swift) currently has one visual state: pulsing. The entrainment detection (lines 20-28) works but only manifests as opacity changes. Users don't understand what it means.

**Current state:** Single pulse animation with entrainment-based opacity boost. `musicBPM` bug was fixed (Core Data fallback added).

**Required change:** Three visually distinct states:
1. **Calm Pulse** — Gentle glow breathing with heart rate (current behavior, low entrainment)
2. **Sync Pulse** — Ring brightens, tightens, and color-shifts toward gold when entrainment > 0.7 (music BPM ~= heart rate). Add subtle haptic feedback.
3. **Transition Pulse** — Ring ripples outward with a wave effect when the AI is about to change tracks. Prepares the listener subconsciously.

**What to modify:**
- `HeartPulseRing.swift` — Add state enum, transition ring effect, sync glow
- `NowPlayingView.swift` — Pass `isTransitioning` flag from ViewModel
- `NowPlayingViewModel.swift` — Expose transition state from DecisionEngine

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 4 | Ship-now |

---

### R5. Settings Restructuring
**Problem:** SettingsView needs NavigationLink sub-pages (design audit finding). Currently a flat list.

**Current state:** Single-page settings view.

**Required change:** Restructure into 5 goal-oriented sections:
1. **"My Body"** — HealthKit permissions, biometric signal toggles, sensitivity controls
2. **"My Music"** — Apple Music connection, library analysis refresh, excluded playlists
3. **"My AI"** — AI personality sliders (Adventurous ↔ Familiar, Body ↔ Mind, DJ ↔ Jukebox), explanation verbosity
4. **"My Sessions"** — Default duration, ritual reminders, streak settings
5. **"My Data"** — Export, privacy controls, what's stored on-device

**What to modify:**
- `SettingsView.swift` — Split into NavigationLink sub-pages
- New files: `BodySettingsView.swift`, `MusicSettingsView.swift`, `AISettingsView.swift`, `SessionSettingsView.swift`, `DataSettingsView.swift`

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 5 | 3 | Ship-now |

---

### R6. MoodForecastView as Session Centerpiece
**Problem:** MoodForecastView (MoodForecastView.swift) is a strong differentiator — draggable Catmull-Rom spline energy curves with control points — but it's buried behind SessionIntentPicker as a secondary sheet.

**Current state:** Full implementation with draggable points, gradient fill, BPM labels, reset button. Shown only if `forecastViewModel` and `availableSongs` exist.

**Required change:** Make it the centerpiece of pre-session setup:
- Show a default AI-suggested arc (based on time-of-day + current biometrics) immediately in SessionIntentPicker
- Replace Y-axis numerical labels with emotional labels ("Grounded", "Lifted", "Flowing", "Energized")
- Add small track-type icons along the arc ("acoustic here... electronic buildup here...")
- Post-session: overlay actual mood trajectory onto the forecast to show alignment

**What to modify:**
- `SessionIntentPicker.swift` — Embed MoodForecastView preview directly
- `MoodForecastView.swift` — Add emotional labels, post-session overlay mode
- `SessionSummaryView.swift` — Include forecast vs. actual comparison

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Ship-now |

---

### R7. Post-Session Summary Enhancement
**Problem:** SessionSummaryView is functional but generic. It shows stats, HRV trend, best-fit song, and bookmarks — but doesn't leverage Resonance's unique data advantage.

**Current state:** Duration, songs played, skip rate, HRV delta, best match song, bookmarks, quality bar, feedback buttons.

**Required change:** Add:
- Forecast vs. actual mood trajectory overlay
- "Highlight moment" — the track where biometrics showed peak engagement, with bookmark option
- Trend line: "This is your 12th evening session. Wind-down time improved 15%."
- Shareable Instagram-story-sized card with session mood arc gradient
- Breakdown of biometric-music correlation per track

**What to modify:**
- `SessionSummaryView.swift` — Add trajectory overlay, highlight moment, trend
- New `SessionShareCardView.swift` — Shareable gradient card
- `ResonanceScoreCalculator.swift` — Expose per-track alignment data more richly

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 4 | Next-cycle |

---

### R8. Onboarding "Golden Path" — 3 Minutes to Wow
**Problem:** No optimized first-use flow. Users must navigate permissions, library analysis, and feature discovery on their own.

**Current state:** OnboardingContainerView (4-page PageTabView), then LandingView with brain orb, then LibraryAnalysisView.

**Required change:** Redesign Golden Path:
1. See brain orb animation (intrigue) — 10s
2. Grant Apple Music → see library being analyzed with emotion tags appearing in real-time ("Found 47 songs for deep focus... 23 for energy boosts...") — 60s
3. Put on headphones + grant HealthKit (with pre-permission screen: "Let me tune into your body") — 30s
4. Press play → within 30 seconds see HeartPulseRing syncing to actual heartbeat while a contextually-matched song plays — 30s
Target: under 3 minutes from install to "my music is responding to my body."

**What to modify:**
- `OnboardingContainerView.swift` — Redesign flow with contextual permission timing
- `LibraryAnalysisView.swift` — Show real-time emotion categorization during scan
- Pre-load a "starter" playlist during analysis so user can experience biometric playback before full scan

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Ship-now |

---

## PART 2: EXTENSIONS — Natural Additions to Existing Architecture

These features build directly on Resonance's current Brain/State/Learning engine and require moderate new development.

---

### E1. ADHD / Neurodivergent Focus Mode
**Market signal:** Brain.fm's most passionate user segment. Reddit r/ADHD has extensive discussion of music for focus. PLOS One (2025) analyzed 9,215 distinct tracks from r/ADHD for focus music. A Nature study found participants with higher ADHD scores showed GREATER benefits from modulated music. No app plays the user's OWN familiar music with biometric focus detection.

**Why it fits Resonance:** HRV patterns indicate focus vs. distraction. The existing `MusicNeed.focus` and `SessionIntent.deepWork` already target this. The EffectivenessLearner can learn which specific user songs correlate with productive HRV patterns over time.

**Implementation:**
- New `SessionIntent.adhdFocus` case with specialized scoring weights (high familiarity, moderate tempo, high instrumentalness)
- HRV-based distraction detection: when HRV pattern shifts from focused to distracted, the Brain automatically selects a high-familiarity, proven-effective track
- "Focus streak" visualization showing sustained productive HRV periods
- Pomodoro timer integration with session arcs

**What to modify:**
- `SessionIntent` enum — Add `.adhdFocus` case
- `StateEngine.swift` — Add focus/distraction detection from HRV patterns
- `SongScorer.swift` — Heavily weight familiarity + historical effectiveness in focus context
- New `FocusStreakView.swift` component

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Ship-now |

---

### E2. Workout-to-Recovery Auto-Transition
**Market signal:** The single most requested fitness music feature across Reddit. No app handles the workout-to-cooldown transition automatically. Sports science research shows recovery music at 60-80 BPM matching resting HR promotes faster recovery. RockMyRun comes closest but uses its own library.

**Why it fits Resonance:** `WorkoutBPMAdvisor.swift` exists but isn't wired to DecisionEngine. Heart rate zones are computed via Karvonen method in `BiometricCrossfadeEngine.swift`. The architecture is ready — just needs wiring.

**Implementation:**
- Wire `WorkoutBPMAdvisor` to `DecisionEngine` for HR-zone-aware track selection
- Detect workout end via declining HR + reduced motion → auto-transition to recovery arc
- Recovery arc targets: BPM decreasing by ~5 BPM/track toward resting HR, high-valence/low-energy selections
- Track HRV recovery rate and report in session summary: "You recovered to baseline HRV in 12 minutes"

**What to modify:**
- `DecisionEngine.swift` — Wire WorkoutBPMAdvisor, add HR zone input to scoring
- `SessionPlanner.swift` — Add recovery arc template
- `StateEngine.swift` — Detect workout→recovery transition
- `SessionSummaryView.swift` — Show recovery metrics

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 5 | 5 | Ship-now |

---

### E3. Natural Language DJ via Apple Foundation Models
**Market signal:** Spotify DJ takes voice requests. Apple announced Foundation Models framework (WWDC 2025) for on-device LLM inference — free, private, zero-latency. No app combines natural language with biometric grounding.

**Why it fits Resonance:** `ConversationalExplanation.swift` exists but isn't wired (noted as pending in AgentDB). Foundation Models framework enables on-device, privacy-preserving natural language understanding. The LLM interprets "play something for how I feel right now" and cross-references current biometric state.

**Implementation:**
- Integrate `FoundationModels` framework
- Add text input field in NowPlayingView toolbar: "Tell me what you want..."
- LLM translates natural language + current biometric state into track selection parameters
- Also power richer AI explanations: "Your heart rate has been climbing, so I'm matching the energy"
- Replace static `ExplanationGenerator` output with LLM-generated contextual commentary

**What to modify:**
- New `NaturalLanguageDJService.swift` — Foundation Models integration
- `ConversationalExplanation.swift` — Wire to Foundation Models
- `DecisionEngine.swift` — Accept natural language parameters as scoring overrides
- `NowPlayingView.swift` — Add text input UI

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Next-cycle |

---

### E4. Anxiety Interception Engine
**Market signal:** IoT-MT (2025, PMC) demonstrated automated music therapy triggered by biometric anxiety detection. No consumer app does proactive anxiety intervention through music. Mental health apps (Calm, Headspace) require manual activation.

**Why it fits Resonance:** All required biometric signals already stream via HealthKit/Watch: elevated resting HR, decreased HRV (SDNN), increased wrist temperature. `StateCalculationHelpers.swift` already computes stress from HRV. `RealTimeGuardAdjuster.swift` already modifies track selection based on biometric changes.

**Implementation:**
- Anxiety detection model: composite score from HR deviation + HRV drop + wrist temp increase
- When anxiety score exceeds threshold, gradually shift selection toward anxiolytic profile over 2-3 tracks (avoid jarring transition): 60-80 BPM, major keys, low dissonance, high familiarity
- Post-episode report showing the biometric timeline and how music helped regulate
- Opt-out and sensitivity controls in Settings

**What to modify:**
- `StateEngine.swift` — Add anxiety detection composite score
- `RealTimeGuardAdjuster.swift` — Add anxiolytic override pathway
- `GuardFilters.swift` — Add anxiolytic profile filter
- New `AnxietyInterventionReport.swift` — Post-episode visualization

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Next-cycle |

---

### E5. Sleep Wind-Down Mode
**Market signal:** Apple Watch sleep tracking is mature (stages, HRV, respiratory rate) but completely disconnected from music. No app bridges sleep biometrics to music selection. Research shows music at 60-80 BPM promotes sleep onset.

**Why it fits Resonance:** `SleepMoodBaseline.swift` already processes overnight HRV. `OvernightTemperatureSensor.swift` on Watch already reads wrist temp. Circadian rhythm engine (`CircadianProfileManager.swift`) knows the user's natural energy curve. Sleep is a natural session arc.

**Implementation:**
- New `SessionIntent.sleepWindDown` case
- Detect pre-sleep state: declining wrist temp + rising HRV + reduced motion + late hour
- Session arc: start at current energy, gradually decrease over user's average sleep onset latency
- Auto-fade volume to zero over final 10 minutes
- Next-morning feedback: "Your sleep quality was 15% better after last night's wind-down session"

**What to modify:**
- `SessionIntent` enum — Add `.sleepWindDown`
- `SessionPlanner.swift` — Add sleep arc template
- New `SleepWindDownManager.swift` — Auto-detection + volume fade
- `SessionSummaryView.swift` — Sleep correlation reporting

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 4 | Next-cycle |

---

### E6. Emotional Regulation Ladder (ISO Principle)
**Market signal:** Music therapy's ISO principle — matching current mood before gradually shifting — is clinically validated. Resonance already implements this via `MoodTrajectory` and `SessionPlanner.planTrajectoryArc()`. But it's hidden behind manual slider input.

**Why it fits Resonance:** The entire Mood Journey feature in `MoodTabView.swift` already does this. The gap is automation: the system should auto-detect negative emotional state and offer a ladder without requiring manual mood slider input.

**Implementation:**
- When biometrics indicate negative state (low valence from HRV/motion patterns), auto-suggest a mood ladder
- Gentle notification: "Rough moment? I can guide you through a 15-minute mood lift. Just press play."
- Start with tracks matching current negative state (validation), shift valence by +0.1/track
- Verify each step with HRV improvement before advancing
- Post-session show mood trajectory: "You went from stressed to calm in 12 minutes"

**What to modify:**
- `StateEngine.swift` — Add negative state detection
- `SessionPlanner.swift` — Add auto-ISO-principle mode triggered by detected negative state
- `MoodTabView.swift` — Show auto-suggested ladder when negative state detected
- Notification logic for gentle prompt

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Next-cycle |

---

### E7. Biometric Music Health Dashboard ("Resonance Insights")
**Market signal:** Spotify Wrapped proved personal data insights are massively engaging and shareable. No competitor can correlate music features with biometric data. Quantified-self community has shown strong interest in music-mood correlations.

**Why it fits Resonance:** All data already exists in Core Data. ResonanceScoreHistory, EventLogger, and LearningStore track per-session and per-song biometric-music correlations. Just needs visualization.

**Implementation:**
- New "Insights" tab or section showing:
  - "Songs in D major reduce your heart rate 12% more than other keys"
  - "Your HRV is 23% higher on days with 45+ min sessions"
  - "Your most resonant track: [song] — played in 8 sessions, always raised mood"
  - Weekly/monthly mood trajectory charts
  - "Your body's favorite genre at 10 PM is ambient electronic"
- Annual "Resonance Wrapped" shareable cards

**What to modify:**
- New `InsightsView.swift` with Swift Charts
- New `InsightsEngine.swift` — Statistical correlations between music features and biometric outcomes
- New `WrappedCardView.swift` — Shareable annual summary
- Add to main TabView as 5th tab or within Settings

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Next-cycle |

---

### E8. AI DJ Commentary via Foundation Models
**Market signal:** Spotify DJ's voice commentary is divisive (some love it, some hate it), but the CONCEPT of a DJ who explains choices is universally desired. No competitor explains choices through biometric reasoning.

**Why it fits Resonance:** `ConversationalExplanation.swift` exists. Foundation Models enables on-device text generation. Session context data (biometric state, song features, historical patterns) provides rich commentary material.

**Implementation:**
- At each track transition, assemble context: previous track features, current biometric state, trend direction, session duration, notable events
- Generate 1-2 sentence commentary via Foundation Models: "Your stress is dropping, so I'm keeping this vibe going" or "This song brought your heart rate down 8 BPM last Tuesday"
- Display as a toast notification. Optionally synthesize speech via `AVSpeechSynthesizer`
- User controls commentary frequency (every track / every 3rd / off)

**What to modify:**
- `ConversationalExplanation.swift` — Wire to Foundation Models
- `NowPlayingViewModel.swift` — Trigger commentary at transitions
- New `DJCommentaryService.swift` — Context assembly + LLM generation
- `SettingsView.swift` — Commentary frequency control

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Next-cycle |

---

### E9. Weather-Reactive Influence
**Market signal:** Endel's strongest differentiator is environmental adaptation (weather, location, time). Users praise this as "magical." WeatherKit is native to iOS.

**Why it fits Resonance:** `ContextCollector.swift` already aggregates signals from multiple sources. Weather is a natural additional context signal. `ContextSignal.swift` model could be extended.

**Implementation:**
- Subscribe to WeatherKit for current conditions
- Map weather to audio feature adjustments: rain → lower valence/energy, sun → higher valence, storm → dramatic/cinematic
- Blend at 20-30% influence weight alongside biometrics (70-80%)
- Optionally layer ambient textures (rain, birdsong) at very low volume beneath music

**What to modify:**
- `ContextCollector.swift` — Add WeatherKit subscription
- `ContextSignal.swift` — Add weather fields
- `SongScorer.swift` — Factor weather context into scoring
- Info.plist — Add WeatherKit entitlement

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 4 | 4 | 3 | Next-cycle |

---

### E10. CarPlay Commute DJ
**Market signal:** LifeScore proved automotive is compelling. Users want different music for morning commute (energizing) vs. evening commute (decompressing). No app does this biometrically via CarPlay. A drowsiness detection variant could be life-saving.

**Why it fits Resonance:** `SessionIntent.morningRampUp` already exists. CarPlay via `CPNowPlayingTemplate` is well-supported. Apple Watch biometric streaming continues during driving.

**Implementation:**
- Detect CarPlay connection → auto-activate commute mode
- Morning commute: escalating energy arc based on HR/HRV wake state
- Evening commute: decompression arc from work stress (detected via elevated HR/low HRV) to calm
- Drowsiness detection: declining HRV + declining HR + reduced wrist motion → shift to alerting music
- Display simplified CarPlay-optimized UI

**What to modify:**
- New `CarPlayManager.swift` — CarPlay lifecycle + simplified UI
- `SessionPlanner.swift` — Add commute-specific arcs (morning vs. evening auto-detected)
- `StateEngine.swift` — Add drowsiness detection pathway

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 4 | 3 | 4 | Future |

---

### E11. Couples "Heart Sync" Mode
**Market signal:** Research shows synchronized rhythm promotes shared purpose (PubMed). No app offers multi-user biometric music optimization. Deeply shareable and viral-worthy.

**Why it fits Resonance:** Apple Watch data sharing via MultipeerConnectivity or CloudKit is feasible. The scoring engine already takes a StateVector — it can take a blended one.

**Implementation:**
- Two Apple Watch users connect via MultipeerConnectivity
- AI finds the musical "sweet spot" between both biometric states
- Display "Heart Sync Score" showing physiological alignment over time
- Goal: converge both users' states through shared music

**What to modify:**
- New `HeartSyncManager.swift` — P2P connection, biometric exchange, consent
- `DecisionEngine.swift` — Accept blended StateVector from two users
- New `HeartSyncView.swift` — Dual-waveform convergence visualization

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 3 | 3 | 4 | Future |

---

## PART 3: MOONSHOTS — "Never Seen Anything Like This"

These are the features that would generate headlines and word-of-mouth. They build on Resonance's unique position but require significant new development.

---

### M1. Vertical Remixing Engine
**Concept:** Borrow gaming's "vertical remixing" — add/remove stem layers (drums, bass, synths, vocals) based on biometric state. As heart rate rises, percussion intensifies. As HRV stabilizes during cool-down, layers peel back to ambient pads. The user hears their favorite song biometrically remixed in real-time.

**Why it's unprecedented:** Nobody has heard their favorite song rearranged by their own heartbeat. Every play is different because every body state is different.

**Feasibility:** Medium — `AVAudioEngine` supports real-time stem mixing. Dolby Atmos tracks on Apple Music have stem separation. CoreML can drive layer weighting.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 4 | 2 | 5 | Future |

---

### M2. Embedded Brainwave Entrainment in Real Music
**Concept:** Rather than standalone binaural beats, embed alpha (8-12 Hz) or theta (4-7 Hz) frequency differentials into the user's own music. Spectral analysis finds "gaps" in the frequency spectrum where entrainment tones can be inserted imperceptibly. Alpha for work, theta for sleep. The user's own music becomes a neurofeedback instrument.

**Why it's unprecedented:** Turns a personal music library into a therapeutic tool. Frontiers in Digital Health (2025) validates embedded beats are more effective than pure tones.

**Feasibility:** Medium — Real-time DSP via `AVAudioEngine` + custom AudioUnit. Requires headphones (binaural effect needs L/R separation). Gate to AirPods detection.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 4 | 3 | 5 | Future |

---

### M3. Predictive Wellness Forecasting
**Concept:** Using long-term biometric + music data, predict future states and proactively prepare. "Based on your patterns, you typically experience elevated stress on Monday afternoons. I've prepared a calming session." "Your HRV has been declining over 3 days — consider recovery sessions."

**Why it's unprecedented:** Moves from reactive to predictive. The AI DJ becomes a wellness oracle.

**Feasibility:** Medium — Requires weeks/months of data. CoreML timeseries forecasting handles simple predictions.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 4 | 3 | 5 | Future |

---

### M4. AirPods Pro 3 Dual-Biometric Integration
**Market signal:** Apple AirPods Pro 3 will ship with heart rate + temperature sensors. Resonance would be the only app using biometrics from BOTH wrist AND ear simultaneously — the most complete physiological picture of any music app.

**Why it's unprecedented:** Dual-source biometric triangulation. Ear-based HR has different accuracy characteristics than wrist-based, enabling cross-validation and higher confidence scoring.

**Feasibility:** Unknown — depends on Apple's API exposure for AirPods biometric data.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 2 | 5 | Future (watch Apple APIs) |

---

## PART 4: UX DESIGN UPGRADES (Not Yet Implemented)

These were researched and planned in prior sprints but never built.

---

### D1. Plutchik Emotion Flower Mood Picker
**Status:** Researched, must-have from Novel UX Design study. Not implemented.

**Implementation:** 8 "petals" (primary emotions: joy, trust, fear, surprise, sadness, disgust, anger, anticipation) in a radial tap-target layout. On tap, selected petal expands to reveal 3 intensity levels (e.g., Serenity → Joy → Ecstasy). Album-art-derived colors. Haptic feedback on selection. Replaces or complements the energy/valence sliders in MoodTabView.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 4 | Next-cycle |

---

### D2. Gradient Aurora Mood Picker
**Status:** Researched, must-have. Not implemented.

**Implementation:** 2D canvas where X = Valence, Y = Energy. Aurora gradient background where color regions correspond to mood clusters. User drags a cursor orb to desired position. Label updates as they drag: "Peaceful," "Euphoric," "Introspective," "Fierce." Replaces dual sliders with a single, more intuitive gesture. Haptic feedback at mood boundaries.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 4 | Next-cycle |

---

### D3. Haptic Music Scrubbing
**Status:** Researched, must-have. Not implemented.

**Implementation:** When scrubbing the progress slider in NowPlayingView, provide haptic ticks at beat markers. On Apple Watch, Digital Crown scrubbing with `.click` haptics at beat points (every 2-4 beats to avoid desensitization). Requires beat detection from spectral analysis — the `FFTProcessor.swift` and `SpectralAnalyzer.swift` already provide this.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 3 | 3 | Next-cycle |

---

### D4. Liquid Glass Depth Layers
**Status:** Researched, must-have. Not implemented. Requires iOS 26.

**Implementation:** Apply `.glassEffect()` modifiers across all navigation elements. Tab bar collapses on scroll per iOS 26 conventions. MiniPlayerView already uses Liquid Glass — verify all modal sheets, cards, and overlays follow suit. Consider submitting to Apple's Liquid Glass Gallery for editorial visibility.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 5 | 4 | Ship-now |

---

### D5. Synchronized Audio-Haptic-Visual Transitions
**Status:** Researched, must-have. Not implemented.

**Implementation:** When the AI transitions between tracks, synchronize: (1) biometric crossfade duration (already computed by `BiometricCrossfadeEngine`), (2) visual transition (album art gradient blend), (3) haptic pattern (gentle pulse on transition start, confirmatory tap on new track). All three events must be temporally aligned within 50ms for perceptual coherence.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 3 | 4 | Next-cycle |

---

## PART 5: GROWTH & MONETIZATION FEATURES

---

### G1. "Resonance Wrapped" — Annual Biometric Music Report
**Concept:** A Spotify Wrapped equivalent but with biometric data no competitor can replicate. "Your heart's favorite genre at 10 PM is ambient electronic." "You had 23 flow states this month." "Your most resonant track brought your stress down every time." Beautiful, branded, shareable cards.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 4 | 5 | Next-cycle |

---

### G2. Streaks & Milestones System
**Concept:** "Resonance Streak" (consecutive days with 15+ min session). Milestones: "First Session," "7-Day Streak," "100 Songs Resonated," "Night Owl (10 evening sessions)." Display subtly — never interrupt sessions. Post-session celebrations only. Duolingo-style but wellness-framed.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 4 | 5 | 3 | Next-cycle |

---

### G3. Smart Notifications — Behavior-Based Only
**Concept:** Three notification types only: (1) "Your body is telling me something" — triggered by biometric patterns that historically preceded a session. (2) "Streak reminder" — at user's typical session time. (3) "Weekly Resonance Report" — single weekly summary. No promotional notifications ever.

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 4 | 4 | 4 | Next-cycle |

---

### G4. Freemium Tier Design
**Market insight:** Subscription fatigue is real. Endel charges $50/year, Brain.fm $70/year. Users are increasingly anti-subscription. Resonance works WITH Apple Music (users already pay $10.99/month).

**Recommended model:**
- **Free tier:** Basic AI DJ with manual mood input, standard crossfades, session summaries, up to 3 playlists
- **Premium ($4.99/month or $39.99/year or $79.99 lifetime):** Full biometric integration, all session types (focus, sleep, workout, commute), Resonance Wrapped, mood forecast, ADHD mode, CarPlay, insights dashboard, unlimited playlists
- Position as: "The health companion for your existing Apple Music subscription"

| Relevance | Feasibility | Impact | Priority |
|:---------:|:-----------:|:------:|:--------:|
| 5 | 5 | 5 | Ship-now |

---

## PRIORITY MATRIX SUMMARY

### Ship Now (8 items)
| # | Feature | Type | Impact |
|---|---------|------|--------|
| R1 | AI Explanation Bar Redesign | Refinement | 5 |
| R2 | Queue / Up-Next View | Refinement | 5 |
| R3 | Shuffle/Repeat as AI Controls | Refinement | 4 |
| R4 | HeartPulseRing 3 States | Refinement | 4 |
| R5 | Settings Restructuring | Refinement | 3 |
| R6 | MoodForecast as Centerpiece | Refinement | 5 |
| R8 | Onboarding Golden Path | Refinement | 5 |
| E1 | ADHD Focus Mode | Extension | 5 |
| E2 | Workout-to-Recovery Transition | Extension | 5 |
| D4 | Liquid Glass Depth Layers | Design | 4 |
| G4 | Freemium Tier Design | Growth | 5 |

### Next Cycle (13 items)
| # | Feature | Type | Impact |
|---|---------|------|--------|
| R7 | Post-Session Summary Enhancement | Refinement | 4 |
| E3 | Natural Language DJ (Foundation Models) | Extension | 5 |
| E4 | Anxiety Interception Engine | Extension | 5 |
| E5 | Sleep Wind-Down Mode | Extension | 4 |
| E6 | Emotional Regulation Ladder | Extension | 5 |
| E7 | Biometric Music Dashboard / Insights | Extension | 5 |
| E8 | AI DJ Commentary | Extension | 5 |
| E9 | Weather-Reactive Influence | Extension | 3 |
| D1 | Plutchik Emotion Flower | Design | 4 |
| D2 | Aurora Mood Picker | Design | 4 |
| D3 | Haptic Music Scrubbing | Design | 3 |
| D5 | Synchronized Transitions | Design | 4 |
| G1 | Resonance Wrapped | Growth | 5 |
| G2 | Streaks & Milestones | Growth | 3 |
| G3 | Smart Notifications | Growth | 4 |

### Future (5 items)
| # | Feature | Type | Impact |
|---|---------|------|--------|
| E10 | CarPlay Commute DJ | Extension | 4 |
| E11 | Couples Heart Sync | Extension | 4 |
| M1 | Vertical Remixing Engine | Moonshot | 5 |
| M2 | Brainwave Entrainment in Music | Moonshot | 5 |
| M3 | Predictive Wellness Forecasting | Moonshot | 5 |
| M4 | AirPods Pro 3 Dual-Biometric | Moonshot | 5 |

---

## COMPETITIVE POSITIONING STATEMENT

**For Apple Watch wearers who listen to music daily**, Resonance is **the AI DJ that reads your body to play your music**. Unlike Spotify's AI DJ (which reads your history) or Endel (which generates ambient sounds), Resonance plays **songs you already love** based on **what your body needs right now** — your heart rate, stress level, energy, and circadian rhythm.

**Tagline options:**
- "Your music. Your body. Your DJ."
- "Music that reads the room — when the room is you."
- "The DJ who knows your heartbeat."

---

## KEY MARKET INSIGHTS

1. **Resonance is genuinely first-to-market** with biometrics + own library + real-time adaptation. No competitor does all three. The timing window is optimal — Apple's 2026 sensor expansion and Foundation Models framework create a technical enablement moment.
2. **Spotify DJ's #1 complaint is repetitiveness** — Resonance avoids this architecturally because the signal is physiological, not historical.
3. **Apple Music users are desperate for better personalization** — Resonance delivers context-awareness Apple refuses to build.
4. **The ADHD/focus market is massive and underserved** — familiar music + biometric focus detection is a unique wedge.
5. **AirPods Pro 3 with biometric sensors** is coming — Resonance should be the launch-day showcase app.
6. **Subscription fatigue is real** — offer a lifetime purchase option alongside subscription.
7. **"Resonance Wrapped"** with biometric data is an unbeatable viral mechanic no competitor can replicate.
8. **Users trust AI curation but distrust AI-generated music** — 74% say AI-generated music decreases artistic worth (2025 survey). Resonance is on the right side: AI curation of human-made music the user already loves.
9. **Sound therapy market is $3.2B** growing at 9.5% CAGR. UMG partnered with Apple on a "Sound Therapy" music collection (May 2025) — major-label validation of music-as-wellness.
10. **Spotify AI DJ usage jumped 48% in 2025** — 1-in-6 Premium subscribers use it. This validates massive consumer demand for intelligent music curation.
11. **watchOS 26 adds "Workout Buddy"** — Apple is moving AI audio into workouts. Resonance should be ready before Apple builds this natively.
12. **Individual physiological responses to music are highly consistent** (Nature 2024) — each person has a reliable "fingerprint" of how their body responds to specific songs. This validates Resonance's per-user learning model.
13. **Biometric-adaptive music increased positive affect by 165%** and physical activity levels by 49% (JMIR Human Factors 2025, meta-analysis of 18 studies). This is Resonance's strongest scientific selling point.
14. **80% of young people feel like "the main character in a movie" while listening to music** (Spotify survey). Resonance makes this real by dynamically soundtracking actual lived experience.
15. **Music therapy market is $4.06B in 2026**, growing to $6.68B by 2030 (13.2% CAGR). Wearable wellness devices: $37.4B in 2026. Resonance sits at the intersection of both.
16. **Charles Petzold's viral "Appalling Stupidity of Spotify's AI DJ"** hit Hacker News front page (Feb 2026). Trust in AI music curation is eroding at Spotify — the window for a biometric-first alternative is wide open.
17. **Liz Pelly's "Mood Machine" book** catalyzed backlash against platform mood playlists (ghost artists, sonic homogeneity). Resonance's own-library approach completely sidesteps this critique.

---

## MARKET SIZING & GROWTH STRATEGY

### Addressable Market
- **Apple Watch installed base:** ~31.9 million users (2025)
- **Apple Music subscribers:** 94 million globally, 32.6 million US
- **Overlap (Watch + Apple Music + daily listener):** 8-12 million users globally
- Apple Watch users average 6.5 hours/week listening to music

### Launch Target: "The Active Optimizer"
25-44 year old urban fitness enthusiasts who run/cycle/gym 3-5x/week with Apple Watch and Apple Music. ~3-4 million in US alone. Clearest, most demonstrable value — workout music mismatch is a visceral problem.

### Recommended Pricing: $5.99/month or $39.99/year + $79.99 lifetime
Deliberately below Endel ($50/year) and Brain.fm ($70/year) because Resonance doesn't generate/supply music — it reorganizes music the user already owns. Subscription apps generate 82% of all non-gaming iOS app revenue.

### Free Tier
- Basic HR-based song selection
- 3 sessions/day (30 min each)
- Single mood mode
- Basic listening stats

### Premium Tier
- Full biometric integration (HRV, sleep, wrist temp)
- All session types (Focus, Sleep, Workout, Commute, ADHD)
- Resonance Wrapped + Insights dashboard
- Full Watch complications suite
- Unlimited sessions, multi-device sync
- Custom DJ personality controls

### Growth Levers (Priority Order)
1. **Apple editorial featuring** — Featured apps see up to 1,747% download boost. Submit nomination 3+ weeks before launch. Align with Apple Watch hardware announcements (September).
2. **TikTok "heart rate DJ" videos** — Visual of HR changing and music shifting is inherently compelling. #BiometricMusic #HeartRateMusic #AppleWatchHack
3. **Micro-influencer campaign** — 10-20 fitness TikTokers showing Resonance during workouts. Engagement rate ~10% for nano/micro influencers vs 2% for macro.
4. **Reddit r/AppleWatch community** — Build-in-public presence, genuine engagement. High-quality, high-retention users.
5. **"Resonance Wrapped"** — Annual biometric music review. Spotify Wrapped hit 200M users in first 24 hours with 500M social shares. Resonance data is MORE interesting because it reveals biology, not just taste.

### Retention Targets
| Metric | Music App Avg | Resonance Target |
|--------|:------------:|:----------------:|
| D1 | 25% | 35% |
| D7 | 12% | 22% |
| D30 | 3.8% | 12% |
| Free→Paid | — | 6% |
| Trial→Paid | — | 25% |

### Revenue Projection (Conservative)
At 100K downloads, 6% conversion, $40/year = **$240K ARR**
At 500K downloads (post Apple feature) = **$1.2M ARR**

### App Store Strategy
- **Primary category:** Health & Fitness (higher trial-to-paid rates: 18-40%)
- **Secondary category:** Music
- **Title:** "Resonance: AI Music DJ"
- **Subtitle:** "Heart Rate Powered Playlists"

---

## SOURCES

Research compiled from:
- Competitive analysis: Endel, Brain.fm, Mubert, Aimi, LifeScore, Weav Run, Spotify DJ, Apple Music, RockMyRun, Calm, Headspace, Moodagent
- Reddit: r/AppleMusic, r/AppleWatch, r/Spotify, r/ADHD, r/running, r/Fitness
- Academic: Nature Communications, PLOS One, Frontiers in Digital Health, Scandinavian Journal of Medicine & Science in Sports, PMC, IEEE Pulse
- Industry: TechCrunch, The Verge, Billboard, Tracxn, Apple Newsroom, Spotify Newsroom
- UX: Apple HIG, Smashing Magazine, UXmatters, Eleken, UX Collective, IDEO
- Innovation: Gaming audio (vertical remixing), neuroscience (entrainment, coherence), sports science (cadence matching, recovery), automotive (drowsiness detection), AI/LLM (Foundation Models)
