//
//  WatchCapabilityDetector.swift
//  Resonance Watch
//
//  Detects the sensor capability tier of the current Apple Watch.
//  Determines whether device motion and wrist temperature are available.
//

import CoreMotion
import Foundation
import HealthKit
import WatchKit

// MARK: - WatchCapabilityDetector

final class WatchCapabilityDetector {

    // MARK: - Singleton

    static let shared = WatchCapabilityDetector()

    // MARK: - Thread Safety (FIX 3)

    private let lock = NSLock()

    // MARK: - Cached Result

    private var cachedTier: WatchCapabilityTier?

    // MARK: - Cached Motion Manager (FIX 2)

    /// Single lazily-created CMMotionManager instance, avoiding repeated allocations.
    private static let motionManager = CMMotionManager()

    // MARK: - Detection

    /// Returns the capability tier of the current Watch hardware.
    /// Result is cached after first detection. Thread-safe.
    var currentTier: WatchCapabilityTier {
        lock.lock()
        if let cached = cachedTier {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let tier = detectTier()

        lock.lock()
        // Double-check: another thread may have written while we computed.
        if let cached = cachedTier {
            lock.unlock()
            return cached
        }
        cachedTier = tier
        lock.unlock()

        logInfo("Watch capability tier detected: \(tier.rawValue)", category: .general)
        return tier
    }

    /// Whether device motion (CMMotionManager) is available on this Watch.
    /// Uses a cached static CMMotionManager instance (FIX 2).
    var isDeviceMotionAvailable: Bool {
        Self.motionManager.isDeviceMotionAvailable
    }

    /// Whether wrist temperature data is available (Series 8+, Ultra).
    ///
    /// Detection strategy (FIX 1):
    ///   1. Requires watchOS 9.0+ (temperature API not available earlier).
    ///   2. Queries HealthKit for any wrist-temperature samples recorded in the
    ///      last 30 days. A non-empty result proves the sensor hardware exists.
    ///   3. Falls back to `false` on older watchOS or when no samples are found,
    ///      because `authorizationStatus` alone cannot distinguish "no sensor"
    ///      from "permission not yet requested".
    var isTemperatureAvailable: Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard #available(watchOS 9.0, *) else { return false }

        let systemVersion = WKInterfaceDevice.current().systemVersion
        guard systemVersion.compare("9.0", options: .numeric) != .orderedAscending else {
            return false
        }

        return hasRecentTemperatureSamples()
    }

    // MARK: - Private

    private func detectTier() -> WatchCapabilityTier {
        let hasMotion = isDeviceMotionAvailable
        let hasTemp = isTemperatureAvailable

        if hasMotion && hasTemp {
            return .full
        } else if hasMotion {
            return .motion
        } else {
            return .basic
        }
    }

    /// Queries HealthKit for wrist-temperature samples within the last 30 days.
    /// Returns `true` only when at least one sample exists, which proves the
    /// hardware sensor is present and has recorded data.
    @available(watchOS 9.0, *)
    private func hasRecentTemperatureSamples() -> Bool {
        let store = HKHealthStore()
        let tempType = HKQuantityType(.appleSleepingWristTemperature)

        let authStatus = store.authorizationStatus(for: tempType)
        if authStatus == .sharingDenied {
            // User explicitly denied; we cannot query. Assume no capability
            // rather than returning a false positive.
            return false
        }

        let now = Date()
        guard let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) else {
            return false
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: thirtyDaysAgo,
            end: now,
            options: .strictStartDate
        )

        let semaphore = DispatchSemaphore(value: 0)
        var foundSamples = false

        let query = HKSampleQuery(
            sampleType: tempType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, results, error in
            if let error {
                logWarning(
                    "Temperature sample query failed: \(error.localizedDescription)",
                    category: .healthKit
                )
            }
            if let results, !results.isEmpty {
                foundSamples = true
            }
            semaphore.signal()
        }

        store.execute(query)
        _ = semaphore.wait(timeout: .now() + 5)

        return foundSamples
    }

    private init() {}
}
