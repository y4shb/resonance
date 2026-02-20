//
//  StatusItemView.swift
//  Resonance Mac
//
//  SwiftUI view for the menu bar icon area with dynamic state indication
//

#if os(macOS)

import SwiftUI

// MARK: - Status Item View

struct StatusItemView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        iconForState
            .imageScale(.medium)
    }

    // MARK: - Icon States

    @ViewBuilder
    private var iconForState: some View {
        switch controller.connectionStatus {
        case .disconnected:
            // Music note with X overlay for disconnected
            Image(systemName: "music.note")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

        case .syncing:
            // Music note with sync indicator
            Image(systemName: "music.note")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)

        case .connected:
            if controller.nowPlayingInfo.isPlaying {
                // Active playing state
                Image(systemName: "music.note.list")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            } else {
                // Connected but not playing
                Image(systemName: "music.note")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Connected Playing") {
    let controller = MenuBarController()
    controller.connectionStatus = .connected
    controller.nowPlayingInfo = MenuBarNowPlayingInfo(
        songTitle: "Test Song",
        artistName: "Test Artist",
        isPlaying: true,
        progress: 0.5,
        duration: 240,
        explanation: nil,
        artworkData: nil
    )
    return StatusItemView(controller: controller)
        .padding()
}

#Preview("Disconnected") {
    let controller = MenuBarController()
    controller.connectionStatus = .disconnected
    return StatusItemView(controller: controller)
        .padding()
}

#endif
