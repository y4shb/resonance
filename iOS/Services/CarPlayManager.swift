//
//  CarPlayManager.swift
//  Resonance
//
//  Manages CarPlay lifecycle, UI, and commute session orchestration.
//  Auto-detects CarPlay connection via UIScene lifecycle, determines
//  morning vs evening commute using CircadianProfileManager, and presents
//  a simplified CPNowPlayingTemplate with mode-toggle and HR-zone buttons.
//
//  Safety: NEVER display complex UI or alerts while driving.
//  All interactions are simple button presses on the now-playing template.
//
//  Integration: AudioRouteService, SessionPlanner, DecisionEngine,
//  CircadianProfileManager, DrowsinessDetector
//

#if os(iOS)

#if canImport(CarPlay)
import CarPlay
#endif
import Foundation
import Combine

// MARK: - Commute Direction

/// Whether the user is heading to work (morning) or heading home (evening).
enum CommuteDirection: String, Sendable {
    /// Morning commute: escalating energy arc (low -> high).
    case morning

    /// Evening commute: decompression arc (high -> low).
    case evening

    var displayName: String {
        switch self {
        case .morning: return "Morning Commute"
        case .evening: return "Evening Commute"
        }
    }

    /// The arc template to use for this commute direction.
    var arcTemplate: ArcTemplate {
        switch self {
        case .morning: return .commuteEnergize
        case .evening: return .commuteDecompress
        }
    }
}

// MARK: - Commute Mode

/// User-togglable mode override for the commute session.
enum CommuteMode: String, Sendable {
    /// Energize: bias toward higher BPM, more upbeat tracks.
    case energize

    /// Calm: bias toward lower BPM, more relaxed tracks.
    case calm

    var displayName: String {
        switch self {
        case .energize: return "Energize"
        case .calm: return "Calm"
        }
    }

    var toggled: CommuteMode {
        switch self {
        case .energize: return .calm
        case .calm: return .energize
        }
    }
}

// MARK: - CarPlay Constants

enum CarPlayConstants {
    /// Morning commute window: hours considered "morning" for direction detection.
    static let morningStartHour = 5
    static let morningEndHour = 11

    /// Evening commute window: hours considered "evening" for direction detection.
    static let eveningStartHour = 15
    static let eveningEndHour = 22

    /// Default commute session duration estimate (minutes).
    static let defaultCommuteDurationMinutes: TimeInterval = 30

    /// Heart rate zone labels for the now-playing button.
    static let hrZoneLabels = ["--", "Rest", "Easy", "Moderate", "Hard", "Max"]
}

// MARK: - CarPlay Manager

/// Manages the CarPlay experience: connection lifecycle, now-playing template,
/// commute direction detection, and integration with the DJ brain.
/// Conforms to CPTemplateApplicationSceneDelegate for CarPlay scene events.
#if canImport(CarPlay)
final class CarPlayManager: NSObject, CPTemplateApplicationSceneDelegate, ObservableObject {

    // MARK: - Singleton

    static let shared = CarPlayManager()

    // MARK: - Published State

    /// Whether a CarPlay session is currently active.
    @Published private(set) var isConnected = false

    /// Detected commute direction.
    @Published private(set) var commuteDirection: CommuteDirection = .morning

    /// Current user-selected commute mode.
    @Published private(set) var currentMode: CommuteMode = .energize

    /// Current HR zone label for the now-playing button.
    @Published private(set) var currentHRZoneLabel: String = CarPlayConstants.hrZoneLabels[0]

    // MARK: - Dependencies

    /// Set externally after init. Provides circadian profile for commute direction.
    weak var circadianProfileManager: CircadianProfileManager?

    /// Set externally after init. Provides the decision pipeline.
    weak var decisionEngine: DecisionEngine?

    /// Set externally after init. Provides audio route awareness.
    weak var audioRouteService: AudioRouteService?

    /// Set externally after init. Provides drowsiness detection.
    weak var drowsinessDetector: DrowsinessDetector?

    // MARK: - CarPlay State

    private var interfaceController: CPInterfaceController?
    private var nowPlayingTemplate: CPNowPlayingTemplate?
    private var sessionStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private override init() {
        super.init()
        logInfo("CarPlayManager initialized", category: .general)
    }

    // MARK: - CPTemplateApplicationSceneDelegate

    /// Called when the CarPlay scene connects. Sets up the now-playing template
    /// and auto-starts a commute session.
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        logInfo("CarPlay connected", category: .general)

        self.interfaceController = interfaceController
        isConnected = true

