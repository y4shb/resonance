//
//  ResonanceApp.swift
//  Resonance
//
//  Main entry point for the iOS app.
//  Creates the MusicKitService and view models, then presents MainView.
//

import SwiftUI
import MusicKit
import HealthKit
import BackgroundTasks
import Combine
import WidgetKit

@main
struct ResonanceApp: App {
    // MARK: - State

    /// Whether the user has completed the onboarding flow
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Scene phase for detecting foreground/background transitions
    @Environment(\.scenePhase) private var scenePhase

    /// Persistence controller for Core Data
    let persistenceController = PersistenceController.shared

    /// MusicKit service for Apple Music integration
    @StateObject private var musicService: MusicKitService

    /// View model for the Now Playing screen
    @StateObject private var nowPlayingViewModel: NowPlayingViewModel

    /// View model for the Playlist Browser
    @StateObject private var playlistViewModel: PlaylistViewModel

    /// HealthKit service for biometric data access
    @StateObject private var healthKitService: HealthKitService

    /// Event logger for tracking playback events
    @StateObject private var eventLogger: EventLogger

    /// Context collector for aggregating biometric and environmental signals
    @StateObject private var contextCollector: ContextCollector

    /// Historical backfill engine for processing past playback data
    @StateObject private var historicalEngine: HistoricalEngine

    /// Real-time state estimation engine
    @StateObject private var stateEngine: StateEngine

    /// AI DJ decision engine
    @StateObject private var decisionEngine: DecisionEngine

    /// Real-time learning store
    @StateObject private var learningStore: LearningStore

    /// Real-time guard adjuster
    @StateObject private var guardAdjuster: RealTimeGuardAdjuster

    /// WatchConnectivity manager for iPhone <-> Watch communication
    private let watchConnectivityManager = WatchConnectivityManager.shared

    // MARK: - Initialization

