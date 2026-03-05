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
    private let nowPlayingRequestSubject = PassthroughSubject<Void, Never>()

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

    var nowPlayingRequests: AnyPublisher<Void, Never> {
        nowPlayingRequestSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    /// Messages queued before session activation; flushed once activated.
    private var pendingMessages: [WatchMessage] = []

    /// Maximum pending messages to buffer (prevents unbounded memory growth).
    private let maxPendingMessages = 10

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

    /// Flushes any messages that were queued before the session became activated.
    private func flushPendingMessages() {
        guard !pendingMessages.isEmpty else { return }
        logInfo("Flushing \(pendingMessages.count) pending WCSession messages", category: .watchConnectivity)
        let messages = pendingMessages
        pendingMessages.removeAll()
        for message in messages {
            sendMessage(message)
        }
    }

    // MARK: - Sending (Phone -> Watch)

    func sendNowPlaying(_ packet: NowPlayingPacket) {
        let message = WatchMessage.nowPlayingUpdate(packet)
        sendMessage(message)
        // sendMessage already falls back to applicationContext when Watch is
        // unreachable, which is persistent. Avoid transferUserInfo here because
        // it queues every call for guaranteed delivery, creating duplicate
        // deliveries and filling the transfer queue with stale now-playing data.
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
            logWarning("Complication data transfer failed, scheduling retry", category: .watchConnectivity)
            Task {
                await retryComplicationTransfer(data: data, attempt: 1, maxAttempts: 3)
            }
        }
    }

    // MARK: - Complication Transfer Retry

    private func retryComplicationTransfer(data: ComplicationData, attempt: Int, maxAttempts: Int) async {
        guard attempt <= maxAttempts else {
            logWarning("Complication transfer failed after \(maxAttempts) attempts, giving up", category: .watchConnectivity)
            return
        }

        let delaySeconds = UInt64(pow(2.0, Double(attempt - 1))) // 1s, 2s, 4s
        let delayNanoseconds = delaySeconds * 1_000_000_000

        do {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        } catch {
            return // Task was cancelled
        }

        guard let session = session, session.activationState == .activated else {
            logWarning("Complication retry attempt \(attempt)/\(maxAttempts): session not activated", category: .watchConnectivity)
            await retryComplicationTransfer(data: data, attempt: attempt + 1, maxAttempts: maxAttempts)
            return
        }

        do {
            let message = WatchMessage.complicationUpdate(data)
            let dict = try message.toDictionary()

            if session.isComplicationEnabled {
                session.transferCurrentComplicationUserInfo(dict)
                logInfo("Complication data transferred on retry attempt \(attempt)/\(maxAttempts)", category: .watchConnectivity)
            } else {
                session.transferUserInfo(dict)
                logInfo("Complication data transferred via userInfo on retry attempt \(attempt)/\(maxAttempts)", category: .watchConnectivity)
            }
        } catch {
            logWarning("Complication retry attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)", category: .watchConnectivity)
            await retryComplicationTransfer(data: data, attempt: attempt + 1, maxAttempts: maxAttempts)
        }
    }

    // MARK: - Application Context

    func updateApplicationContext(_ context: [String: Any]) throws {
        guard let session = session, session.activationState == .activated else {
            logWarning("Cannot update application context: session not activated", category: .watchConnectivity)
            return
        }

        // Merge with existing context to avoid overwriting unrelated keys.
        // updateApplicationContext replaces the entire dictionary.
        var merged = session.applicationContext
        for (key, value) in context {
            merged[key] = value
        }
        try session.updateApplicationContext(merged)
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
            // Queue message for delivery after activation
            if pendingMessages.count < maxPendingMessages {
                pendingMessages.append(watchMessage)
                logDebug("Message queued (session not activated); queue size: \(pendingMessages.count)", category: .watchConnectivity)
            } else {
                // Drop oldest to keep only latest state
                pendingMessages.removeFirst()
                pendingMessages.append(watchMessage)
                logDebug("Pending queue full; oldest message dropped", category: .watchConnectivity)
            }
            return
        }

        do {
            let realtimeDict = try watchMessage.toDictionary()

            if session.isReachable {
                // Real-time delivery when Watch app is in foreground
                session.sendMessage(realtimeDict, replyHandler: nil) { [weak self] error in
                    logError("sendMessage failed, falling back to application context",
                             error: error, category: .watchConnectivity)
                    // Fall back to application context for persistent delivery
                    self?.fallbackToApplicationContext(watchMessage)
                }
                logDebug("Message sent via sendMessage (reachable)", category: .watchConnectivity)
            } else {
                // Watch not reachable; use application context for persistent state
                fallbackToApplicationContext(watchMessage)
                logDebug("Message sent via applicationContext (not reachable)", category: .watchConnectivity)
            }
        } catch {
            logError("Failed to encode watch message", error: error, category: .watchConnectivity)
        }
    }

    private func fallbackToApplicationContext(_ watchMessage: WatchMessage) {
        guard let session = session else { return }
        do {
            // Use message-type-specific key so nowPlaying, state, and complication
            // data coexist in application context without overwriting each other.
            let contextDict = try watchMessage.toContextDictionary()
            var merged = session.applicationContext
            for (key, value) in contextDict {
                merged[key] = value
            }
            try session.updateApplicationContext(merged)
        } catch {
            logError("Failed to update application context as fallback",
                     error: error, category: .watchConnectivity)
        }
    }

    private func handleReceivedMessage(_ dict: [String: Any]) {
        do {
            let message = try WatchMessage.fromDictionary(dict)
            handleDecodedMessage(message)
        } catch {
            logError("Failed to decode received message", error: error, category: .watchConnectivity)
        }
    }

    private func handleDecodedMessage(_ message: WatchMessage) {
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

        case .requestNowPlaying:
            logInfo("Watch requested current NowPlaying state", category: .watchConnectivity)
            nowPlayingRequestSubject.send(())

        case .nowPlayingUpdate, .stateUpdate, .complicationUpdate:
            // These are phone -> watch messages; should not be received on iOS
            logWarning("Received unexpected phone->watch message on iOS side", category: .watchConnectivity)
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

            // Flush any messages that were queued before activation
            if activationState == .activated {
                DispatchQueue.main.async { [weak self] in
                    self?.flushPendingMessages()
                }
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        logInfo("WCSession became inactive", category: .watchConnectivity)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logInfo("WCSession deactivated, reactivating", category: .watchConnectivity)
        // Reactivate for device switching scenarios.
        // Must use WCSession.default, not the parameter — the parameter is the
        // deactivated session and cannot be reused.
        WCSession.default.activate()
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
        // Application context may contain multiple message-type keys.
        // Try the multi-key approach first, fall back to single-key.
        let messages = WatchMessage.allFromContextDictionary(applicationContext)
        if !messages.isEmpty {
            for message in messages {
                handleDecodedMessage(message)
            }
        } else {
            handleReceivedMessage(applicationContext)
        }
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
