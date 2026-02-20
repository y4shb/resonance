# Agent B Context: Watch + macOS + Connectivity

## Your Role
You are Agent B in a parallel implementation. You handle Watch UI, macOS UI, and WatchConnectivity between iPhone and Watch. Agent A (running separately) handles iOS MusicKit and iOS UI. You have **zero file overlap** with Agent A.

## Prerequisite Already Complete
`Shared/Models/WatchMessages.swift` has been created with all shared message types:
- `WatchMessage` enum (Codable)
- `PlaybackCommand`, `NowPlayingPacket`, `BiometricPacket`, `MoodPacket`, `CrownAdjustment`, `StatePacket`, `ComplicationData`

## Files You Create/Modify

| File | Action |
|------|--------|
| `iOS/Services/WatchConnectivityManager.swift` | **Create** — iOS-side WCSession delegate |
| `Watch/Services/PhoneConnectivityService.swift` | **Create** — Watch-side WCSession delegate |
| `Watch/Views/WatchNowPlayingView.swift` | **Create** — song info + playback controls |
| `Watch/ResonanceWatchApp.swift` | **Modify** — wire up PhoneConnectivityService |
| `macOS/MenuBar/MenuBarController.swift` | **Create** — manages menu bar state |
| `macOS/MenuBar/StatusItemView.swift` | **Create** — menu bar icon |
| `macOS/MenuBar/PopoverView.swift` | **Create** — popover with now playing + status |
| `macOS/ResonanceMacApp.swift` | **Modify** — wire up enhanced menu bar |

## Files You Do NOT Touch
- `Shared/Services/MusicKitService.swift`
- `iOS/Views/*`
- `iOS/ViewModels/*`
- `iOS/ResonanceApp.swift`
- `Shared/Models/WatchMessages.swift` (already created)

## Specifications

### WatchConnectivityManager (iOS side) — plan.md 6.3.2

```swift
protocol WatchConnectivityManagerProtocol {
    func activate()
    var isReachable: Bool { get }
    var isPaired: Bool { get }

    // Sending (Phone -> Watch)
    func sendNowPlaying(_ packet: NowPlayingPacket)
    func sendStateUpdate(_ packet: StatePacket)
    func updateComplication(_ data: ComplicationData)

    // Receiving (Watch -> Phone)
    var biometricUpdates: AnyPublisher<BiometricPacket, Never> { get }
    var moodInputs: AnyPublisher<MoodPacket, Never> { get }
    var playbackCommands: AnyPublisher<PlaybackCommand, Never> { get }
    var crownAdjustments: AnyPublisher<CrownAdjustment, Never> { get }

    // Application Context (persistent)
    func updateApplicationContext(_ context: [String: Any]) throws
    var receivedApplicationContext: [String: Any] { get }

    // User Info Transfer (queued)
    func transferUserInfo(_ userInfo: [String: Any])
}
```

Implementation notes:
- Use `sendMessage` for real-time when reachable
- Use `updateApplicationContext` for persistent state (survives restarts)
- Use `transferUserInfo` for queued, guaranteed delivery (biometric batches)
- Use `transferCurrentComplicationUserInfo` for complications

### PhoneConnectivityService (Watch side)
Mirror of WatchConnectivityManager but from the Watch perspective:
- Receives `NowPlayingPacket` from phone
- Sends `PlaybackCommand` to phone
- Sends `BiometricPacket` to phone (stub for now)
- Publishes received data via Combine publishers for UI binding

### WatchNowPlayingView — plan.md 7.2.1

```
┌─────────────────────┐
│ AI DJ               │
├─────────────────────┤
│    [Album Art]      │
│      80x80          │
│                     │
│   Song Title...     │
│   Artist Name       │
│                     │
│  ──────●──────      │
│                     │
│  [⏮] [⏸] [⏭]       │
│                     │
│ "Calming you down"  │
└─────────────────────┘
```

- Display current song info from PhoneConnectivityService
- Play/pause/skip controls send PlaybackCommand to phone
- Show progress bar
- Show explanation text (if available)

### macOS Menu Bar — plan.md 7.3

Icon states:
- Normal: musical note
- Playing: note with play indicator
- Syncing: note with sync
- Disconnected: note with X

Popover view:
```
┌─────────────────────────────────┐
│ AI DJ                    [Gear]│
├─────────────────────────────────┤
│ [Album Art]  Song Title         │
│   50x50      Artist Name        │
│              ───●─────── 2:34   │
├─────────────────────────────────┤
│ Context Sending:                │
│ ✓ Focus Mode: Work              │
│ ✓ Active App: Xcode             │
│ ✓ Deep Work Detected            │
├─────────────────────────────────┤
│ iPhone: Connected ✓             │
│ Last sync: Just now             │
│ [Open iPhone App]               │
│ [Quit]                          │
└─────────────────────────────────┘
```

### Existing File Contents

**Watch/ResonanceWatchApp.swift** (current):
- Has `@main struct ResonanceWatchApp: App` with a placeholder `WatchContentView`
- Uses `logInfo()` from Logging.swift
- Modify to inject `PhoneConnectivityService` as `@StateObject` and pass to `WatchNowPlayingView`

**macOS/ResonanceMacApp.swift** (current):
- Has `@main struct ResonanceMacApp: App` with `MenuBarExtra` and `AppDelegate`
- Has placeholder `MenuBarContentView` and `MacSettingsView`
- Modify to use `MenuBarController` as `@StateObject` and wire to enhanced popover

### Logging
Use the existing logging utility: `logInfo("message", category: .watchConnectivity)` or `.general` etc.
Categories available: `.general`, `.watchConnectivity`, `.ui`, `.musicKit`, `.healthKit`, `.persistence`

### Checklist Items (from progress.md)
- 2.3 watchOS Basic UI (all items)
- 2.4 WatchConnectivity (all items)
- 2.5 macOS Basic UI (all items)
