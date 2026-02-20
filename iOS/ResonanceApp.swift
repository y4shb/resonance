//
//  ResonanceApp.swift
//  Resonance
//
//  Main entry point for the iOS app.
//  Creates the MusicKitService and view models, then presents MainView.
//

import SwiftUI
import MusicKit

@main
struct ResonanceApp: App {
    // MARK: - State

    /// Persistence controller for Core Data
    let persistenceController = PersistenceController.shared

    /// MusicKit service for Apple Music integration
    @StateObject private var musicService = MusicKitService()

    /// View model for the Now Playing screen
    @StateObject private var nowPlayingViewModel: NowPlayingViewModel

    /// View model for the Playlist Browser
    @StateObject private var playlistViewModel: PlaylistViewModel

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
        // Background task registration will be expanded in future phases
        logDebug("Background tasks registration placeholder", category: .background)
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
