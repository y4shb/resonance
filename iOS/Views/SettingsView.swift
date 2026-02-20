//
//  SettingsView.swift
//  Resonance
//
//  Basic settings shell for M1. Shows MusicKit authorization status,
//  app version, and placeholder sections for future features.
//

import SwiftUI
import MusicKit

// MARK: - Settings View

struct SettingsView: View {
    // MARK: - Properties

    @ObservedObject var musicService: MusicKitService

    @State private var isRequestingAuth: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                musicKitSection
                healthKitSection
                preferencesSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }

    // MARK: - MusicKit Section

    private var musicKitSection: some View {
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

    // MARK: - Auth Status Badge

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

    // MARK: - HealthKit Section (Placeholder)

    private var healthKitSection: some View {
        Section {
            HStack {
                Label("HealthKit", systemImage: "heart.fill")
                Spacer()
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Health Integration")
        } footer: {
            Text("Heart rate and activity data will be used to personalize music selection in a future update.")
        }
    }

    // MARK: - Preferences Section (Placeholder)

    private var preferencesSection: some View {
        Section {
            HStack {
                Label("Music Preferences", systemImage: "slider.horizontal.3")
                Spacer()
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Notifications", systemImage: "bell.badge")
                Spacer()
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Preferences")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("App")
                Spacer()
                Text(AppConstants.appName)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Actions

    private func requestAuthorization() {
        isRequestingAuth = true
        logInfo("User tapped request authorization", category: .ui)

        Task {
            await musicService.requestAuthorization()
            isRequestingAuth = false
        }
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Preview

#Preview {
    SettingsView(musicService: MusicKitService())
}
