//
//  NowPlayingCloudKitSync.swift
//  Resonance
//
//  Publishes now playing state to CloudKit so the macOS menu bar companion
//  can display the current song. Uses a single well-known record ID to
//  upsert (create-or-replace) instead of appending new records each time.
//

#if os(iOS)

import Foundation
import CloudKit

/// Syncs now playing state from iPhone to CloudKit for macOS companion consumption.
final class NowPlayingCloudKitSync {

    // MARK: - Singleton

    static let shared = NowPlayingCloudKitSync()

    // MARK: - Constants

    private let recordType = "iPhoneNowPlaying"

    /// Fixed record name so every save is an upsert, not an append.
    private let fixedRecordName = "currentNowPlaying"

    // MARK: - State

    /// Debounce guard: skip saves that arrive faster than this interval (seconds).
    private let minimumSaveInterval: TimeInterval = 5
    private var lastSaveDate: Date?

    /// Tracks in-flight save to avoid overlapping writes.
    private var isSaving = false

    // MARK: - CloudKit

    private lazy var container: CKContainer? = {
        let id = AppConstants.cloudKitContainerIdentifier
        guard !id.isEmpty else { return nil }
        return CKContainer(identifier: id)
    }()

    private init() {}

    // MARK: - Public API

    /// Saves the given now playing packet to CloudKit.
    /// Safe to call frequently -- calls within `minimumSaveInterval` are debounced.
    func syncNowPlaying(_ packet: NowPlayingPacket) {
        guard let container = container else {
            logDebug("NowPlayingCloudKitSync: CloudKit container not available", category: .network)
            return
        }

        // Debounce rapid-fire calls (e.g. progress updates)
        if let lastSave = lastSaveDate,
           Date().timeIntervalSince(lastSave) < minimumSaveInterval {
            return
        }

        guard !isSaving else { return }
        isSaving = true

        let recordID = CKRecord.ID(recordName: fixedRecordName)
        let database = container.privateCloudDatabase

        // Fetch existing record to update, or create a new one
        database.fetch(withRecordID: recordID) { [weak self] existingRecord, fetchError in
            guard let self = self else { return }

            let record: CKRecord
            if let existing = existingRecord {
                record = existing
            } else {
                record = CKRecord(recordType: self.recordType, recordID: recordID)
            }

            record["songTitle"] = packet.songTitle as NSString
            record["artistName"] = packet.artistName as NSString
            record["isPlaying"] = (packet.isPlaying ? 1 : 0) as NSNumber
            record["progress"] = packet.progress as NSNumber
            record["duration"] = packet.duration as NSNumber
            // Sanitize explanation before CloudKit upload: strip any raw biometric
            // values (HR in BPM, HRV in ms) to comply with Guideline 5.1.3(ii)
            // which prohibits health data in iCloud. Keep the qualitative description
            // ("stress elevated", "energy rising") but remove numeric readings.
            record["explanation"] = Self.sanitizeExplanation(packet.explanation) as NSString?
            record["timestamp"] = Date() as NSDate

            // Artwork: save as CKAsset if available (skip to avoid large writes
            // on every call -- only include when song changes).
            if let artworkData = packet.artworkData {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("nowplaying_artwork.jpg")
                do {
                    try artworkData.write(to: tempURL)
                    record["artwork"] = CKAsset(fileURL: tempURL)
                } catch {
                    logDebug("NowPlayingCloudKitSync: artwork write failed: \(error.localizedDescription)", category: .network)
                }
            }

            database.save(record) { [weak self] _, saveError in
                DispatchQueue.main.async {
                    self?.isSaving = false
                    self?.lastSaveDate = Date()

                    if let saveError = saveError {
                        logDebug(
                            "NowPlayingCloudKitSync: save failed: \(saveError.localizedDescription)",
                            category: .network
                        )
                    } else {
                        logDebug("NowPlayingCloudKitSync: synced now playing to CloudKit", category: .network)
                    }
                }
            }
        }
    }

    /// Clears the now playing record in CloudKit (call when playback stops).
    func clearNowPlaying() {
        guard let container = container else { return }

        let recordID = CKRecord.ID(recordName: fixedRecordName)
        container.privateCloudDatabase.delete(withRecordID: recordID) { _, error in
            if let error = error {
                logDebug(
                    "NowPlayingCloudKitSync: clear failed: \(error.localizedDescription)",
                    category: .network
                )
            }
        }
    }

    // MARK: - Explanation Sanitization (Guideline 5.1.3(ii))

    /// Strips raw biometric values from explanation text before CloudKit upload.
    /// Removes patterns like "58 bpm", "22ms HRV", "heart rate 72", etc.
    /// Keeps qualitative descriptions ("stress elevated", "energy rising").
    private static func sanitizeExplanation(_ text: String?) -> String? {
        guard let text = text else { return nil }

        var sanitized = text

        // Remove "XX bpm" / "XX BPM" patterns
        sanitized = sanitized.replacingOccurrences(
            of: "\\b\\d+\\.?\\d*\\s*(?:bpm|BPM)\\b",
            with: "",
            options: .regularExpression
        )

        // Remove "XX ms" / "XXms HRV" patterns
        sanitized = sanitized.replacingOccurrences(
            of: "\\b\\d+\\.?\\d*\\s*(?:ms|MS)(?:\\s+HRV)?\\b",
            with: "",
            options: .regularExpression
        )

        // Remove "heart rate XX" / "HR XX" patterns
        sanitized = sanitized.replacingOccurrences(
            of: "(?:heart rate|HR|resting HR)\\s+\\d+\\.?\\d*",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove "HRV XX" / "VO2 XX" patterns
        sanitized = sanitized.replacingOccurrences(
            of: "(?:HRV|VO2|VO2Max)\\s+\\d+\\.?\\d*",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Clean up double spaces left by removals
        sanitized = sanitized.replacingOccurrences(
            of: "\\s{2,}",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)

        return sanitized.isEmpty ? nil : sanitized
    }
}

#endif
