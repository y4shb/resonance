# Resonance UI/UX Overhaul: Full Retro-Tech Immersion

**Date**: 2026-04-11
**Status**: Approved
**Approach**: Design System Spine + Parallel Screens (Approach 3)

## Overview

Transform every screen in Resonance into a cohesive 1980s Walkman / Hi-Fi retro-tech universe. The existing Walkman cassette player (Now Playing) and cassette grids (Playlists) set the aesthetic baseline. This spec extends that aesthetic to Mood, Insights, Settings, Landing, Onboarding, the tab bar, and the mini player with full skeuomorphic realism — rotary gestures, spring physics, physical travel depth, and mechanical haptics.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Scope | Full Retro-Tech Immersion — every screen |
| Era/Vibe | 1980s Walkman / Hi-Fi — warm, mechanical, tactile |
| Navigation | Cassette deck control strip — mechanical buttons, LED indicators, tray-slide transitions |
| Interaction Fidelity | Skeuomorphic realism — rotary gestures, spring physics, physical travel depth |
| Accent Color | Dynamic — extracted from current song's album artwork, propagated app-wide |
| Implementation | Design system spine first, then components + screens in parallel |

---

## 1. Design System Spine

All retro components and screens draw from these shared tokens.

### 1.1 Color Palette

| Token | Value | Usage |
|-------|-------|-------|
| `accent` | Dynamic from album art | Power LEDs, active indicators, AI glow. Fallback: `#5A8CFF` periwinkle |
| `accentSecondary` | Complementary from art | Secondary highlights. Fallback: derived from `#5A8CFF` |
| `accentMuted` | Accent at 60% saturation | Dark mode desaturated variant |
| `ledAmber` | `#FFB347` | Warm indicator LEDs, pause state, warning |
| `ledGreen` | `#4ADE80` | Active/on state, signal present, healthy |
| `ledRed` | `#EF4444` | Peak/clip indicator, error, recording |
| `phosphorBlue` | Accent at 80% opacity | LCD backlight tint, display readouts |
| `metalLight` | `#C0C0C8` | Brushed aluminum highlights |
| `metalMid` | `#8A8A94` | Metal surface mid-tone |
| `metalDark` | `#3A3A42` | Panel recesses, button wells |
| `screwChrome` | `#D4D4DC` | Corner screws, bezels |
| `panelBg` | `#1A1A22` | Recessed panel interiors |
| `grainOverlay` | White at 2-4% | Horizontal grain texture on metal surfaces |

### 1.2 Dynamic Accent Color System

The accent color is extracted from the current song's album artwork and propagated across the entire app in real-time.

**Flow:**
1. `DominantColorExtractor` pulls the dominant color from `MusicKit.Artwork` (already exists)
2. `NowPlayingViewModel.artworkAccentColor` publishes it (already exists)
3. A custom `@Environment(\.retroAccentColor)` environment key propagates the color to every view
4. Color transitions between songs use `withAnimation(.easeInOut(duration: 0.8))`
5. Fixed LED colors (`ledAmber`, `ledGreen`, `ledRed`) are NOT affected — only accent-derived elements shift

**What changes color:** Power LEDs on tab bar, VU meter needle tint, rotary knob highlight ring, LCD panel backlight tint, mini player progress bar, AI glow effects, button active state highlights.

**What stays fixed:** Warning/error LEDs, signal-present LED, metal surface colors, typography colors, shadow/highlight values.

### 1.3 Typography Scale

| Level | Font | Size | Weight | Usage |
|-------|------|------|--------|-------|
| `lcdTitle` | `.monospaced` | 14pt | `.semibold` | Screen titles in LCD panels |
| `lcdBody` | `.monospaced` | 11pt | `.medium` | Readout values, counters |
| `lcdCaption` | `.monospaced` | 9pt | `.regular` | Labels, secondary info |
| `engraved` | `.monospaced` | 8pt | `.heavy` + tracking 3pt | Embossed panel labels |
| `ledDigit` | `.monospaced` | 16pt | `.bold` | Large numeric readouts |

All retro text uses monospaced design. System fonts are preserved for accessibility-critical text (error messages, long descriptions).

### 1.4 Surface Textures

- **Brushed Metal**: Horizontal linear gradient with 2% white grain lines at 1pt intervals. Applied via `BrushedMetalModifier` ViewModifier.
- **Recessed Panel**: Inner shadow (black 30%, 2pt inset) + dark fill (`panelBg`). Used for LCD displays, VU meter faces, control wells.
- **Raised Surface**: Outer shadow (black 40%, 4pt drop) + top highlight (white 8%, 1pt). Used for buttons, knobs, panels.
- **Screw Detail**: 6pt chrome circle with cross-slot engraving at panel corners.

