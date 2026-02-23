//
//  ResonanceWatchApp.swift
//  Resonance Watch
//
//  Main entry point for the watchOS app
//

import SwiftUI
import HealthKit
import WidgetKit

@main
struct ResonanceWatchApp: App {
    // MARK: - Services

    @StateObject private var connectivityService: PhoneConnectivityService
    @StateObject private var sensorCoordinator: SensorCoordinator
    @StateObject private var crownHandler: CrownHandler
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Initialization

    init() {
        logInfo("Resonance Watch app launching", category: .general)
        let connectivity = PhoneConnectivityService()
        _connectivityService = StateObject(wrappedValue: connectivity)
        _sensorCoordinator = StateObject(wrappedValue: SensorCoordinator(connectivityService: connectivity))
        _crownHandler = StateObject(wrappedValue: CrownHandler(connectivityService: connectivity))
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchNowPlayingView(
                    connectivityService: connectivityService,
                    crownHandler: crownHandler
                )
                .onAppear {
                    connectivityService.activate()
                    logInfo("PhoneConnectivityService activated", category: .watchConnectivity)
                }
                .onReceive(
                    connectivityService.$isSessionActivated
                        .filter { $0 }
                        .first()
                ) { _ in
                    // Request current NowPlaying once the WCSession has activated,
                    // rather than relying on an arbitrary delay.
                    connectivityService.requestNowPlaying()
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
                .onReceive(connectivityService.complicationUpdates) { data in
                    ComplicationDataStore.update(from: data)
                }
                .onReceive(connectivityService.nowPlayingUpdates) { packet in
                    ComplicationDataStore.updateFromNowPlaying(packet)
                }
        }
    }
}

// MARK: - Preview

#Preview {
    let service = PhoneConnectivityService()
    WatchNowPlayingView(
        connectivityService: service,
        crownHandler: CrownHandler(connectivityService: service)
    )
}
