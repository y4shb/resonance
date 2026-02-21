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

@main
struct ResonanceApp: App {
    // MARK: - State

    /// Persistence controller for Core Data
    let persistenceController = PersistenceController.shared

    /// MusicKit service for Apple Music integration
    @StateObject private var musicService: MusicKitService

    /// View model for the Now Playing screen
    @StateObject private var nowPlayingViewModel: NowPlayingViewModel

    /// View model for the Playlist Browser
    @StateObject private var playlistViewModel: PlaylistViewModel

    /// HealthKit service for biometric data access
    @StateObject private var healthKitService = HealthKitService()

    /// Event logger for tracking playback events
    @StateObject private var eventLogger: EventLogger

    /// Context collector for aggregating biometric and environmental signals
    @StateObject private var contextCollector: ContextCollector

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

        logInfo("View models initialized with Watch connectivity", category: .general)

        // Register background tasks
        registerBackgroundTasks()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            MainView(
                nowPlayingViewModel: nowPlayingViewModel,
                playlistViewModel: playlistViewModel,
                musicService: musicService
            )
            .environment(\.managedObjectContext, persistenceController.viewContext)
            .task {
                await requestMusicKitAuthorization()

                // Request HealthKit authorization
                do {
                    try await healthKitService.requestAuthorization()
                    try await healthKitService.enableBackgroundDelivery()
                } catch {
                    logWarning("HealthKit setup failed: \(error.localizedDescription)", category: .healthKit)
                }

                // Start context collection and event logging
                contextCollector.startCollecting()
                eventLogger.observeNowPlaying(musicService.nowPlayingPublisher)

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

    private func registerBackgroundTasks() {
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

        schedulePlaylistSync()
        scheduleFeatureUpdate()

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
}

// MARK: - Preview

#Preview {
    let service = MusicKitService()
    MainView(
        nowPlayingViewModel: NowPlayingViewModel(musicService: service),
        playlistViewModel: PlaylistViewModel(musicService: service),
        musicService: service
    )
}
