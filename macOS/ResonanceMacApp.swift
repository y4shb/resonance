//
//  ResonanceMacApp.swift
//  Resonance Mac
//
//  Main entry point for the macOS menu bar app
//

import SwiftUI
import AppKit

@main
struct ResonanceMacApp: App {
    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - State

    @StateObject private var menuBarController = MenuBarController()

    // MARK: - Initialization

    init() {
        logInfo("Resonance Mac app launching", category: .general)
    }

    // MARK: - Body

    var body: some Scene {
        // Menu bar apps don't have a main window
        // The MenuBarExtra is the primary UI
        MenuBarExtra("AI DJ", systemImage: menuBarController.menuBarIconName) {
            PopoverView(controller: menuBarController)
        }
        .menuBarExtraStyle(.window)

        // Settings window (accessible via menu bar)
        Settings {
            MacSettingsView(controller: menuBarController)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("macOS app delegate did finish launching", category: .general)
    }

    func applicationWillTerminate(_ notification: Notification) {
        logInfo("macOS app delegate will terminate", category: .general)
    }
}

// MARK: - Settings View

struct MacSettingsView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        TabView {
            connectionSettingsTab
                .tabItem {
                    Label("Connection", systemImage: "link")
                }

            contextSettingsTab
                .tabItem {
                    Label("Context", systemImage: "brain")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }

    // MARK: - Connection Tab

    private var connectionSettingsTab: some View {
        Form {
            Section("iPhone Connection") {
                HStack {
                    Text("Status:")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(controller.connectionStatus.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Last Sync:")
                    Spacer()
                    Text(controller.lastSyncTimeString)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Info") {
                Text("The macOS companion connects to your iPhone via the local network to provide desktop context signals like focus mode and active application.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Context Tab

    private var contextSettingsTab: some View {
        Form {
            Section("Context Providers") {
                Toggle("Send Focus Mode", isOn: Binding(
                    get: { controller.contextInfo.isFocusModeEnabled },
                    set: { controller.contextInfo.isFocusModeEnabled = $0 }
                ))

                Toggle("Send Active App", isOn: Binding(
                    get: { controller.contextInfo.isActiveAppEnabled },
                    set: { controller.contextInfo.isActiveAppEnabled = $0 }
                ))
            }

            Section("Current Context") {
                HStack {
                    Text("Focus Mode:")
                    Spacer()
                    Text(controller.contextInfo.focusMode)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Active App:")
                    Spacer()
                    Text(controller.contextInfo.activeApp)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Deep Work:")
                    Spacer()
                    Text(controller.contextInfo.isDeepWorkDetected ? "Detected" : "Not Detected")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        Form {
            Section("About") {
                HStack {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI DJ for macOS")
                            .font(.headline)
                        Text("Context-aware companion")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Version:")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch controller.connectionStatus {
        case .connected: return .green
        case .disconnected: return .red
        case .syncing: return .orange
        }
    }
}

// MARK: - Previews

#Preview("Popover") {
    let controller = MenuBarController()
    controller.connectionStatus = .connected
    controller.nowPlayingInfo = MenuBarNowPlayingInfo(
        songTitle: "Weightless",
        artistName: "Marconi Union",
        isPlaying: true,
        progress: 0.45,
        duration: 234,
        explanation: nil,
        artworkData: nil
    )
    return PopoverView(controller: controller)
}

#Preview("Settings") {
    MacSettingsView(controller: MenuBarController())
}
