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
        case insights
        case settings

        var title: String {
            switch self {
            case .nowPlaying: return "Now Playing"
            case .mood: return "Mood"
            case .playlists: return "Playlists"
            case .insights: return "Insights"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .nowPlaying: return "play.circle"
            case .mood: return "face.smiling"
            case .playlists: return "music.note.list"
            case .insights: return "chart.bar.xaxis"
            case .settings: return "gear"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch selectedTab {
            case .nowPlaying:
                NavigationStack {
                    NowPlayingView(
                        viewModel: nowPlayingViewModel,
                        stateEngine: stateEngine,
                        heroNamespace: heroNamespace,
                        onBrowsePlaylists: { selectedTab = .playlists }
                    )
                }
            case .mood:
                MoodTabView(stateEngine: stateEngine)
            case .playlists:
                NavigationStack {
                    PlaylistBrowserView(
                        viewModel: playlistViewModel,
                        onPlaylistSelected: { _ in selectedTab = .nowPlaying }
                    )
                }
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
        .animation(.spring(RetroAnimation.traySlide), value: selectedTab)
        .safeAreaInset(edge: .bottom) {
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
        .animation(.spring(RetroAnimation.traySlide), value: shouldShowMiniPlayer)
        .retroAccentColor(nowPlayingViewModel.artworkAccentColor)
        .onAppear {
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
