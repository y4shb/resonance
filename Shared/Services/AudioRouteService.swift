//
//  AudioRouteService.swift
//  Resonance
//
//  Detects the current audio output route (speaker, headphones, Bluetooth,
//  CarPlay/car audio, AirPlay) by subscribing to AVAudioSession route change
//  notifications. Also infers driving state from car audio detection.
//  (Workstream 3.4 & 3.5)
//

#if os(iOS)

import Foundation
import AVFoundation
import Combine

// MARK: - Audio Route Service

/// Monitors the audio output route and publishes changes.
/// Subscribes to `AVAudioSession.routeChangeNotification` for real-time updates.
final class AudioRouteService: ObservableObject {

    // MARK: - Published State

    /// Current detected audio route.
    @Published private(set) var currentRoute: AudioRoute = .unknown

    /// Whether car audio is detected, indicating the user may be driving.
    @Published private(set) var isCarAudioActive = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let audioSession = AVAudioSession.sharedInstance()

    // MARK: - Initialization

    init() {
        logInfo("AudioRouteService initializing", category: .general)
        detectCurrentRoute()
        subscribeToRouteChanges()
    }

    // MARK: - Route Detection

    /// Reads the current audio route from AVAudioSession and updates published state.
    private func detectCurrentRoute() {
        let route = audioSession.currentRoute
        let detectedRoute = classifyRoute(route)

        currentRoute = detectedRoute
        isCarAudioActive = detectedRoute == .carAudio

        logDebug(
            "Audio route detected: \(detectedRoute.rawValue), "
            + "outputs: \(route.outputs.map { $0.portType.rawValue })",
            category: .general
        )
    }

    /// Subscribes to route change notifications for real-time updates.
    private func subscribeToRouteChanges() {
        NotificationCenter.default.publisher(
            for: AVAudioSession.routeChangeNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        .store(in: &cancellables)
    }

    // MARK: - Route Change Handling

    private func handleRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[
            AVAudioSessionRouteChangeReasonKey
        ] as? UInt,
        let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            detectCurrentRoute()
            return
        }

        logDebug(
            "Audio route changed: reason=\(reason.rawValue)",
            category: .general
        )

        detectCurrentRoute()
    }

    // MARK: - Route Classification

    /// Maps AVAudioSession port types to the app's AudioRoute enum.
    private func classifyRoute(_ route: AVAudioSessionRouteDescription) -> AudioRoute {
        // Check outputs in priority order
        for output in route.outputs {
            switch output.portType {
            case .carAudio:
                return .carAudio

            case .headphones, .usbAudio:
                return .headphones

            case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
                // Check if the Bluetooth device name suggests car audio
                let name = output.portName.lowercased()
                let carKeywords = ["car", "vehicle", "carplay", "sync", "uconnect",
                                   "mylink", "entune", "starlink"]
                if carKeywords.contains(where: { name.contains($0) }) {
                    return .carAudio
                }
                return .bluetoothA2DP

            case .airPlay:
                return .airPlay

            case .builtInSpeaker, .builtInReceiver:
                return .builtInSpeaker

            default:
                continue
            }
        }

        return .unknown
    }
}

#endif
