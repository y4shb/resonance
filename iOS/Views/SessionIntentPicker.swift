//
//  SessionIntentPicker.swift
//  Resonance
//
//  Presents a session intent picker when the user starts a listening session.
//  Each intent maps to a biometric target state and BPM arc.
//

import SwiftUI

// MARK: - Session Intent

/// Represents a user's listening session intent.
enum SessionIntent: String, CaseIterable, Identifiable, Codable {
    case deepWork = "Deep Work"
    case workout = "Workout"
    case windDown = "Wind Down"
    case morningRampUp = "Morning Ramp-Up"
    case creativeFlow = "Creative Flow"
    case autoDetect = "Auto-Detect"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .deepWork: return "brain.head.profile"
        case .workout: return "figure.run"
        case .windDown: return "moon.stars.fill"
        case .morningRampUp: return "sunrise.fill"
        case .creativeFlow: return "paintpalette.fill"
        case .autoDetect: return "waveform.badge.magnifyingglass"
        }
    }

    var color: Color {
        switch self {
        case .deepWork: return .purple
        case .workout: return .red
        case .windDown: return .indigo
        case .morningRampUp: return .orange
        case .creativeFlow: return .pink
        case .autoDetect: return ResonanceColors.accent
        }
    }

    var sessionDescription: String {
        switch self {
        case .deepWork: return "Moderate tempo, high instrumentalness, minimal distraction"
        case .workout: return "High energy BPM-locked to your heart rate zone"
        case .windDown: return "Gradually decreasing tempo toward relaxation"
        case .morningRampUp: return "Gentle start building to your peak energy"
        case .creativeFlow: return "Varied, inspiring tracks at moderate energy"
        case .autoDetect: return "Let your biometrics guide the music"
        }
    }

    /// Maps to UserPreferences preset for scoring weights
    var presetWeights: (bpm: Double, energy: Double, familiarity: Double, historical: Double, context: Double) {
        switch self {
        case .deepWork: return (0.10, 0.15, 0.15, 0.25, 0.35)
        case .workout: return (0.30, 0.30, 0.10, 0.15, 0.15)
        case .windDown: return (0.15, 0.25, 0.20, 0.25, 0.15)
        case .morningRampUp: return (0.20, 0.25, 0.15, 0.20, 0.20)
        case .creativeFlow: return (0.10, 0.20, 0.20, 0.25, 0.25)
        case .autoDetect: return (0.15, 0.20, 0.15, 0.25, 0.25)
        }
    }

    /// Maps to MusicNeed for the Mood Forecast engine.
    var musicNeed: MusicNeed {
        switch self {
        case .deepWork:       return .focus
        case .workout:        return .energize
        case .windDown:       return .calm
        case .morningRampUp:  return .transition
        case .creativeFlow:   return .maintain
        case .autoDetect:     return .maintain
        }
    }
}

// MARK: - Session Intent Picker

struct SessionIntentPicker: View {
    @Binding var selectedIntent: SessionIntent?
    @Environment(\.dismiss) private var dismiss

    /// View model for mood forecast generation and display.
    var forecastViewModel: MoodForecastViewModel?

    /// Songs available in the current playlist for forecast-based reordering.
    var availableSongs: [SongFeatures] = []

    /// Callback invoked when the user accepts a forecast with reordered songs.
    var onForecastAccepted: (([SongFeatures]) -> Void)?

    /// Tracks the intent chosen before showing the forecast sheet.
    @State private var pendingIntent: SessionIntent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("What's your session for?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 8)

                    Text("Choose a mode and Resonance will adapt the music to match.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 12) {
                        ForEach(SessionIntent.allCases) { intent in
                            SessionIntentCard(
                                intent: intent,
                                isSelected: selectedIntent == intent
                            ) {
                                handleIntentSelection(intent)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Session Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        selectedIntent = .autoDetect
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { forecastViewModel?.isShowingForecast ?? false },
                set: { newValue in
                    if !newValue { forecastViewModel?.dismiss() }
                }
            )) {
                if let vm = forecastViewModel, let forecast = vm.forecast {
                    MoodForecastView(
                        forecast: forecast,
                        onAccept: { acceptedForecast in
                            vm.applyUserModification(acceptedForecast, songs: availableSongs)
                            onForecastAccepted?(vm.reorderedSongs)
                            selectedIntent = pendingIntent
                            dismiss()
                        },
                        onDismiss: {
                            vm.dismiss()
                            // Still apply the selected intent without forecast
                            selectedIntent = pendingIntent
                            dismiss()
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    /// Handles intent selection: generates a forecast if possible, otherwise applies directly.
    private func handleIntentSelection(_ intent: SessionIntent) {
        pendingIntent = intent

        if let vm = forecastViewModel, !availableSongs.isEmpty {
            let currentHour = Calendar.current.component(.hour, from: Date())
            let timeSlot = TimeSlot(hour: currentHour)

            vm.generateForecast(
                intent: intent.musicNeed,
                timeSlot: timeSlot,
                currentHRV: nil,
                playlistSongs: availableSongs
            )
        } else {
            // No forecast capability -- apply intent directly
            selectedIntent = intent
            dismiss()
        }
    }
}

// MARK: - Session Intent Card

struct SessionIntentCard: View {
    let intent: SessionIntent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: intent.icon)
                    .font(.title)
                    .foregroundStyle(intent.color)
                    .frame(height: 36)

                Text(intent.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(intent.sessionDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? intent.color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? intent.color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(intent.rawValue) session mode")
        .accessibilityHint(intent.sessionDescription)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
