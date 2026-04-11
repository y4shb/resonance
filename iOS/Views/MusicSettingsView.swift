//
//  MusicSettingsView.swift
//  Resonance
//
//  "My Music" settings: Apple Music connection, library analysis,
//  playlist management, and cross-playlist recommendations.
//

import SwiftUI
import MusicKit

// MARK: - Music Settings View

struct MusicSettingsView: View {
    @ObservedObject var musicService: MusicKitService
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    @State private var isRequestingAuth = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectionSection
                librarySection
                playlistSection
            }
            .padding()
        }
        .background(ResonanceColors.panelBg)
        .navigationTitle("My Music")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Connection Section (moved from SettingsView.musicKitSection)

    private var connectionSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("MUSIC ACCESS")
                    .retroEngravedLabel()

                HStack {
                    Label("Apple Music", systemImage: "music.note")
                    Spacer()
                    authStatusLED
                }

                if musicService.authorizationStatus != .authorized {
                    Button(action: requestAuthorization) {
                        HStack {
                            Text("Grant Access")
                            if isRequestingAuth {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRequestingAuth || musicService.authorizationStatus == .denied)
                }

                if musicService.authorizationStatus == .denied {
                    Text("Access was denied. Please enable Apple Music in Settings > Privacy > Media & Apple Music.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Resonance requires an Apple Music subscription to play music and access your library.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    // MARK: - Auth Status LED (replaces badge)

    @ViewBuilder
    private var authStatusLED: some View {
        switch musicService.authorizationStatus {
        case .authorized:
            RetroLEDIndicator(isOn: true, color: ResonanceColors.ledGreen)
        case .denied:
            RetroLEDIndicator(isOn: true, color: ResonanceColors.ledRed)
        case .restricted:
            RetroLEDIndicator(isOn: true, color: ResonanceColors.ledAmber)
        case .notDetermined:
            RetroLEDIndicator(isOn: false, color: ResonanceColors.ledAmber)
        @unknown default:
            RetroLEDIndicator(isOn: false, color: ResonanceColors.ledAmber)
        }
    }

    // MARK: - Library Section

    private var librarySection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("LIBRARY")
                    .retroEngravedLabel()

                Button {
                    // Trigger library re-scan via notification so the app coordinator can handle it
                    NotificationCenter.default.post(name: .resonanceRescanLibrary, object: nil)
                } label: {
                    Label("Re-scan Music Library", systemImage: "arrow.clockwise")
                }
                .disabled(musicService.authorizationStatus != .authorized)

                Text("Re-analyzes your Apple Music library to discover new songs and update audio features.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    // MARK: - Playlist Section

    private var playlistSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("PLAYLISTS")
                    .retroEngravedLabel()

                HStack {
                    Text("Cross-Playlist Recommendations")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.allowCrossPlaylistRecommendations,
                        label: ""
                    )
                }
                .onChange(of: preferences.allowCrossPlaylistRecommendations) { _, _ in
                    onSave()
                }

                Text("Let the AI DJ pick songs from other playlists when they fit your current mood better.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    // MARK: - Actions (moved from SettingsView)

    private func requestAuthorization() {
        isRequestingAuth = true
        logInfo("User tapped request authorization", category: .ui)

        Task {
            await musicService.requestAuthorization()
            await MainActor.run { isRequestingAuth = false }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let resonanceRescanLibrary = Notification.Name("resonanceRescanLibrary")
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MusicSettingsView(
            musicService: MusicKitService(),
            preferences: .constant(UserPreferences.load()),
            onSave: { }
        )
    }
}