### 1.5 Animation Constants

| Parameter | Value | Usage |
|-----------|-------|-------|
| `needleBounce` | `Spring(response: 0.4, dampingFraction: 0.5)` | VU meter needle overshoot |
| `knobRotation` | `Spring(response: 0.2, dampingFraction: 0.8)` | Rotary knob snap |
| `switchFlip` | `Spring(response: 0.15, dampingFraction: 0.7)` | Toggle switch throw |
| `buttonPress` | `Spring(response: 0.1, dampingFraction: 0.6)` | Push button travel |
| `traySlide` | `Spring(response: 0.35, dampingFraction: 0.85)` | Screen transitions |
| `ledFade` | `easeInOut(duration: 0.3)` | LED on/off state change |

### 1.6 Haptic Patterns

| Event | Haptic | Intensity |
|-------|--------|-----------|
| Knob detent | `.impact(.light)` | Each detent position |
| Switch flip | `.impact(.medium)` | On toggle |
| Button press | `.impact(.rigid)` | On press down |
| Button release | `.impact(.soft)` | On release |
| Tab switch | `.impact(.medium)` | On tab change |
| VU peak | `.notification(.warning)` | When needle hits red zone |

---

## 2. Retro Component Library

Nine reusable building blocks that every screen assembles from. All live in `iOS/Views/Components/RetroControls/`.

### 2.1 RetroKnob (Rotary Control)

**File**: `RetroKnob.swift`

**Appearance**: 3D cylindrical knob on brushed metal. Top face has a white pointer line engraving. Outer rim has metallic shadow. Sits in a circular recess with embossed position markers (0-10 style).

**Interaction**: `RotationGesture` mapped to value range. Spring snaps to detent positions (configurable: continuous vs. stepped). Each detent fires `.impact(.light)` haptic.

**Rendering**: Canvas-drawn knob body with radial gradient for 3D cylinder illusion. Pointer line rotates with value. Shadow rotates opposite to simulate fixed top-left light source.

**Parameters**:
- `value: Binding<Double>` — current value
- `range: ClosedRange<Double>` — min/max
- `detents: Int?` — number of snap positions (nil = continuous)
- `label: String` — engraved label below knob
- `size: CGFloat` — overall diameter (default: 60)

### 2.2 RetroSliderPot (Linear Fader)

**File**: `RetroSliderPot.swift`

**Appearance**: Vertical or horizontal slot cut into brushed metal. Rectangular fader cap (metallic with center groove) slides along slot. Scale markings along side. Inner shadow in slot showing depth.

**Interaction**: `DragGesture` along slot axis. Cap follows finger, clamped to bounds. Haptic on min/max hit. Optional center detent.

**Parameters**:
- `value: Binding<Double>` — current value
- `orientation: Axis` — `.vertical` or `.horizontal`
- `label: String` — engraved label
- `showScale: Bool` — show tick marks

### 2.3 RetroVUMeter (Needle Gauge)

**File**: `RetroVUMeter.swift`

**Appearance**: Semi-circular meter face in recessed panel. White face with scale markings (-20 to +3 dB style). Thin accent-colored needle with center pivot pin. "VU" label in vintage style. Green/yellow/red zones on scale arc.

**Interaction**: Read-only. Needle driven by `Double` value. Uses `needleBounce` spring for overshoot-then-settle behavior.

**Rendering**: Canvas for meter face and markings. Needle as rotated line from pivot. Peak hold: thin accent line at highest recent position, decays after 2s.

**Parameters**:
- `value: Double` — 0.0 to 1.0
- `label: String` — meter label
- `showPeakHold: Bool` — enable peak hold indicator
- `size: CGFloat` — overall width

### 2.4 RetroToggleSwitch (Rocker Switch)

**File**: `RetroToggleSwitch.swift`

**Appearance**: 3D rectangular rocker in metal bezel. ON tilts up-right, OFF tilts down-left. Matte texture body with embossed ON/OFF text. Adjacent LED dot.

**Interaction**: Tap toggles. Switch animates with `switchFlip` spring through 15-degree 3D rotation. Adjacent LED fades with `ledFade`.

**Parameters**:
- `isOn: Binding<Bool>` — state
- `label: String` — switch label
- `ledColor: Color` — LED color when ON

