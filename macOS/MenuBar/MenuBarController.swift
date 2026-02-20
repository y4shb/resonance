//
//  MenuBarController.swift
//  Resonance Mac
//
//  ObservableObject managing menu bar state for the macOS menu bar app
//

#if os(macOS)

import Foundation
import Combine

// MARK: - Connection Status

enum ConnectionStatus: String {
    case connected = "Connected"
    case disconnected = "Disconnected"
    case syncing = "Syncing"

    var iconSuffix: String {
        switch self {
        case .connected: return ""
        case .disconnected: return ".slash"
        case .syncing: return ".arrow.trianglehead.2.clockwise"
        }
    }

    var statusColor: String {
        switch self {
        case .connected: return "green"
        case .disconnected: return "red"
        case .syncing: return "orange"
        }
    }
}

// MARK: - Now Playing Info

struct MenuBarNowPlayingInfo {
    var songTitle: String
    var artistName: String
    var isPlaying: Bool
    var progress: Double          // 0.0 - 1.0
    var duration: TimeInterval
    var explanation: String?
    var artworkData: Data?

    static let empty = MenuBarNowPlayingInfo(
        songTitle: "Not Playing",
        artistName: "",
        isPlaying: false,
        progress: 0,
        duration: 0,
        explanation: nil,
        artworkData: nil
    )
}

// MARK: - Context Info

struct MenuBarContextInfo {
    var focusMode: String
    var activeApp: String
    var isDeepWorkDetected: Bool
    var isFocusModeEnabled: Bool
    var isActiveAppEnabled: Bool

    static let `default` = MenuBarContextInfo(
        focusMode: "Off",
        activeApp: "Monitoring",
        isDeepWorkDetected: false,
        isFocusModeEnabled: true,
        isActiveAppEnabled: true
    )
}

// MARK: - MenuBarController

final class MenuBarController: ObservableObject {

    // MARK: - Published Properties

    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var nowPlayingInfo: MenuBarNowPlayingInfo = .empty
    @Published var contextInfo: MenuBarContextInfo = .default
    @Published var lastSyncTime: Date?

    // MARK: - Computed Properties

    /// The SF Symbol name to display in the menu bar
    var menuBarIconName: String {
        switch connectionStatus {
        case .disconnected:
            return "music.note"
        case .syncing:
            return "music.note"
        case .connected:
            return nowPlayingInfo.isPlaying ? "music.note.list" : "music.note"
        }
    }

    /// Formatted last sync time string
    var lastSyncTimeString: String {
        guard let lastSync = lastSyncTime else {
            return "Never"
        }

        let interval = Date().timeIntervalSince(lastSync)

        if interval < 5 {
            return "Just now"
        } else if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: lastSync)
        }
    }

    // MARK: - Initialization

    init() {
        logInfo("MenuBarController initialized", category: .ui)
    }

    // MARK: - Update Methods

    /// Update now playing info from a NowPlayingPacket (when connectivity is available)
    func updateNowPlaying(_ packet: NowPlayingPacket) {
        nowPlayingInfo = MenuBarNowPlayingInfo(
            songTitle: packet.songTitle,
            artistName: packet.artistName,
            isPlaying: packet.isPlaying,
            progress: packet.progress,
            duration: packet.duration,
            explanation: packet.explanation,
            artworkData: packet.artworkData
        )
        lastSyncTime = Date()
        logDebug("Now playing updated: \(packet.songTitle)", category: .ui)
    }

    /// Update connection status
    func updateConnectionStatus(_ status: ConnectionStatus) {
        connectionStatus = status
        logDebug("Connection status: \(status.rawValue)", category: .ui)
    }

    /// Update context info
    func updateContextInfo(focusMode: String? = nil, activeApp: String? = nil, isDeepWork: Bool? = nil) {
        if let focusMode = focusMode {
            contextInfo.focusMode = focusMode
        }
        if let activeApp = activeApp {
            contextInfo.activeApp = activeApp
        }
        if let isDeepWork = isDeepWork {
            contextInfo.isDeepWorkDetected = isDeepWork
        }
        logDebug("Context info updated", category: .ui)
    }

    /// Clear now playing state
    func clearNowPlaying() {
        nowPlayingInfo = .empty
        logDebug("Now playing cleared", category: .ui)
    }
}

#endif
