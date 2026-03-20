//
//  SettingsView.swift
//  Resonance
//
//  Settings view for managing MusicKit/HealthKit authorization,
//  user preferences, ranking weights, behavioral rules, and data.
//
//  Split into basic (main screen) and advanced (DJ Tuning, Data & Analysis)
//  sub-views for reduced cognitive load.
//

import SwiftUI
import HealthKit
import MusicKit

// MARK: - Settings View

struct SettingsView: View {
    // MARK: - Properties

    @ObservedObject var musicService: MusicKitService
    @ObservedObject var historicalEngine: HistoricalEngine
    @ObservedObject var stateEngine: StateEngine

    @State private var isRequestingAuth = false
    @State private var preferences = UserPreferences.load()

    // HealthKit
    @State private var healthReadAccessVerified = false
    @State private var isRequestingHealthAuth = false
    @State private var healthAuthRequested = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                musicKitSection
                healthKitSection

                advancedNavigationSection

                privacySection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }

    // MARK: - Advanced Navigation Section

    private var advancedNavigationSection: some View {
        Section {
            NavigationLink {
                DJTuningView(preferences: $preferences, onSave: savePreferences)
            } label: {
                Label("DJ Tuning", systemImage: "slider.horizontal.3")
            }

            NavigationLink {
                DataAnalysisView(
                    historicalEngine: historicalEngine,
                    stateEngine: stateEngine,
                    preferences: $preferences,
                    onSave: savePreferences
                )
            } label: {
                Label("Data & Analysis", systemImage: "chart.bar.xaxis")
            }
        } header: {
            Text("Advanced")
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

    // MARK: - HealthKit Section

    private var healthKitSection: some View {
        Section {
            HStack {
                Label("HealthKit", systemImage: "heart.fill")
                Spacer()
                healthAuthStatusBadge
            }

            if !healthReadAccessVerified {
                Button {
                    requestHealthAuthorization()
                } label: {
                    HStack {
                        Text("Grant Health Access")
                        if isRequestingHealthAuth {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRequestingHealthAuth)
            }

            if healthReadAccessVerified {
                Label("Heart Rate: Available", systemImage: "waveform.path.ecg")
                    .font(.subheadline)
                    .foregroundStyle(.green)

                Label("HRV: Available", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("Health Integration")
        } footer: {
            Text("Heart rate and HRV data are used to personalize music selection based on your physiological state.")
        }
        .onAppear {
            checkHealthAuthorizationStatus()
        }
    }

    @ViewBuilder
    private var healthAuthStatusBadge: some View {
        if healthReadAccessVerified {
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        } else {
            Label("Not Set Up", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        }
    }

    // MARK: - Privacy Section

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    private var privacySection: some View {
        Section {
            Toggle("Backup to iCloud", isOn: $preferences.backupToiCloud)
                .onChange(of: preferences.backupToiCloud) { _, _ in
                    savePreferences()
                }

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
            Text("Privacy")
        }
    }

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

        // 2. Clear App Group UserDefaults (preferences, circadian profile, watermarks)
        let appGroupDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        if let appGroupDefaults = appGroupDefaults,
           let bundleId = Bundle.main.bundleIdentifier {
            appGroupDefaults.removePersistentDomain(forName: bundleId)
        }
        // Also remove known keys explicitly for safety
        let appGroupKeys = [
            "com.y4sh.resonance.userPreferences",
            "\(CircadianConstants.persistenceKeyPrefix).profileData",
            "\(CircadianConstants.persistenceKeyPrefix).lastRefresh",
            BackfillConstants.WatermarkKey.sessionReconstruction,
            BackfillConstants.WatermarkKey.songImpact,
            BackfillConstants.WatermarkKey.lastFullBackfill
        ]
        for key in appGroupKeys {
            appGroupDefaults?.removeObject(forKey: key)
        }

        // 3. Clear standard UserDefaults (bookmarks)
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

    // MARK: - Actions

    private func requestAuthorization() {
        isRequestingAuth = true
        logInfo("User tapped request authorization", category: .ui)

        Task {
            await musicService.requestAuthorization()
            isRequestingAuth = false
        }
    }

    private func requestHealthAuthorization() {
        isRequestingHealthAuth = true
        logInfo("User tapped request health authorization", category: .ui)

        Task {
            let healthStore = HKHealthStore()
            let readTypes: Set<HKObjectType> = {
                var types = Set<HKObjectType>()
                if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                    types.insert(hr)
                }
                if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                    types.insert(hrv)
                }
                if let rhr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
                    types.insert(rhr)
                }
                if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                    types.insert(steps)
                }
                if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                    types.insert(energy)
                }
                if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                    types.insert(sleep)
                }
                types.insert(HKObjectType.workoutType())
                return types
            }()

            do {
                try await healthStore.requestAuthorization(toShare: [], read: readTypes)
                await MainActor.run {
                    healthReadAccessVerified = true
                    healthAuthRequested = true
                    isRequestingHealthAuth = false
                }
                logInfo("HealthKit authorization requested from Settings", category: .ui)
            } catch {
                await MainActor.run {
                    isRequestingHealthAuth = false
                }
                logError("HealthKit authorization request failed from Settings", error: error, category: .ui)
            }
        }
    }

    private func checkHealthAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // HealthKit doesn't expose read authorization status directly.
        // The only way to check is to attempt a query and see if data comes back.
        let healthStore = HKHealthStore()
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            DispatchQueue.main.async {
                // If we get samples back (even empty array with no error), read access was granted.
                // A nil samples with an error means access was denied.
                if error == nil {
                    self.healthReadAccessVerified = true
                }
            }
        }
        healthStore.execute(query)
    }

    private func savePreferences() {
        try? preferences.save()
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
    SettingsView(
        musicService: MusicKitService(),
        historicalEngine: HistoricalEngine(healthKitService: hkService),
        stateEngine: StateEngine(contextCollector: contextCollector, healthKitService: hkService)
    )
}