        detectCommuteDirection()
        configureNowPlayingTemplate()
        startCommuteSession()
        subscribeToStateUpdates()
    }

    /// Called when the CarPlay scene disconnects. Ends the commute session
    /// and cleans up resources.
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        logInfo("CarPlay disconnected", category: .general)

        endCommuteSession()
        cancellables.removeAll()
        self.interfaceController = nil
        nowPlayingTemplate = nil
        isConnected = false
    }

    // MARK: - Commute Direction Detection

    /// Determines morning vs evening commute using CircadianProfileManager's
    /// learned wake/sleep hours, or fixed hour thresholds as fallback.
    private func detectCommuteDirection() {
        let currentHour = Calendar.current.component(.hour, from: Date())

        if let profile = circadianProfileManager?.currentProfile {
            let wakeHour = profile.typicalWakeHour
            let sleepHour = profile.typicalSleepHour
            // Midpoint of active day
            let midpoint = wakeHour + (sleepHour - wakeHour) / 2

            if currentHour < midpoint {
                commuteDirection = .morning
                currentMode = .energize
            } else {
                commuteDirection = .evening
                currentMode = .calm
            }
        } else {
            // Fallback: fixed hour thresholds
            if currentHour >= CarPlayConstants.morningStartHour
                && currentHour < CarPlayConstants.morningEndHour {
                commuteDirection = .morning
                currentMode = .energize
            } else if currentHour >= CarPlayConstants.eveningStartHour
                && currentHour <= CarPlayConstants.eveningEndHour {
                commuteDirection = .evening
                currentMode = .calm
            } else {
                // Outside typical commute hours, default to energize
                commuteDirection = .morning
                currentMode = .energize
            }
        }

        logInfo(
            "Commute direction detected: \(commuteDirection.displayName) "
            + "(hour=\(currentHour), mode=\(currentMode.displayName))",
            category: .general
        )
    }

    // MARK: - Now Playing Template Configuration

    /// Configures CPNowPlayingTemplate with mode toggle and HR zone buttons.
    /// Safety: simple, glanceable buttons only. Compliant with CarPlay HIG.
    private func configureNowPlayingTemplate() {
        let template = CPNowPlayingTemplate.shared

        // Build custom buttons
        var buttons: [CPNowPlayingButton] = []

        // 1. Mode toggle button (Energize / Calm)
        let modeButton = CPNowPlayingImageButton(
            image: modeButtonImage(for: currentMode)
        ) { [weak self] _ in
            self?.toggleCommuteMode()
        }
        buttons.append(modeButton)

        // 2. Heart rate zone indicator (non-interactive display)
        let hrButton = CPNowPlayingImageButton(
            image: hrZoneImage()
        ) { _ in
            // No action -- purely informational.
            // Safety: Do NOT show alerts or complex UI while driving.
        }
        buttons.append(hrButton)

        template.updateNowPlayingButtons(buttons)

        nowPlayingTemplate = template

        // Set the template as root
        interfaceController?.setRootTemplate(template, animated: true, completion: nil)

        logDebug("CarPlay now-playing template configured", category: .general)
    }

    // MARK: - Mode Toggle

    /// Toggles between Energize and Calm modes.
    private func toggleCommuteMode() {
        currentMode = currentMode.toggled

        logInfo(
            "CarPlay mode toggled to: \(currentMode.displayName)",
            category: .general
        )

        // Refresh the now-playing buttons to reflect the new mode
        refreshNowPlayingButtons()

        // Notify the decision engine about the mode change.
        // The mode change affects which arc template is used for song selection.
        applyModeToSession()
    }

    /// Updates the now-playing buttons to reflect current state.
    private func refreshNowPlayingButtons() {
        guard let template = nowPlayingTemplate else { return }

        var buttons: [CPNowPlayingButton] = []

        let modeButton = CPNowPlayingImageButton(
            image: modeButtonImage(for: currentMode)
        ) { [weak self] _ in
            self?.toggleCommuteMode()
        }
        buttons.append(modeButton)

        let hrButton = CPNowPlayingImageButton(
            image: hrZoneImage()
        ) { _ in
            // Informational only -- no action for driving safety
        }
        buttons.append(hrButton)

        template.updateNowPlayingButtons(buttons)
    }

    // MARK: - Session Lifecycle

    /// Starts a commute session and resets the DecisionEngine.
    private func startCommuteSession() {
        sessionStartTime = Date()

        logInfo(
            "Commute session started: direction=\(commuteDirection.displayName), "
            + "mode=\(currentMode.displayName)",
            category: .general
        )

        // Reset the decision engine for a fresh commute session
        decisionEngine?.resetSession()

        applyModeToSession()
    }

    /// Ends the commute session and cleans up state.
    private func endCommuteSession() {
        guard let startTime = sessionStartTime else { return }

        let duration = Date().timeIntervalSince(startTime) / 60.0

        logInfo(
            "Commute session ended: duration=\(String(format: "%.1f", duration))min, "
            + "direction=\(commuteDirection.displayName)",
            category: .general
        )

        sessionStartTime = nil
    }

    /// Applies the current mode to the active session arc selection.
    private func applyModeToSession() {
        // Energize -> .commuteEnergize arc; Calm -> .commuteDecompress arc.
        // Actual arc selection happens in DecisionEngine.selectNextSong()
        // via the StateVector's context and effectiveArcTemplate.
        logDebug("Applying commute mode to session: \(currentMode.displayName)", category: .general)
    }

    // MARK: - State Subscription

    /// Subscribes to biometric state updates to refresh the HR zone indicator.
    private func subscribeToStateUpdates() {
        // Observe audio route changes
        audioRouteService?.$isCarAudioActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                if !isActive && self?.isConnected == true {
                    logDebug("Car audio route lost while CarPlay connected", category: .general)
                }
            }
            .store(in: &cancellables)
    }

    /// Updates the HR zone label on the now-playing template.
    func updateHRZone(heartRate: Double?, restingHeartRate: Double?) {
        guard let hr = heartRate, let resting = restingHeartRate, resting > 0 else {
            currentHRZoneLabel = CarPlayConstants.hrZoneLabels[0]
            refreshNowPlayingButtons()
            return
        }

        // Simple 5-zone model based on heart rate reserve
        let maxHR = 208.0 - 0.7 * 30.0  // Tanaka formula, default age 30
        let hrReserve = maxHR - resting
        guard hrReserve > 0 else {
            currentHRZoneLabel = CarPlayConstants.hrZoneLabels[0]
            refreshNowPlayingButtons()
            return
        }

        let percentage = (hr - resting) / hrReserve
        let zoneIndex: Int
        switch percentage {
        case ..<0.2:
            zoneIndex = 1  // Rest
        case 0.2..<0.4:
            zoneIndex = 2  // Easy
        case 0.4..<0.6:
            zoneIndex = 3  // Moderate
        case 0.6..<0.8:
            zoneIndex = 4  // Hard
        default:
            zoneIndex = 5  // Max
        }

        let label = CarPlayConstants.hrZoneLabels[zoneIndex]
        if label != currentHRZoneLabel {
            currentHRZoneLabel = label
            refreshNowPlayingButtons()
        }
    }

    /// Returns the activity context appropriate for the current commute mode.
    /// Used by the StateEngine to override context during CarPlay sessions.
    var effectiveActivityContext: ActivityContext {
        return .commute
    }

    /// Returns the arc template appropriate for the current commute mode.
    /// Used by the DecisionEngine to select the correct session arc.
    var effectiveArcTemplate: ArcTemplate {
        switch currentMode {
        case .energize: return .commuteEnergize
        case .calm: return .commuteDecompress
        }
    }

    // MARK: - Button Image Helpers

    /// Returns a system image for the mode toggle button.
    /// Uses SF Symbols for CarPlay compatibility.
    private func modeButtonImage(for mode: CommuteMode) -> UIImage {
        let symbolName: String
        switch mode {
        case .energize:
            symbolName = "bolt.fill"
        case .calm:
            symbolName = "leaf.fill"
        }

        return UIImage(systemName: symbolName)
            ?? UIImage(systemName: "music.note")!
    }

    /// Returns a system image representing the current HR zone.
    private func hrZoneImage() -> UIImage {
        let symbolName: String
        switch currentHRZoneLabel {
        case "Rest":
            symbolName = "heart"
        case "Easy":
            symbolName = "heart.fill"
        case "Moderate":
            symbolName = "heart.circle"
        case "Hard":
            symbolName = "heart.circle.fill"
        case "Max":
            symbolName = "bolt.heart.fill"
        default:
            symbolName = "heart.slash"
        }

        return UIImage(systemName: symbolName)
            ?? UIImage(systemName: "heart")!
    }
}

#else

// MARK: - Stub for non-CarPlay targets

/// Stub implementation when CarPlay framework is not available.
/// Provides the same public interface so callers do not need conditional compilation.
final class CarPlayManager: ObservableObject {

    static let shared = CarPlayManager()

    @Published private(set) var isConnected = false
    @Published private(set) var commuteDirection: CommuteDirection = .morning
    @Published private(set) var currentMode: CommuteMode = .energize
    @Published private(set) var currentHRZoneLabel: String = CarPlayConstants.hrZoneLabels[0]

    weak var circadianProfileManager: CircadianProfileManager?
    weak var decisionEngine: DecisionEngine?
    weak var audioRouteService: AudioRouteService?
    weak var drowsinessDetector: DrowsinessDetector?

    private init() {}

    var effectiveActivityContext: ActivityContext { .commute }
    var effectiveArcTemplate: ArcTemplate { .commuteEnergize }

    func updateHRZone(heartRate: Double?, restingHeartRate: Double?) {}
}

#endif

#endif
