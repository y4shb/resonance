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

AIDJ/
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
