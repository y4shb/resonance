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
        List {
            connectionSection
            librarySection
            playlistSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Music")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Connection Section (moved from SettingsView.musicKitSection)

    private var connectionSection: some View {
        Section {
            HStack {
                Label("Apple Music", systemImage: "music.note")
                Spacer()
                authStatusBadge
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
        } header: {
            Text("Music Access")
        } footer: {
            Text("Resonance requires an Apple Music subscription to play music and access your library.")
        }
    }

    // MARK: - Auth Status Badge (moved from SettingsView)

    @ViewBuilder
    private var authStatusBadge: some View {
        switch musicService.authorizationStatus {
        case .authorized:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        case .denied:
            Label("Denied", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .labelStyle(.titleAndIcon)
        case .restricted:
            Label("Restricted", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .labelStyle(.titleAndIcon)
        case .notDetermined:
            Label("Not Set Up", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        @unknown default:
            Label("Unknown", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        }
    }

    // MARK: - Library Section

    private var librarySection: some View {
        Section {
            Button {
                // Trigger library re-scan via notification so the app coordinator can handle it
                NotificationCenter.default.post(name: .resonanceRescanLibrary, object: nil)
            } label: {
                Label("Re-scan Music Library", systemImage: "arrow.clockwise")
            }
            .disabled(musicService.authorizationStatus != .authorized)
        } header: {
            Text("Library")
        } footer: {
            Text("Re-analyzes your Apple Music library to discover new songs and update audio features.")
        }
    }

    // MARK: - Playlist Section

    private var playlistSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Cross-Playlist Recommendations", isOn: $preferences.allowCrossPlaylistRecommendations)
                    .onChange(of: preferences.allowCrossPlaylistRecommendations) { _, _ in
                        onSave()
                    }

                Text("Let the AI DJ pick songs from other playlists when they fit your current mood better.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Playlists")
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
