# Agent A Context: iOS + MusicKit

## Your Role
You are Agent A in a parallel implementation. You handle MusicKit playback on iOS and the iOS UI shell. Agent B (running separately) handles Watch UI, macOS UI, and WatchConnectivity. You have **zero file overlap** with Agent B.

## Prerequisite Already Complete
`Shared/Models/WatchMessages.swift` has been created with all shared message types. You do not need to touch it.

## Files You Create/Modify

| File | Action |
|------|--------|
| `Shared/Services/MusicKitService.swift` | **Create** — protocol + implementation |
| `iOS/ViewModels/NowPlayingViewModel.swift` | **Create** — wraps MusicKitService, publishes now playing state |
| `iOS/ViewModels/PlaylistViewModel.swift` | **Create** — fetches & displays playlists |
| `iOS/Views/MainView.swift` | **Create** — tab navigation |
| `iOS/Views/NowPlayingView.swift` | **Create** — artwork, controls, song info |
| `iOS/Views/PlaylistBrowserView.swift` | **Create** — playlist list + selection |
| `iOS/Views/SettingsView.swift` | **Create** — basic settings shell |
| `iOS/ResonanceApp.swift` | **Modify** — wire up MusicKit auth + MainView |

## Files You Do NOT Touch
- `Watch/` directory (any file)
- `macOS/` directory (any file)
- `iOS/Services/` directory (Agent B creates WatchConnectivityManager there)
- `Shared/Models/WatchMessages.swift`
- Any WatchConnectivity code

## Specifications

### MusicKitService — plan.md 6.1.2

```swift
protocol MusicKitServiceProtocol {
    // Authorization
    func requestAuthorization() async throws -> MusicAuthorization.Status
    var authorizationStatus: MusicAuthorization.Status { get }

    // Library Access
    func fetchUserPlaylists() async throws -> [Playlist]
    func fetchPlaylistSongs(playlistId: String) async throws -> [Song]
    func fetchRecentlyPlayed(limit: Int) async throws -> [PlayHistoryItem]

    // Playback Control
    func play(song: Song) async throws
    func pause() async
    func skip() async
    func setQueue(songs: [Song]) async throws

    // Playback State
    var nowPlaying: Song? { get }
    var playbackState: MusicPlayer.PlaybackStatus { get }
    var currentPlaybackTime: TimeInterval { get }

    // Publishers
    var nowPlayingPublisher: AnyPublisher<Song?, Never> { get }
    var playbackStatePublisher: AnyPublisher<MusicPlayer.PlaybackStatus, Never> { get }
}
```

Implementation notes:
- Use `ApplicationMusicPlayer.shared` for playback
- Use `MusicAuthorization.request()` for auth
- Use `MusicLibraryRequest<MusicKit.Playlist>()` for fetching playlists
- Use `MusicCatalogResourceRequest<MusicKit.Song>` for song lookup
- MusicKit requires iOS 15.0+
- The protocol uses domain types `Playlist` and `Song` — for this phase, use MusicKit's own types directly (`MusicKit.Playlist`, `MusicKit.Song`) rather than Core Data entities. The mapping will happen in Phase 3.

### NowPlayingViewModel
- Wraps MusicKitService
- Published properties: `currentSong`, `isPlaying`, `playbackProgress`, `currentTime`, `duration`
- Actions: `play()`, `pause()`, `togglePlayPause()`, `skip()`, `previous()`
- Subscribes to `nowPlayingPublisher` and `playbackStatePublisher`

### PlaylistViewModel
- Wraps MusicKitService for playlist fetching
- Published properties: `playlists`, `isLoading`, `error`
- Actions: `fetchPlaylists()`, `selectPlaylist(_:)`
- On playlist select, load songs and pass to NowPlayingViewModel queue

### MainView — plan.md 7.1.1 (Tab-based Navigation)

```
┌─────────────────────────────────────────┐
│ [Status Bar]                            │
├─────────────────────────────────────────┤
│                                         │
│          [Now Playing View]             │
│               OR                        │
│          [Playlist Browser]             │
│               OR                        │
│          [Settings View]                │
│                                         │
├─────────────────────────────────────────┤
│ [Now Playing] [Playlists] [Settings]    │
└─────────────────────────────────────────┘
```

Three tabs for M1: Now Playing, Playlists, Settings. (Insights tab deferred to later phase.)

### NowPlayingView — plan.md 7.1.2

```
┌─────────────────────────────────────────┐
│ AI DJ                                   │
├─────────────────────────────────────────┤
│                                         │
│        ┌───────────────────────┐        │
│        │    [Album Artwork]    │        │
│        │       300x300         │        │
│        └───────────────────────┘        │
│                                         │
│          Song Title                     │
│          Artist Name                    │
│                                         │
│  ────────────●─────────────────  2:34   │
│  0:00                           4:12    │
│                                         │
│     [⏮]    [⏸/▶]    [⏭]               │
│                                         │
├─────────────────────────────────────────┤
│ Active Playlist: Chill Vibes ▼          │
│ [Change Playlist]                       │
└─────────────────────────────────────────┘
```

For M1, skip the "Why this song?" explanation and "Current State" sections — those come in later phases. Focus on:
- Album artwork (use `MusicKit.Artwork`)
- Song title + artist
- Progress bar with time labels
- Play/pause/skip controls
- Active playlist display

### PlaylistBrowserView — plan.md 7.1.3

```
┌─────────────────────────────────────────┐
│ Your Playlists              [Refresh]   │
├─────────────────────────────────────────┤
│                                         │
│ All Playlists                           │
│ ┌───────────────────────────────────┐   │
│ │ [Art] Playlist Name              │   │
│ │       N songs                    │ → │
│ └───────────────────────────────────┘   │
│ ...                                     │
└─────────────────────────────────────────┘
```

For M1, keep it simple: list all playlists from user's library. Skip "Best for Current State" and "Recently Played" sections (those require the State Engine from Phase 5). Each row shows playlist artwork, name, and song count. Tapping a playlist selects it as active and navigates to Now Playing.

### SettingsView
Basic shell with sections:
- MusicKit authorization status + button to re-request
- App version info
- Placeholder sections for future settings (HealthKit, preferences, etc.)

### Existing ResonanceApp.swift (you will modify this)
Current state:
- Has `PersistenceController.shared` injected
- Has placeholder `ContentView` with "Phase 1 Complete" message
- Has `registerBackgroundTasks()` placeholder
- Uses `logInfo()` / `logDebug()` from Logging.swift

Your modifications:
- Create `MusicKitService` as `@StateObject`
- Replace `ContentView()` with `MainView()`
- Pass MusicKitService to views via `@EnvironmentObject` or init injection
- Add MusicKit authorization request on launch

### Logging
Use the existing logging utility: `logInfo("message", category: .musicKit)` or `.ui`, `.general`, etc.
Categories available: `.general`, `.musicKit`, `.healthKit`, `.watchConnectivity`, `.persistence`, `.ui`, `.background`

### Checklist Items (from progress.md)
- 2.1 MusicKit Service (all items)
- 2.2 iOS Basic UI (all items)
