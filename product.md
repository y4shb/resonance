AI DJ – Apple Music Nervous System

Technical Blueprint

⸻

1. Vision

AI DJ is a cross-device music intelligence system that selects the most appropriate song exclusively from the user’s existing Apple Music playlists.
Decisions are driven by:
	•	Apple Watch biometrics
	•	historical HealthKit timelines
	•	macOS behavioral context
	•	time, location, and calendar signals

The product is not a recommender for new music. It is a decision engine for personal music you already trust.

Core Principles
	•	Playlist-first: no external catalog exploration
	•	On-device intelligence and privacy
	•	Cross platform: iOS + macOS + watchOS
	•	Transparent reasoning for every selection
	•	Continuous learning from physiology

⸻

2. Platform Capabilities

Apple Watch Role
	•	Background heart rate and HRV sampling
	•	Workout state detection
	•	Complications and Smart Stack widgets
	•	MusicKit remote playback control
	•	Crown-based intensity adjustment
	•	Quick mood confirmation taps

Device Responsibility Model

Device	Responsibilities
Apple Watch	Sensor acquisition, lightweight controls, mood input
iPhone	Core ML inference, history engine, MusicKit playback
macOS	Focus and productivity context provider


⸻

3. System Architecture

Logical Flow

[Apple Watch Sensors]
      ↓
[Context Collector – iPhone]
      ↓
[State Estimator]
      ↓
[Decision Engine]
      ↓
[MusicKit Player]
      ↑
[Learning Store]
      ↑
[macOS Context Agent]

Components
	1.	Context Collector
Aggregates real-time signals from HealthKit, WatchConnectivity, and macOS agent.
	2.	Historical Engine
Reconstructs long-term correlations between playlists and physiological outcomes.
	3.	State Estimator
Converts raw signals into a normalized emotional/energy vector.
	4.	Decision Engine
Ranks songs within the active playlist and manages transitions.
	5.	Learning Store
Maintains per-song and per-playlist effectiveness metrics.

⸻

4. Historical Intelligence

Data Reconstruction

For every past listening session:
	•	active playlist and timestamp
	•	heart rate and HRV trajectory
	•	steps and motion state
	•	workout markers
	•	next-night sleep quality
	•	skip and volume behavior

Derived Knowledge
	•	Playlist Effect Signature
Quantifies how a playlist historically changes stress and recovery.
	•	Song Micro-Impact
Estimates stabilization or activation effects per track.
	•	Context Memory
Associates environments (home, travel, work) with outcomes.

⸻

5. Core Engines

5.1 State Engine

Produces:

StateVector {
  arousal: number      // 0..1
  energy: number       // 0..1
  focus: number        // 0..1
  stress: number       // 0..1
  context: string
}

Inputs:
	•	Watch biometrics
	•	macOS behavior signals
	•	time of day
	•	historical priors
	•	manual mood taps

⸻

5.2 Music Feature Layer

Per song representation:
	•	tempo / BPM
	•	energy estimate
	•	acoustic density
	•	lyrical complexity
	•	familiarity score
	•	personal effectiveness vector

⸻

5.3 Decision Logic
	1.	Candidate pool limited to current playlist
	2.	Apply guard filters
	•	avoid repeats
	•	time-of-day rules
	3.	Ranking function

score =
  w1 * BPM_match +
  w2 * energy_match +
  w3 * familiarity +
  w4 * historical_effect +
  w5 * context_alignment

	4.	Transition controller ensures smooth mood continuity.

⸻

6. Technology Stack

iOS
	•	SwiftUI
	•	MusicKit
	•	HealthKit
	•	CoreML
	•	BackgroundTasks
	•	WidgetKit

watchOS
	•	WatchKit
	•	Complications
	•	NowPlaying
	•	Digital Crown interactions

macOS
	•	Menu Bar agent
	•	Accessibility / Screen Time signals
	•	App focus monitoring

Storage
	•	CoreData / SQLite
	•	On-device embeddings
	•	Secure App Groups

