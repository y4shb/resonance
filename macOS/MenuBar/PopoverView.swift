//
//  PopoverView.swift
//  Resonance Mac
//
//  SwiftUI popover content for the menu bar: now playing, context, connection status
//

#if os(macOS)

import SwiftUI
import AppKit

// MARK: - Popover View

struct PopoverView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()

            // Now Playing
            nowPlayingSection

            Divider()

            // Context Sending
            contextSection

            Divider()

            // Connection Status
            connectionSection

            Divider()

            // Actions
            actionsSection
        }
        .frame(width: 280)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "music.note")
                .foregroundStyle(.blue)
            Text("Resonance")
                .font(.headline)
            Spacer()
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Now Playing Section

    private var nowPlayingSection: some View {
        HStack(spacing: 12) {
            // Album Art Placeholder
            albumArtView

            // Song Info
            VStack(alignment: .leading, spacing: 4) {
                if controller.nowPlayingInfo.songTitle != "Not Playing" {
                    Text(controller.nowPlayingInfo.songTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(controller.nowPlayingInfo.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // Progress Bar
                    progressBar
                } else {
                    Text("Not Playing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Open Resonance on iPhone to start")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Album Art

    private var albumArtView: some View {
        Group {
            if let artworkData = controller.nowPlayingInfo.artworkData,
               let nsImage = NSImage(data: artworkData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                        .frame(width: 50, height: 50)
                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.quaternary)
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.blue)
                        .frame(
                            width: geometry.size.width * max(0, min(1, controller.nowPlayingInfo.progress)),
                            height: 3
                        )
                }
            }
            .frame(height: 3)

            Text(formatTime(controller.nowPlayingInfo.duration * controller.nowPlayingInfo.progress))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Context Section

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Context Sending:")
                .font(.caption)
                .foregroundStyle(.secondary)

            contextRow(
                enabled: controller.contextInfo.isFocusModeEnabled,
                label: "Focus Mode: \(controller.contextInfo.focusMode)"
            )

            contextRow(
                enabled: controller.contextInfo.isActiveAppEnabled,
                label: "Active App: \(controller.contextInfo.activeApp)"
            )

            if controller.contextInfo.isDeepWorkDetected {
                contextRow(enabled: true, label: "Deep Work Detected")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func contextRow(enabled: Bool, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(enabled ? .green : .secondary)
                .font(.caption)
            Text(label)
                .font(.caption)
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("iPhone:")
                    .font(.caption)

                HStack(spacing: 4) {
                    Text(controller.connectionStatus.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)

                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 6, height: 6)
                }
            }

            Text("Last sync: \(controller.lastSyncTimeString)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var connectionStatusColor: Color {
        switch controller.connectionStatus {
        case .connected: return .green
        case .disconnected: return .red
        case .syncing: return .orange
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 4) {
            Button {
                openSettings()
            } label: {
                HStack {
                    Text("Open Settings...")
                        .font(.caption)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Divider()
                .padding(.horizontal, 16)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit Resonance")
                        .font(.caption)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Preview

#Preview("Popover - Playing") {
    let controller = MenuBarController()
    controller.connectionStatus = .connected
    controller.nowPlayingInfo = MenuBarNowPlayingInfo(
        songTitle: "Weightless",
        artistName: "Marconi Union",
        isPlaying: true,
        progress: 0.45,
        duration: 234,
        explanation: "Calming you down after a stressful meeting",
        artworkData: nil
    )
    controller.contextInfo = MenuBarContextInfo(
        focusMode: "Work",
        activeApp: "Xcode",
        isDeepWorkDetected: true,
        isFocusModeEnabled: true,
        isActiveAppEnabled: true
    )
    controller.lastSyncTime = Date()
    return PopoverView(controller: controller)
}

#Preview("Popover - Disconnected") {
    let controller = MenuBarController()
    controller.connectionStatus = .disconnected
    return PopoverView(controller: controller)
}

#endif
