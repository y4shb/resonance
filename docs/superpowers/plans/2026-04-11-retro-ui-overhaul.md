# Retro-Tech UI Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform every Resonance screen into a cohesive 1980s Walkman/Hi-Fi retro-tech universe with skeuomorphic controls, dynamic accent colors, and a custom cassette-deck tab bar.

**Architecture:** Design system spine (tokens + environment) built first, then 9 reusable retro components, then screen redesigns in parallel using those components. The existing Walkman cassette player, playlist grid, and playlist detail carousel are preserved untouched.

**Tech Stack:** SwiftUI, Canvas (GPU-composited drawing), MusicKit, Spring animations, RotationGesture/DragGesture, sensoryFeedback haptics, @Environment for dynamic accent color propagation.

**Spec:** `docs/superpowers/specs/2026-04-11-retro-ui-overhaul-design.md`

---

## File Map

### New Files (14)

| File | Responsibility |
|------|---------------|
| `iOS/Utilities/RetroDesignSystem.swift` | All retro color tokens, animation springs, haptic definitions |
| `iOS/Utilities/RetroTypography.swift` | Monospaced font scale (lcdTitle, lcdBody, lcdCaption, engraved, ledDigit) |
| `iOS/Utilities/BrushedMetalModifier.swift` | ViewModifier for brushed metal surface texture |
| `iOS/Utilities/RetroAccentEnvironment.swift` | `@Environment(\.retroAccentColor)` key + propagation |
| `iOS/Views/Components/RetroControls/RetroLEDIndicator.swift` | LED dot with glow, on/off/blink states |
| `iOS/Views/Components/RetroControls/RetroLCDPanel.swift` | Recessed LCD display with scanlines |
| `iOS/Views/Components/RetroControls/BrushedMetalSurface.swift` | Container with metal gradient + optional screws |
| `iOS/Views/Components/RetroControls/RetroVUMeter.swift` | Analog needle gauge with spring physics |
| `iOS/Views/Components/RetroControls/RetroKnob.swift` | Rotary control with RotationGesture + detents |
| `iOS/Views/Components/RetroControls/RetroSliderPot.swift` | Linear fader with DragGesture |
| `iOS/Views/Components/RetroControls/RetroToggleSwitch.swift` | 3D rocker switch with adjacent LED |
| `iOS/Views/Components/RetroControls/RetroPushButton.swift` | Momentary/latching button with press depth |
| `iOS/Views/Components/RetroControls/RetroSegmentedSelector.swift` | Metal segment strip with LED indicators |
| `iOS/Views/Components/CassetteDeckTabBar.swift` | Custom tab bar replacing system TabView |

### Modified Files (18)

| File | Change |
|------|--------|
| `Shared/Utilities/ResonanceColors.swift` | Add LED colors + metal palette tokens |
| `iOS/Utilities/ColorTheme.swift` | Add retro surface color helpers |
| `iOS/Views/MainView.swift` | Replace TabView with CassetteDeckTabBar |
| `iOS/Views/MoodTabView.swift` | Full redesign — VU meters, knobs, presets |
| `iOS/Views/InsightsView.swift` | Full redesign — oscilloscope charts, LED heat map |
| `iOS/Views/SettingsView.swift` | Hardware config panel with metal sub-panels |
| `iOS/Views/LandingView.swift` | Power-on boot sequence |
| `iOS/Views/QueueView.swift` | LED confidence bars, LCD reasoning strips |
| `iOS/Views/Components/MiniPlayerView.swift` | Cassette-style mini strip |
| `iOS/Views/BodySettingsView.swift` | Retro control reskinning |
| `iOS/Views/MusicSettingsView.swift` | Retro control reskinning |
| `iOS/Views/AISettingsView.swift` | Retro control reskinning |
| `iOS/Views/SessionSettingsView.swift` | Retro control reskinning |
| `iOS/Views/DataSettingsView.swift` | Retro control reskinning |
| `iOS/Views/Onboarding/OnboardingContainerView.swift` | Calibration wizard chrome |
| `iOS/Views/Onboarding/OnboardingPageViews.swift` | Retro restyling |
| `iOS/Views/Onboarding/OnboardingMusicConnectionPage.swift` | VU meter sweep |
| `iOS/Views/Onboarding/OnboardingFirstPlayPage.swift` | Retro restyling |

---

## Phase 1: Design System Spine

### Task 1: Retro Color Tokens

**Files:**
- Modify: `Shared/Utilities/ResonanceColors.swift`
- Modify: `iOS/Utilities/ColorTheme.swift`

- [ ] **Step 1: Add LED and metal color tokens to ResonanceColors**

Open `Shared/Utilities/ResonanceColors.swift`. Add these static properties inside the `ResonanceColors` enum, after the existing `accentSubtle` property:

```swift
// MARK: - LED Colors

/// Warm amber LED for pause state, warning indicators.
static let ledAmber = Color(red: 1.0, green: 0.702, blue: 0.278) // #FFB347

/// Green LED for active/on state, signal present.
static let ledGreen = Color(red: 0.290, green: 0.871, blue: 0.502) // #4ADE80

/// Red LED for peak/clip indicators, errors.
static let ledRed = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444

// MARK: - Metal Surface Colors

/// Brushed aluminum highlight.
static let metalLight = Color(red: 0.753, green: 0.753, blue: 0.784) // #C0C0C8

/// Metal surface mid-tone.
static let metalMid = Color(red: 0.541, green: 0.541, blue: 0.580) // #8A8A94

/// Panel recesses, button wells.
static let metalDark = Color(red: 0.227, green: 0.227, blue: 0.259) // #3A3A42

/// Corner screws, bezels.
static let screwChrome = Color(red: 0.831, green: 0.831, blue: 0.863) // #D4D4DC

/// Recessed panel interiors.
static let panelBg = Color(red: 0.102, green: 0.102, blue: 0.133) // #1A1A22

/// Horizontal grain texture overlay on metal surfaces.
static let grainOverlay = Color.white.opacity(0.03)
```

- [ ] **Step 2: Add retro surface helpers to ColorTheme**

Open `iOS/Utilities/ColorTheme.swift`. Add this section at the end of the `ResonanceColors` extension, after the `darkModeAdjusted` function:

```swift
// MARK: - Retro Surface Colors

/// Accent color at 60% saturation for dark mode desaturated variant.
static func accentMuted(_ accent: Color) -> Color {
    adjustSaturation(accent, by: -0.4)
}

/// Accent at 80% opacity for LCD backlight tint.
static func phosphorBlue(_ accent: Color) -> Color {
    accent.opacity(0.8)
}
```

- [ ] **Step 3: Verify build**

Open Xcode and build the project (Cmd+B). Confirm no errors in `ResonanceColors.swift` or `ColorTheme.swift`.

- [ ] **Step 4: Commit**

```bash
git add Shared/Utilities/ResonanceColors.swift iOS/Utilities/ColorTheme.swift
git commit -m "feat(design-system): add retro LED colors and metal surface tokens"
```

---

### Task 2: Retro Typography Scale

**Files:**
- Create: `iOS/Utilities/RetroTypography.swift`

- [ ] **Step 1: Create RetroTypography**

