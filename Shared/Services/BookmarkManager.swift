//
//  BookmarkManager.swift
//  Resonance
//
//  Core service for Sonic Bookmark feature. Captures and persists
//  bookmarked moments during a listening session with biometric state,
//  track info, and playback position.
//

import Foundation

// BookmarkTriggerSource is defined in WatchMessages.swift (shared across all targets)

// MARK: - Sonic Bookmark Data

struct SonicBookmarkData: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let triggerSource: BookmarkTriggerSource
    let songTitle: String
    let artistName: String
    let songAppleMusicId: String
    let playbackPosition: TimeInterval
    let songDuration: TimeInterval
    let heartRate: Double?
    let hrv: Double?
    let arousal: Double
    let energy: Double
    let stress: Double
    let valence: Double
    let activityContext: String
    let inferredNeed: String
}

// MARK: - Bookmark Manager

/// Manages creation, persistence, and retrieval of Sonic Bookmarks.
/// Uses UserDefaults with JSON encoding for simplicity (no Core Data migration needed).
@MainActor
final class BookmarkManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var sessionBookmarks: [SonicBookmarkData] = []

    // MARK: - Private Properties

    private let storageKey = "sonic_bookmarks_v1"
    private let sessionStorageKey = "sonic_bookmarks_sessions_v1"
    private var lastBookmarkTime: Date?

    // MARK: - Initialization

    init() {
        loadCurrentSession()
        logInfo("BookmarkManager initialized with \(sessionBookmarks.count) session bookmarks", category: .general)
    }

    // MARK: - Bookmark Creation

    /// Creates a new bookmark with debounce protection.
    /// Returns the created bookmark, or nil if debounced.
    @discardableResult
    func createBookmark(
        triggerSource: BookmarkTriggerSource,
        songTitle: String,
        artistName: String,
        songAppleMusicId: String,
        playbackPosition: TimeInterval,
        songDuration: TimeInterval,
        heartRate: Double?,
        hrv: Double?,
        arousal: Double,
        energy: Double,
        stress: Double,
        valence: Double,
        activityContext: String,
        inferredNeed: String
    ) -> SonicBookmarkData? {
        // Debounce check
        if let last = lastBookmarkTime,
           Date().timeIntervalSince(last) < BookmarkConstants.debounceInterval {
            logDebug("Bookmark debounced (too soon after last bookmark)", category: .general)
            return nil
        }

        // Max per session check
        if sessionBookmarks.count >= BookmarkConstants.maxPerSession {
            logWarning("Bookmark limit reached (\(BookmarkConstants.maxPerSession) per session)", category: .general)
            return nil
        }

        lastBookmarkTime = Date()

        let bookmark = SonicBookmarkData(
            id: UUID(),
            timestamp: Date(),
            triggerSource: triggerSource,
            songTitle: songTitle,
            artistName: artistName,
            songAppleMusicId: songAppleMusicId,
            playbackPosition: playbackPosition,
            songDuration: songDuration,
            heartRate: heartRate,
            hrv: hrv,
            arousal: arousal,
            energy: energy,
            stress: stress,
            valence: valence,
            activityContext: activityContext,
            inferredNeed: inferredNeed
        )

        sessionBookmarks.append(bookmark)
        persistCurrentSession()

        logInfo(
            "Bookmark created: \(songTitle) at \(String(format: "%.1f", playbackPosition))s "
            + "via \(triggerSource.rawValue)",
            category: .general
        )

        return bookmark
    }

    // MARK: - Session Management

    /// Clears the current session's bookmarks.
    func clearSession() {
        sessionBookmarks.removeAll()
        lastBookmarkTime = nil
        persistCurrentSession()
        logInfo("Bookmark session cleared", category: .general)
    }

    /// Archives the current session's bookmarks and starts a fresh session.
    func archiveSession() {
        guard !sessionBookmarks.isEmpty else { return }

        var allSessions = fetchAllSessions()
        allSessions.append(sessionBookmarks)
        persistAllSessions(allSessions)
        sessionBookmarks.removeAll()
        lastBookmarkTime = nil
        persistCurrentSession()

        logInfo("Bookmark session archived (\(allSessions.count) total sessions)", category: .general)
    }

    /// Returns all archived bookmark sessions (most recent first).
    func fetchAllSessions() -> [[SonicBookmarkData]] {
        guard let data = UserDefaults.standard.data(forKey: sessionStorageKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([[SonicBookmarkData]].self, from: data)
        } catch {
            logError("Failed to decode bookmark sessions", error: error, category: .general)
            return []
        }
    }

    /// Returns all bookmarks across all sessions (flat list, most recent first).
    func fetchAllBookmarks() -> [SonicBookmarkData] {
        let sessions = fetchAllSessions()
        return sessions.flatMap { $0 }.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Persistence

    private func persistCurrentSession() {
        do {
            let data = try JSONEncoder().encode(sessionBookmarks)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            logError("Failed to persist session bookmarks", error: error, category: .general)
        }
    }

    private func loadCurrentSession() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            sessionBookmarks = try JSONDecoder().decode([SonicBookmarkData].self, from: data)
        } catch {
            logError("Failed to load session bookmarks", error: error, category: .general)
            sessionBookmarks = []
        }
    }

    private func persistAllSessions(_ sessions: [[SonicBookmarkData]]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: sessionStorageKey)
        } catch {
            logError("Failed to persist bookmark sessions", error: error, category: .general)
        }
    }
}
