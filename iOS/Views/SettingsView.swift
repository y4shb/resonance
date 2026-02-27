//
//  SettingsView.swift
//  Resonance
//
//  Settings view for managing MusicKit/HealthKit authorization,
//  user preferences, ranking weights, behavioral rules, and data.
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

    @State private var isRequestingAuth: Bool = false
    @State private var preferences = UserPreferences.load()

    // HealthKit
    @State private var healthReadAccessVerified: Bool = false
    @State private var isRequestingHealthAuth: Bool = false
    @State private var healthAuthRequested: Bool = false

    // Alerts
    @State private var showClearHistoryAlert: Bool = false
    @State private var showResetPreferencesAlert: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                musicKitSection
                healthKitSection
                historicalAnalysisSection
                stateEngineSection
                rankingWeightsSection
                behavioralPreferencesSection
                timeOfDaySection
                dataManagementSection
                privacySection
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

    // MARK: - HealthKit Section

    private var healthKitSection: some View {
        Section {
            HStack {
                Label("HealthKit", systemImage: "heart.fill")
                Spacer()
                healthAuthStatusBadge
            }

            if !healthAuthRequested && !healthReadAccessVerified {
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

            if healthAuthRequested || healthReadAccessVerified {
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
        if healthAuthRequested || healthReadAccessVerified {
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

    // MARK: - Historical Analysis Section

    private var historicalAnalysisSection: some View {
        Section {
            switch historicalEngine.progress {
            case .idle:
                HStack {
                    Label("Last Run", systemImage: "clock")
                    Spacer()
                    Text(historicalEngine.lastBackfillDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await historicalEngine.runFullBackfill() }
                } label: {
                    Label("Run Full Backfill", systemImage: "arrow.clockwise")
                }

            case .reconstructingSessions:
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Reconstructing sessions...")
                        .foregroundStyle(.secondary)
                }

            case .calculatingSongImpacts:
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Calculating song impacts...")
                        .foregroundStyle(.secondary)
                }

            case .calculatingPlaylistImpacts:
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Calculating playlist impacts...")
                        .foregroundStyle(.secondary)
                }

            case .completed(let sessions, let events, let playlists):
                Label(
                    "\(sessions) sessions, \(events) events, \(playlists) playlists",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
                .font(.caption)

                HStack {
                    Label("Last Run", systemImage: "clock")
                    Spacer()
                    Text(historicalEngine.lastBackfillDate?.formatted(date: .abbreviated, time: .shortened) ?? "Just now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)

                Button {
                    Task { await historicalEngine.runFullBackfill() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text("Historical Analysis")
        } footer: {
            Text("Analyzes your listening history to learn song effectiveness across different contexts.")
        }
    }

    // MARK: - State Engine Section

    private var stateEngineSection: some View {
        Section {
            HStack {
                Label(stateEngine.currentState.context.displayName, systemImage: "brain.head.profile")
                Spacer()
                Text(stateEngine.currentState.inferredNeed.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                StateDebugView(stateEngine: stateEngine)
            } label: {
                Label("State Debug", systemImage: "ant")
            }
        } header: {
            Text("State Engine")
        } footer: {
            Text("Real-time estimation of your current state for intelligent song selection.")
        }
    }

    // MARK: - Ranking Weights Section

    private var rankingWeightsSection: some View {
        Section {
            weightSlider(label: "BPM Match", value: $preferences.bpmWeight)
            weightSlider(label: "Energy Level", value: $preferences.energyWeight)
            weightSlider(label: "Familiarity", value: $preferences.familiarityWeight)
            weightSlider(label: "Historical", value: $preferences.historicalWeight)
            weightSlider(label: "Context", value: $preferences.contextWeight)

            Button("Normalize Weights") {
                preferences.normalizeWeights()
                savePreferences()
            }

            HStack(spacing: 12) {
                Button("Focus") {
                    preferences = .focusPreset
                    savePreferences()
                }
                .buttonStyle(.bordered)

                Button("Workout") {
                    preferences = .workoutPreset
                    savePreferences()
                }
                .buttonStyle(.bordered)

                Button("Relaxation") {
                    preferences = .relaxationPreset
                    savePreferences()
                }
                .buttonStyle(.bordered)
            }

            Button("Reset to Defaults") {
                preferences = .default
                savePreferences()
            }
            .foregroundStyle(.red)
        } header: {
            Text("Ranking Weights")
        } footer: {
            Text("Adjust how different factors influence song selection. Weights should sum to 100%. Use Normalize to rebalance.")
        }
    }

    private func weightSlider(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0.0...1.0, step: 0.01) { editing in
                if !editing {
                    savePreferences()
                }
            }
        }
    }

    // MARK: - Behavioral Preferences Section

    private var behavioralPreferencesSection: some View {
        Section {
            Stepper(
                "Avoid Recent: \(preferences.avoidRecentMinutes) min",
                value: $preferences.avoidRecentMinutes,
                in: 0...480,
                step: 15
            ) { editing in
                if !editing {
                    savePreferences()
                }
            }

            Stepper(
                "Max Same Artist in Row: \(preferences.maxSameArtistInRow)",
                value: $preferences.maxSameArtistInRow,
                in: 1...10
            ) { editing in
                if !editing {
                    savePreferences()
                }
            }

            Toggle("Prefer Familiar in Stress", isOn: $preferences.preferFamiliarInStress)
                .onChange(of: preferences.preferFamiliarInStress) { _, _ in
                    savePreferences()
                }

            Toggle("Enable Smooth Transitions", isOn: $preferences.enableSmoothTransitions)
                .onChange(of: preferences.enableSmoothTransitions) { _, _ in
                    savePreferences()
                }
        } header: {
            Text("Behavioral Preferences")
        } footer: {
            Text("Control playback behavior such as song repetition avoidance and artist variety.")
        }
    }

    // MARK: - Time of Day Section

    private var timeOfDaySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Morning Max BPM")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(preferences.morningMaxBPM))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $preferences.morningMaxBPM, in: 60...200, step: 5) { editing in
                    if !editing {
                        savePreferences()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Night Max BPM")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(preferences.nightMaxBPM))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $preferences.nightMaxBPM, in: 40...200, step: 5) { editing in
                    if !editing {
                        savePreferences()
                    }
                }
            }

            Picker("Morning Ends At", selection: $preferences.morningEndHour) {
                ForEach(5...12, id: \.self) { hour in
                    Text("\(hour):00").tag(hour)
                }
            }
            .onChange(of: preferences.morningEndHour) { _, _ in
                savePreferences()
            }

            Picker("Night Starts At", selection: $preferences.nightStartHour) {
                ForEach(18...23, id: \.self) { hour in
                    Text("\(hour):00").tag(hour)
                }
            }
            .onChange(of: preferences.nightStartHour) { _, _ in
                savePreferences()
            }
        } header: {
            Text("Time-of-Day Rules")
        } footer: {
            Text("Limit BPM during morning and evening hours for gentler music at appropriate times.")
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section {
            Button(role: .destructive) {
                showClearHistoryAlert = true
            } label: {
                Label("Clear All Listening History", systemImage: "trash")
            }
            .alert("Clear All Listening History?", isPresented: $showClearHistoryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    try? PersistenceController.shared.deleteAllData()
                }
            } message: {
                Text("This will permanently delete all listening history, session data, and learned song effectiveness scores. This action cannot be undone.")
            }

            Button(role: .destructive) {
                showResetPreferencesAlert = true
            } label: {
                Label("Reset Preferences", systemImage: "arrow.counterclockwise")
            }
            .alert("Reset All Preferences?", isPresented: $showResetPreferencesAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    UserPreferences.reset()
                    preferences = UserPreferences.load()
                }
            } message: {
                Text("This will restore all preferences to their default values.")
            }

            Button {
                Task { await historicalEngine.runFullBackfill() }
            } label: {
                Label("Re-run Historical Backfill", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Data Management")
        }
    }

    // MARK: - Privacy Section

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
        } header: {
            Text("Privacy")
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
