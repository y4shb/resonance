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
            ScrollView {
                BrushedMetalSurface(showScrews: true) {
                    VStack(spacing: 16) {
                        // Header LCD
                        RetroLCDPanel(title: "SYSTEM") {
                            Text("CONFIGURATION")
                                .font(RetroTypography.lcdTitle)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Settings panels
                        settingsPanel(
                            icon: "figure.stand",
                            title: "BODY",
                            subtitle: "HealthKit, biometric signals, sensitivity"
                        ) {
                            BodySettingsView(preferences: $preferences, onSave: savePreferences)
                        }

                        settingsPanel(
                            icon: "music.note.list",
                            title: "MUSIC",
                            subtitle: "Apple Music, library, playlists"
                        ) {
                            MusicSettingsView(
                                musicService: musicService,
                                preferences: $preferences,
                                onSave: savePreferences
                            )
                        }

                        settingsPanel(
                            icon: "brain.head.profile",
                            title: "AI",
                            subtitle: "Exploration, autonomy, tuning"
                        ) {
                            AISettingsView(preferences: $preferences, onSave: savePreferences)
                        }

                        settingsPanel(
                            icon: "clock.fill",
                            title: "SESSIONS",
                            subtitle: "Duration, intent, crossfade"
                        ) {
                            SessionSettingsView(preferences: $preferences, onSave: savePreferences)
                        }

                        settingsPanel(
                            icon: "externaldrive.fill",
                            title: "DATA",
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
                    .padding(.vertical, 16)
                }
                .padding()
            }
            .background(ResonanceColors.panelBg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers

    private func settingsPanel<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            BrushedMetalSurface(cornerRadius: 8) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(ResonanceColors.screwChrome)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .retroEngravedLabel()
                        Text(subtitle)
                            .font(RetroTypography.lcdCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    RetroLEDIndicator(isOn: true, color: ResonanceColors.ledGreen, size: 5)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(ResonanceColors.metalMid)
                }
                .padding(12)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
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
