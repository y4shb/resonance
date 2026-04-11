//
//  BodySettingsView.swift
//  Resonance
//
//  "My Body" settings: HealthKit permissions, biometric signal toggles,
//  sensitivity control, and current data source status.
//

import SwiftUI
import HealthKit

// MARK: - Body Settings View

struct BodySettingsView: View {
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    // HealthKit authorization state (moved from SettingsView)
    @State private var healthReadAccessVerified = false
    @State private var isRequestingHealthAuth = false
    @State private var healthAuthRequested = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                healthKitSection
                biometricSignalsSection
                sensitivitySection
                dataSourcesSection
            }
            .padding()
        }
        .background(ResonanceColors.panelBg)
        .navigationTitle("My Body")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - HealthKit Permission Section

    private var healthKitSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("HEALTH INTEGRATION")
                    .retroEngravedLabel()

                HStack {
                    Label("HealthKit", systemImage: "heart.fill")
                    Spacer()
                    RetroLEDIndicator(
                        isOn: true,
                        color: healthReadAccessVerified ? ResonanceColors.ledGreen : ResonanceColors.ledAmber
                    )
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

                Text("Heart rate and HRV data personalize music selection based on your physiological state.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .onAppear {
            checkHealthAuthorizationStatus()
        }
    }

    // MARK: - Biometric Signals Section

    private var biometricSignalsSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("BIOMETRIC SIGNALS")
                    .retroEngravedLabel()

                signalToggle(
                    label: "Heart Rate",
                    icon: "waveform.path.ecg",
                    isOn: $preferences.heartRateEnabled
                )

                signalToggle(
                    label: "Heart Rate Variability",
                    icon: "chart.line.uptrend.xyaxis",
                    isOn: $preferences.hrvEnabled
                )

                signalToggle(
                    label: "Motion & Activity",
                    icon: "figure.walk.motion",
                    isOn: $preferences.motionEnabled
                )

                signalToggle(
                    label: "Sleep Quality",
                    icon: "bed.double.fill",
                    isOn: $preferences.sleepEnabled
                )

                signalToggle(
                    label: "Wrist Temperature",
                    icon: "thermometer.medium",
                    isOn: $preferences.temperatureEnabled
                )

                Text("Choose which body signals influence your music. Disabling a signal removes it from the AI's decision-making.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    private func signalToggle(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            RetroToggleSwitch(isOn: isOn, label: "")
        }
        .onChange(of: isOn.wrappedValue) { _, _ in
            onSave()
        }
    }

    // MARK: - Sensitivity Section

    private var sensitivitySection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SENSITIVITY")
                    .retroEngravedLabel()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Biometric Sensitivity")
                            .font(.subheadline)
                        Spacer()
                        Text(sensitivityLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    RetroSliderPot(
                        value: $preferences.biometricSensitivity,
                        orientation: .horizontal,
                        label: sensitivityLabel,
                        length: 200
                    )
                    .onChange(of: preferences.biometricSensitivity) { _, _ in
                        onSave()
                    }

                    HStack {
                        Text("Subtle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Aggressive")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Controls how strongly biometric changes affect song selection. Lower values mean gentler, slower reactions.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    private var sensitivityLabel: String {
        switch preferences.biometricSensitivity {
        case 0..<0.3: return "Low"
        case 0.3..<0.7: return "Medium"
        default: return "High"
        }
    }

    // MARK: - Data Sources Section

    private var dataSourcesSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("CURRENT DATA SOURCES")
                    .retroEngravedLabel()

                if healthReadAccessVerified {
                    Label("Heart Rate: Available", systemImage: "waveform.path.ecg")
                        .font(.subheadline)
                        .foregroundStyle(.green)

                    Label("HRV: Available", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(.green)

                    Label("Motion: Via CoreMotion", systemImage: "figure.walk.motion")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    Label("No biometric data sources connected", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    // MARK: - HealthKit Authorization (moved from SettingsView)

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
                if error == nil, let samples = samples, !samples.isEmpty {
                    self.healthReadAccessVerified = true
                }
            }
        }
        healthStore.execute(query)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BodySettingsView(
            preferences: .constant(UserPreferences.load()),
            onSave: { }
        )
    }
}
