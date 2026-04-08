//
//  SettingsView.swift
//  Resonance
//
//  Main settings hub with goal-oriented navigation to 5 sub-pages:
//  My Body, My Music, My AI, My Sessions, My Data.
//

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    // MARK: - Properties

    @ObservedObject var musicService: MusicKitService
    @ObservedObject var historicalEngine: HistoricalEngine
    @ObservedObject var stateEngine: StateEngine

    @State private var preferences = UserPreferences.load()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                settingsRow(
                    icon: "figure.stand",
                    color: .red,
                    title: "My Body",
                    subtitle: "HealthKit, biometric signals, sensitivity"
                ) {
                    BodySettingsView(preferences: $preferences, onSave: savePreferences)
                }

                settingsRow(
                    icon: "music.note.list",
                    color: .pink,
                    title: "My Music",
                    subtitle: "Apple Music, library, playlists"
                ) {
                    MusicSettingsView(
                        musicService: musicService,
                        preferences: $preferences,
                        onSave: savePreferences
                    )
                }

                settingsRow(
                    icon: "brain.head.profile",
                    color: .purple,
                    title: "My AI",
                    subtitle: "Exploration, autonomy, tuning"
                ) {
                    AISettingsView(preferences: $preferences, onSave: savePreferences)
                }

                settingsRow(
                    icon: "clock.fill",
                    color: .orange,
                    title: "My Sessions",
                    subtitle: "Duration, intent, crossfade"
                ) {
                    SessionSettingsView(preferences: $preferences, onSave: savePreferences)
                }

                settingsRow(
                    icon: "externaldrive.fill",
                    color: .blue,
                    title: "My Data",
                    subtitle: "Privacy, export, about"
                ) {
                    DataSettingsView(
                        historicalEngine: historicalEngine,
                        stateEngine: stateEngine,
                        preferences: $preferences,
                        onSave: savePreferences
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }

    // MARK: - Helpers

    private func settingsRow<Destination: View>(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func savePreferences() {
        try? preferences.save()
    }
}

// MARK: - Preview

#Preview {
    let hkService = HealthKitService()
    let contextCollector = ContextCollector()
    SettingsView(
        musicService: MusicKitService(),
        historicalEngine: HistoricalEngine(healthKitService: hkService),
        stateEngine: StateEngine(contextCollector: contextCollector, healthKitService: hkService)
    )
}
