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
    private var queryTimer: Timer?

    // MARK: - Monitoring Control

    /// Starts periodic pedometer queries. Each query covers the last sampleWindow
    /// seconds to determine whether the user is stationary or in motion.
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

        // Query immediately and then periodically
        queryRecentSteps()
        queryTimer = Timer.scheduledTimer(
            withTimeInterval: MotionSensor.sampleWindowSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.queryRecentSteps()
        }

        logInfo("MotionSensor monitoring started", category: .general)
    }

    /// Stops pedometer queries and resets to a stationary baseline.
    func stopMonitoring() {
        queryTimer?.invalidate()
        queryTimer = nil
        pedometer.stopUpdates()
        isMonitoring = false

        DispatchQueue.main.async { [weak self] in
            self?.recentSteps = 0
            self?.isStationary = true
        }

        logInfo("MotionSensor monitoring stopped", category: .general)
    }

    // MARK: - Private Helpers

    /// Queries step count over the last sampleWindow seconds to determine stationarity.
    private func queryRecentSteps() {
        let now = Date()
        let start = now.addingTimeInterval(-MotionSensor.sampleWindowSeconds)
        pedometer.queryPedometerData(from: start, to: now) { [weak self] data, error in
            guard let self = self else { return }
            if let error = error {
                logError("Pedometer query error", error: error, category: .general)
                return
            }
            let steps = data?.numberOfSteps.intValue ?? 0
            let stationary = steps <= MotionSensor.stationaryStepThreshold
            logDebug("Pedometer query: \(steps) steps in window, stationary=\(stationary)", category: .general)
            DispatchQueue.main.async { [weak self] in
                self?.recentSteps = steps
                self?.isStationary = stationary
            }
        }
    }
}