### 2.5 RetroPushButton (Momentary/Latching Button)

**File**: `RetroPushButton.swift`

**Appearance**: Rectangular button sitting 4pt proud of metal surface. Top face with embossed icon/text. Visible side edges. Shadow beneath for depth.

**Interaction**: Press: sinks 3pt, shadow reduces, sides compress. Release: springs back with `buttonPress` spring. Haptic pair: `.rigid` press, `.soft` release.

**Parameters**:
- `label: String` — button text
- `icon: String?` — SF Symbol name
- `action: () -> Void` — callback
- `isLatching: Bool` — stays pressed (for tab bar buttons)

### 2.6 RetroLEDIndicator

**File**: `RetroLEDIndicator.swift`

**Appearance**: Small circle (6-10pt) with colored fill and soft glow bloom. Recessed into panel (inner ring shadow). OFF state: dark gray lens.

**States**: OFF (dark lens), ON (solid color + glow), BLINK (pulsing at configurable rate).

**Parameters**:
- `isOn: Bool` — on/off state
- `color: Color` — LED color
- `size: CGFloat` — diameter (default: 8)
- `blinkRate: Double?` — nil = steady, otherwise Hz

### 2.7 RetroLCDPanel (Display)

**File**: `RetroLCDPanel.swift`

**Appearance**: Recessed rectangular panel with dark blue-black interior. Content in monospaced accent-tinted text. Horizontal scanline texture overlay (1px lines at 50% opacity, 2px apart). Inner shadow on all edges. Corner radius 4pt.

**Parameters**:
- `content: () -> Content` — ViewBuilder for display content
- `title: String?` — optional header label in engraved text
- `width: CGFloat?` — optional fixed width

### 2.8 RetroSegmentedSelector

**File**: `RetroSegmentedSelector.swift`

**Appearance**: Row of embossed metal buttons in shared bezel. Active segment pressed-in with lit LED above. Inactive segments sit proud. Metal dividers between segments.

**Interaction**: Tap to select. Active presses in, previous rises. LED transitions with `ledFade`.

**Parameters**:
- `selection: Binding<T>` — selected value (T: Hashable)
- `options: [T]` — available options
- `label: (T) -> String` — display text mapper

### 2.9 BrushedMetalSurface (Container)

**File**: `BrushedMetalSurface.swift`

**Appearance**: Rounded rectangle with 5-stop horizontal gradient (metalLight/metalMid alternating), 2% white grain lines, chrome edge highlight (top: white 8%, bottom: black 15%), optional corner screws.

**Parameters**:
- `cornerRadius: CGFloat` — default 12
- `showScrews: Bool` — show corner screw details
- `content: () -> Content` — ViewBuilder

---

## 3. Cassette Deck Tab Bar

**File**: `CassetteDeckTabBar.swift`

Replaces the system `TabView` tab bar with a custom bottom bar.

### Appearance
- Horizontal brushed metal strip, ~70pt height + safe area inset
- Brushed aluminum surface with horizontal grain
- Thin chrome edge highlight along top edge
- 5 mechanical button wells, evenly spaced

### Buttons

| Position | Icon | Engraved Label | Tab |
|----------|------|---------------|-----|
| 1 | `play.circle` | PLAY | Now Playing |
| 2 | `face.smiling` | MOOD | Mood |
| 3 | `music.note.list` | LIBRARY | Playlists |
| 4 | `chart.bar.xaxis` | DATA | Insights |
| 5 | `gear` | CONFIG | Settings |

Each button is a latching `RetroPushButton`. Active tab's button is pressed-in with a lit `RetroLEDIndicator` (accent color) above it. Inactive buttons sit proud with dark LEDs.

### Transition Animation
- Current screen slides out horizontally (cassette tray eject)
- New screen slides in from opposite side
- Uses `traySlide` spring animation
- `.impact(.medium)` haptic on transition

### Mini Player Integration
When a song is playing and user is not on Now Playing tab, a 48pt slim brushed metal strip appears **above** the tab bar:
- Tiny spinning reel animation (Canvas, 20pt diameter)
- Song title scrolling in monospaced LCD text
- Play/pause + skip as small mechanical buttons
- Accent-colored thin progress line along top edge
- Tapping navigates to Now Playing tab

---

## 4. Mood Tab Redesign

**Concept**: Hi-Fi receiver front panel — "tuning" your mood like tuning a stereo.

### Layout (top to bottom)

