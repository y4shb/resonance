//
//  ResonanceWatchApp.swift
//  Resonance Watch
//
//  Main entry point for the watchOS app
//

import SwiftUI
import HealthKit

@main
struct ResonanceWatchApp: App {
    // MARK: - Services

    @StateObject private var connectivityService: PhoneConnectivityService
    @StateObject private var sensorCoordinator: SensorCoordinator
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Initialization

    init() {
        logInfo("Resonance Watch app launching", category: .general)
        let connectivity = PhoneConnectivityService()
        _connectivityService = StateObject(wrappedValue: connectivity)
        _sensorCoordinator = StateObject(wrappedValue: SensorCoordinator(connectivityService: connectivity))
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchNowPlayingView(connectivityService: connectivityService)
                .onAppear {
                    connectivityService.activate()
                    logInfo("PhoneConnectivityService activated", category: .watchConnectivity)
                }
                .task {
                    if HKHealthStore.isHealthDataAvailable() {
                        let store = HKHealthStore()
                        let types: Set<HKObjectType> = [
                            HKQuantityType(.heartRate),
                            HKQuantityType(.heartRateVariabilitySDNN),
                            HKQuantityType(.stepCount),
                            HKObjectType.workoutType()
                        ]
                        try? await store.requestAuthorization(toShare: [], read: types)
                        sensorCoordinator.startAllSensors()
                        logInfo("Watch sensors started", category: .healthKit)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        sensorCoordinator.startAllSensors()
                        logInfo("Watch became active — sensors started", category: .healthKit)
                    case .background:
                        sensorCoordinator.stopAllSensors()
                        logInfo("Watch entered background — sensors stopped", category: .healthKit)
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    let service = PhoneConnectivityService()
    WatchNowPlayingView(connectivityService: service)
}
