//
//  AIDJMacApp.swift
//  AIDJ Mac
//
//  Main entry point for the macOS menu bar app
//

import SwiftUI
import AppKit

@main
struct AIDJMacApp: App {
    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Initialization

    init() {
        logInfo("AI DJ Mac app launching", category: .general)
    }

    // MARK: - Body

    var body: some Scene {
        // Menu bar apps don't have a main window
        // The MenuBarExtra is the primary UI
        MenuBarExtra("AI DJ", systemImage: "music.note") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)

        // Settings window (accessible via menu bar)
        Settings {
            MacSettingsView()
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

// MARK: - Menu Bar Content View

struct MenuBarContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "music.note")
                    .foregroundStyle(.blue)
                Text("AI DJ")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Status
            VStack(alignment: .leading, spacing: 4) {
                Text("Status: Ready")
                    .font(.subheadline)
                Text("iPhone: Not Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Context Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Context Sending:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Focus Mode: Off")
                        .font(.caption)
                }
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Active App: Monitoring")
                        .font(.caption)
                }
            }

            Divider()

            // Actions
            Button("Open Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Button("Quit AI DJ") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 250)
    }
}

// MARK: - Settings View

struct MacSettingsView: View {
    var body: some View {
        Form {
            Section("Connection") {
                Text("iPhone connection settings will appear here.")
                    .foregroundStyle(.secondary)
            }

            Section("Context Providers") {
                Toggle("Send Focus Mode", isOn: .constant(true))
                Toggle("Send Active App", isOn: .constant(true))
                Toggle("Send Calendar Events", isOn: .constant(true))
            }

            Section("About") {
                Text("AI DJ for macOS")
                Text("Version 1.0")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}

// MARK: - Previews

#Preview("Menu Bar") {
    MenuBarContentView()
}

#Preview("Settings") {
    MacSettingsView()
}