```swift
//
//  RetroTypography.swift
//  Resonance
//
//  Monospaced font scale for retro-tech UI elements.
//  All retro text uses monospaced design. System fonts preserved
//  for accessibility-critical text (error messages, long descriptions).
//

import SwiftUI

// MARK: - Retro Typography

enum RetroTypography {
    /// Screen titles in LCD panels. 14pt semibold monospaced.
    static let lcdTitle: Font = .system(size: 14, weight: .semibold, design: .monospaced)

    /// Readout values, counters. 11pt medium monospaced.
    static let lcdBody: Font = .system(size: 11, weight: .medium, design: .monospaced)

    /// Labels, secondary info. 9pt regular monospaced.
    static let lcdCaption: Font = .system(size: 9, weight: .regular, design: .monospaced)

    /// Embossed panel labels. 8pt heavy monospaced with wide tracking.
    static let engraved: Font = .system(size: 8, weight: .heavy, design: .monospaced)

    /// Tracking value for engraved text (3pt).
    static let engravedTracking: CGFloat = 3

    /// Large numeric readouts. 16pt bold monospaced.
    static let ledDigit: Font = .system(size: 16, weight: .bold, design: .monospaced)
}

// MARK: - View Extension

extension View {
    /// Applies engraved label styling: heavy monospaced with wide tracking, secondary foreground.
    func retroEngravedLabel() -> some View {
        self
            .font(RetroTypography.engraved)
            .tracking(RetroTypography.engravedTracking)
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 2: Verify build**

Build in Xcode. Confirm `RetroTypography` compiles.

- [ ] **Step 3: Commit**

```bash
git add iOS/Utilities/RetroTypography.swift
git commit -m "feat(design-system): add retro typography scale"
```

---

### Task 3: Retro Design System (Animation + Haptics)

**Files:**
- Create: `iOS/Utilities/RetroDesignSystem.swift`

- [ ] **Step 1: Create RetroDesignSystem**

```swift
//
//  RetroDesignSystem.swift
//  Resonance
//
//  Shared animation constants and haptic patterns for retro-tech controls.
//  Every retro component references these values for consistent feel.
//

import SwiftUI

// MARK: - Retro Animations

enum RetroAnimation {
    /// VU meter needle overshoot-then-settle.
    static let needleBounce = Spring(response: 0.4, dampingFraction: 0.5)

    /// Rotary knob snap to detent.
    static let knobRotation = Spring(response: 0.2, dampingFraction: 0.8)

    /// Toggle switch throw.
    static let switchFlip = Spring(response: 0.15, dampingFraction: 0.7)

    /// Push button press/release travel.
    static let buttonPress = Spring(response: 0.1, dampingFraction: 0.6)

    /// Screen transition (cassette tray slide).
    static let traySlide = Spring(response: 0.35, dampingFraction: 0.85)

    /// LED on/off state change.
    static let ledFade = Animation.easeInOut(duration: 0.3)
}

// MARK: - Retro Dimensions

enum RetroDimensions {
    /// Standard button press depth in points.
    static let buttonPressDepth: CGFloat = 3

    /// Button proud height above surface.
    static let buttonProudHeight: CGFloat = 4

    /// Rocker switch rotation angle in degrees.
    static let switchRotationAngle: Double = 15

    /// Standard corner screw diameter.
    static let screwDiameter: CGFloat = 6

    /// Standard LED indicator diameter.
    static let ledDefaultSize: CGFloat = 8
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Utilities/RetroDesignSystem.swift
git commit -m "feat(design-system): add retro animation constants and dimensions"
```

---

### Task 4: Dynamic Accent Color Environment

**Files:**
- Create: `iOS/Utilities/RetroAccentEnvironment.swift`

- [ ] **Step 1: Create the environment key and propagation**

```swift
//
//  RetroAccentEnvironment.swift
//  Resonance
//
//  Custom SwiftUI environment key that propagates the dynamic accent color
//  (extracted from the current song's album artwork) to every view in the
//  hierarchy. Falls back to ResonanceColors.accent when no song is playing.
//

import SwiftUI

// MARK: - Environment Key

private struct RetroAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = ResonanceColors.accent
}

extension EnvironmentValues {
    /// The current retro accent color, derived from album artwork.
    /// Falls back to `ResonanceColors.accent` (periwinkle #5A8CFF).
    var retroAccentColor: Color {
        get { self[RetroAccentColorKey.self] }
        set { self[RetroAccentColorKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Injects the dynamic retro accent color into the environment.
    /// Call this at the root view (MainView) to propagate to all children.
    func retroAccentColor(_ color: Color?) -> some View {
        environment(\.retroAccentColor, color ?? ResonanceColors.accent)
    }
}
```

- [ ] **Step 2: Wire up accent color propagation in MainView**

Open `iOS/Views/MainView.swift`. Add the `.retroAccentColor` modifier to the root `TabView` so every child view inherits it.

Find this line at the end of the `TabView` block:
```swift
.tint(ResonanceColors.accent)
```

Add this modifier immediately before `.tint(...)`:
```swift
.retroAccentColor(nowPlayingViewModel.artworkAccentColor)
```

The result should read:
```swift
.retroAccentColor(nowPlayingViewModel.artworkAccentColor)
.tint(ResonanceColors.accent)
```

- [ ] **Step 3: Verify build**

Build in Xcode.

- [ ] **Step 4: Commit**

```bash
git add iOS/Utilities/RetroAccentEnvironment.swift iOS/Views/MainView.swift
git commit -m "feat(design-system): add dynamic retro accent color environment key"
```

---

### Task 5: Brushed Metal ViewModifier

**Files:**
- Create: `iOS/Utilities/BrushedMetalModifier.swift`

- [ ] **Step 1: Create BrushedMetalModifier**

```swift
//
//  BrushedMetalModifier.swift
//  Resonance
//
//  ViewModifier that applies a brushed aluminum surface texture to any view.
//  5-stop horizontal gradient with 2% white grain lines and chrome edge highlights.
//

import SwiftUI

// MARK: - Brushed Metal Modifier

struct BrushedMetalModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                ResonanceColors.metalLight,
                                ResonanceColors.metalMid,
                                ResonanceColors.metalLight.opacity(0.9),
                                ResonanceColors.metalMid,
                                ResonanceColors.metalLight.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        // Grain texture: thin horizontal lines
                        grainOverlay
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    )
                    .overlay(
                        // Chrome edge highlights
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.08),
                                        Color.clear,
                                        Color.black.opacity(0.15)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }

    /// Horizontal grain lines at 1pt intervals.
    private var grainOverlay: some View {
        Canvas { context, size in
            let lineCount = Int(size.height / 2)
            for i in 0..<lineCount {
                let y = CGFloat(i) * 2
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.white.opacity(0.02)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies brushed metal surface texture to the view.
    func brushedMetal(cornerRadius: CGFloat = 12) -> some View {
        modifier(BrushedMetalModifier(cornerRadius: cornerRadius))
    }
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Utilities/BrushedMetalModifier.swift
git commit -m "feat(design-system): add brushed metal surface ViewModifier"
```

---

## Phase 2: Core Components

### Task 6: RetroLEDIndicator

**Files:**
- Create: `iOS/Views/Components/RetroControls/RetroLEDIndicator.swift`

- [ ] **Step 1: Create the RetroControls directory**

```bash
mkdir -p iOS/Views/Components/RetroControls
```

- [ ] **Step 2: Create RetroLEDIndicator**

```swift
//
//  RetroLEDIndicator.swift
//  Resonance
//
//  Small LED dot with colored fill and soft glow bloom.
//  Recessed into panel with inner ring shadow.
//  Supports OFF, ON, and BLINK states.
//

import SwiftUI

// MARK: - Retro LED Indicator

struct RetroLEDIndicator: View {
    let isOn: Bool
    var color: Color = ResonanceColors.ledGreen
    var size: CGFloat = RetroDimensions.ledDefaultSize
    var blinkRate: Double? = nil

    @State private var blinkVisible = true

    private var effectivelyOn: Bool {
        isOn && blinkVisible
    }

    var body: some View {
        ZStack {
            // Recessed well
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: size + 2, height: size + 2)

            // LED lens
            Circle()
                .fill(effectivelyOn ? color : ResonanceColors.metalDark)
                .frame(width: size, height: size)

            // Glow bloom when on
            if effectivelyOn {
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: size, height: size)
                    .blur(radius: size * 0.6)
            }
        }
        .animation(RetroAnimation.ledFade, value: effectivelyOn)
        .onAppear { startBlinkIfNeeded() }
        .onChange(of: blinkRate) { startBlinkIfNeeded() }
        .accessibilityHidden(true)
    }

    private func startBlinkIfNeeded() {
        guard let rate = blinkRate, rate > 0 else {
            blinkVisible = true
            return
        }
        let interval = 1.0 / (rate * 2)
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            blinkVisible.toggle()
        }
    }
}

// MARK: - Preview

#Preview("LED States") {
    HStack(spacing: 20) {
        RetroLEDIndicator(isOn: false, color: .green)
        RetroLEDIndicator(isOn: true, color: ResonanceColors.ledGreen)
        RetroLEDIndicator(isOn: true, color: ResonanceColors.ledAmber)
        RetroLEDIndicator(isOn: true, color: ResonanceColors.ledRed)
        RetroLEDIndicator(isOn: true, color: .blue, blinkRate: 2)
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
```

- [ ] **Step 3: Verify build**

Build in Xcode.

- [ ] **Step 4: Commit**

```bash
git add iOS/Views/Components/RetroControls/RetroLEDIndicator.swift
git commit -m "feat(components): add RetroLEDIndicator with on/off/blink states"
```

---

### Task 7: RetroLCDPanel

**Files:**
- Create: `iOS/Views/Components/RetroControls/RetroLCDPanel.swift`

- [ ] **Step 1: Create RetroLCDPanel**

```swift
//
//  RetroLCDPanel.swift
//  Resonance
//
//  Recessed rectangular display panel with dark blue-black interior,
//  monospaced accent-tinted content, and horizontal scanline texture.
//

import SwiftUI

// MARK: - Retro LCD Panel

struct RetroLCDPanel<Content: View>: View {
    let content: () -> Content
    var title: String? = nil
    var width: CGFloat? = nil

    @Environment(\.retroAccentColor) private var accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .retroEngravedLabel()
            }

            ZStack {
                // Recessed panel background
                RoundedRectangle(cornerRadius: 4)
                    .fill(ResonanceColors.panelBg)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.black.opacity(0.4), lineWidth: 1)
                    )

