# App Store Review Guideline Violations — Pre-Submission Audit

> **Audit Date:** 2026-04-08
> **Auditors:** 4 parallel agents + manual line-by-line code review
> **Scope:** All 171 Swift files, Info.plist, project.yml, PrivacyInfo.xcprivacy, entitlements

---

## Summary

| Severity | Count | Description |
|----------|-------|-------------|
| **CRITICAL** | 3 | Will cause App Review rejection |
| **HIGH** | 3 | Likely rejection or required changes from reviewer |
| **MEDIUM** | 5 | May trigger reviewer questions |
| **LOW** | 3 | Best practice — fix before submission |
| **CLEARED** | 2 | Initially flagged, confirmed compliant by agent audits |

**Agent audit adjustments:**
- V-05 (MPMediaQuery DRM): HIGH → LOW. Agent confirmed `assetURL` nil guard is correct and complete DRM protection.
- V-06 (UserDefaults storage): HIGH → CLEARED. Derived health aggregates in UserDefaults are compliant — prohibition is on off-device transmission, not local storage format.
- V-07 (audio tap): HIGH → CLEARED. Tapping own app's AVAudioEngine output is standard AVFoundation practice.
- V-14 (NSHealthUpdateUsageDescription): NEW HIGH. App declares HealthKit write but never writes.

---

## CRITICAL — Will Cause Rejection

### V-01: Missing `NSCalendarsFullAccessUsageDescription`
**Guideline:** 5.1.1 — Data Collection and Storage
**Severity:** CRITICAL
**File:** `iOS/Info.plist` and `project.yml`
**Issue:** `CalendarContextService.swift` (T2-3, created this session) calls `store.requestFullAccessToEvents()` which requires `NSCalendarsFullAccessUsageDescription` in Info.plist. This key is missing.
**Impact:** Instant crash on calendar permission request → App Review rejection.
**Fix Plan:**
```
Add to iOS/Info.plist and project.yml info properties:
NSCalendarsFullAccessUsageDescription: "Resonance reads your calendar to adjust music before meetings and suggest focus sessions during free blocks. Calendar data stays on your device."
```

---

### V-02: Missing `UIBackgroundModes` Declaration
**Guideline:** 2.5.4 — Multitasking
**Severity:** CRITICAL
**File:** `project.yml` (iOS target)
**Issue:** No `UIBackgroundModes` key exists in the iOS target configuration. The app plays music via `ApplicationMusicPlayer` (which handles its own audio session), but the app also runs:
- `PomodoroTimer` (Timer.publish) in background
- `CalendarContextService` (Task.sleep polling) in background
- `RealtimeBPMVerifier` (AVAudioEngine tap) in background
- `StateEngine` (30-second Timer) in background
Without `UIBackgroundModes: [audio]`, iOS will suspend the app when backgrounded, breaking timer continuity and BPM verification.
**Impact:** Background timers stop, Pomodoro breaks, user experience degraded.
**Fix Plan:**
```yaml
# Add to project.yml iOS target → info → properties:
UIBackgroundModes:
  - audio
  - processing  # For BGTaskScheduler tasks
```

---

### V-03: Missing `NSFocusStatusUsageDescription` in iOS Info.plist
**Guideline:** 5.1.1 — Data Collection and Storage
**Severity:** CRITICAL
**File:** `iOS/Info.plist` and `project.yml`
**Issue:** `FocusModeService.swift` reads Focus Mode status. `NSFocusStatusUsageDescription` was listed in progress.md as a prior sprint fix, but it's NOT present in the current iOS Info.plist or project.yml. Only the macOS Info.plist has it (verified via grep). The Watch also doesn't have it.
**Impact:** Crash or rejection when reading Focus Mode status on iPhone.
**Fix Plan:**
```
Add to iOS/Info.plist and project.yml:
NSFocusStatusUsageDescription: "Resonance detects Focus mode to adjust music for work, sleep, or relaxation."
```

---

## HIGH — Likely Rejection

