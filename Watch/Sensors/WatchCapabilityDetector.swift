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
    /// Detection strategy:
    ///   1. Requires watchOS 9.0+ (temperature API not available earlier).
    ///   2. Runs a trial HKSampleQuery to verify the hardware supports the
    ///      wrist temperature type. On devices without the sensor, HealthKit
    ///      returns an error. On devices with the sensor, it completes without
    ///      error even if no data has been recorded yet.
    ///   3. This correctly distinguishes "no sensor hardware" from "haven't
    ///      asked permission" which `authorizationStatus` alone cannot do.
    var isTemperatureAvailable: Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard #available(watchOS 9.0, *) else { return false }
        return hasTemperatureHardwareSupport()
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

    /// Verifies temperature hardware support via a trial HealthKit sample query.
    ///
    /// On devices **without** the wrist temperature sensor, HealthKit returns
    /// an error (e.g. `HKError.errorInvalidArgument`) because the type is not
    /// recognized by the hardware. On devices **with** the sensor, the query
    /// completes without error -- even if no samples have been recorded yet
    /// (e.g. the user has never worn the watch to sleep).
    ///
    /// This correctly distinguishes "no sensor hardware" from "haven't asked
    /// permission" or "no data recorded yet", which `authorizationStatus`
    /// alone cannot do (it returns `.notDetermined` for both cases).
    @available(watchOS 9.0, *)
    private func hasTemperatureHardwareSupport() -> Bool {
        let store = HKHealthStore()
        let tempType = HKQuantityType(.appleSleepingWristTemperature)

        let authStatus = store.authorizationStatus(for: tempType)
        if authStatus == .sharingAuthorized {
            // User already granted access -- hardware definitely exists.
            return true
        }
        if authStatus == .sharingDenied {
            // User denied, but denial implies the type was recognized by the
            // system. Hardware exists; we just cannot access the data.
            // Return true so the tier reflects actual hardware capability.
            return true
        }

        // authStatus == .notDetermined: ambiguous. Run a trial query to
        // determine if the hardware supports this sample type.
        let semaphore = DispatchSemaphore(value: 0)
        var hardwareSupported = false

        let now = Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: now.addingTimeInterval(-86400),
            end: now,
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: tempType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, _, error in
            // No error means the type is recognized by hardware.
            // An error (e.g. HKError.errorInvalidArgument) means the
            // hardware does not support this sample type.
            hardwareSupported = (error == nil)
            semaphore.signal()
        }

        store.execute(query)
        let result = semaphore.wait(timeout: .now() + 3)
        if result == .timedOut {
            store.stop(query)
            return false
        }

        return hardwareSupported
    }

    private init() {}
}
