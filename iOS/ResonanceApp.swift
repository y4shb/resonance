//
//  ResonanceApp.swift
//  Resonance
//
//  Main entry point for the iOS app
//

import SwiftUI

@main
struct ResonanceApp: App {
    // MARK: - State

    /// Persistence controller for Core Data
    let persistenceController = PersistenceController.shared

    // MARK: - Initialization

    init() {
        // Configure logging
        #if DEBUG
        Logger.shared.setMinimumLevel(.debug)
        #else
        Logger.shared.setMinimumLevel(.info)
        #endif

        logInfo("Resonance iOS app launching", category: .general)

        // Register background tasks
        registerBackgroundTasks()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        // Background task registration will be implemented in Phase 2
        logDebug("Background tasks registration placeholder", category: .background)
    }
}

// MARK: - Content View (Placeholder)

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("AI DJ")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Resonance")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Spacer().frame(height: 40)

                Text("Phase 1 Complete")
                    .font(.headline)

                Text("Project structure initialized.\nReady for Phase 2: Platform Skeleton")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("AI DJ")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
