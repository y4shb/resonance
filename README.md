# Resonance

An intelligent music selection system that picks songs from your Apple Music playlists based on biometrics, context, and historical effectiveness.

## Project Setup

### Prerequisites

- Xcode 15.0 or later
- macOS 14.0 (Sonoma) or later
- iOS 15.0+ device or simulator
- watchOS 8.0+ device or simulator
- Apple Developer account (for HealthKit and MusicKit entitlements)

### Option 1: Generate Xcode Project with XcodeGen

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

2. Generate the project:
   ```bash
   xcodegen generate
   ```

3. Open the generated project:
   ```bash
   open Resonance.xcodeproj
   ```

### Option 2: Manual Xcode Setup

1. Open Xcode and create a new project
2. Choose "App" template for iOS
3. Set Product Name to "Resonance"
4. Add watchOS and macOS targets manually
5. Add the source files from this directory structure
6. Configure entitlements and Info.plist as provided

### Configuration Steps

1. **Set Development Team**
   - Open `project.yml` and set your `DEVELOPMENT_TEAM`
   - Or configure in Xcode: Project > Signing & Capabilities

2. **Configure App Group**
   - In Apple Developer Portal, create App Group: `group.com.y4sh.resonance`
   - Enable App Groups capability for all targets

3. **Enable Capabilities**
   - iOS: HealthKit, MusicKit, App Groups, Background Modes
   - watchOS: HealthKit, App Groups
   - macOS: App Groups, Network (for iPhone communication)

4. **Register for MusicKit**
   - Visit [Apple Developer Portal](https://developer.apple.com)
   - Request MusicKit access for your app

## Project Structure

```
resonance/
├── Shared/                 # Cross-platform code
│   ├── Models/             # Data models (StateVector, SongScore, etc.)
│   ├── Persistence/        # Core Data stack
│   ├── Services/           # Business logic services
│   └── Utilities/          # Constants, Logging, Extensions
│
├── Brain/                  # Core intelligence (iPhone)
│   ├── Historical/         # Historical analysis
│   ├── State/              # State estimation
│   ├── Ranking/            # Song selection
│   ├── Features/           # Audio feature extraction
│   └── Learning/           # Continuous learning
│
├── iOS/                    # iPhone app
├── Watch/                  # Apple Watch app
├── macOS/                  # Menu bar app
├── Widgets/                # iOS widgets
└── Tests/                  # Unit and integration tests
```

## Development Phases

- [x] **Phase 1**: Project Setup
- [ ] **Phase 2**: Platform Skeleton (M1)
- [ ] **Phase 3**: Data Foundations (M2)
- [ ] **Phase 4**: Historical Backfill (M3)
- [ ] **Phase 5**: State Engine (M4)
- [ ] **Phase 6**: DJ Brain (M5)
- [ ] **Phase 7**: Watch Experience (M6)
- [ ] **Phase 8**: Learning Loop (M7)
- [ ] **Phase 9**: MVP Polish (M8)

## Key Files

| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen project configuration |
| `Shared/Models/StateVector.swift` | User state representation |
| `Shared/Models/SongScore.swift` | Song ranking result |
| `Shared/Persistence/PersistenceController.swift` | Core Data management |
| `Shared/Utilities/Constants.swift` | App-wide constants |

## Running the App

1. Select the `Resonance` scheme in Xcode
2. Choose an iOS simulator or device
3. Press Cmd+R to build and run

For Watch app:
1. Select the `ResonanceWatch` scheme
2. Choose a Watch simulator paired with iOS simulator
3. Press Cmd+R to build and run

## Testing

Run unit tests with Cmd+U or:
```bash
xcodebuild test -scheme Resonance -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Documentation

- `product.md` - Product specification
- `plan.md` - Technical implementation plan
- `progress.md` - Progress tracker
- `learn-from/` - Learning resources
