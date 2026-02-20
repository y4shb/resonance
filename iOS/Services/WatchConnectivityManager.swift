//
//  WatchConnectivityManager.swift
//  Resonance
//
//  iOS-side WCSession delegate for Watch <-> Phone communication
//

#if os(iOS)

import Foundation
import Combine

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// MARK: - Protocol

protocol WatchConnectivityManagerProtocol: AnyObject {
    func activate()
    var isReachable: Bool { get }
    var isPaired: Bool { get }

    // Sending (Phone -> Watch)
    func sendNowPlaying(_ packet: NowPlayingPacket)
    func sendStateUpdate(_ packet: StatePacket)
    func updateComplication(_ data: ComplicationData)

    // Receiving (Watch -> Phone)
    var biometricUpdates: AnyPublisher<BiometricPacket, Never> { get }
    var moodInputs: AnyPublisher<MoodPacket, Never> { get }
    var playbackCommands: AnyPublisher<PlaybackCommand, Never> { get }
    var crownAdjustments: AnyPublisher<CrownAdjustment, Never> { get }

    // Application Context (persistent)
    func updateApplicationContext(_ context: [String: Any]) throws
    var receivedApplicationContext: [String: Any] { get }

    // User Info Transfer (queued)
    func transferUserInfo(_ userInfo: [String: Any])
}

// MARK: - Implementation

final class WatchConnectivityManager: NSObject, ObservableObject, WatchConnectivityManagerProtocol {

    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    @Published private(set) var isSessionActivated = false
    @Published private(set) var watchIsReachable = false
    @Published private(set) var watchIsPaired = false

    // MARK: - Protocol Conformance

    var isReachable: Bool { watchIsReachable }
    var isPaired: Bool { watchIsPaired }

    // MARK: - Receiving Subjects

    private let biometricSubject = PassthroughSubject<BiometricPacket, Never>()
    private let moodSubject = PassthroughSubject<MoodPacket, Never>()
    private let playbackCommandSubject = PassthroughSubject<PlaybackCommand, Never>()
    private let crownAdjustmentSubject = PassthroughSubject<CrownAdjustment, Never>()

    var biometricUpdates: AnyPublisher<BiometricPacket, Never> {
        biometricSubject.eraseToAnyPublisher()
    }

    var moodInputs: AnyPublisher<MoodPacket, Never> {
        moodSubject.eraseToAnyPublisher()
    }

    var playbackCommands: AnyPublisher<PlaybackCommand, Never> {
        playbackCommandSubject.eraseToAnyPublisher()
    }

    var crownAdjustments: AnyPublisher<CrownAdjustment, Never> {
        crownAdjustmentSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        logInfo("WatchConnectivityManager initialized", category: .watchConnectivity)
    }

    // MARK: - Activation

    func activate() {
        guard let session = session else {
            logWarning("WCSession is not supported on this device", category: .watchConnectivity)
            return
        }

        session.delegate = self
        session.activate()
        logInfo("WCSession activation requested", category: .watchConnectivity)
    }

    // MARK: - Sending (Phone -> Watch)

    func sendNowPlaying(_ packet: NowPlayingPacket) {
        let message = WatchMessage.nowPlayingUpdate(packet)
        sendMessage(message)
    }

    func sendStateUpdate(_ packet: StatePacket) {
        let message = WatchMessage.stateUpdate(packet)
        sendMessage(message)
    }

    func updateComplication(_ data: ComplicationData) {
        guard let session = session, session.activationState == .activated else {
            logWarning("Cannot update complication: session not activated", category: .watchConnectivity)
            return
        }

        do {
            let message = WatchMessage.complicationUpdate(data)
            let dict = try message.toDictionary()

            if session.isComplicationEnabled {
                session.transferCurrentComplicationUserInfo(dict)
                logDebug("Complication data transferred", category: .watchConnectivity)
            } else {
                // Fall back to regular user info transfer
                session.transferUserInfo(dict)
                logDebug("Complication not enabled, using transferUserInfo", category: .watchConnectivity)
            }
        } catch {
            logError("Failed to encode complication data", error: error, category: .watchConnectivity)
        }
    }

    // MARK: - Application Context

    func updateApplicationContext(_ context: [String: Any]) throws {
        guard let session = session, session.activationState == .activated else {
            logWarning("Cannot update application context: session not activated", category: .watchConnectivity)
            return
        }

        try session.updateApplicationContext(context)
        logDebug("Application context updated", category: .watchConnectivity)
    }

