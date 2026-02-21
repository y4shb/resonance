//
//  SensorCoordinator.swift
//  Resonance Watch
//
//  Owns all Watch sensors, buffers BiometricPackets, and flushes them to
//  the phone via PhoneConnectivityService on a fixed timer.
//

import Foundation
import Combine
import HealthKit

// MARK: - SensorCoordinator

final class SensorCoordinator: ObservableObject {

    // MARK: - Sub-sensors

    private let heartRateSensor = HeartRateSensor()
    private let motionSensor = MotionSensor()
    private let workoutDetector = WorkoutDetector()

    // MARK: - Dependencies

    private let connectivityService: PhoneConnectivityService

    // MARK: - Buffer & Timer

    private var sampleBuffer: [BiometricPacket] = []
    private var batchTimer: Timer?
    private var isRunning = false

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(connectivityService: PhoneConnectivityService) {
        self.connectivityService = connectivityService
        setupSensorSubscriptions()
        logInfo("SensorCoordinator initialized", category: .healthKit)
    }

    // MARK: - Public Interface

    /// Starts all three sensors and the batching timer.
    func startAllSensors() {
        guard !isRunning else {
            logDebug("SensorCoordinator already running", category: .healthKit)
            return
        }
        isRunning = true
        heartRateSensor.startMonitoring()
        motionSensor.startMonitoring()
        workoutDetector.startObserving()
        startBatchTimer()
        logInfo("All Watch sensors started", category: .healthKit)
    }

    /// Stops all three sensors and the batching timer, flushing any remaining
    /// buffered packets before shutting down.
    func stopAllSensors() {
        guard isRunning else { return }
        isRunning = false
        heartRateSensor.stopMonitoring()
        motionSensor.stopMonitoring()
        workoutDetector.stopObserving()
        stopBatchTimer()
        // Flush whatever is left in the buffer on a clean shutdown.
        flushBuffer()
        logInfo("All Watch sensors stopped", category: .healthKit)
    }

    // MARK: - Combine Subscriptions

    /// Subscribes to each sensor's published properties. Any state change
    /// immediately snapshots a new packet and checks whether to flush.
    private func setupSensorSubscriptions() {
        // React to heart rate changes.
        heartRateSensor.$latestHeartRate
            .dropFirst()                      // skip initial nil
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectAndBuffer()
            }
            .store(in: &cancellables)

        // React to HRV changes.
        heartRateSensor.$latestHRV
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectAndBuffer()
            }
            .store(in: &cancellables)

        // React to motion / stationarity changes.
        motionSensor.$isStationary
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectAndBuffer()
            }
            .store(in: &cancellables)

        // React to workout state changes.
        workoutDetector.$isInWorkout
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectAndBuffer()
            }
            .store(in: &cancellables)

        logDebug("SensorCoordinator Combine subscriptions configured", category: .healthKit)
    }

    // MARK: - Batch Timer

    private func startBatchTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let interval = WatchConnectivityConstants.biometricBatchIntervalSeconds
            self.batchTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: true
            ) { [weak self] _ in
                guard let self = self else { return }
                self.collectAndBuffer()
                self.flushBuffer()
            }
            logDebug(
                "Batch timer started with interval \(interval)s",
                category: .healthKit
            )
        }
    }

    private func stopBatchTimer() {
        batchTimer?.invalidate()
        batchTimer = nil
        logDebug("Batch timer stopped", category: .healthKit)
    }

    // MARK: - Packet Collection

    /// Snapshots the current sensor readings into a BiometricPacket and appends
    /// it to the buffer. If the buffer has reached maxSamplesPerBatch, flush
    /// immediately to avoid unbounded growth.
    private func collectAndBuffer() {
        let packet = BiometricPacket(
            heartRate: heartRateSensor.latestHeartRate,
            hrv: heartRateSensor.latestHRV,
            isStationary: motionSensor.isStationary,
            isInWorkout: workoutDetector.isInWorkout,
            workoutType: workoutDetector.workoutType,
            timestamp: Date()
        )

        sampleBuffer.append(packet)

        logDebug(
            "Buffered biometric packet — buffer size: \(sampleBuffer.count), " +
            "HR: \(packet.heartRate.map { String(format: "%.0f", $0) } ?? "nil") BPM, " +
            "stationary: \(packet.isStationary), workout: \(packet.isInWorkout)",
            category: .healthKit
        )

        if sampleBuffer.count >= WatchConnectivityConstants.maxSamplesPerBatch {
            logInfo(
                "Buffer reached maxSamplesPerBatch (\(WatchConnectivityConstants.maxSamplesPerBatch)) — flushing early",
                category: .healthKit
            )
            flushBuffer()
        }
    }

    // MARK: - Buffer Flush

    /// Sends the latest buffered packet to the phone via the connectivity
    /// service and then clears the buffer, discarding intermediate samples.
    private func flushBuffer() {
        guard let latestPacket = sampleBuffer.last else { return }
        let count = sampleBuffer.count
        sampleBuffer.removeAll()

        logInfo(
            "Flushing latest biometric packet to phone (discarding \(count - 1) intermediate samples)",
            category: .watchConnectivity
        )

        connectivityService.sendBiometricUpdate(latestPacket)
    }
}
