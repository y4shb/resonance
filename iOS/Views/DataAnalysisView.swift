//
//  DataAnalysisView.swift
//  Resonance
//
//  Advanced settings for historical analysis, state engine, resonance scores,
//  and data management. Navigated to from SettingsView under "Advanced > Data & Analysis".
//

import SwiftUI

// MARK: - Data & Analysis View

/// Advanced settings for historical analysis, state engine, resonance scores, and data management.
struct DataAnalysisView: View {
    @ObservedObject var historicalEngine: HistoricalEngine
    @ObservedObject var stateEngine: StateEngine
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    @State private var showClearHistoryAlert = false
    @State private var showResetPreferencesAlert = false

    var body: some View {
        List {
            historicalAnalysisSection
            stateEngineSection
            resonanceScoreSection
            dataManagementSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data & Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Historical Analysis Section

    private var historicalAnalysisSection: some View {
        Section {
            switch historicalEngine.progress {
            case .idle:
                HStack {
                    Label("Last Run", systemImage: "clock")
                    Spacer()
                    Text(historicalEngine.lastBackfillDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await historicalEngine.runFullBackfill() }
                } label: {
                    Label("Run Full Backfill", systemImage: "arrow.clockwise")
                }

            case .reconstructingSessions:
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Reconstructing sessions...")
                        .foregroundStyle(.secondary)
                }

            case .calculatingSongImpacts:
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Calculating song impacts...")
                        .foregroundStyle(.secondary)
                }

            case .calculatingPlaylistImpacts:
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Calculating playlist impacts...")
                        .foregroundStyle(.secondary)
                }

            case .completed(let sessions, let events, let playlists):
                Label(
                    "\(sessions) sessions, \(events) events, \(playlists) playlists",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
                .font(.caption)

                HStack {
                    Label("Last Run", systemImage: "clock")
                    Spacer()
                    Text(historicalEngine.lastBackfillDate?.formatted(date: .abbreviated, time: .shortened) ?? "Just now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)

                Button {
                    Task { await historicalEngine.runFullBackfill() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text("Historical Analysis")
        } footer: {
            Text("Analyzes your listening history to learn song effectiveness across different contexts.")
        }
    }

    // MARK: - State Engine Section

    private var stateEngineSection: some View {
        Section {
            HStack {
                Label(stateEngine.currentState.context.displayName, systemImage: "brain.head.profile")
                Spacer()
                Text(stateEngine.currentState.inferredNeed.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if DEBUG
            NavigationLink {
                StateDebugView(stateEngine: stateEngine)
            } label: {
                Label("State Debug", systemImage: "ant")
            }
            #endif
        } header: {
            Text("State Engine")
        } footer: {
            Text("Real-time estimation of your current state for intelligent song selection.")
        }
    }

    // MARK: - Resonance Score Section

    private var resonanceScoreSection: some View {
        Section {
            NavigationLink {
                ResonanceScoreTrendView(scores: ResonanceScoreStore().fetchAll())
            } label: {
                Label("Resonance Score Trends", systemImage: "waveform.path.ecg")
            }
        } header: {
            Text("Resonance Score")
        } footer: {
            Text("View how well your music aligned with your biometric state across sessions.")
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section {
            Button(role: .destructive) {
                showClearHistoryAlert = true
            } label: {
                Label("Clear All Listening History", systemImage: "trash")
            }
            .alert("Clear All Listening History?", isPresented: $showClearHistoryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    try? PersistenceController.shared.deleteAllData()
                }
            } message: {
                Text("This will permanently delete all listening history, session data, and learned song effectiveness scores. This action cannot be undone.")
            }

            Button(role: .destructive) {
                showResetPreferencesAlert = true
            } label: {
                Label("Reset Preferences", systemImage: "arrow.counterclockwise")
            }
            .alert("Reset All Preferences?", isPresented: $showResetPreferencesAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    UserPreferences.reset()
                    preferences = UserPreferences.load()
                }
            } message: {
                Text("This will restore all preferences to their default values.")
            }

            Button {
                Task { await historicalEngine.runFullBackfill() }
            } label: {
                HStack {
                    Label("Re-run Historical Backfill", systemImage: "arrow.clockwise")
                    if case .reconstructingSessions = historicalEngine.progress {
                        Spacer()
                        ProgressView()
                    } else if case .calculatingSongImpacts = historicalEngine.progress {
                        Spacer()
                        ProgressView()
                    } else if case .calculatingPlaylistImpacts = historicalEngine.progress {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled({
                switch historicalEngine.progress {
                case .idle, .completed, .failed: return false
                default: return true
                }
            }())
        } header: {
            Text("Data Management")
        }
    }
}

// MARK: - Preview

#Preview {
    let hkService = HealthKitService()
    let contextCollector = ContextCollector()
    NavigationStack {
        DataAnalysisView(
            historicalEngine: HistoricalEngine(healthKitService: hkService),
            stateEngine: StateEngine(contextCollector: contextCollector, healthKitService: hkService),
            preferences: .constant(UserPreferences.load()),
            onSave: { }
        )
    }
}