**4.1 Mood VU Meter Pair** (replaces mood orb)
- Two side-by-side `RetroVUMeter` in shared recessed panel
- Left: "ENERGY" — needle reflects current energy value
- Right: "VALENCE" — needle reflects current valence
- Needles animate with `needleBounce` physics on value change
- Scale: "LOW" left, "HIGH" right of each arc
- During active journey, needles update in real-time from state engine

**4.2 Current Mood Controls — "YOU ARE HERE"**
- `RetroLCDPanel` header: "CURRENT STATE" in engraved text
- Two `RetroKnob` controls side by side on brushed metal panel:
  - Left: Energy (0-1, 10 detents)
  - Right: Valence (0-1, 10 detents)
- Knob positions drive VU meter needles above
- `RetroLEDIndicator` between knobs showing mood color (warm-to-cool gradient from valence)

**4.3 Target Mood Controls — "DESTINATION"**
- Same layout as Current, labeled "TARGET STATE"
- Two `RetroKnob` controls for target energy/valence
- LCD readout between sections: "DELTA: 0.35" showing distance

**4.4 Preset Buttons**
- `RetroSegmentedSelector` full-width strip
- Segments matching existing presets: CALM | FOCUS | ENERGY | UPBEAT
  - CALM → energy 0.2, valence 0.7
  - FOCUS → energy 0.5, valence 0.6
  - ENERGY → energy 0.85, valence 0.75
  - UPBEAT → energy 0.75, valence 0.9
- Tapping auto-rotates target knobs to preset positions with spring animation
- Active preset gets lit LED

**4.5 Mood Trajectory Suggestion**
- `RetroLCDPanel` with AI suggestion
- Monospaced text: "AI RECOMMENDS: CALM -> FOCUS (12 TRACKS)"
- wand.and.stars icon in accent color

**4.6 Journey Controls**
- No journey: `RetroPushButton` "START JOURNEY", accent LED lit
- Active journey:
  - Tape counter progress (4-digit `0000`-`9999` rolling numbers for %)
  - LED dot bar graph showing position in trajectory
  - `RetroPushButton` "STOP" to end journey

### Container
- `BrushedMetalSurface` with corner screws
- Scrollable vertical layout
- Navigation title as engraved metal plate

---

## 5. Insights Tab Redesign

**Concept**: Oscilloscope / test equipment rack — each insight is a piece of measurement gear.

### Layout (top to bottom)

**5.1 Time Range Selector**
- `RetroSegmentedSelector`: WEEK | MONTH | 3MO | YEAR
- Metal panel with lit LED on active range

**5.2 Header — "SIGNAL ANALYSIS"**
- `RetroLCDPanel` with large monospaced text
- Subtitle: "BIOMETRIC-MUSIC CORRELATIONS"
- Scanning dot animation (radar sweep left-to-right across LCD)

**5.3 Most Resonant Track Card**
- `BrushedMetalSurface` panel with:
  - `MiniCassetteView` (width: 140) for track artwork
  - `RetroLCDPanel`: title, artist, resonance score
  - Small `RetroVUMeter` (80pt) showing resonance score
  - 5 `RetroLEDIndicator` dots for signal strength

**5.4 Insight Cards (restyled charts)**
- Each insight in a metal panel frame with engraved title
- Chart area styled as oscilloscope screen:
  - Background: `panelBg` dark
  - Grid: accent color at 15% opacity
  - Data: accent color with glow effect (blur 4pt shadow)
  - Area fills: accent at 10% opacity
- Existing Swift Charts preserved, restyled with retro tokens
- Below each chart: `RetroLEDIndicator` trend dots (up/down/stable)

**5.5 Best Time Heat Map**
- Grid of `RetroLEDIndicator` dots, brightness = heat value
- Row labels (days) and column labels (hours) in engraved monospaced text
- Recessed panel with inner shadow

**5.6 Metric Cells**
- Each metric as mini instrument:
  - `RetroLCDPanel` (compact) with `ledDigit` value
  - `engraved` label below
  - `RetroLEDIndicator` trend dot (green=up, amber=flat, red=down)

### Container
- `BrushedMetalSurface` with screws
- ScrollView with vertical instrument stack

---

## 6. Settings Tab Redesign

**Concept**: Hardware configuration panel — the back panel of a stereo receiver.

