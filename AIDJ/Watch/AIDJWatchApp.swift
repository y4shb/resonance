//
//  AIDJWatchApp.swift
//  AIDJ Watch
//
//  Main entry point for the watchOS app
//

import SwiftUI

@main
struct AIDJWatchApp: App {
    // MARK: - Initialization

    init() {
        logInfo("AI DJ Watch app launching", category: .general)
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

// MARK: - Watch Content View (Placeholder)

struct WatchContentView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.title)
                .foregroundStyle(.blue)

            Text("AI DJ")
                .font(.headline)

            Text("Ready")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    WatchContentView()
}