                // Content with accent tint
                content()
                    .foregroundStyle(ResonanceColors.phosphorBlue(accentColor))

                // Scanline overlay
                scanlineOverlay
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .allowsHitTesting(false)
            }
            .frame(width: width)
        }
    }

    /// Horizontal scanline texture: 1px lines at 50% opacity, 2px apart.
    private var scanlineOverlay: some View {
        Canvas { context, size in
            let lineCount = Int(size.height / 2)
            for i in 0..<lineCount {
                let y = CGFloat(i) * 2
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.black.opacity(0.50)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Preview

#Preview("LCD Panel") {
    VStack(spacing: 20) {
        RetroLCDPanel(title: "CURRENT STATE") {
            Text("ENERGY: 0.72")
                .font(RetroTypography.lcdBody)
                .padding(12)
        }

        RetroLCDPanel {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI RECOMMENDS:")
                    .font(RetroTypography.lcdCaption)
                Text("CALM -> FOCUS (12 TRACKS)")
                    .font(RetroTypography.lcdTitle)
            }
            .padding(12)
        }
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Views/Components/RetroControls/RetroLCDPanel.swift
git commit -m "feat(components): add RetroLCDPanel with scanline overlay"
```

---

### Task 8: BrushedMetalSurface

**Files:**
- Create: `iOS/Views/Components/RetroControls/BrushedMetalSurface.swift`

- [ ] **Step 1: Create BrushedMetalSurface**

```swift
//
//  BrushedMetalSurface.swift
//  Resonance
//
//  Container view with brushed aluminum texture, chrome edge highlights,
//  and optional corner screws. Used as the outer frame for every retro panel.
//

import SwiftUI

// MARK: - Brushed Metal Surface

struct BrushedMetalSurface<Content: View>: View {
    var cornerRadius: CGFloat = 12
    var showScrews: Bool = false
    let content: () -> Content

    var body: some View {
        ZStack {
            content()
        }
        .brushedMetal(cornerRadius: cornerRadius)
        .overlay {
            if showScrews {
                screwCorners
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
    }

    /// Chrome screw details at each corner.
    private var screwCorners: some View {
        GeometryReader { geo in
            let inset: CGFloat = 10
            let size = RetroDimensions.screwDiameter
            ForEach(0..<4, id: \.self) { corner in
                let x = corner % 2 == 0 ? inset : geo.size.width - inset
                let y = corner < 2 ? inset : geo.size.height - inset
                screwView(size: size)
                    .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
    }

    private func screwView(size: CGFloat) -> some View {
        ZStack {
            // Screw body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ResonanceColors.screwChrome, ResonanceColors.metalMid],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)

            // Cross slot
            Rectangle()
                .fill(ResonanceColors.metalDark)
                .frame(width: size * 0.6, height: 0.5)

            Rectangle()
                .fill(ResonanceColors.metalDark)
                .frame(width: 0.5, height: size * 0.6)
        }
    }
}

// MARK: - Preview

#Preview("Metal Surface") {
    BrushedMetalSurface(showScrews: true) {
        VStack {
            Text("CONFIGURATION")
                .retroEngravedLabel()
            Spacer()
        }
        .padding(20)
        .frame(width: 300, height: 200)
    }
    .padding(40)
    .background(Color.black)
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Views/Components/RetroControls/BrushedMetalSurface.swift
git commit -m "feat(components): add BrushedMetalSurface container with screws"
```

---

### Task 9: RetroVUMeter

**Files:**
- Create: `iOS/Views/Components/RetroControls/RetroVUMeter.swift`

- [ ] **Step 1: Create RetroVUMeter**

```swift
//
//  RetroVUMeter.swift
//  Resonance
//
//  Semi-circular analog needle gauge with spring physics.
//  Canvas-drawn meter face with green/yellow/red zones and accent-colored needle.
//  Same GPU-composited Canvas pattern as CassettePlayerView reel animation.
//

import SwiftUI

// MARK: - Retro VU Meter

struct RetroVUMeter: View {
    let value: Double  // 0.0 to 1.0
    var label: String = "VU"
    var showPeakHold: Bool = false
    var size: CGFloat = 160

    @Environment(\.retroAccentColor) private var accentColor
    @State private var animatedValue: Double = 0
    @State private var peakValue: Double = 0
    @State private var peakDecayTimer: Timer?

    private let startAngle: Double = -135  // degrees from 12 o'clock
    private let endAngle: Double = -45
    private let meterHeight: CGFloat = 0.6  // height as fraction of width

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.85)
                let radius = min(canvasSize.width, canvasSize.height) * 0.7

                // Draw meter face (recessed panel)
                drawMeterFace(context: context, center: center, radius: radius, size: canvasSize)

                // Draw scale markings and zones
                drawScaleMarkings(context: context, center: center, radius: radius)

                // Draw needle
                let needleAngle = startAngle + (endAngle - startAngle) * animatedValue
                drawNeedle(context: context, center: center, radius: radius, angle: needleAngle)

                // Draw peak hold line
                if showPeakHold && peakValue > 0 {
                    let peakAngle = startAngle + (endAngle - startAngle) * peakValue
                    drawPeakHold(context: context, center: center, radius: radius, angle: peakAngle)
                }

                // Draw pivot pin
                drawPivot(context: context, center: center)

                // Draw "VU" label
                drawLabel(context: context, center: center, radius: radius)
            }
            .frame(width: size, height: size * meterHeight)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(ResonanceColors.panelBg)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.black.opacity(0.4), lineWidth: 1)
                    )
            )

            Text(label)
                .retroEngravedLabel()
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(RetroAnimation.needleBounce)) {
                animatedValue = max(0, min(1, newValue))
            }
            updatePeakHold(newValue)
        }
        .onAppear {
            animatedValue = max(0, min(1, value))
        }
        .accessibilityElement()
        .accessibilityLabel("\(label) meter")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Drawing Methods

    private func drawMeterFace(context: GraphicsContext, center: CGPoint, radius: CGFloat, size: CGSize) {
        // White face arc background
        let facePath = Path { p in
            p.addArc(center: center, radius: radius * 0.95,
                     startAngle: .degrees(startAngle - 90), endAngle: .degrees(endAngle - 90),
                     clockwise: false)
            p.addLine(to: center)
            p.closeSubpath()
        }
        context.fill(facePath, with: .color(.white.opacity(0.08)))
    }

    private func drawScaleMarkings(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let tickCount = 11
        for i in 0..<tickCount {
            let fraction = Double(i) / Double(tickCount - 1)
            let angle = Angle.degrees(startAngle + (endAngle - startAngle) * fraction - 90)

            let innerRadius = radius * 0.75
            let outerRadius = radius * 0.9

            let innerPoint = CGPoint(
                x: center.x + innerRadius * cos(angle.radians),
                y: center.y + innerRadius * sin(angle.radians)
            )
            let outerPoint = CGPoint(
                x: center.x + outerRadius * cos(angle.radians),
                y: center.y + outerRadius * sin(angle.radians)
            )

            // Color zones: green (0-0.6), yellow (0.6-0.8), red (0.8-1.0)
            let tickColor: Color
            if fraction < 0.6 {
                tickColor = ResonanceColors.ledGreen.opacity(0.6)
            } else if fraction < 0.8 {
                tickColor = ResonanceColors.ledAmber.opacity(0.6)
            } else {
                tickColor = ResonanceColors.ledRed.opacity(0.6)
            }

            var tickPath = Path()
            tickPath.move(to: innerPoint)
            tickPath.addLine(to: outerPoint)
            context.stroke(tickPath, with: .color(tickColor), lineWidth: i % 5 == 0 ? 2 : 1)
        }
    }

    private func drawNeedle(context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double) {
        let needleAngle = Angle.degrees(angle - 90)
        let needleLength = radius * 0.85
        let tip = CGPoint(
            x: center.x + needleLength * cos(needleAngle.radians),
            y: center.y + needleLength * sin(needleAngle.radians)
        )

        var needlePath = Path()
        needlePath.move(to: center)
        needlePath.addLine(to: tip)
        context.stroke(needlePath, with: .color(accentColor), lineWidth: 1.5)
    }

    private func drawPeakHold(context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double) {
        let peakAngle = Angle.degrees(angle - 90)
        let innerR = radius * 0.7
        let outerR = radius * 0.85
        let innerPt = CGPoint(
            x: center.x + innerR * cos(peakAngle.radians),
            y: center.y + innerR * sin(peakAngle.radians)
        )
        let outerPt = CGPoint(
            x: center.x + outerR * cos(peakAngle.radians),
            y: center.y + outerR * sin(peakAngle.radians)
        )

        var peakPath = Path()
        peakPath.move(to: innerPt)
        peakPath.addLine(to: outerPt)
        context.stroke(peakPath, with: .color(accentColor.opacity(0.5)), lineWidth: 1)
    }

    private func drawPivot(context: GraphicsContext, center: CGPoint) {
        let pivotPath = Path(ellipseIn: CGRect(
            x: center.x - 3, y: center.y - 3, width: 6, height: 6
        ))
        context.fill(pivotPath, with: .color(ResonanceColors.screwChrome))
    }

    private func drawLabel(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let labelText = Text(label)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.3))
        context.draw(labelText, at: CGPoint(x: center.x, y: center.y - radius * 0.3))
    }

    // MARK: - Peak Hold

    private func updatePeakHold(_ newValue: Double) {
        guard showPeakHold else { return }
        let clamped = max(0, min(1, newValue))
        if clamped > peakValue {
            peakValue = clamped
            peakDecayTimer?.invalidate()
            peakDecayTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                withAnimation(.easeOut(duration: 0.5)) {
                    peakValue = 0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("VU Meter") {
    HStack(spacing: 20) {
        RetroVUMeter(value: 0.3, label: "ENERGY", size: 140)
        RetroVUMeter(value: 0.7, label: "VALENCE", showPeakHold: true, size: 140)
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Views/Components/RetroControls/RetroVUMeter.swift
git commit -m "feat(components): add RetroVUMeter with Canvas drawing and spring physics"
```

---

### Task 10: RetroKnob

**Files:**
- Create: `iOS/Views/Components/RetroControls/RetroKnob.swift`

- [ ] **Step 1: Create RetroKnob**

```swift
//
//  RetroKnob.swift
//  Resonance
//
//  3D cylindrical rotary control with RotationGesture.
//  Canvas-drawn knob body with radial gradient for 3D cylinder illusion.
//  Spring snaps to configurable detent positions with haptic feedback.
//

import SwiftUI

// MARK: - Retro Knob

struct RetroKnob: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var detents: Int? = nil
    var label: String = ""
    var size: CGFloat = 60

    @Environment(\.retroAccentColor) private var accentColor
    @State private var rotationAngle: Angle = .zero
    @State private var lastDetentIndex: Int = -1
    @State private var hapticTrigger = 0

    /// Maps value to rotation: 0.0 = -135deg, 1.0 = 135deg (270deg sweep)
    private let sweepDegrees: Double = 270
    private let startDegrees: Double = -135

    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var currentAngleDegrees: Double {
        startDegrees + normalizedValue * sweepDegrees
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Recess well
                Circle()
                    .fill(ResonanceColors.panelBg)
                    .frame(width: size + 8, height: size + 8)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

                // Detent markers around the recess
                detentMarkers

                // Knob body
                knobBody

                // Pointer line
                pointerLine
            }
            .frame(width: size + 16, height: size + 16)
            .gesture(dragRotation)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: hapticTrigger)

            if !label.isEmpty {
                Text(label)
                    .retroEngravedLabel()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(label.isEmpty ? "Rotary control" : label)
        .accessibilityValue(String(format: "%.0f percent", normalizedValue * 100))
        .accessibilityAdjustableAction { direction in
            let step = 1.0 / Double(detents ?? 10)
            switch direction {
            case .increment: value = min(range.upperBound, value + step * (range.upperBound - range.lowerBound))
            case .decrement: value = max(range.lowerBound, value - step * (range.upperBound - range.lowerBound))
            @unknown default: break
            }
        }
    }

    // MARK: - Knob Body (Canvas)

    private var knobBody: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2

            // 3D cylinder illusion via radial gradient
            let knobPath = Path(ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))

            context.fill(knobPath, with: .radialGradient(
                Gradient(colors: [
                    ResonanceColors.metalLight,
                    ResonanceColors.metalMid,
                    ResonanceColors.metalDark
                ]),
                center: CGPoint(x: center.x - radius * 0.2, y: center.y - radius * 0.2),
                startRadius: 0,
                endRadius: radius
            ))

            // Highlight ring
            context.stroke(knobPath, with: .color(accentColor.opacity(0.3)), lineWidth: 1.5)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Pointer Line

    private var pointerLine: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: size * 0.35)
            .offset(y: -size * 0.15)
            .rotationEffect(.degrees(currentAngleDegrees))
    }

    // MARK: - Detent Markers

    private var detentMarkers: some View {
        ForEach(0..<(detents ?? 10) + 1, id: \.self) { i in
            let fraction = Double(i) / Double(detents ?? 10)
            let angle = startDegrees + fraction * sweepDegrees
            let markerRadius = (size + 8) / 2 + 4

            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 2, height: 2)
                .offset(y: -markerRadius)
                .rotationEffect(.degrees(angle))
        }
    }

    // MARK: - Drag Gesture (maps vertical drag to rotation)

    private var dragRotation: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gestureValue in
                // Vertical drag: up = increase, down = decrease
                let delta = -gestureValue.translation.height / 200
                let newNormalized = max(0, min(1, normalizedValue + delta))
                let newValue = range.lowerBound + newNormalized * (range.upperBound - range.lowerBound)

                if let detentCount = detents {
                    // Snap to nearest detent
                    let step = (range.upperBound - range.lowerBound) / Double(detentCount)
                    let snapped = (newValue / step).rounded() * step
                    let detentIndex = Int((snapped - range.lowerBound) / step)

                    if detentIndex != lastDetentIndex {
                        lastDetentIndex = detentIndex
                        hapticTrigger += 1
                    }

                    withAnimation(.spring(RetroAnimation.knobRotation)) {
                        value = max(range.lowerBound, min(range.upperBound, snapped))
                    }
                } else {
                    value = max(range.lowerBound, min(range.upperBound, newValue))
                }
            }
    }
}

