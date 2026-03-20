//
//  OvernightTemperatureSensor.swift
//  Resonance Watch
//
//  Queries HKQuantityType(.appleSleepingWristTemperature) on morning launch.
//  Computes deviation from a multi-night baseline and trend direction.
//  Sends OvernightTemperaturePacket to the iPhone via WatchConnectivity.
//

import HealthKit
import Foundation

// MARK: - Temperature Trend

enum TemperatureTrend: String, Codable, Sendable {
    case rising
    case falling
    case stable
}

// MARK: - OvernightTemperatureSensor

final class OvernightTemperatureSensor {

    // MARK: - Configuration

    /// Number of nights for baseline computation.
    private static let baselineNights = 7

    /// Threshold (Celsius) above which a change is considered non-stable.
    private static let trendThreshold: Double = 0.1

    // MARK: - Dependencies

    private let healthStore = HKHealthStore()
    private let connectivityService: PhoneConnectivityService

    // MARK: - State

    private var lastQueryDate: Date?

    // MARK: - Initialization

    init(connectivityService: PhoneConnectivityService) {
        self.connectivityService = connectivityService
    }

    // MARK: - Public Interface

    /// Queries overnight temperature on morning launch (once per day).
    /// Only available on watchOS 9.0+ (Series 8, Ultra).
    func queryIfMorning() {
        guard #available(watchOS 9.0, *) else { return }

        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 5 && hour < 12 else { return }

        // Only query once per day
        if let lastDate = lastQueryDate,
           Calendar.current.isDateInToday(lastDate) {
            return
        }

        lastQueryDate = Date()
        fetchOvernightTemperature()
    }

    // MARK: - Private: Fetching

    @available(watchOS 9.0, *)
    private func fetchOvernightTemperature() {
        let tempType = HKQuantityType(.appleSleepingWristTemperature)
        let unit = HKUnit.degreeCelsius()

        // Fetch last N nights of data
        let endDate = Date()
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -(Self.baselineNights + 1),
            to: endDate
        ) ?? endDate.addingTimeInterval(-Double(Self.baselineNights + 1) * 86400)

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        let query = HKSampleQuery(
            sampleType: tempType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self = self else { return }

            if let error = error {
                logError("Wrist temperature query failed", error: error, category: .healthKit)
                return
            }

            guard let quantitySamples = samples as? [HKQuantitySample],
                  !quantitySamples.isEmpty else {
                logDebug("No wrist temperature data available", category: .healthKit)
                return
            }

            self.processTemperatureSamples(quantitySamples, unit: unit)
        }

        healthStore.execute(query)
    }

    // MARK: - Private: Processing

    private func processTemperatureSamples(
        _ samples: [HKQuantitySample],
        unit: HKUnit
    ) {
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        guard let latestValue = values.last else { return }

        // Baseline: average of all samples except the latest
        let baselineValues = values.dropLast()
        let baseline: Double
        if baselineValues.isEmpty {
            baseline = latestValue
        } else {
            baseline = baselineValues.reduce(0.0, +) / Double(baselineValues.count)
        }

        let deviation = latestValue - baseline

        // Trend from last 3 readings
        let trend: TemperatureTrend
        if values.count >= 3 {
            let recent = Array(values.suffix(3))
            let diff = recent.last.map { $0 - recent[0] } ?? 0.0
            if diff > Self.trendThreshold {
                trend = .rising
            } else if diff < -Self.trendThreshold {
                trend = .falling
            } else {
                trend = .stable
            }
        } else {
            trend = .stable
        }

        let packet = OvernightTemperaturePacket(
            deviation: deviation,
            baseline: baseline,
            latestReading: latestValue,
            trend: trend.rawValue,
            timestamp: Date()
        )

        logDebug(
            "Overnight temp: deviation=\(String(format: "%+.2f", deviation))C, "
            + "trend=\(trend.rawValue)",
            category: .healthKit
        )

        // Send to iPhone
        let message = WatchMessage.overnightTemperature(packet)
        sendOvernightTemperature(message)
    }

    private func sendOvernightTemperature(_ message: WatchMessage) {
        do {
            let dict = try message.toDictionary()
            connectivityService.sendGuaranteedMessage(dict)
        } catch {
            logError(
                "Failed to send overnight temperature",
                error: error,
                category: .watchConnectivity
            )
        }
    }
}
