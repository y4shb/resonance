# Resonance Vinyl UI — UX Navigation & Interaction Map

## Stitch Project

**Project ID:** `14027195738695383179`
**Design System:** Resonance Obsidian (`a863d5681cf5435287947e5f78df329e`)

### Generated Screens

| # | Screen | Stitch Screen ID |
|---|--------|-----------------|
| 1 | Now Playing — Turntable | `06c9c00130e042938d59808d0150b0b4` |
| 2 | Record Collection Browser | `c8cdec2749d84a9c96363e4a54c7c456` |
| 3 | Music Queue | `d8556b31d2fc4da9b14836b717ea45e8` |
| 4 | Landing / Splash | `91861a5a342c4aae89d59bff688048a8` |
| 5 | Mini Player Bar | `7adae882a94344ab864585fc109581e7` |
| 6 | Session Mode Picker | `3194b1fd8a82483792837906ae148bcf` |

---

## App Flow — Navigation Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    LandingView (4)                       │
│  Vinyl spins up → album art fades into label            │
│  "Let's Resonate" button                                │
│         │                                               │
│         ▼  tap "Let's Resonate"                         │
│  ┌──────────────────────────────────────────┐           │
│  │     SessionIntentPicker (6)              │           │
│  │  9 vinyl-label intent cards              │           │
│  │  tap intent → starts session             │           │
│  └──────────┬───────────────────────────────┘           │
│             │ intent selected                           │
│             ▼                                           │
│  ┌──────────────────────────────────────────┐           │
│  │          MainView (TabView)              │           │
│  │                                          │           │
│  │  Tab 1: Now Playing (1)                  │           │
│  │  Tab 2: Mood                             │           │
│  │  Tab 3: Playlists / Record Browser (2)   │           │
│  │  Tab 4: Insights                         │           │
│  │  Tab 5: Settings                         │           │
│  │                                          │           │
│  │  ┌─────────────────────────────────┐     │           │
│  │  │    Mini Player Bar (5)          │     │           │
│  │  │    always visible on tabs 2-5   │     │           │
│  │  │    tap → navigates to Tab 1     │     │           │
│  │  └─────────────────────────────────┘     │           │
│  └──────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────┘
```

---

## Screen-by-Screen Interaction Specification

### 1. Now Playing — Turntable View

**File:** `NowPlayingView.swift` (modified) + `TurntableView.swift` (new)

**Visual Composition (top to bottom):**
- Full-bleed blurred album artwork background
- StatusPill + NL Input Bar (preserved from current UI)
- FocusStreakView overlay (preserved)
- **Turntable Assembly** (ZStack):
  - VinylRecordView — spinning disc with groove rings + album art label
  - TonearmView — chrome arm tracking playback progress
- Song title + artist + album
- Transport controls (prev / play-pause / next) in glass capsule
- Bottom action row ("Why this song?" + Queue button)
- CommentaryToastView overlay (preserved)

**Interactions:**

| Action | Trigger | Result | Sound | Haptic |
|--------|---------|--------|-------|--------|
| Play | Tap play button | Record starts spinning at 33⅓ RPM, tonearm sweeps from rest (-27°) to outer groove (0°) | needle_drop.wav | Medium impact |
| Pause | Tap pause button | Record stops spinning (angle preserved), tonearm lifts to rest (-27°) | needle_drop.wav (quiet) | Light impact |
| Skip forward | Tap skip button | Track changes, record cross-fades, tonearm resets to outer groove | needle_drop.wav (on new track) | Light impact |
| Skip backward | Tap prev button | Previous track, same transition as skip forward | needle_drop.wav | Light impact |
| Seek | Drag tonearm | Tonearm follows finger between 0°–22°, maps to 0–1 progress | — | Selection on grab |
| Seek release | Release tonearm | Seeks to computed progress, tonearm settles | needle_drop.wav (brief) | Medium impact |
| "Why?" | Tap "Why this song?" | Sheet slides up with AI explanation factors | — | — |
| Queue | Tap queue button | Sheet slides up with Queue View (3) | — | — |
| NL Input | Tap NL bar | Keyboard appears, user types request to AI DJ | — | — |
| Ambient crackle | During playback (if enabled) | vinyl_crackle.wav loops at 12% volume | — | — |

**Navigation FROM this screen:**
- Queue button → Queue sheet (3)
- "Why this song?" → Explanation sheet (modal)
- Toolbar: AI select, tuning, bookmark, mood → respective sheets
- Tab bar → other tabs (mini player appears)

**Navigation TO this screen:**
- Tap mini player bar (5) from any tab
- Tap album in Record Collection Browser (2)
- Tab 1 in tab bar
- Hero transition from LandingView (4) / SessionIntentPicker (6)

---

### 2. Record Collection Browser

**File:** `PlaylistBrowserView.swift` (modified) + `RecordCarouselView.swift` (new)

**Visual Composition:**
- Navigation title "Record Collection"
- **RecordCarouselView** (hero section):
  - 3D CoverFlow horizontal scroll of album art as vinyl sleeves
  - Centered album faces forward, off-center tilt 35° on Y-axis
  - Off-center albums scale down 15%, fade 30%
  - Vinyl disc edge peeks from right side of each sleeve
  - `.scrollTargetBehavior(.viewAligned)` for magnetic snap
- **Playlist List** (below carousel):
  - Mood playlists section
  - User playlists section
  - Each row has thin vinyl disc accent on left edge
  - Search bar + pull-to-refresh

**Interactions:**

| Action | Trigger | Result |
|--------|---------|--------|
| Scroll carousel | Horizontal swipe | Albums rotate in 3D CoverFlow, snap to center |
| Tap album (carousel) | Tap centered album | Hero transition: sleeve morphs into spinning record on Now Playing (1) |
| Tap playlist row | Tap list row | NavigationLink to playlist detail, albums populate carousel |
| Search | Pull down or tap search | Filter playlists by name |
| Refresh | Pull to refresh | Reload playlists from MusicKit |

**Navigation FROM this screen:**
- Tap carousel album → Now Playing (1) via hero transition
- Tap playlist row → Playlist detail (albums listed)
- Tab bar → other tabs
- Mini player tap → Now Playing (1)

**Navigation TO this screen:**
- Tab 3 in tab bar

---

### 3. Music Queue — Record Crate

**File:** `QueueView.swift` (modified)

**Visual Composition:**
- "Now Spinning" header (was "Now Playing")
- Current song with tiny spinning record (replaces speaker.wave icon)
- "Up Next" section:
  - Each row styled as record-in-crate: artwork with dark vinyl disc peeking behind
  - AI confidence ring (existing) — looks like vinyl quality indicator
  - AI reasoning text (existing)
  - Drag handle for reorder
- "Up Next in Queue" fallback section (MusicKit queue)

**Interactions:**

| Action | Trigger | Result |
|--------|---------|--------|
| Reorder | Long-press + drag | Row lifts with spring animation, reorder queue |
| Remove | Swipe left | Row slides out, removed from queue |
| Tap row | Tap queue item | Jumps to that song, turntable transitions |
| View reasoning | Visible inline | AI reasoning text + confidence gauge per row |

**Navigation FROM this screen:**
- Dismiss sheet → returns to Now Playing (1)
- Tap queue item → Now Playing updates to that song

**Navigation TO this screen:**
- Queue button on Now Playing (1)
- Presented as sheet overlay

---

### 4. Landing / Splash

**File:** `LandingView.swift` (modified)

**Visual Composition:**
- Dark gradient background
- Central vinyl record with visible groove rings
- Record spins up from 0 RPM as animation
- Album art fades into the label center
- "Resonance" title text
- "Your AI-Powered DJ" subtitle
- "Let's Resonate" CTA button with vinyl-inspired styling
- matchedGeometryEffect("heroArtwork") on vinyl disc

**Interactions:**

| Action | Trigger | Result |
|--------|---------|--------|
| Appear | App launch | Vinyl spins up, art fades in (1.5s animation) |
| Tap CTA | Tap "Let's Resonate" | Hero transition: vinyl morphs into SessionIntentPicker or MainView |

**Navigation FROM this screen:**
- "Let's Resonate" → SessionIntentPicker (6) or MainView if session exists

**Navigation TO this screen:**
- App cold launch (no active session)

---

### 5. Mini Player Bar

**File:** `VinylMiniPlayerView.swift` (new), replaces `MiniPlayerView.swift`

**Visual Composition:**
- Compact HStack with `.glassEffect(.regular)`:
  - 36pt spinning VinylRecordView (simplified grooves) on left
  - Progress arc: 2pt accent-colored circle trim around mini record
  - Song title (semibold) + artist (caption)
  - Play/pause + skip buttons (compact)
- Sits in `.safeAreaInset(edge: .bottom)` on tabs 2-5
- Hidden on Now Playing tab (Tab 1)

**Interactions:**

| Action | Trigger | Result |
|--------|---------|--------|
| Tap bar | Tap anywhere on bar | Navigate to Now Playing (1) via tab switch |
| Play/Pause | Tap play/pause button | Toggle playback, mini record starts/stops spinning |
| Skip | Tap skip button | Next track, mini record artwork updates |

**Navigation FROM this screen:**
- Tap → Now Playing tab (1)

**Navigation TO this screen:**
- Visible on tabs 2-5 whenever a song is loaded

---

### 6. Session Mode Picker

**File:** `SessionIntentPicker.swift` (modified)

**Visual Composition:**
- 2-column grid of 9 intent cards
- Each card restyled as colored vinyl record label:
  - Circular concentric ring background (suggesting grooves)
  - Intent icon centered like a label graphic (brain, figure.run, etc.)
  - Intent name + description below
  - `.glassEffect(.regular)` container
- ForecastPreviewArc integration (existing)

**Interactions:**

| Action | Trigger | Result |
|--------|---------|--------|
| Tap intent card | Tap any card | Starts session with selected intent, transitions to MainView |
| View forecast | Visible inline | Energy forecast arc shows predicted session trajectory |

**Navigation FROM this screen:**
- Tap intent → MainView with Now Playing (1) active

**Navigation TO this screen:**
- From LandingView (4) via "Let's Resonate"
- From session end → new session prompt

---

## Cross-View Interaction Matrix

```
                Landing  Intent   NowPlay  Browser  Queue  MiniPlayer