⸻

7. Milestones to MVP

M1 – Platform Skeleton
	•	iOS, macOS, watchOS targets
	•	MusicKit authentication
	•	basic playback control
	•	Watch remote session

Outcome: music can be controlled from all devices.

⸻

M2 – Data Foundations
	•	playlist ingestion pipeline
	•	song feature store
	•	event logging
	•	Watch sensor streaming

⸻

M3 – Historical Backfill
	•	HealthKit timeline import
	•	alignment with playlist history
	•	build:

PlaylistImpact
SongImpact


⸻

M4 – State v1
	•	real-time vector generation
	•	macOS context signals
	•	manual mood slider

⸻

M5 – DJ Brain v1
	•	ranking implementation
	•	transition guard
	•	explanation generator

⸻

M6 – Watch Experience
	•	complication
	•	three-tap mood input
	•	crown intensity control

⸻

M7 – Learning Loop
	•	skip penalties
	•	HRV response credit
	•	session quality scoring

⸻

M8 – MVP Release
	•	daily usability
	•	cross device sync
	•	offline operation

⸻

8. Data Models

HistoricalSession
	•	playlistId
	•	start / end
	•	avg HRV
	•	delta HR
	•	next sleep score
	•	context tags

SongEffect
	•	calmScore
	•	focusScore
	•	energyScore
	•	confidence

⸻

9. Algorithms

Impact Estimation

impact =
  ΔHRV * a +
  ΔHR * b +
  skip_penalty +
  session_bonus

Real-Time Guard
	•	rising HR during calm → downshift BPM
	•	falling engagement → increase familiarity

⸻

10. Privacy Model
	•	all processing on device
	•	no raw health export
	•	encrypted local backup
	•	opt-in analytics only

⸻

11. Experience Flow

Morning
System detects elevated HR and selects a stabilizing track from the current playlist, providing a short rationale.

Workout End
Energy ramp sequence begins automatically based on historical recovery curves.

⸻

12. Repository Layout

resonance/
 ├─ iOS
 ├─ Watch
 ├─ macOS
 ├─ Brain
 │   ├─ Historical
 │   ├─ State
 │   ├─ Ranking
 └─ UI


⸻

13. Definition of Done
	•	operates across three devices
	•	learns from historical physiology
	•	provides explanations
	•	playlist-only selection
	•	reliable offline behavior

⸻

14. Implemented Features (as of 2026-03-20)

All milestones M1-M8 are COMPLETE. The following additional features have been implemented beyond the original MVP scope.

14.1 Brain Intelligence Features (COMPLETE)

	•	Spectral Audio Analysis -- Accelerate vDSP FFT, 40-band mel filterbank, spectral centroid/rolloff/flux for real frequency-domain audio analysis
	•	Circadian Rhythm Personalization -- Per-user circadian energy profiles built from 7-day HRV/HR history; song selection adapts to time-of-day energy
	•	Watch Emotion Detection (5 states) -- Multi-signal emotion detection using accelerometer, gyroscope, HR, HRV, and wrist temperature with Bayesian fusion
	•	Core ML Song Feature Prediction -- On-device Core ML model predicts song emotional impact from audio features; training pipeline included
	•	Multi-Signal Valence Fusion -- Fuses HR, HRV, motion, temperature with learned weights for accurate emotional valence
	•	Circadian HRV Correction -- Normalizes HRV by time-of-day baseline to eliminate false stress readings
	•	HR Acceleration Scoring -- Uses rate-of-change (not absolute HR) for arousal detection
	•	Entrainment Mode Detection -- Identifies rhythmic HR-music coupling for biometric-audio synchronization
	•	Adaptive Signal Weights -- Per-user signal weight learning from feedback
	•	Sleep Baseline Integration -- Overnight HRV for daily calibration
	•	Session Arc Planning -- Hierarchical energy arc planning with 6 templates (workout, relaxation, focus, sleep, morning, commute)
	•	ISO Principle Mood Trajectory -- Match-then-shift strategy for therapeutic music sequencing
	•	Multi-Component Reward Function -- R_total = w1*R_hrv + w2*R_hr + w3*R_behavioral + w4*R_session with cold-start transition
	•	Motion-Aware Reward Gating -- Rejects biometric rewards during high-motion periods
	•	Personal HRV Baseline Tracking -- Replaces hardcoded 50ms with adaptive alpha=0.02 tracking