// MARK: - Preview

#Preview("Knobs") {
    @Previewable @State var energy = 0.5
    @Previewable @State var valence = 0.7

    HStack(spacing: 30) {
        RetroKnob(value: $energy, detents: 10, label: "ENERGY")
        RetroKnob(value: $valence, detents: 10, label: "VALENCE")
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Views/Components/RetroControls/RetroKnob.swift
git commit -m "feat(components): add RetroKnob with RotationGesture and detent haptics"
```

---

### Task 11: RetroSliderPot

**Files:**
- Create: `iOS/Views/Components/RetroControls/RetroSliderPot.swift`

- [ ] **Step 1: Create RetroSliderPot**

```swift
//
//  RetroSliderPot.swift
//  Resonance
//
//  Linear fader control with DragGesture. Metallic fader cap slides
//  along a recessed slot with scale markings and inner shadow.
//

import SwiftUI

// MARK: - Retro Slider Pot

struct RetroSliderPot: View {
    @Binding var value: Double  // 0.0 to 1.0
    var orientation: Axis = .vertical
    var label: String = ""
    var showScale: Bool = true
    var length: CGFloat = 140

    @State private var hapticTrigger = 0
    private let slotWidth: CGFloat = 6
    private let capSize: CGSize = CGSize(width: 20, height: 12)

    var body: some View {
        VStack(spacing: 6) {
            if orientation == .vertical {
                verticalSlider
            } else {
                horizontalSlider
            }

            if !label.isEmpty {
                Text(label)
                    .retroEngravedLabel()
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.6), trigger: hapticTrigger)
        .accessibilityElement()
        .accessibilityLabel(label.isEmpty ? "Slider" : label)
        .accessibilityValue(String(format: "%.0f percent", value * 100))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.1)
            case .decrement: value = max(0, value - 0.1)
            @unknown default: break
            }
        }
    }

    // MARK: - Vertical Layout

    private var verticalSlider: some View {
        HStack(spacing: 6) {
            if showScale { scaleMarks(vertical: true) }

            ZStack(alignment: .bottom) {
                // Slot
                RoundedRectangle(cornerRadius: slotWidth / 2)
                    .fill(ResonanceColors.panelBg)
                    .frame(width: slotWidth, height: length)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

                // Fader cap
                faderCap
                    .offset(y: -CGFloat(value) * (length - capSize.height))
            }
            .frame(height: length)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let fraction = 1.0 - (gesture.location.y / length)
                        let newValue = max(0, min(1, fraction))
                        checkBoundsHaptic(newValue)
                        value = newValue
                    }
            )
        }
    }

    // MARK: - Horizontal Layout

    private var horizontalSlider: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .leading) {
                // Slot
                RoundedRectangle(cornerRadius: slotWidth / 2)
                    .fill(ResonanceColors.panelBg)
                    .frame(width: length, height: slotWidth)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

                // Fader cap (rotated for horizontal)
                faderCap
                    .offset(x: CGFloat(value) * (length - capSize.width))
            }
            .frame(width: length)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let fraction = gesture.location.x / length
                        let newValue = max(0, min(1, fraction))
                        checkBoundsHaptic(newValue)
                        value = newValue
                    }
            )

            if showScale { scaleMarks(vertical: false) }
        }
    }

    // MARK: - Fader Cap

    private var faderCap: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [ResonanceColors.metalLight, ResonanceColors.metalMid],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: capSize.width, height: capSize.height)
            .overlay(
                // Center groove
                Rectangle()
                    .fill(ResonanceColors.metalDark)
                    .frame(width: capSize.width * 0.6, height: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
    }

    // MARK: - Scale Marks

    private func scaleMarks(vertical: Bool) -> some View {
        let tickCount = 5
        return Group {
            if vertical {
                VStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { i in
                        if i > 0 { Spacer() }
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 6, height: 1)
                    }
                }
                .frame(height: length)
            } else {
                HStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { i in
                        if i > 0 { Spacer() }
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 6)
                    }
                }
                .frame(width: length)
            }
        }
    }

    // MARK: - Bounds Haptic

    private func checkBoundsHaptic(_ newValue: Double) {
        if (newValue <= 0 && value > 0) || (newValue >= 1 && value < 1) {
            hapticTrigger += 1
        }
    }
}

