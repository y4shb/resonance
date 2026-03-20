import SwiftUI
import Combine
import WatchKit

/// Manages Digital Crown interaction for energy adjustment (DJ Mode).
/// Crown rotation adjusts energy target; sent to iPhone to influence song selection.
final class CrownHandler: ObservableObject {
    // MARK: - Published State

    @Published var isDJModeActive = false
    @Published var crownValue = 0.0
    @Published var energyAdjustment = 0.0

    // MARK: - Dependencies

    private let connectivityService: PhoneConnectivityService
    private var debounceTimer: Timer?
    private var lastSentValue = 0.0

    init(connectivityService: PhoneConnectivityService) {
        self.connectivityService = connectivityService
    }

    deinit {
        debounceTimer?.invalidate()
    }

    // MARK: - Crown Rotation

    func handleCrownRotation(value: Double) {
        guard isDJModeActive else { return }

        let clamped = max(-CrownConstants.maxAdjustment,
                          min(CrownConstants.maxAdjustment, value))
        crownValue = clamped
        energyAdjustment = clamped / CrownConstants.maxAdjustment

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: CrownConstants.debounceIntervalSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.sendAdjustment()
        }
    }

    // MARK: - DJ Mode Toggle

    func toggleDJMode() {
        isDJModeActive.toggle()
        WKInterfaceDevice.current().play(isDJModeActive ? .start : .stop)

        if !isDJModeActive {
            crownValue = 0.0
            energyAdjustment = 0.0
            sendAdjustment()
        }
    }

    // MARK: - Send to iPhone

    private func sendAdjustment() {
        let normalizedDelta = energyAdjustment  // -1.0 to 1.0 range
        guard abs(normalizedDelta - lastSentValue) > 0.01 else { return }

        let adjustment = CrownAdjustment(
            delta: normalizedDelta,
            adjustmentType: "energy"
        )
        connectivityService.sendCrownAdjustment(adjustment)
        lastSentValue = normalizedDelta
    }
}