    var receivedApplicationContext: [String: Any] {
        session?.receivedApplicationContext ?? [:]
    }

    // MARK: - User Info Transfer

    func transferUserInfo(_ userInfo: [String: Any]) {
        guard let session = session, session.activationState == .activated else {
            logWarning("Cannot transfer user info: session not activated", category: .watchConnectivity)
            return
        }

        session.transferUserInfo(userInfo)
        logDebug("User info transfer queued", category: .watchConnectivity)
    }

    // MARK: - Private Helpers

    private func sendMessage(_ watchMessage: WatchMessage) {
        guard let session = session, session.activationState == .activated else {
            logWarning("Cannot send message: session not activated", category: .watchConnectivity)
            return
        }

        do {
            let dict = try watchMessage.toDictionary()

            if session.isReachable {
                // Real-time delivery when Watch app is in foreground
                session.sendMessage(dict, replyHandler: nil) { [weak self] error in
                    logError("sendMessage failed, falling back to application context",
                             error: error, category: .watchConnectivity)
                    // Fall back to application context for persistent delivery
                    self?.fallbackToApplicationContext(dict)
                }
                logDebug("Message sent via sendMessage (reachable)", category: .watchConnectivity)
            } else {
                // Watch not reachable; use application context for persistent state
                fallbackToApplicationContext(dict)
                logDebug("Message sent via applicationContext (not reachable)", category: .watchConnectivity)
            }
        } catch {
            logError("Failed to encode watch message", error: error, category: .watchConnectivity)
        }
    }

    private func fallbackToApplicationContext(_ dict: [String: Any]) {
        guard let session = session else { return }
        do {
            try session.updateApplicationContext(dict)
        } catch {
            logError("Failed to update application context as fallback",
                     error: error, category: .watchConnectivity)
        }
    }

    private func handleReceivedMessage(_ dict: [String: Any]) {
        do {
            let message = try WatchMessage.fromDictionary(dict)

            switch message {
            case .biometricUpdate(let packet):
                logDebug("Received biometric update: HR=\(packet.heartRate ?? 0)", category: .watchConnectivity)
                biometricSubject.send(packet)

            case .moodInput(let packet):
                logDebug("Received mood input: mood=\(packet.moodLevel), energy=\(packet.energyLevel)", category: .watchConnectivity)
                moodSubject.send(packet)

            case .playbackCommand(let command):
                logDebug("Received playback command: \(command.command.rawValue)", category: .watchConnectivity)
                playbackCommandSubject.send(command)

            case .crownAdjustment(let adjustment):
                logDebug("Received crown adjustment: \(adjustment.adjustmentType) delta=\(adjustment.delta)", category: .watchConnectivity)
                crownAdjustmentSubject.send(adjustment)

            case .nowPlayingUpdate, .stateUpdate, .complicationUpdate:
                // These are phone -> watch messages; should not be received on iOS
                logWarning("Received unexpected phone->watch message on iOS side", category: .watchConnectivity)
            }
        } catch {
            logError("Failed to decode received message", error: error, category: .watchConnectivity)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isSessionActivated = (activationState == .activated)
            self?.watchIsPaired = session.isPaired
            self?.watchIsReachable = session.isReachable
        }

        if let error = error {
            logError("WCSession activation failed", error: error, category: .watchConnectivity)
        } else {
            logInfo("WCSession activation completed: \(activationState.rawValue)", category: .watchConnectivity)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        logInfo("WCSession became inactive", category: .watchConnectivity)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logInfo("WCSession deactivated, reactivating", category: .watchConnectivity)
        // Reactivate for device switching scenarios
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.watchIsReachable = session.isReachable
        }
        logInfo("Watch reachability changed: \(session.isReachable)", category: .watchConnectivity)
    }

    // MARK: - Receiving Messages

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        logDebug("Received application context update", category: .watchConnectivity)
        handleReceivedMessage(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        logDebug("Received user info transfer", category: .watchConnectivity)
        handleReceivedMessage(userInfo)
    }

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        if let error = error {
            logError("User info transfer failed", error: error, category: .watchConnectivity)
        } else {
            logDebug("User info transfer completed successfully", category: .watchConnectivity)
        }
    }
}

#endif
