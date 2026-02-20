//
//  MainView.swift
//  Resonance
//
//  Root tab-based navigation view for the iOS app.
//  Three tabs for M1: Now Playing, Playlists, Settings.
//

import SwiftUI

// MARK: - Main View

struct MainView: View {
    // MARK: - Properties

    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var playlistViewModel: PlaylistViewModel
    let musicService: MusicKitService

    @State private var selectedTab: Tab = .nowPlaying

    // MARK: - Tab Definition

    enum Tab: Int, CaseIterable {
        case nowPlaying
        case playlists
        case settings

        var title: String {
            switch self {
            case .nowPlaying: return "Now Playing"
            case .playlists: return "Playlists"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .nowPlaying: return "play.circle.fill"
            case .playlists: return "music.note.list"
            case .settings: return "gear"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            NowPlayingView(viewModel: nowPlayingViewModel)
                .tabItem {
                    Label(Tab.nowPlaying.title, systemImage: Tab.nowPlaying.systemImage)
                }
                .tag(Tab.nowPlaying)

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

            SettingsView(musicService: musicService)
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.systemImage)
                }
                .tag(Tab.settings)
        }
        .tint(.blue)
        .onAppear {
            logDebug("MainView appeared", category: .ui)
        }
    }
}

// MARK: - Preview

#Preview {
    MainView(
        nowPlayingViewModel: NowPlayingViewModel(musicService: MusicKitService()),
        playlistViewModel: PlaylistViewModel(musicService: MusicKitService()),
        musicService: MusicKitService()
    )
}