// MARK: - Preview

#Preview("Slider Pots") {
    @Previewable @State var v1 = 0.5
    @Previewable @State var h1 = 0.3

    HStack(spacing: 40) {
        RetroSliderPot(value: $v1, orientation: .vertical, label: "GAIN")
        VStack {
            RetroSliderPot(value: $h1, orientation: .horizontal, label: "PAN", length: 120)
        }
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Views/Components/RetroControls/RetroSliderPot.swift
git commit -m "feat(components): add RetroSliderPot linear fader"
```

---

### Task 12: RetroToggleSwitch

**Files:**
- Create: `iOS/Views/Components/RetroControls/RetroToggleSwitch.swift`

- [ ] **Step 1: Create RetroToggleSwitch**

```swift
//
//  RetroToggleSwitch.swift
//  Resonance
//
//  3D rectangular rocker switch in metal bezel with adjacent LED.
//  ON tilts up-right, OFF tilts down-left via 3D rotation.
//

import SwiftUI

// MARK: - Retro Toggle Switch

struct RetroToggleSwitch: View {
    @Binding var isOn: Bool
    var label: String = ""
    var ledColor: Color = ResonanceColors.ledGreen

    @State private var hapticTrigger = 0

    var body: some View {
        HStack(spacing: 10) {
            if !label.isEmpty {
                Text(label)
                    .retroEngravedLabel()
            }

            // Switch body
            Button {
                withAnimation(.spring(RetroAnimation.switchFlip)) {
                    isOn.toggle()
                }
                hapticTrigger += 1
            } label: {
                ZStack {
                    // Metal bezel
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ResonanceColors.metalDark)
                        .frame(width: 32, height: 18)

                    // Rocker
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [ResonanceColors.metalLight, ResonanceColors.metalMid],
                                startPoint: isOn ? .topTrailing : .bottomLeading,
                                endPoint: isOn ? .bottomLeading : .topTrailing
                            )
                        )
                        .frame(width: 28, height: 14)
                        .overlay(
                            Text(isOn ? "ON" : "OFF")
                                .font(.system(size: 5, weight: .bold, design: .monospaced))
                                .foregroundStyle(ResonanceColors.metalDark)
                        )
                        .rotation3DEffect(
                            .degrees(isOn ? RetroDimensions.switchRotationAngle : -RetroDimensions.switchRotationAngle),
                            axis: (x: 1, y: 0, z: 0),
                            perspective: 0.3
                        )
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            // Adjacent LED
            RetroLEDIndicator(isOn: isOn, color: ledColor)
        }
        .accessibilityElement()
        .accessibilityLabel(label.isEmpty ? "Toggle" : label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        .accessibilityAction { isOn.toggle() }
    }
}

// MARK: - Preview

#Preview("Toggle Switches") {
    @Previewable @State var s1 = true
    @Previewable @State var s2 = false

    VStack(spacing: 20) {
        RetroToggleSwitch(isOn: $s1, label: "HEART RATE")
        RetroToggleSwitch(isOn: $s2, label: "SLEEP DATA", ledColor: ResonanceColors.ledAmber)
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Views/Components/RetroControls/RetroToggleSwitch.swift
git commit -m "feat(components): add RetroToggleSwitch with 3D rotation"
```

---

### Task 13: RetroPushButton

**Files:**
- Create: `iOS/Views/Components/RetroControls/RetroPushButton.swift`

- [ ] **Step 1: Create RetroPushButton**

```swift
//
//  RetroPushButton.swift
//  Resonance
//
//  Rectangular button with press depth animation.
//  Supports momentary (fires on release) and latching (stays pressed) modes.
//  Used for tab bar buttons, action buttons, and navigation.
//

import SwiftUI

// MARK: - Retro Push Button

struct RetroPushButton: View {
    let label: String
    var icon: String? = nil
    var action: () -> Void = {}
    var isLatching: Bool = false
    var isPressed: Bool = false  // External state for latching mode

    @State private var isMomentaryPressed = false
    @State private var pressTrigger = 0
    @State private var releaseTrigger = 0

    private var effectivelyPressed: Bool {
        isLatching ? isPressed : isMomentaryPressed
    }

    var body: some View {
        Button {
            if !isLatching {
                action()
            }
        } label: {
            VStack(spacing: 2) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(effectivelyPressed ? .white : .secondary)
            .frame(minWidth: 44, minHeight: 36)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: effectivelyPressed
                                ? [ResonanceColors.metalDark, ResonanceColors.metalDark.opacity(0.8)]
                                : [ResonanceColors.metalLight, ResonanceColors.metalMid],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            // Side edges for 3D depth
            .background(alignment: .bottom) {
                if !effectivelyPressed {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ResonanceColors.metalDark)
                        .frame(height: RetroDimensions.buttonProudHeight)
                        .offset(y: RetroDimensions.buttonProudHeight)
                }
            }
            .offset(y: effectivelyPressed ? RetroDimensions.buttonPressDepth : 0)
            .shadow(
                color: .black.opacity(effectivelyPressed ? 0.1 : 0.3),
                radius: effectivelyPressed ? 1 : 3,
                x: 0,
                y: effectivelyPressed ? 1 : 3
            )
            .animation(.spring(RetroAnimation.buttonPress), value: effectivelyPressed)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.7), trigger: pressTrigger)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: releaseTrigger)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isMomentaryPressed && !isLatching {
                        isMomentaryPressed = true
                        pressTrigger += 1
                    }
                }
                .onEnded { _ in
                    if !isLatching {
                        isMomentaryPressed = false
                        releaseTrigger += 1
                    }
                }
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(isLatching ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("Push Buttons") {
    HStack(spacing: 16) {
        RetroPushButton(label: "PLAY", icon: "play.fill")
        RetroPushButton(label: "STOP", icon: "stop.fill")
        RetroPushButton(label: "ENGAGE")
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Views/Components/RetroControls/RetroPushButton.swift
git commit -m "feat(components): add RetroPushButton with momentary/latching modes"
```

---

### Task 14: RetroSegmentedSelector

**Files:**
- Create: `iOS/Views/Components/RetroControls/RetroSegmentedSelector.swift`

- [ ] **Step 1: Create RetroSegmentedSelector**

```swift
//
//  RetroSegmentedSelector.swift
//  Resonance
//
//  Row of embossed metal buttons in shared bezel with LED indicators.
//  Active segment presses in with lit LED. Generic over Hashable selection type.
//

import SwiftUI

// MARK: - Retro Segmented Selector

struct RetroSegmentedSelector<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    @State private var hapticTrigger = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = selection == option

                Button {
                    withAnimation(.spring(RetroAnimation.buttonPress)) {
                        selection = option
                    }
                    hapticTrigger += 1
                } label: {
                    VStack(spacing: 3) {
                        // LED above button
                        RetroLEDIndicator(
                            isOn: isSelected,
                            color: .white,
                            size: 4
                        )

                        // Button label
                        Text(label(option))
                            .font(.system(size: 7, weight: .heavy, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        Rectangle()
                            .fill(
                                isSelected
                                    ? ResonanceColors.metalDark
                                    : LinearGradient(
                                        colors: [ResonanceColors.metalLight, ResonanceColors.metalMid],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ).opacity(1)
                            )
                    )
                    .overlay(alignment: .trailing) {
                        // Metal divider (except last)
                        if index < options.count - 1 {
                            Rectangle()
                                .fill(ResonanceColors.metalDark)
                                .frame(width: 1)
                        }
                    }
                    .offset(y: isSelected ? 2 : 0)
                    .animation(.spring(RetroAnimation.buttonPress), value: isSelected)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(ResonanceColors.metalDark, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preview

#Preview("Segmented Selector") {
    @Previewable @State var selected = "WEEK"

    RetroSegmentedSelector(
        selection: $selected,
        options: ["WEEK", "MONTH", "3MO", "YEAR"],
        label: { $0 }
    )
    .frame(width: 300)
    .padding(40)
    .background(ResonanceColors.metalDark)
}
```

- [ ] **Step 2: Verify build**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add iOS/Views/Components/RetroControls/RetroSegmentedSelector.swift
git commit -m "feat(components): add RetroSegmentedSelector with LED indicators"
```

---

## Phase 3: Screen Redesigns

### Task 15: MoodTabView Redesign

**Files:**
- Modify: `iOS/Views/MoodTabView.swift`

This is the largest single task. The entire view body is rewritten to use VU meters, knobs, LCD panels, and segmented selectors.

- [ ] **Step 1: Read the current MoodTabView in full**

Read `iOS/Views/MoodTabView.swift` to understand all existing properties, state variables, and helper methods that must be preserved (stateEngine bindings, journey logic, suggestion computation).

- [ ] **Step 2: Rewrite the view body**

Replace the body and all section views. Keep all `@State` variables, `@ObservedObject`, constants, and the non-UI methods (`initializeFromState`, `startJourney`, `suggestedTrajectory`, `formatDelta`). Replace:

- `moodOrbSection` → Two `RetroVUMeter` controls in a shared recessed panel ("ENERGY" / "VALENCE")
- `currentMoodSection` → `RetroLCDPanel` titled "CURRENT STATE" with two `RetroKnob` controls for energy/valence
- `targetMoodSection` → Same layout titled "TARGET STATE" with delta LCD readout
- `presetButtonsSection` → `RetroSegmentedSelector` with CALM/FOCUS/ENERGY/UPBEAT mapped to the 4 existing preset energy/valence values
- `suggestionPreview` → `RetroLCDPanel` with monospaced AI recommendation
- `journeyProgressSection` → Tape counter (4-digit rolling numbers) + LED bar graph + STOP button
- `startJourneyButton` → `RetroPushButton` "START JOURNEY"
- Wrap everything in `BrushedMetalSurface(showScrews: true)`
- Add `@Environment(\.retroAccentColor)` and use it for accent elements

- [ ] **Step 3: Verify build**

Build in Xcode.

- [ ] **Step 4: Run on simulator**

Launch on iPhone simulator. Navigate to Mood tab. Verify VU meters render, knobs rotate with drag, presets change knob positions, LCD panels show text.

- [ ] **Step 5: Commit**

```bash
git add iOS/Views/MoodTabView.swift
git commit -m "feat(mood): redesign MoodTabView with retro VU meters, knobs, and LCD panels"
```

---

### Task 16: InsightsView Redesign

**Files:**
- Modify: `iOS/Views/InsightsView.swift`

- [ ] **Step 1: Read the current InsightsView in full**

Read `iOS/Views/InsightsView.swift` to understand the InsightsEngine, InsightTimeRange, chart sections, heat map, and metric cells.

- [ ] **Step 2: Restyle the time range picker**

Replace the standard `Picker` with `RetroSegmentedSelector<InsightTimeRange>`.

- [ ] **Step 3: Restyle the header**

Replace `profileHeader` with a `RetroLCDPanel` titled "SIGNAL ANALYSIS" containing "BIOMETRIC-MUSIC CORRELATIONS" in monospaced text.

- [ ] **Step 4: Restyle the most resonant track card**

Wrap in `BrushedMetalSurface`. Add a small `RetroVUMeter(size: 80)` showing the resonance score. Add 5 `RetroLEDIndicator` dots as signal strength.

- [ ] **Step 5: Restyle chart cards as oscilloscope screens**

For each insight card: wrap in `BrushedMetalSurface` with engraved title. Set chart background to `panelBg`, grid lines to accent at 15% opacity, data strokes to accent with `.shadow(color: accentColor, radius: 4)` glow. Add `RetroLEDIndicator` trend dot below each chart.

- [ ] **Step 6: Restyle heat map**

Replace heat map cells with `RetroLEDIndicator` dots where brightness = heat value. Use engraved monospaced labels for rows/columns. Wrap in recessed panel.

- [ ] **Step 7: Restyle metric cells**

Each metric as `RetroLCDPanel` (compact) with `ledDigit` value, engraved label, and trend `RetroLEDIndicator`.

- [ ] **Step 8: Wrap in container**

Wrap the ScrollView content in `BrushedMetalSurface(showScrews: true)`. Add `@Environment(\.retroAccentColor)`.

- [ ] **Step 9: Verify build and test**

Build and run on simulator. Navigate to Insights tab.

- [ ] **Step 10: Commit**

```bash
git add iOS/Views/InsightsView.swift
git commit -m "feat(insights): redesign InsightsView as oscilloscope/test equipment"
```

---

### Task 17: SettingsView Redesign

**Files:**
- Modify: `iOS/Views/SettingsView.swift`

- [ ] **Step 1: Read the current SettingsView in full**

Read `iOS/Views/SettingsView.swift`.

- [ ] **Step 2: Replace settings list with metal sub-panels**

Replace the `List` body with a `ScrollView` containing `BrushedMetalSurface(showScrews: true)`. Each settings group becomes a metal sub-panel: `BrushedMetalSurface(cornerRadius: 8, showScrews: true)` containing an engraved section label (BODY, MUSIC, AI, SESSIONS, DATA), a `lcdCaption` description, and a `NavigationLink`.

- [ ] **Step 3: Update navigation title**

Replace `.navigationTitle("Settings")` with a `RetroLCDPanel` header containing "CONFIGURATION" in engraved text, or keep the navigation title as `.inline` with the LCD panel in the toolbar.

- [ ] **Step 4: Verify build and test**

Build and run. Navigate to Settings.

- [ ] **Step 5: Commit**

```bash
git add iOS/Views/SettingsView.swift
git commit -m "feat(settings): redesign SettingsView as hardware config panel"
```

---

### Task 18: Settings Sub-Page Reskinning

**Files:**
- Modify: `iOS/Views/BodySettingsView.swift`
- Modify: `iOS/Views/MusicSettingsView.swift`
- Modify: `iOS/Views/AISettingsView.swift`
- Modify: `iOS/Views/SessionSettingsView.swift`
- Modify: `iOS/Views/DataSettingsView.swift`

- [ ] **Step 1: Read all 5 settings sub-views**

Read each file to catalog which standard controls are used (Toggle, Slider, Picker, Stepper).

- [ ] **Step 2: Replace controls in each file**

Apply the control mapping from the spec:

| Standard | Retro |
|----------|-------|
| `Toggle` | `RetroToggleSwitch(isOn:label:ledColor:)` |
| `Slider` | `RetroSliderPot(value:orientation:.horizontal, label:)` |
| `Picker` | `RetroSegmentedSelector(selection:options:label:)` |
| `Stepper` | Two `RetroPushButton` (-/+) flanking a `RetroLCDPanel` value |
| Section headers | `.retroEngravedLabel()` |
| Section footers | `RetroTypography.lcdCaption` in recessed strip |

Set list background to `metalDark` with grain texture. Separators to thin chrome lines.

- [ ] **Step 3: Verify build**

Build in Xcode.

- [ ] **Step 4: Test each sub-page on simulator**

Navigate to each settings sub-page. Verify controls render and function.

- [ ] **Step 5: Commit**

```bash
git add iOS/Views/BodySettingsView.swift iOS/Views/MusicSettingsView.swift iOS/Views/AISettingsView.swift iOS/Views/SessionSettingsView.swift iOS/Views/DataSettingsView.swift
git commit -m "feat(settings): reskin all 5 settings sub-pages with retro controls"
```

---

### Task 19: LandingView Boot Sequence

**Files:**
- Modify: `iOS/Views/LandingView.swift`

- [ ] **Step 1: Read the current LandingView in full**

Read `iOS/Views/LandingView.swift`.

- [ ] **Step 2: Replace the animated sequence**

Replace the brain orb + title + button with the boot sequence:

1. Black screen (0.0s)
2. Single `RetroLEDIndicator` fades on center with glow bloom (0.3s)
3. Accent-colored scanline sweeps top-to-bottom (0.5s)
4. `RetroLCDPanel` shows boot text character-by-character (1.0s–2.0s)
5. Two `RetroVUMeter` appear flanking LCD, needles sweep (2.0s–2.5s)
6. `RetroPushButton` "ENGAGE" fades in with spring bounce (2.5s)

Boot text:
```
RESONANCE AI DJ SYSTEM
v2.0 ■■■■■■■■ OK
INITIALIZING NEURAL ENGINE...
BIOMETRIC LINK: CONNECTED
LIBRARY SCAN: 1,247 TRACKS
STATUS: READY
```

Preserve the `matchedGeometryEffect` transition to main app. Preserve `@Binding var hasStartedFirstSession`. Respect `accessibilityReduceMotion`: skip character animation, show full text, reduce to ~0.5s.

- [ ] **Step 3: Verify build and test**

Build and run. Force the landing view to show (reset onboarding state or adjust the condition). Verify the sequence plays.

- [ ] **Step 4: Commit**

```bash
git add iOS/Views/LandingView.swift
git commit -m "feat(landing): redesign as retro power-on boot sequence"
```

---

### Task 20: QueueView Enhancements

**Files:**
- Modify: `iOS/Views/QueueView.swift`

- [ ] **Step 1: Read the current QueueView**

Already read above, but re-read to confirm current structure.

- [ ] **Step 2: Add VU meters to Now Playing row**

In `nowPlayingRow`, add two small `RetroVUMeter(size: 40)` for live audio levels alongside the existing mini cassette. These can reflect `viewModel.currentSong` energy/mood or simply show a decorative idle animation.

- [ ] **Step 3: Replace confidence indicator**

In `aiQueueRow`, replace the circular confidence gauge with a row of 5 `RetroLEDIndicator` dots. Fill count = `Int(item.confidence * 5)`. Example: confidence 0.7 = 3.5 → 4 LEDs lit.

- [ ] **Step 4: Replace AI reasoning display**

Replace the `HStack` with wand.and.stars icon and text with a slim `RetroLCDPanel` strip containing the reasoning text in `RetroTypography.lcdCaption`.

- [ ] **Step 5: Restyle section headers**

Replace `Text("Now Playing")` and `Text("AI Queue")` section headers with `.retroEngravedLabel()`.

- [ ] **Step 6: Set list background and drag handles**

Add `.listRowBackground(ResonanceColors.metalDark)` and grain texture to list rows. Replace standard iOS drag indicators with embossed chrome ridges: three horizontal `Rectangle` bars in `ResonanceColors.screwChrome` at 0.5pt height, 2pt spacing.

- [ ] **Step 7: Verify build and test**

Build and run. Open the queue sheet from Now Playing.

- [ ] **Step 8: Commit**

```bash
git add iOS/Views/QueueView.swift
git commit -m "feat(queue): add LED confidence bars and LCD reasoning panels"
```

---

### Task 21: Onboarding Retro Restyling

**Files:**
- Modify: `iOS/Views/Onboarding/OnboardingContainerView.swift`
- Modify: `iOS/Views/Onboarding/OnboardingPageViews.swift`
- Modify: `iOS/Views/Onboarding/OnboardingMusicConnectionPage.swift`
- Modify: `iOS/Views/Onboarding/OnboardingFirstPlayPage.swift`

- [ ] **Step 1: Read all 4 onboarding files**

Read each file to understand the current page structure, navigation logic, and permission handling.

- [ ] **Step 2: Restyle container**

In `OnboardingContainerView`: replace page indicator dots with `RetroLEDIndicator` dots (active = lit, inactive = dark). Replace BACK/NEXT buttons with `RetroPushButton`. Wrap content in `BrushedMetalSurface`.

- [ ] **Step 3: Restyle page content**

In `OnboardingPageViews`: wrap each page's content area in `RetroLCDPanel`. Use `RetroTypography.lcdBody` for text.

- [ ] **Step 4: Add VU meter to music connection page**

In `OnboardingMusicConnectionPage`: add a `RetroVUMeter` that sweeps from 0 to 1 when Apple Music connects successfully.

- [ ] **Step 5: Restyle health permissions**

Replace permission toggles with `RetroToggleSwitch` per permission, LED turns green on grant.

- [ ] **Step 6: Restyle first play page**

In `OnboardingFirstPlayPage`: use retro styling consistent with the other pages.

- [ ] **Step 7: Verify build and test**

Build and run. Reset onboarding to test the full flow.

- [ ] **Step 8: Commit**

```bash
git add iOS/Views/Onboarding/
git commit -m "feat(onboarding): restyle as equipment calibration wizard"
```

---

## Phase 4: Tab Bar + Transitions + Polish

### Task 22: CassetteDeckTabBar

**Files:**
- Create: `iOS/Views/Components/CassetteDeckTabBar.swift`

- [ ] **Step 1: Ensure MainView.Tab conforms to CaseIterable**

Open `iOS/Views/MainView.swift` and verify the `Tab` enum conforms to `CaseIterable`. If not, add the conformance: `enum Tab: String, CaseIterable { ... }`. This is required for `Tab.allCases` used below.

- [ ] **Step 2: Create CassetteDeckTabBar**

```swift
//
//  CassetteDeckTabBar.swift
//  Resonance
//
//  Custom tab bar replacing system TabView. Brushed metal control strip
//  with 5 latching mechanical buttons and LED indicators.
//

import SwiftUI

// MARK: - Cassette Deck Tab Bar

struct CassetteDeckTabBar: View {
    @Binding var selectedTab: MainView.Tab
    @Environment(\.retroAccentColor) private var accentColor
    @State private var hapticTrigger = 0

    private let tabs = MainView.Tab.allCases

    private let tabIcons: [MainView.Tab: String] = [
        .nowPlaying: "play.circle",
        .mood: "face.smiling",
        .playlists: "music.note.list",
        .insights: "chart.bar.xaxis",
        .settings: "gear"
    ]

    private let tabLabels: [MainView.Tab: String] = [
        .nowPlaying: "PLAY",
        .mood: "MOOD",
        .playlists: "LIBRARY",
        .insights: "DATA",
        .settings: "CONFIG"
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.rawValue) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.vertical, 8)
        .padding(.bottom, 4)
        .brushedMetal(cornerRadius: 0)
        .overlay(alignment: .top) {
            // Chrome edge highlight along top
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }

    private func tabButton(for tab: MainView.Tab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(RetroAnimation.traySlide)) {
                selectedTab = tab
            }
            hapticTrigger += 1
        } label: {
            VStack(spacing: 4) {
                // LED indicator
                RetroLEDIndicator(
                    isOn: isSelected,
                    color: accentColor,
                    size: 5
                )

                // Button
                VStack(spacing: 2) {
                    Image(systemName: tabIcons[tab] ?? "circle")
                        .font(.system(size: 14, weight: .medium))
                    Text(tabLabels[tab] ?? "")
                        .font(.system(size: 6, weight: .heavy, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isSelected ? ResonanceColors.metalDark : Color.clear)
                )
                .offset(y: isSelected ? 2 : 0)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Tab Bar") {
    @Previewable @State var tab = MainView.Tab.nowPlaying

    VStack {
        Spacer()
        CassetteDeckTabBar(selectedTab: $tab)
    }
    .background(Color.black)
}
```

- [ ] **Step 3: Verify build**

Build in Xcode.

- [ ] **Step 4: Commit**

```bash
git add iOS/Views/Components/CassetteDeckTabBar.swift iOS/Views/MainView.swift
git commit -m "feat(navigation): add CassetteDeckTabBar custom tab bar"
```

---

### Task 23: Replace System TabView in MainView

**Files:**
- Modify: `iOS/Views/MainView.swift`

- [ ] **Step 1: Read MainView in full**

Re-read `iOS/Views/MainView.swift`.

- [ ] **Step 2: Replace TabView with custom navigation**

Replace the `TabView` with a `ZStack` that shows the selected tab's content, plus the `CassetteDeckTabBar` as a bottom bar. Keep the mini player above the tab bar.

The body becomes:
```swift
var body: some View {
    ZStack(alignment: .bottom) {
        // Selected tab content
        Group {
            switch selectedTab {
            case .nowPlaying:
                NowPlayingView(
                    viewModel: nowPlayingViewModel,
                    stateEngine: stateEngine,
                    heroNamespace: heroNamespace,
                    onBrowsePlaylists: { selectedTab = .playlists }
                )
            case .mood:
                MoodTabView(stateEngine: stateEngine)
            case .playlists:
                PlaylistBrowserView(
                    viewModel: playlistViewModel,
                    onPlaylistSelected: { _ in selectedTab = .nowPlaying }
                )
            case .insights:
                InsightsView()
            case .settings:
                SettingsView(
                    musicService: musicService,
                    historicalEngine: historicalEngine,
                    stateEngine: stateEngine
                )
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        ))
        .animation(.spring(RetroAnimation.traySlide), value: selectedTab)

        // Bottom bar stack
        VStack(spacing: 0) {
            if shouldShowMiniPlayer {
                MiniPlayerView(
                    viewModel: nowPlayingViewModel,
                    onTapNavigate: { selectedTab = .nowPlaying }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            CassetteDeckTabBar(selectedTab: $selectedTab)
        }
    }
    .retroAccentColor(nowPlayingViewModel.artworkAccentColor)
    .ignoresSafeArea(edges: .bottom)
    .onAppear {
        if nowPlayingViewModel.activePlaylistName == nil {
            selectedTab = .playlists
        }
    }
}
```

- [ ] **Step 3: Verify build**

Build in Xcode.

- [ ] **Step 4: Test tab navigation on simulator**

Launch on simulator. Verify all 5 tabs render, transitions slide, mini player appears above tab bar, LED indicators light up for active tab.

- [ ] **Step 5: Commit**

```bash
git add iOS/Views/MainView.swift
git commit -m "feat(navigation): replace system TabView with CassetteDeckTabBar"
```

---

### Task 24: MiniPlayerView Retro Redesign

**Files:**
- Modify: `iOS/Views/Components/MiniPlayerView.swift`

- [ ] **Step 1: Read MiniPlayerView in full**

Read `iOS/Views/Components/MiniPlayerView.swift`.

- [ ] **Step 2: Restyle as cassette control strip**

Replace `.glassEffect(.regular)` with `.brushedMetal(cornerRadius: 0)`. Add a tiny spinning reel animation (Canvas, 20pt diameter — same pattern as `CassettePlayerView` reel but smaller) on the left side. Replace song title display with scrolling monospaced `RetroTypography.lcdBody` text (use `.marquee` or a custom horizontal scroll). Replace the `ResonanceProgressBar` with an accent-colored thin line along the top edge. Restyle transport controls as small `RetroPushButton` (play/pause, skip). Keep the artwork thumbnail but reduce to 36pt with 2pt metal border.

- [ ] **Step 3: Verify build and test**

Build and run. Play a song, navigate away from Now Playing. Verify mini player renders in retro style.

- [ ] **Step 4: Commit**

```bash
git add iOS/Views/Components/MiniPlayerView.swift
git commit -m "feat(mini-player): restyle as brushed metal cassette strip"
```

---

### Task 25: Final Polish and Cleanup

**Files:**
- All modified files

- [ ] **Step 1: Haptic consistency audit**

Grep for `.sensoryFeedback` across all retro files. Verify:
- Knob detents: `.impact(.light)`
- Switch toggles: `.impact(.medium)`
- Button press: `.impact(.rigid)` / release `.impact(.soft)`
- Tab changes: `.impact(.medium)`

- [ ] **Step 2: Accessibility audit**

Grep for `accessibilityLabel` and `accessibilityValue` across all retro controls. Verify every interactive control is accessible. Check `accessibilityReduceMotion` is respected in LandingView and any continuous animations.

- [ ] **Step 3: Dead code cleanup**

Check for unused views/structs from the old design:
- `PlaylistRow` in `PlaylistBrowserView.swift` — already unused (grid replaced it)
- `SongRow` in `PlaylistDetailView.swift` — verify unused (carousel replaced it)
- Old mood orb code in `MoodTabView.swift` — should be removed during redesign

- [ ] **Step 4: Performance check**

Run on physical device (or high-fidelity simulator). Navigate through all tabs. Check for frame drops in:
- VU meter needle animation
- Knob rotation
- Tab bar transitions
- Scrolling through Insights charts

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: polish haptics, accessibility, and remove dead code"
```

---

## Summary

| Phase | Tasks | New Files | Modified Files |
|-------|-------|-----------|---------------|
| 1: Design System Spine | 1-5 | 4 | 3 |
| 2: Core Components | 6-14 | 9 | 0 |
| 3: Screen Redesigns | 15-21 | 0 | 14 |
| 4: Tab Bar + Polish | 22-25 | 1 | 2 |
| **Total** | **25** | **14** | **19** |
