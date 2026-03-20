//
//  ResonanceScoreHistory.swift
//  Resonance
//
//  Persistent storage for resonance score history using UserDefaults.
//  Stores per-session scores for trend visualization without requiring
//  Core Data schema migration.
//

import Foundation

// MARK: - Resonance Score History Entry

/// A single historical resonance score entry for trend tracking.
struct ResonanceScoreHistoryEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    /// Overall resonance score (0-100)
    let score: Int
    /// Biometric alignment sub-score (0-100)
    let biometricScore: Int
    /// Engagement sub-score (0-100)
    let engagementScore: Int
    /// Number of tracks played in this session
    let tracksPlayed: Int
    /// Total session duration in seconds
    let sessionDuration: TimeInterval
    /// The session's music need (raw string for Codable simplicity)
    let sessionIntent: String
}

// MARK: - Resonance Score Store

/// Persists resonance score history to UserDefaults as a JSON array.
/// Provides simple save/fetch operations without Core Data migration.
final class ResonanceScoreStore {

    // MARK: - Constants

    private let key = "resonance_score_history"
    private let defaults: UserDefaults

    /// Maximum number of entries to retain (rolling window).
    static let maxEntries: Int = 365

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Save

    /// Saves a new score entry, appending to the existing history.
    /// Trims entries beyond `maxEntries` to prevent unbounded growth.
    func save(_ entry: ResonanceScoreHistoryEntry) {
        var entries = fetchAll()
        entries.append(entry)

        // Trim oldest entries if over the limit
        if entries.count > Self.maxEntries {
            entries = Array(entries.suffix(Self.maxEntries))
        }

        persist(entries)
    }

    // MARK: - Fetch

    /// Returns all stored resonance score entries, sorted by date ascending.
    func fetchAll() -> [ResonanceScoreHistoryEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }

        do {
            let entries = try JSONDecoder().decode([ResonanceScoreHistoryEntry].self, from: data)
            return entries.sorted { $0.date < $1.date }
        } catch {
            #if DEBUG
            print("ResonanceScoreStore: failed to decode score history, returning empty: \(error)")
            #endif
            return []
        }
    }

    /// Returns entries from the most recent N days.
    func fetchRecent(days: Int) -> [ResonanceScoreHistoryEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return fetchAll().filter { $0.date >= cutoff }
    }

    // MARK: - Helpers

    private func persist(_ entries: [ResonanceScoreHistoryEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            defaults.set(data, forKey: key)
        } catch {
            #if DEBUG
            print("ResonanceScoreStore: failed to encode score history for persistence: \(error)")
            #endif
        }
    }
}
