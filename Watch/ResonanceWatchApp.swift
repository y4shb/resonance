//
//  ResonanceWatchApp.swift
//  Resonance Watch
//
//  Main entry point for the watchOS app
//

import SwiftUI

@main
struct ResonanceWatchApp: App {
    // MARK: - Services

    @StateObject private var connectivityService = PhoneConnectivityService()

    // MARK: - Initialization

    init() {
        logInfo("Resonance Watch app launching", category: .general)
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchNowPlayingView(connectivityService: connectivityService)
                .onAppear {
                    connectivityService.activate()
                    logInfo("PhoneConnectivityService activated", category: .watchConnectivity)
                }
        }
    }
}

// MARK: - Preview

#Preview {
    let service = PhoneConnectivityService()
    WatchNowPlayingView(connectivityService: service)
}
