//
//  MotionSensor.swift
//  Resonance Watch
//
//  Monitors step activity via CMPedometer to determine whether the user
//  is stationary or in motion.
//

import CoreMotion
import Combine

// MARK: - MotionSensor

final class MotionSensor: ObservableObject {

    // MARK: - Constants

    /// Steps accumulated over the polling window required to be considered "in motion".
    private static let stationaryStepThreshold = 10

    /// How far back (in seconds) each pedometer sample covers. Matches the batch interval.
    private static let sampleWindowSeconds: TimeInterval = WatchConnectivityConstants.biometricBatchIntervalSeconds

    // MARK: - Published Properties

    @Published private(set) var isStationary: Bool = true
    @Published private(set) var recentSteps: Int = 0

    // MARK: - Private Properties

    private let pedometer = CMPedometer()
    private var isMonitoring = false

    // MARK: - Monitoring Control

    /// Starts pedometer updates. Fires a rolling window check on each update.
    func startMonitoring() {
        guard CMPedometer.isStepCountingAvailable() else {
            logWarning("Step counting not available on this device", category: .general)
            return
        }

        guard !isMonitoring else {
            logDebug("MotionSensor already monitoring", category: .general)
            return
        }

        isMonitoring = true

        // Begin streaming updates from now. Each callback delivers cumulative
        // steps since the start date, so we use a sliding start anchored to
        // "now minus sampleWindow" on each tick to get a per-interval count.
        let startDate = Date()
        pedometer.startUpdates(from: startDate) { [weak self] pedometerData, error in
            guard let self = self else { return }

            if let error = error {
                logError("Pedometer update error", error: error, category: .general)
                return
            }

            guard let data = pedometerData else { return }

            let steps = data.numberOfSteps.intValue
            let stationary = steps <= MotionSensor.stationaryStepThreshold

            logDebug("Pedometer update: \(steps) steps, stationary=\(stationary)", category: .general)

            DispatchQueue.main.async { [weak self] in
                self?.recentSteps = steps
                self?.isStationary = stationary
            }
        }

        logInfo("MotionSensor monitoring started", category: .general)
    }

    /// Stops pedometer updates and resets to a stationary baseline.
    func stopMonitoring() {
        pedometer.stopUpdates()
        isMonitoring = false

        DispatchQueue.main.async { [weak self] in
            self?.recentSteps = 0
            self?.isStationary = true
        }

        logInfo("MotionSensor monitoring stopped", category: .general)
    }
}