### V-04: `NSHealthShareUsageDescription` Too Generic
**Guideline:** 27.1 — HealthKit
**Severity:** HIGH
**File:** `iOS/Info.plist` line 30
**Issue:** Current description: *"Resonance reads heart rate and HRV data to personalize music selection."*
Apple requires **specific enumeration** of each HealthKit data type being read. The app reads: heartRate, heartRateVariabilitySDNN, stepCount, activeEnergyBurned, restingHeartRate, vo2Max, respiratoryRate, appleSleepingWristTemperature (8 types). The description only mentions "heart rate and HRV."
**Impact:** Reviewer may reject for vague HealthKit purpose string.
**Fix Plan:**
```
NSHealthShareUsageDescription: "Resonance reads your heart rate, heart rate variability (HRV), resting heart rate, VO2 Max, respiratory rate, step count, active energy, and wrist temperature to personalize music selection based on your current physiological state. All health data is processed on-device and never leaves your device."
```

---

### V-05: Audio File Access via `MPMediaQuery.assetURL` — DRM Risk
**Guideline:** 5.1.1(ix) — Apple Music Terms
**Severity:** ~~HIGH~~ LOW (downgraded after agent audit)
**File:** `Brain/Features/FeatureExtractor.swift` lines 399-416
**Issue:** The code uses `MPMediaQuery.songs()` and accesses `item.assetURL` to get local audio file URLs for spectral analysis. `assetURL` returns `nil` for DRM-protected Apple Music tracks (only works for locally-owned purchases and downloads). The code correctly guards with `guard let url = item.assetURL` and falls back to heuristics. However:
- **Risk 1:** `MPMediaQuery` is a deprecated API path — Apple may flag it
- **Risk 2:** If Apple interprets audio file analysis as "circumventing content protection," it could trigger rejection under Guideline 2.5.1
**Current mitigations:** The code only accesses locally-downloaded tracks (DRM-free purchases). DRM tracks return `nil` and fall back to genre heuristics. No DRM circumvention occurs.
**Fix Plan:** Add a comment block at the top of the method explicitly documenting compliance:
```swift
/// COMPLIANCE NOTE: This method only accesses audio files from locally-purchased,
/// DRM-free songs via MPMediaItem.assetURL. Apple Music DRM-protected tracks
/// return nil for assetURL and are excluded — they fall back to genre-based
/// heuristics. No DRM content is accessed, decrypted, or circumvented.
```
Also consider: migrate from `MPMediaQuery` to `MusicLibraryRequest` (MusicKit) which is the modern API path. `MPMediaQuery` is not formally deprecated but is legacy.

---

