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

    func sendPlaybackCommand(_ command: PlaybackCommand) {
        let message = WatchMessage.playbackCommand(command)
        sendMessage(message)
    }

    func sendBiometricUpdate(_ packet: BiometricPacket) {
        let message = WatchMessage.biometricUpdate(packet)
        sendMessageGuaranteed(message)
    }

    func sendMoodInput(_ packet: MoodPacket) {
        let message = WatchMessage.moodInput(packet)
        sendMessage(message)
    }

    func sendCrownAdjustment(_ adjustment: CrownAdjustment) {
        let message = WatchMessage.crownAdjustment(adjustment)
        sendMessage(message)
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
                // Phone not reachable; use application context
                try session.updateApplicationContext(dict)
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

    private func handleReceivedMessage(_ dict: [String: Any]) {
        do {
            let message = try WatchMessage.fromDictionary(dict)

            switch message {
            case .nowPlayingUpdate(let packet):
                logDebug("Received now playing: \(packet.songTitle) - \(packet.artistName)", category: .watchConnectivity)
                DispatchQueue.main.async { [weak self] in
                    self?.currentNowPlaying = packet
                }
                nowPlayingSubject.send(packet)

            case .stateUpdate(let packet):
                logDebug("Received state update: context=\(packet.currentContext ?? "none")", category: .watchConnectivity)
                DispatchQueue.main.async { [weak self] in
                    self?.currentState = packet
                }
                stateSubject.send(packet)

            case .complicationUpdate(let data):
                logDebug("Received complication update", category: .watchConnectivity)
                complicationSubject.send(data)

            case .biometricUpdate, .moodInput, .playbackCommand, .crownAdjustment:
                // These are watch -> phone messages; should not be received on watchOS
                logWarning("Received unexpected watch->phone message on watchOS side", category: .watchConnectivity)
            }
        } catch {
            logError("Failed to decode received message", error: error, category: .watchConnectivity)
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

        // Check for any application context that arrived before activation
        if activationState == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                logDebug("Processing application context received before activation", category: .watchConnectivity)
                handleReceivedMessage(context)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isPhoneReachable = session.isReachable
        }
        logInfo("Phone reachability changed: \(session.isReachable)", category: .watchConnectivity)
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
        handleReceivedMessage(applicationContext)
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
