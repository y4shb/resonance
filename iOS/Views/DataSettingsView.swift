//
//  DataSettingsView.swift
//  Resonance
//
//  "My Data" settings: iCloud backup, privacy policy, data deletion,
//  data analysis link, export, and about information.
//

import SwiftUI

// MARK: - Data Settings View

struct DataSettingsView: View {
    @ObservedObject var historicalEngine: HistoricalEngine
    @ObservedObject var stateEngine: StateEngine
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        List {
            backupSection
            privacySection
            analysisSection
            dangerZoneSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Backup Section

    private var backupSection: some View {
        Section {
            Toggle("Backup to iCloud", isOn: $preferences.backupToiCloud)
                .onChange(of: preferences.backupToiCloud) { _, _ in
                    onSave()
                }
        } header: {
            Text("Backup")
        } footer: {
            Text("Syncs your preferences and listening history to iCloud for restoration on new devices.")
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            if let privacyURL = URL(string: "https://resonance.app/privacy") {
                Link(destination: privacyURL) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Privacy")
        }
    }

    // MARK: - Analysis Section

    private var analysisSection: some View {
        Section {
            NavigationLink {
                DataAnalysisView(
                    historicalEngine: historicalEngine,
                    stateEngine: stateEngine,
                    preferences: $preferences,
                    onSave: onSave
                )
            } label: {
                Label("Data & Analysis", systemImage: "chart.bar.xaxis")
            }

            Button {
                exportData()
            } label: {
                Label("Export My Data", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Analysis & Export")
        } footer: {
            Text("View listening trends, resonance scores, and export your data.")
        }
    }

    // MARK: - Danger Zone Section (moved from SettingsView.privacySection)

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Label("Delete All My Data", systemImage: "trash")
                    if isDeleting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isDeleting)
            .confirmationDialog(
                "Delete All Data",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    performDeleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your listening history, preferences, circadian profile, bookmarks, and learned data. This action cannot be undone.")
            }
        } header: {
            Text("Danger Zone")
        }
    }

    // MARK: - About Section (moved from SettingsView.aboutSection)

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

            if let supportURL = URL(string: "mailto:support@resonance.app") {
                Link(destination: supportURL) {
                    HStack {
                        Text("Contact Support")
                        Spacer()
                        Image(systemName: "envelope")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Delete All Data (moved from SettingsView)

    private func performDeleteAllData() {
        isDeleting = true
        logInfo("User initiated Delete All Data", category: .ui)

        // 1. Delete Core Data
        do {
            try PersistenceController.shared.deleteAllData()
            logInfo("Core Data cleared", category: .persistence)
        } catch {
            logError("Failed to clear Core Data", error: error, category: .persistence)
        }

        // 2. Clear App Group UserDefaults
        let appGroupDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        if let appGroupDefaults = appGroupDefaults,
           let bundleId = Bundle.main.bundleIdentifier {
            appGroupDefaults.removePersistentDomain(forName: bundleId)
        }
        let appGroupKeys = [
            "com.y4sh.resonance.userPreferences",
            "\(CircadianConstants.persistenceKeyPrefix).profileData",
            "\(CircadianConstants.persistenceKeyPrefix).lastRefresh",
            BackfillConstants.WatermarkKey.sessionReconstruction,
            BackfillConstants.WatermarkKey.songImpact,
            BackfillConstants.WatermarkKey.lastFullBackfill,
            "resonance_session_history"
        ]
        for key in appGroupKeys {
            appGroupDefaults?.removeObject(forKey: key)
        }

        // E5 Sleep Wind-Down data
        appGroupDefaults?.removeObject(forKey: "com.y4sh.resonance.sleepWindDown.lastReport")
        appGroupDefaults?.removeObject(forKey: "com.y4sh.resonance.sleepWindDown.lastSessionDate")

        // 3. Clear standard UserDefaults
        let standardKeys = [
            "sonic_bookmarks_v1",
            "sonic_bookmarks_sessions_v1"
        ]
        for key in standardKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 4. Reset circadian profile
        CircadianProfileManager().reset()

        // 5. Reset UserPreferences
        UserPreferences.reset()
        preferences = UserPreferences.default

        isDeleting = false
        logInfo("All user data deleted successfully", category: .ui)
    }

    // MARK: - Export Data

    private func exportData() {
        // Export user data as JSON via share sheet
        logInfo("User tapped Export My Data", category: .ui)

        guard let data = try? JSONEncoder().encode(preferences),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("resonance-preferences.json")
        try? jsonString.write(to: tempURL, atomically: true, encoding: .utf8)

        // Present via UIActivityViewController
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
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
    let hkService = HealthKitService()
    let contextCollector = ContextCollector()
    NavigationStack {
        DataSettingsView(
            historicalEngine: HistoricalEngine(healthKitService: hkService),
            stateEngine: StateEngine(contextCollector: contextCollector, healthKitService: hkService),
            preferences: .constant(UserPreferences.load()),
            onSave: { }
        )
    }
}