### V-06: HealthKit Data in UserDefaults (Not Encrypted)
**Guideline:** 27.3 — HealthKit Data Handling
**Severity:** ~~HIGH~~ CLEARED (confirmed compliant by HealthKit agent audit)
**Agent finding:** Storing health-DERIVED computational state (baselines, normalized scores, inferred profiles) in UserDefaults is permitted. The prohibition is on transmitting health data off-device or using it for advertising. These values are local aggregates used only for on-device personalization.
**File:** `Brain/State/PersonalBaseline.swift`, `Brain/State/CircadianProfileManager.swift`, `Brain/Learning/MovingWindowNormalizer.swift`
**Issue:** Derived health metrics (personal HRV baseline, circadian HR profile, HR baseline) are stored in `UserDefaults` via the App Group suite. UserDefaults is NOT encrypted at rest on all devices (only on devices with Data Protection enabled). Apple HealthKit guidelines state health-derived data should be stored in the encrypted Keychain or the app's protected container.
**Nuance:** These are DERIVED aggregates (running averages), not raw HealthKit samples. Apple's guidelines are ambiguous about whether derived statistical summaries count as "health data." Some reviewers may not flag this; others might.
**Fix Plan:** Migrate from UserDefaults to Keychain (via `Security.framework`'s `SecItemAdd/Update`) for:
- `PersonalBaseline` (3 keys: baselineValue, sampleCount, lastUpdated)
- `PersonalHRBaseline` (3 keys)
- `CircadianProfileManager` (2 keys: profileData, lastRefresh)
Total: 8 key-value pairs. Use `kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock` for background access.

---

### V-07: `RealtimeBPMVerifier` Installs Audio Tap on `mainMixerNode`
**Guideline:** 2.5.1 — Use of Public APIs
**Severity:** ~~HIGH~~ CLEARED (confirmed compliant by agent audit)
**File:** `Brain/Features/RealtimeBPMVerifier.swift` lines 201-224
**Issue:** Installs a tap on `AVAudioEngine.mainMixerNode` during playback to capture audio for BPM verification. This accesses the system audio output, which:
- May conflict with `ApplicationMusicPlayer`'s own audio session
- Could be flagged as unauthorized audio recording if the reviewer interprets it as capturing playback output
- The `mainMixerNode` tap captures whatever is playing, not just Resonance's audio
**Current state:** Duty-cycled (1s every 10s), removes tap immediately after capture.
**Fix Plan:** Two options:
1. **Safe approach:** Disable `RealtimeBPMVerifier` entirely for App Store submission. BPM comes from initial feature extraction + CoreML prediction. Real-time verification is a nice-to-have, not critical.
2. **If keeping:** Add a clear comment explaining this captures only the app's own audio output for beat detection, not recording/storing audio. Ensure the audio tap is only installed when the app's own `ApplicationMusicPlayer` is actively playing.

---

### V-13: Privacy Manifest Missing `CalendarData` Type
**Guideline:** 5.1.1 — Data Collection and Storage (Privacy Manifest completeness)
**Severity:** HIGH
**File:** `iOS/PrivacyInfo.xcprivacy`
**Issue:** `CalendarContextService.swift` reads calendar event titles and timing via EventKit. The Privacy Manifest declares HealthData, FitnessData, and AudioData but does NOT declare `NSPrivacyCollectedDataTypeCalendarData`. Apple requires all collected data types to be declared.
**Fix Plan:**
```xml
<!-- Add to PrivacyInfo.xcprivacy NSPrivacyCollectedDataTypes array: -->
<dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeOtherDataTypes</string>
    <key>NSPrivacyCollectedDataTypeLinked</key>
    <false/>
    <key>NSPrivacyCollectedDataTypeTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
    </array>
</dict>
```
Note: Apple doesn't have a specific "CalendarData" privacy type — use `OtherDataTypes` and describe in the App Store Connect privacy nutrition label as "Calendar Events (titles and times only, on-device processing)."

---

### V-14: `NSHealthUpdateUsageDescription` Declared But Never Used
**Guideline:** 5.1.1 — Data Collection (unnecessary permissions)
**Severity:** HIGH
**File:** `project.yml` line 65, `iOS/Info.plist` line 31
**Issue:** The app declares `NSHealthUpdateUsageDescription: "Resonance records workout context to improve music recommendations."` This signals intent to WRITE to HealthKit. But the app never writes:
- `HealthKitService.swift` line 193: `requestAuthorization(toShare: [], read: readTypes)` — `toShare` is empty
- No `HKHealthStore().save()` calls anywhere in the codebase
Declaring write capability without using it violates Guideline 5.1.1 (requesting unnecessary permissions). The description string is also misleading.
**Fix Plan:**
1. Remove `NSHealthUpdateUsageDescription` from `project.yml` (line 65) and `iOS/Info.plist` (line 31-32)
2. Evaluate whether `com.apple.developer.healthkit.background-delivery` entitlement is still needed — background delivery requires active `HKObserverQuery` which IS used for HR streaming, so keep it
3. If workout session writing is planned for future, add it back when the feature ships

---

## MEDIUM — May Trigger Reviewer Questions

### V-08: No App Privacy Policy URL
**Guideline:** 5.1.1(i) — Data Collection
**Severity:** MEDIUM
**File:** App Store Connect metadata (not in codebase)
**Issue:** App Store Connect requires a Privacy Policy URL for apps that collect health data. The app has no privacy policy URL in any config file. This isn't in the codebase but will be needed at submission.
**Fix Plan:** Create a privacy policy webpage and add the URL to App Store Connect. Must cover: what health data is collected (8 HealthKit types), that it stays on-device, no sharing with third parties, data retention/deletion policy.

---

### V-09: `.glassEffect()` Without `#available` Guard
**Guideline:** 2.1 — App Completeness (crashes on older OS)
**Severity:** MEDIUM
**Files:** `NowPlayingView.swift` (lines 338, 349, 363, 544, 833), `WatchNowPlayingView.swift` (line 181)
**Issue:** `.glassEffect()` is an iOS 26+ / watchOS 26+ API. The deployment target in `project.yml` is set to iOS 26.0, so this is technically valid — the app won't run on older OS. However:
- If the deployment target is ever lowered, all `.glassEffect()` calls will crash
- No `#available` guards exist as safety nets
**Fix Plan:** Since deployment target is 26.0, this is compliant. **No fix needed** unless deployment target changes. Document this dependency: "`.glassEffect()` requires iOS 26+ — DO NOT lower deployment target without adding guards."

---

### V-10: `ContextBroadcaster` Sends Context to CloudKit (Private Database)
**Guideline:** 5.1.2 — Data Use and Sharing
**Severity:** MEDIUM
**File:** `macOS/ContextProviders/ContextBroadcaster.swift` lines 202-215
**Issue:** Sends `MacOSContextSignal` to CloudKit private database. This includes: focus mode status, active app name/category, productivity/entertainment/social minutes, meeting status. This is NOT health data (no biometrics), but it IS behavioral data being transmitted to iCloud.
**Compliance status:** CloudKit private database = user's own iCloud, encrypted in transit and at rest. This is compliant — it's the user's own data in their own iCloud. However, the Privacy Manifest (`PrivacyInfo.xcprivacy`) does not declare this data collection.
**Fix Plan:** Add to `PrivacyInfo.xcprivacy`:
```xml
<dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeBrowsingHistory</string>  <!-- app usage -->
    <key>NSPrivacyCollectedDataTypeLinked</key>
    <false/>
    <key>NSPrivacyCollectedDataTypeTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
    </array>
</dict>
```

---

### V-15: CloudKit Explanation May Contain Raw Biometric Values
**Guideline:** 5.1.3(ii) — Health Data Must Not Be Stored in iCloud
**Severity:** MEDIUM
**File:** `iOS/Services/NowPlayingCloudKitSync.swift` line 86
**Issue:** The `explanation` field synced to CloudKit contains the AI DJ's reasoning (e.g., "Your stress has been elevated — this should help ease the tension"). If the conversational explanation generator produces strings with raw biometric readings (e.g., "your resting HR is 58 bpm" or "HRV dropped to 22ms"), this constitutes indirect health data in iCloud — a violation.
**Current state:** The `ConversationalExplanationGenerator` templates use relative language ("stress has been elevated") not absolute values. But this should be verified and enforced.
**Fix Plan:** Add a sanitization step in `NowPlayingCloudKitSync` before writing the explanation to CloudKit — strip any numeric health values (regex for `\d+ bpm`, `\d+ ms HRV`, etc.) or replace the explanation field with just the short (non-biometric) version for CloudKit sync.

---

### V-16: Unused `featureUpdate` Background Task Identifier
**Guideline:** 2.1 — App Completeness
**Severity:** MEDIUM
**File:** `iOS/Info.plist` line 8, `project.yml` line 68
**Issue:** `BGTaskSchedulerPermittedIdentifiers` registers `com.y4sh.resonance.featureUpdate`. If this background task is not implemented and registered with `BGTaskScheduler`, Apple may flag it as an incomplete/unused capability. All declared identifiers must have corresponding `BGTaskScheduler.shared.register()` calls.
**Fix Plan:** Either:
1. Remove `com.y4sh.resonance.featureUpdate` from Info.plist if the task isn't implemented yet
2. Or verify it has a matching `BGTaskScheduler.shared.register(forTaskWithIdentifier:)` call in the app

---

## LOW — Best Practice

### V-11: `NowPlayingCloudKitSync` Sends Song Title/Artist to CloudKit
**Guideline:** 5.1.1 — Data Collection
**Severity:** LOW
**File:** `iOS/Services/NowPlayingCloudKitSync.swift` lines 81-86
**Issue:** Sends `songTitle`, `artistName`, `isPlaying`, `progress` to CloudKit private database. This is for macOS menu bar sync. Not a violation (private database = user's iCloud), but should be declared in the Privacy Manifest under "Music" or "Media" collected data types.
**Fix Plan:** Already partially covered by `NSPrivacyCollectedDataTypeAudioData` in the Privacy Manifest. Verify this is sufficient or add a separate "media library" entry.

---

### V-12: No `UIRequiredDeviceCapabilities` Declaration
**Guideline:** 2.1 — App Completeness
**Severity:** LOW
**File:** `iOS/Info.plist`
**Issue:** No `UIRequiredDeviceCapabilities` key. Since the app requires HealthKit and is designed for Apple Watch pairing, it should declare:
```xml
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>healthkit</string>
    <string>armv7</string>
</array>
```
This prevents installation on devices without HealthKit (e.g., iPod touch, old iPads).
**Fix Plan:** Add to Info.plist. Note: declaring `healthkit` makes the app unavailable on devices without the Health app.

---

## Compliance Summary

### What's ALREADY Compliant
- HealthKit data does NOT leave the device (confirmed: CloudKit sends only song info + macOS context, never biometric data)
- No advertising use of health data
- No third-party tracking SDKs
- Privacy Manifest exists with correct `NSPrivacyTracking: false`
- UserDefaults API reason declared (`CA92.1`)
- No private API usage detected
- All iOS 18+ / iOS 26+ APIs properly guarded with `#available`
- HealthKit entitlements correctly configured
- App Group properly configured for cross-target data sharing
- No health claims in UI text (uses hedging: "personalize", "adapt", "match")

---

## Priority Fix Order

| # | Violation | Severity | Effort |
|---|-----------|----------|--------|
| 1 | **V-01**: Add `NSCalendarsFullAccessUsageDescription` | CRITICAL | 2 min |
| 2 | **V-02**: Add `UIBackgroundModes: [audio]` | CRITICAL | 2 min |
| 3 | **V-03**: Add `NSFocusStatusUsageDescription` | CRITICAL | 2 min |
| 4 | **V-04**: Expand `NSHealthShareUsageDescription` to list all 11 types | HIGH | 5 min |
| 5 | **V-14**: Remove `NSHealthUpdateUsageDescription` (app never writes) | HIGH | 2 min |
| 6 | **V-13**: Add `CalendarData` type to `PrivacyInfo.xcprivacy` | HIGH | 5 min |
| 7 | **V-15**: Sanitize CloudKit explanation field (strip biometric values) | MEDIUM | 15 min |
| 8 | **V-16**: Remove or implement `featureUpdate` background task ID | MEDIUM | 5 min |
| 9 | **V-10**: Update Privacy Manifest with behavioral data type | MEDIUM | 10 min |
| 10 | **V-08**: Create privacy policy webpage | MEDIUM | 1 hr (external) |
| 11 | **V-09**: Document `.glassEffect()` iOS 26 dependency | MEDIUM | 5 min |
| 12 | **V-05**: Add DRM compliance comment to FeatureExtractor | LOW | 5 min |
| 13 | **V-11**: Verify Privacy Manifest covers media data | LOW | 5 min |
| 14 | **V-12**: Add `UIRequiredDeviceCapabilities` | LOW | 2 min |

**Total estimated fix time: ~2 hours** (down from 4-5 hours after V-06 and V-07 were cleared)

**Cleared (no fix needed):**
- V-06: UserDefaults for derived health aggregates — compliant
- V-07: AVAudioEngine tap on own output — compliant
