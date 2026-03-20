//
//  PhoneConnectivityService.swift
//  Resonance Watch
//
//  Watch-side WCSession delegate for Watch <-> Phone communication
//

import Foundation
import Combine
import SwiftUI
import WatchConnectivity

// MARK: - PhoneConnectivityService

final class PhoneConnectivityService: NSObject, ObservableObject {

    // MARK: - Published Properties (for UI binding)

    @Published var currentNowPlaying: NowPlayingPacket?
    @Published var currentState: StatePacket?
    @Published var isPhoneReachable = false
    @Published var isSessionActivated = false

    // MARK: - Receiving Subjects (for additional subscribers)

    private let nowPlayingSubject = PassthroughSubject<NowPlayingPacket, Never>()
    private let stateSubject = PassthroughSubject<StatePacket, Never>()
    private let complicationSubject = PassthroughSubject<ComplicationData, Never>()

    var nowPlayingUpdates: AnyPublisher<NowPlayingPacket, Never> {
        nowPlayingSubject.eraseToAnyPublisher()
    }

    var stateUpdates: AnyPublisher<StatePacket, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var complicationUpdates: AnyPublisher<ComplicationData, Never> {
        complicationSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    private var cancellables = Set<AnyCancellable>()
    private var pendingBiometricData: [BiometricPacket] = []
    private var pendingBookmarks: [BookmarkTriggerPacket] = []
    private let pendingDataLock = NSLock()
    private let maxPendingBiometricEntries = 10
    private let maxPendingBookmarks = 10

    // MARK: - Initialization

    override init() {
        super.init()
        logInfo("PhoneConnectivityService initialized", category: .watchConnectivity)
    }

    // MARK: - Activation

    func activate() {
        guard let session = session else {
            logWarning("WCSession is not supported on this device", category: .watchConnectivity)
            return
        }

        session.delegate = self
        session.activate()
        logInfo("WCSession activation requested (watchOS)", category: .watchConnectivity)
    }

    // MARK: - Sending (Watch -> Phone)

    func requestNowPlaying() {
        let message = WatchMessage.requestNowPlaying
        sendMessage(message)
    }

    func sendPlaybackCommand(_ command: PlaybackCommand) {
        let message = WatchMessage.playbackCommand(command)
        sendMessage(message)
    }

    func sendBiometricUpdate(_ packet: BiometricPacket) {
        guard let session = session, session.activationState == .activated, session.isReachable else {
            logWarning("Phone not reachable, queuing biometric data for later", category: .watchConnectivity)
            pendingDataLock.lock()
            pendingBiometricData.append(packet)
            if pendingBiometricData.count > maxPendingBiometricEntries {
                pendingBiometricData = Array(pendingBiometricData.suffix(maxPendingBiometricEntries))
            }
            pendingDataLock.unlock()
            return
        }

        let message = WatchMessage.biometricUpdate(packet)
        sendMessageGuaranteed(message)
    }

    /// Sends all pending biometric data that was queued while the phone was unreachable.
    func flushPendingData() {
        pendingDataLock.lock()
        guard !pendingBiometricData.isEmpty else {
            pendingDataLock.unlock()
            return
        }
        let dataToSend = pendingBiometricData
        pendingBiometricData.removeAll()
        pendingDataLock.unlock()

        guard let session = session, session.activationState == .activated, session.isReachable else {
            // Put data back since we can't send it
            pendingDataLock.lock()
            pendingBiometricData = dataToSend + pendingBiometricData
            if pendingBiometricData.count > maxPendingBiometricEntries {
                pendingBiometricData = Array(pendingBiometricData.suffix(maxPendingBiometricEntries))
            }
            pendingDataLock.unlock()
            logWarning("Cannot flush pending data: phone still not reachable", category: .watchConnectivity)
            return
        }

        logInfo("Flushing \(dataToSend.count) pending biometric entries", category: .watchConnectivity)
        for packet in dataToSend {
            let message = WatchMessage.biometricUpdate(packet)
            sendMessageGuaranteed(message)
        }
    }

    func sendMoodInput(_ packet: MoodPacket) {
        let message = WatchMessage.moodInput(packet)
        sendMessage(message)
    }

    func sendCrownAdjustment(_ adjustment: CrownAdjustment) {
        let message = WatchMessage.crownAdjustment(adjustment)
        sendMessage(message)
    }

    /// Sends a bookmark trigger to the iPhone with current biometric data.
    /// Falls back to buffering if the phone is not reachable.
    func sendBookmarkTrigger(heartRate: Double?, hrv: Double?, source: String) {
        let packet = BookmarkTriggerPacket(
            triggerSource: source,
            heartRate: heartRate,
            hrv: hrv
        )

        guard let session = session, session.activationState == .activated, session.isReachable else {
            logWarning("Phone not reachable, queuing bookmark trigger for later", category: .watchConnectivity)
            pendingDataLock.lock()
            pendingBookmarks.append(packet)
            if pendingBookmarks.count > maxPendingBookmarks {
                pendingBookmarks = Array(pendingBookmarks.suffix(maxPendingBookmarks))
            }
            pendingDataLock.unlock()
            return
        }

        let message = WatchMessage.bookmarkTrigger(packet)
        sendMessageGuaranteed(message)
        logInfo("Bookmark trigger sent to phone via \(source)", category: .watchConnectivity)
    }

    /// Sends all pending bookmark triggers that were queued while the phone was unreachable.
    private func flushPendingBookmarks() {
        pendingDataLock.lock()
        guard !pendingBookmarks.isEmpty else {
            pendingDataLock.unlock()
            return
        }
        let bookmarksToSend = pendingBookmarks
        pendingBookmarks.removeAll()
        pendingDataLock.unlock()

        guard let session = session, session.activationState == .activated, session.isReachable else {
            pendingDataLock.lock()
            pendingBookmarks = bookmarksToSend + pendingBookmarks
            if pendingBookmarks.count > maxPendingBookmarks {
                pendingBookmarks = Array(pendingBookmarks.suffix(maxPendingBookmarks))
            }
            pendingDataLock.unlock()
            logWarning("Cannot flush pending bookmarks: phone still not reachable", category: .watchConnectivity)
            return
        }

        logInfo("Flushing \(bookmarksToSend.count) pending bookmark triggers", category: .watchConnectivity)
        for packet in bookmarksToSend {
            let message = WatchMessage.bookmarkTrigger(packet)
            sendMessageGuaranteed(message)
        }
    }

    /// Sends a pre-encoded dictionary via guaranteed delivery (transferUserInfo).
    /// Used by OvernightTemperatureSensor for temperature data.
    func sendGuaranteedMessage(_ dict: [String: Any]) {
        guard let session = session, session.activationState == .activated else {
            logWarning("Cannot send guaranteed message: session not activated", category: .watchConnectivity)
            return
        }
        session.transferUserInfo(dict)
        logDebug("Guaranteed message queued via transferUserInfo", category: .watchConnectivity)
    }

    // MARK: - Private Helpers

    /// Send message with real-time preference, falling back to application context
    private func sendMessage(_ watchMessage: WatchMessage) {
        guard let session = session, session.activationState == .activated else {
            logWarning("Cannot send message: session not activated", category: .watchConnectivity)
            return
        }

        do {
            let dict = try watchMessage.toDictionary()

            if session.isReachable {
                session.sendMessage(dict, replyHandler: nil) { error in
                    logError("sendMessage failed", error: error, category: .watchConnectivity)
                }
                logDebug("Message sent via sendMessage (reachable)", category: .watchConnectivity)
            } else {
                // Phone not reachable; use application context.
                // Merge with existing context to avoid overwriting unrelated keys.
                var merged = session.applicationContext
                for (key, value) in dict {
                    merged[key] = value
                }
                try session.updateApplicationContext(merged)
                logDebug("Message sent via applicationContext (not reachable)", category: .watchConnectivity)
            }
        } catch {
            logError("Failed to send watch message", error: error, category: .watchConnectivity)
        }
    }

    /// Send message with guaranteed delivery using transferUserInfo
    private func sendMessageGuaranteed(_ watchMessage: WatchMessage) {
        guard let session = session, session.activationState == .activated else {
            logWarning("Cannot transfer user info: session not activated", category: .watchConnectivity)
            return
        }

        do {
            let dict = try watchMessage.toDictionary()
            session.transferUserInfo(dict)
            logDebug("Message queued via transferUserInfo (guaranteed)", category: .watchConnectivity)
        } catch {
            logError("Failed to encode message for transferUserInfo", error: error, category: .watchConnectivity)
        }
    }

    /// Handle a single decoded WatchMessage.
    private func handleDecodedMessage(_ message: WatchMessage) {
        switch message {
        case .nowPlayingUpdate(let packet):
            logDebug("Received now playing: \(packet.songTitle) - \(packet.artistName)", category: .watchConnectivity)
            DispatchQueue.main.async { [weak self] in
                self?.currentNowPlaying = packet
                self?.nowPlayingSubject.send(packet)
            }

        case .stateUpdate(let packet):
            logDebug("Received state update: context=\(packet.currentContext ?? "none")", category: .watchConnectivity)
            DispatchQueue.main.async { [weak self] in
                self?.currentState = packet
                self?.stateSubject.send(packet)
            }

        case .complicationUpdate(let data):
            logDebug("Received complication update", category: .watchConnectivity)
            DispatchQueue.main.async { [weak self] in
                self?.complicationSubject.send(data)
            }

        case .biometricUpdate, .moodInput, .playbackCommand, .crownAdjustment, .requestNowPlaying, .bookmarkTrigger, .overnightTemperature:
            // These are watch -> phone messages; should not be received on watchOS
            logWarning("Received unexpected watch->phone message on watchOS side", category: .watchConnectivity)
        }
    }

    /// Handle a real-time message dictionary (from sendMessage).
    private func handleReceivedMessage(_ dict: [String: Any]) {
        do {
            let message = try WatchMessage.fromDictionary(dict)
            handleDecodedMessage(message)
        } catch {
            logError("Failed to decode received message", error: error, category: .watchConnectivity)
        }
    }

    /// Handle an application context dictionary that may contain multiple
    /// message-type keys (nowPlaying, state, complication) simultaneously.
    private func handleReceivedContext(_ dict: [String: Any]) {
        let messages = WatchMessage.allFromContextDictionary(dict)
        if messages.isEmpty {
            logDebug("Application context contained no decodable messages", category: .watchConnectivity)
            return
        }
        for message in messages {
            handleDecodedMessage(message)
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityService: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isSessionActivated = (activationState == .activated)
            self?.isPhoneReachable = session.isReachable
        }

        if let error = error {
            logError("WCSession activation failed (watchOS)", error: error, category: .watchConnectivity)
        } else {
            logInfo("WCSession activation completed (watchOS): \(activationState.rawValue)", category: .watchConnectivity)
        }

        // Check for any application context that arrived before activation.
        // Context may contain multiple message-type keys (nowPlaying, state, etc.).
        if activationState == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                logDebug("Processing application context received before activation", category: .watchConnectivity)
                handleReceivedContext(context)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isPhoneReachable = session.isReachable
        }
        logInfo("Phone reachability changed: \(session.isReachable)", category: .watchConnectivity)

        if session.isReachable {
            flushPendingData()
            flushPendingBookmarks()
        }
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
        logDebug("Received application context update (watchOS)", category: .watchConnectivity)
        handleReceivedContext(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        logDebug("Received user info transfer (watchOS)", category: .watchConnectivity)
        handleReceivedMessage(userInfo)
    }

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        if let error = error {
            logError("User info transfer failed (watchOS)", error: error, category: .watchConnectivity)
        } else {
            logDebug("User info transfer completed (watchOS)", category: .watchConnectivity)
        }
    }
}