    init() {
        // Configure logging
        #if DEBUG
        Logger.shared.setMinimumLevel(.debug)
        #else
        Logger.shared.setMinimumLevel(.info)
        #endif

        logInfo("Resonance iOS app launching", category: .general)

        // Create the shared MusicKitService instance for dependency injection.
        // We need a local reference so that @StateObject wrappers can capture it.
        let service = MusicKitService()

        let nowPlaying = NowPlayingViewModel(musicService: service)
        let playlists = PlaylistViewModel(musicService: service, nowPlayingViewModel: nowPlaying)

        _musicService = StateObject(wrappedValue: service)
        _nowPlayingViewModel = StateObject(wrappedValue: nowPlaying)
        _playlistViewModel = StateObject(wrappedValue: playlists)

        // Wire Watch connectivity to NowPlayingViewModel for bidirectional sync
        nowPlaying.connectWatchManager(WatchConnectivityManager.shared)

        // Initialize EventLogger and ContextCollector with the StateObject wrapping pattern
        let eventLogger = EventLogger()
        _eventLogger = StateObject(wrappedValue: eventLogger)
        nowPlaying.eventLogger = eventLogger

        let contextCollector = ContextCollector()
        _contextCollector = StateObject(wrappedValue: contextCollector)

        // Give EventLogger access to biometric data for auto-detected song transitions.
        eventLogger.contextCollector = contextCollector

        let hkService = HealthKitService()
        _healthKitService = StateObject(wrappedValue: hkService)

        let historicalEngine = HistoricalEngine(healthKitService: hkService)
        _historicalEngine = StateObject(wrappedValue: historicalEngine)

        let stateEngine = StateEngine(contextCollector: contextCollector, healthKitService: hkService)
        _stateEngine = StateObject(wrappedValue: stateEngine)

        let decisionEngine = DecisionEngine()
        _decisionEngine = StateObject(wrappedValue: decisionEngine)
        nowPlaying.decisionEngine = decisionEngine
        nowPlaying.stateEngine = stateEngine

        // Create and wire learning store + guard adjuster
        let learningStore = LearningStore()
        _learningStore = StateObject(wrappedValue: learningStore)

        let guardAdjuster = RealTimeGuardAdjuster()
        _guardAdjuster = StateObject(wrappedValue: guardAdjuster)

        // Wire learning store to NowPlayingViewModel
        nowPlaying.connectLearningStore(learningStore, eventLogger: eventLogger)
        nowPlaying.guardAdjuster = guardAdjuster

        // Wire guard adjuster to DecisionEngine
        decisionEngine.guardAdjuster = guardAdjuster

        // Wire mood input from Watch → StateEngine
        contextCollector.onMoodInput = { [weak stateEngine] packet in
            let energy = Double(packet.energyLevel) / 5.0
            let valence = Double(packet.moodLevel) / 5.0
            Task { @MainActor in
                stateEngine?.setManualMood(energy: energy, valence: valence)
            }
        }

        logInfo("View models initialized with Watch connectivity", category: .general)

        // Register background tasks
        registerBackgroundTasks()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainView(
                        nowPlayingViewModel: nowPlayingViewModel,
                        playlistViewModel: playlistViewModel,
                        musicService: musicService,
                        historicalEngine: historicalEngine,
                        stateEngine: stateEngine
                    )
                } else {
                    OnboardingContainerView(
                        hasCompletedOnboarding: $hasCompletedOnboarding,
                        musicService: musicService
                    )
                }
            }
            .environment(\.managedObjectContext, persistenceController.viewContext)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Re-check authorization when returning from Settings
                    musicService.refreshAuthorizationStatus()
                }
            }
            .task {
                await requestMusicKitAuthorization()

                // Request HealthKit authorization
                do {
                    try await healthKitService.requestAuthorization()
                    try await healthKitService.enableBackgroundDelivery()
                } catch {
                    logWarning("HealthKit setup failed: \(error.localizedDescription)", category: .healthKit)
                }

                // Start context collection, event logging, and state engine
                contextCollector.startCollecting()
                eventLogger.observeNowPlaying(musicService.nowPlayingPublisher)
                stateEngine.startUpdating()

                // Wire biometric updates to guard adjuster for real-time filtering
                Self.biometricCancellable = watchConnectivityManager.biometricUpdates
                    .receive(on: DispatchQueue.main)
                    .sink { [weak guardAdjuster, weak stateEngine] packet in
                        if let hr = packet.heartRate {
                            guardAdjuster?.recordHeartRate(hr, currentNeed: stateEngine?.currentState.inferredNeed)
                        }
                    }

                // Wire state engine changes to iOS widgets
                stateEngine.$currentState
                    .debounce(for: .seconds(30), scheduler: DispatchQueue.main)
                    .sink { state in
                        WidgetDataStore.updateState(
                            emoji: state.context.emoji,
                            stateName: state.context.displayName,
                            energy: state.energy,
                            heartRate: nil,
                            context: state.context.rawValue
                        )
                    }
                    .store(in: &Self.widgetCancellables)

                // Wire EventLogger active event to ContextCollector for biometric tagging
                contextCollector.observeEventLogger(eventLogger)
            }
            .onAppear {
                watchConnectivityManager.activate()
                logInfo("WatchConnectivity activated", category: .watchConnectivity)
            }
        }
    }

    // MARK: - MusicKit Authorization

    private func requestMusicKitAuthorization() async {
        logInfo("Requesting MusicKit authorization on launch", category: .musicKit)

        let status = await musicService.requestAuthorization()

        switch status {
        case .authorized:
            logInfo("MusicKit authorized -- ready to access Apple Music", category: .musicKit)
        case .denied:
            logWarning("MusicKit authorization denied -- features will be limited", category: .musicKit)
        case .restricted:
            logWarning("MusicKit authorization restricted on this device", category: .musicKit)
        case .notDetermined:
            logDebug("MusicKit authorization still not determined", category: .musicKit)
        @unknown default:
            logWarning("MusicKit returned unknown authorization status", category: .musicKit)
        }
    }

    // MARK: - Background Tasks

    /// Holds the biometric-to-guard-adjuster subscription across struct copies.
    private static var biometricCancellable: AnyCancellable?

    /// Holds the state-engine-to-widget subscription across struct copies.
    private static var widgetCancellables = Set<AnyCancellable>()

    /// Guard against double-registration crash (BGTaskScheduler crashes if register() called twice for same ID)
    private static var hasRegisteredTasks = false

    private func registerBackgroundTasks() {
        guard !Self.hasRegisteredTasks else {
            logDebug("Background tasks already registered, skipping", category: .background)
            return
        }
        Self.hasRegisteredTasks = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskConstants.TaskIdentifier.playlistSync,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handlePlaylistSync(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskConstants.TaskIdentifier.featureUpdate,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleFeatureUpdate(task: processingTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskConstants.TaskIdentifier.historicalAnalysis,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleHistoricalAnalysis(task: processingTask)
        }

        schedulePlaylistSync()
        scheduleFeatureUpdate()
        scheduleHistoricalAnalysis()

        logInfo("Background tasks registered", category: .background)
    }

    private func handlePlaylistSync(task: BGAppRefreshTask) {
        let syncTask = Task {
            let musicService = MusicKitService()
            let playlists = try await musicService.fetchUserPlaylists()
            let repo = PlaylistRepository()
            try await repo.syncPlaylists(from: playlists)
        }
        task.expirationHandler = { syncTask.cancel() }
        Task {
            do {
                try await syncTask.value
                task.setTaskCompleted(success: true)
            } catch {
                logError("Background playlist sync failed", error: error, category: .background)
                task.setTaskCompleted(success: false)
            }
            schedulePlaylistSync()
        }
    }

    private func handleFeatureUpdate(task: BGProcessingTask) {
        let featureTask = Task {
            let extractor = FeatureExtractor()
            await extractor.extractFeaturesForPendingSongs(limit: 100)
        }
        task.expirationHandler = { featureTask.cancel() }
        Task {
            await featureTask.value
            task.setTaskCompleted(success: true)
            scheduleFeatureUpdate()
        }
    }

    private func schedulePlaylistSync() {
        let request = BGAppRefreshTaskRequest(
            identifier: BackgroundTaskConstants.TaskIdentifier.playlistSync
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow:
            Double(BackgroundTaskConstants.playlistSyncIntervalHours) * 3600
        )
        do {
            try BGTaskScheduler.shared.submit(request)
            logDebug("Playlist sync scheduled", category: .background)
        } catch {
            logError("Failed to schedule playlist sync", error: error, category: .background)
        }
    }

    private func scheduleFeatureUpdate() {
        let request = BGProcessingTaskRequest(
            identifier: BackgroundTaskConstants.TaskIdentifier.featureUpdate
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow:
            Double(BackgroundTaskConstants.featureUpdateIntervalHours) * 3600
        )
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
            logDebug("Feature update scheduled", category: .background)
        } catch {
            logError("Failed to schedule feature update", error: error, category: .background)
        }
    }

    // MARK: - Historical Analysis Background Task

    private func handleHistoricalAnalysis(task: BGProcessingTask) {
        let analysisTask = Task {
            await historicalEngine.runIncrementalBackfill()
        }
        task.expirationHandler = {
            // Cancelling the task triggers CancellationError in SessionReconstructor
            // and SongImpactCalculator via Task.checkCancellation()
            analysisTask.cancel()
        }
        Task {
            await analysisTask.value
            task.setTaskCompleted(success: true)
            scheduleHistoricalAnalysis()
        }
    }

    private func scheduleHistoricalAnalysis() {
        let request = BGProcessingTaskRequest(
            identifier: BackgroundTaskConstants.TaskIdentifier.historicalAnalysis
        )
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow:
            Double(BackgroundTaskConstants.historicalAnalysisIntervalDays) * 86400
        )
        do {
            try BGTaskScheduler.shared.submit(request)
            logDebug("Historical analysis scheduled", category: .background)
        } catch {
            logError("Failed to schedule historical analysis", error: error, category: .background)
        }
    }
}

// MARK: - Preview

#Preview {
    let service = MusicKitService()
    let hkService = HealthKitService()
    let contextCollector = ContextCollector()
    MainView(
        nowPlayingViewModel: NowPlayingViewModel(musicService: service),
        playlistViewModel: PlaylistViewModel(musicService: service),
        musicService: service,
        historicalEngine: HistoricalEngine(healthKitService: hkService),
        stateEngine: StateEngine(contextCollector: contextCollector, healthKitService: hkService)
    )
}