14.2 Novel Features (COMPLETE)

	•	Biometric Crossfade -- Adapts crossfade duration based on heart rate (1-8 seconds)
	•	Resonance Score -- Post-session biometric-music correlation score (0-100) with ring graph
	•	Heart Tempo Pulse Ring -- Pulse ring behind album art beating at user's heart rate
	•	Mood Forecast -- Pre-session mood arc prediction with draggable control points
	•	Sonic Bookmark -- Double-tap Watch / shake iPhone to bookmark a moment with biometric context

14.3 User Experience Features (COMPLETE)

	•	Landing Screen with Brain Orb -- Animated brain visualization as app entry point
	•	Onboarding Flow -- 4-screen PageTabView with MusicKit + HealthKit permissions and initial mood
	•	Playlist Detail Browsing with Search -- Cross-playlist song browsing with search and skeleton loading
	•	Mood Donut Chart -- Circular chart showing mood distribution over time
	•	Auto-Generated Mood Playlists -- Automatic playlist generation based on detected mood state
	•	Library Analysis with Emotion Categorization -- Scans user library and categorizes songs by emotional profile
	•	Mood Trajectory with ISO Principle -- Mood arc visualization with match-then-shift therapeutic sequencing
	•	Cross-Playlist Recommendations -- Cross-reference song effectiveness across playlists
	•	Component Library -- ResonanceCard, ResonanceButton, ResonanceTag reusable components
	•	Dark Mode Palette -- Custom dark palette (#121212 base, blue-undertone surfaces) preventing OLED smearing
	•	Album Art Ambient Glow -- GPU-accelerated dominant color extraction with radial gradient
	•	Skeleton Loading Screens -- Shimmer-animated skeleton placeholders (perceived 30% faster)
	•	Tab Bar Mini Player -- Persistent mini player with Liquid Glass styling (iOS 26)
	•	Liquid Glass Transport Controls -- iOS 26 glass effect on playback controls
	•	Haptic Feedback System -- Context-appropriate haptics throughout the app
	•	Dynamic Island / Live Activity -- Lock Screen and Dynamic Island integration
	•	Interactive Widgets -- Play/pause, skip, and mood buttons in WidgetKit

14.4 Watch Features (COMPLETE)

	•	Emotion Motion Sensor -- 50Hz accelerometer + gyroscope for gesture/posture detection
	•	Overnight Temperature Monitor -- Wrist temperature delta for stress/recovery baseline
	•	Sensor Coordinator -- Lifecycle management for all watch sensors
	•	Crown DJ Mode -- Digital Crown energy level adjustment
	•	3-Tap Mood Input -- Quick mood confirmation (down/neutral/up)
	•	Watch Now Playing -- Dominant color gradient background with transport controls
	•	Workout Session Manager -- HKWorkoutSession for high-frequency HR during exercise

⸻

15. Project Statistics (2026-03-20)

	•	Total Swift files: ~167
	•	Total lines of code: ~45,820
	•	Test files: 13 test suites, ~8,200 LOC
	•	Brain subsystem: 46 files, ~11,427 LOC
	•	iOS UI layer: 44 files, ~11,641 LOC
	•	Watch layer: 14 files, ~2,691 LOC
	•	macOS layer: 8 files, ~1,452 LOC
	•	Shared infrastructure: 39 files, ~9,709 LOC
	•	Bug fixes applied: 80+
	•	Features implemented: 40+
	•	Research papers referenced: 70+

⸻