### Main Screen
- `BrushedMetalSurface` with 4 corner screws
- Title: engraved metal plate "CONFIGURATION"
- 5 settings groups as metal sub-panels, each with:
  - 2 small corner screws
  - Engraved section label: BODY | MUSIC | AI | SESSIONS | DATA
  - Embossed pictograph icon
  - `lcdCaption` description text
  - NavigationLink to sub-page

### Sub-Page Control Reskinning

| Standard Control | Retro Replacement |
|-----------------|-------------------|
| `Toggle` | `RetroToggleSwitch` with LED |
| `Slider` | `RetroSliderPot` (horizontal) |
| `Picker` | `RetroSegmentedSelector` |
| `Stepper` | Two `RetroPushButton` (-/+) flanking `RetroLCDPanel` value |
| Section headers | Engraved metal labels with tracking |
| Section footers | `lcdCaption` in recessed LCD strip |

List background: `metalDark` with grain. Separators: thin chrome lines (white 10%).

---

## 7. Landing View Redesign

**Concept**: Power-on boot sequence — turning on vintage equipment.

### Animated Sequence (~3 seconds)

| Time | Event |
|------|-------|
| 0.0s | Black screen |
| 0.3s | Single accent `RetroLEDIndicator` fades on center-screen with glow bloom |
| 0.5s | Accent-colored horizontal scanline sweeps top-to-bottom revealing brushed metal |
| 1.0s | `RetroLCDPanel` shows boot text character-by-character |
| 2.0s | Two small `RetroVUMeter` appear flanking LCD, needles sweep left-right (self-test) |
| 2.5s | `RetroPushButton` "ENGAGE" fades in below with accent LED, spring bounce |

### Boot Text (monospaced, character-by-character)
```
RESONANCE AI DJ SYSTEM
v2.0 ■■■■■■■■ OK
INITIALIZING NEURAL ENGINE...
BIOMETRIC LINK: CONNECTED
LIBRARY SCAN: 1,247 TRACKS
STATUS: READY
```

### On "ENGAGE" Press
- Button depresses with haptic
- LCD: "LOADING SESSION..."
- VU meters: maximum deflection
- Transition to main app via existing `matchedGeometryEffect`

### Accessibility
- `accessibilityReduceMotion`: skip character animation, show full text immediately, reduce sequence to ~0.5s

---

## 8. Onboarding Redesign

**Concept**: Equipment calibration wizard — initial setup of lab equipment.

### Structure
- Each page is a "calibration step" in a `RetroLCDPanel`
- Step indicator: LED dots (e.g., filled/unfilled circles for step 3 of 5)
- Content: monospaced LCD text
- Illustrations: simple line-art schematics (not photographs)
- Navigation: two `RetroPushButton` controls — "BACK" and "NEXT"

### Special Pages
- **Music connection**: `RetroVUMeter` that sweeps when Apple Music connects
- **Health permissions**: `RetroToggleSwitch` per permission, LED turns green on grant
- **Final page**: "CALIBRATION COMPLETE" — all LEDs lit green, VU meters nominal

---

## 9. Queue View Enhancements

### Changes within retro framework
- **Now Playing row**: Add small VU meter pair for live audio levels alongside existing mini cassette
- **AI queue rows**: Confidence indicator becomes `RetroLEDIndicator` bar (5 LEDs, fill count = confidence)
- **AI reasoning**: Slim `RetroLCDPanel` strip with monospaced accent text + scanlines
- **Section headers**: Engraved metal labels
- **List background**: `metalDark` with grain texture
- **Drag handles**: Embossed chrome ridges instead of standard iOS drag indicators

---

## 10. Implementation Phases

### Phase 1: Design System Spine
- `RetroDesignSystem.swift` — all tokens from Section 1
- `RetroTypography.swift` — monospaced scale
- `BrushedMetalModifier.swift` — reusable texture ViewModifier
- `RetroAccentEnvironment.swift` — `@Environment(\.retroAccentColor)` plumbing
- Wire up dynamic accent color propagation from `NowPlayingViewModel`

### Phase 2: Core Components + Mood Tab
- Build `RetroKnob`, `RetroVUMeter`, `RetroSliderPot` (the most complex components)
- Build `RetroLEDIndicator`, `RetroLCDPanel`, `BrushedMetalSurface` (simpler)
- Redesign MoodTabView using these components
- Components validated in real layout immediately

### Phase 3: Remaining Components + Screens
- Build `RetroToggleSwitch`, `RetroPushButton`, `RetroSegmentedSelector`
- Redesign InsightsView (oscilloscope charts, LED heat map)
- Redesign SettingsView (hardware config panel + sub-page reskinning)
- Redesign LandingView (boot sequence)
- Redesign OnboardingContainerView (calibration wizard)
- Enhance QueueView (LED confidence, LCD reasoning)

