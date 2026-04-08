//
//  MainView.swift
//  Resonance
//
//  Root tab-based navigation view for the iOS app.
//  Four tabs: Now Playing, Mood, Playlists, Settings.
//  Includes a persistent MiniPlayerView as a tab bar bottom accessory
//  (iOS 26+) that shows current track info and transport controls.
//

import SwiftUI

// MARK: - Main View

struct MainView: View {
    // MARK: - Properties

    @Bindable var nowPlayingViewModel: NowPlayingViewModel
    @Bindable var playlistViewModel: PlaylistViewModel
    let musicService: MusicKitService
    @ObservedObject var historicalEngine: HistoricalEngine
    @ObservedObject var stateEngine: StateEngine

    /// Optional namespace for matchedGeometryEffect transition from landing screen
    var heroNamespace: Namespace.ID?

    @State private var selectedTab: Tab = .nowPlaying

    // MARK: - Tab Definition

    enum Tab: Int, CaseIterable {
        case nowPlaying
        case mood
        case playlists
        case settings

        var title: String {
            switch self {
            case .nowPlaying: return "Now Playing"
            case .mood: return "Mood"
            case .playlists: return "Playlists"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .nowPlaying: return "play.circle"
            case .mood: return "face.smiling"
            case .playlists: return "music.note.list"
            case .settings: return "gear"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            NowPlayingView(
                    viewModel: nowPlayingViewModel,
                    stateEngine: stateEngine,
                    heroNamespace: heroNamespace,
                    onBrowsePlaylists: { selectedTab = .playlists }
                )
                .tabItem {
                    Label(Tab.nowPlaying.title, systemImage: Tab.nowPlaying.systemImage)
                }
                .tag(Tab.nowPlaying)

            MoodTabView(stateEngine: stateEngine)
                .tabItem {
                    Label(Tab.mood.title, systemImage: Tab.mood.systemImage)
                }
                .tag(Tab.mood)

            PlaylistBrowserView(
                viewModel: playlistViewModel,
                onPlaylistSelected: { _ in
                    // Switch to Now Playing tab after selecting a playlist
                    selectedTab = .nowPlaying
                }
            )
            .tabItem {
                Label(Tab.playlists.title, systemImage: Tab.playlists.systemImage)
            }
            .tag(Tab.playlists)

            SettingsView(
                musicService: musicService,
                historicalEngine: historicalEngine,
                stateEngine: stateEngine
            )
            .tabItem {
                Label(Tab.settings.title, systemImage: Tab.settings.systemImage)
            }
            .tag(Tab.settings)
        }
        .safeAreaInset(edge: .bottom) {
            if shouldShowMiniPlayer {
                MiniPlayerView(
                    viewModel: nowPlayingViewModel,
                    onTapNavigate: {
                        selectedTab = .nowPlaying
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity).animation(.easeIn(duration: 0.2))
                ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: shouldShowMiniPlayer)
        .tint(ResonanceColors.accent)
        .onAppear {
            // When no playlist is active, default to .playlists so the user
            // lands on the playlist picker instead of an empty Now Playing screen.
            if nowPlayingViewModel.activePlaylistName == nil {
                selectedTab = .playlists
            }
            logDebug("MainView appeared", category: .ui)
        }
    }

    // MARK: - Mini Player Visibility

    /// Shows the mini player when a song is loaded and the user is NOT on the Now Playing tab.
    /// The mini player is hidden on the Now Playing tab to avoid duplicating controls.
    private var shouldShowMiniPlayer: Bool {
        let hasSong = nowPlayingViewModel.currentSong != .placeholder
        let isOnNowPlaying = selectedTab == .nowPlaying
        return hasSong && !isOnNowPlaying
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