Landing    (4)    —       CTA→      —        —       —       —
Intent     (6)    —        —      select→    —       —       —
NowPlay    (1)    —        —        —        —     queue→    —
Browser    (2)    —        —     tap album→  —       —       —
Queue      (3)    —        —    ←dismiss     —       —       —
MiniPlayer (5)    —        —     tap bar→    —       —       —
```

**Legend:** `→` = navigates to, `←` = returns to

## Shared State Connections

| State | Owner | Consumers |
|-------|-------|-----------|
| `isPlaying` | NowPlayingViewModel | VinylRotationController, TonearmView, MiniPlayer, VinylSFXPlayer |
| `playbackProgress` | NowPlayingViewModel | TonearmView angle, MiniPlayer progress arc |
| `currentArtwork` | NowPlayingViewModel | VinylRecordView label, MiniPlayer record, Background blur |
| `currentSongTitle/Artist` | NowPlayingViewModel | NowPlayingView, MiniPlayer |
| `aiQueue` | NowPlayingViewModel | QueueView confidence rings + reasoning |
| `biometricState` | StateEngine | StatusPillView, HeartPulseRing/PlatterRing |
| `sessionIntent` | SessionIntentPicker | MainView initial state |
| `rotationDegrees` | VinylRotationController | VinylRecordView (large + mini) |
| `isCrackleEnabled` | VinylSFXPlayer | Settings toggle, ambient loop |

## Hero Transition Chain

```
LandingView vinyl disc
    ↓ matchedGeometryEffect("heroArtwork")
SessionIntentPicker (or MainView)
    ↓ matchedTransitionSource / .zoom
RecordCarouselView sleeve card
    ↓ matchedTransitionSource / .zoom
NowPlayingView turntable VinylRecordView
```

The album artwork remains the visual thread connecting every screen — from the initial spinning disc on the landing page, through the sleeve cards in the carousel, to the spinning label on the turntable.

## Animation Timing Summary

| Animation | Duration | Easing | Notes |
|-----------|----------|--------|-------|
| Record spin | Continuous | Linear | 33⅓ RPM = 200°/s |
| Tonearm play/pause | ~0.8s | Spring (0.8, 0.7) | Slight overshoot |
| Tonearm progress | 0.5s | Linear | Per progress update |
| Carousel 3D rotation | Interactive | Phase-driven | Zero lag |
| Track change cross-fade | 0.8s | EaseInOut | Background blur |
| Record swap | 0.3s out + 0.3s in | EaseInOut | 0.1s delay between |
| Hero transition | 0.35s | Spring | iOS 18 .zoom |
| Button press | Instant | Spring (0.25, 0.6) | Scale to 0.92 |
| Landing spin-up | 1.5s | EaseOut | 0→33⅓ RPM |