### Phase 4: Tab Bar + Transitions + Polish
- Build `CassetteDeckTabBar` (custom tab bar replacing system TabView)
- Redesign `MiniPlayerView` (mini cassette in control strip)
- Implement tray-slide screen transitions
- Tune haptic feedback across all interactions
- Dead code cleanup (remove old standard controls, unused views)
- Performance profiling (ensure Canvas/animation-heavy views maintain 60fps)

---

## 11. Files Created/Modified

### New Files
```
iOS/Views/Components/RetroControls/
  RetroKnob.swift
  RetroSliderPot.swift
  RetroVUMeter.swift
  RetroToggleSwitch.swift
  RetroPushButton.swift
  RetroLEDIndicator.swift
  RetroLCDPanel.swift
  RetroSegmentedSelector.swift
  BrushedMetalSurface.swift

iOS/Utilities/RetroDesignSystem.swift
iOS/Utilities/RetroTypography.swift
iOS/Utilities/BrushedMetalModifier.swift
iOS/Utilities/RetroAccentEnvironment.swift

iOS/Views/Components/CassetteDeckTabBar.swift
```

### Modified Files
```
iOS/Views/MoodTabView.swift          — full redesign
iOS/Views/InsightsView.swift         — full redesign
iOS/Views/SettingsView.swift         — full redesign
iOS/Views/LandingView.swift          — full redesign
iOS/Views/MainView.swift             — replace TabView with CassetteDeckTabBar
iOS/Views/QueueView.swift            — retro enhancements
iOS/Views/Components/MiniPlayerView.swift — cassette-style redesign
iOS/Views/Onboarding/OnboardingContainerView.swift — calibration wizard
iOS/Views/Onboarding/OnboardingPageViews.swift     — retro restyling
iOS/Views/Onboarding/OnboardingMusicConnectionPage.swift — VU meter
iOS/Views/Onboarding/OnboardingFirstPlayPage.swift — retro restyling
iOS/Views/BodySettingsView.swift     — retro control reskinning
iOS/Views/MusicSettingsView.swift    — retro control reskinning
iOS/Views/AISettingsView.swift       — retro control reskinning
iOS/Views/SessionSettingsView.swift  — retro control reskinning
iOS/Views/DataSettingsView.swift     — retro control reskinning
Shared/Utilities/ResonanceColors.swift — add LED colors, metal palette
iOS/Utilities/ColorTheme.swift       — add retro surface colors
```

### Preserved (No Changes)
```
iOS/Views/NowPlayingView.swift                   — already Walkman-styled
iOS/Views/PlaylistBrowserView.swift              — already cassette grid
iOS/Views/PlaylistDetailView.swift               — already 3D carousel
iOS/Views/Components/CassettePlayerView.swift    — already complete
iOS/Views/Components/WalkmanControlsView.swift   — already complete
iOS/Views/Components/MiniCassetteView.swift      — already complete
```

---

## 12. Performance Considerations

- `RetroVUMeter` needle animation uses Canvas (GPU composited) — same pattern as CassettePlayerView reel animation
- `RetroKnob` rotation uses Canvas — avoid GeometryReader in gesture handlers
- Tab bar transition uses `matchedGeometryEffect` or `.transition(.move)` — no GeometryReader
- Brushed metal textures are static (no per-frame recomputation)
- Scanline overlays are a fixed texture, not per-frame generated
- LED glow uses `.shadow()` modifier — GPU composited, no performance concern
- LazyVStack/LazyVGrid preserved in scrolling views for cell recycling
- `accessibilityReduceMotion` respected throughout — animations simplified or removed
- Target: 60fps on iPhone 12 and later

---

## 13. Accessibility

- All retro controls expose proper accessibility traits and values
- `RetroKnob`: `.adjustable` trait, increment/decrement via accessibility actions
- `RetroToggleSwitch`: standard toggle accessibility
- `RetroVUMeter`: `.updatesFrequently` trait, current value as percentage
- `RetroLCDPanel`: content is accessible as combined text
- `RetroSegmentedSelector`: standard picker accessibility
- Boot sequence animation respects `accessibilityReduceMotion`
- All engraved/monospaced text meets minimum contrast ratios (WCAG AA)
- Haptics complement but never replace visual feedback
