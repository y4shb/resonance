//
//  WatchMessagesTests.swift
//  ResonanceTests
//
//  Unit tests for WatchMessage encoding/decoding round-trips and error handling.
//

import XCTest
@testable import Resonance

final class WatchMessagesTests: XCTestCase {

    // MARK: - BiometricPacket Round-Trip

    func test_biometricUpdate_roundTrip() throws {
        let packet = BiometricPacket(
            heartRate: 72.0,
            hrv: 45.0,
            isStationary: true,
            isInWorkout: false,
            workoutType: nil,
            timestamp: Date()
        )
        let message = WatchMessage.biometricUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .biometricUpdate(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.heartRate, 72.0)
            XCTAssertEqual(decodedPacket.hrv, 45.0)
            XCTAssertTrue(decodedPacket.isStationary)
            XCTAssertFalse(decodedPacket.isInWorkout)
            XCTAssertNil(decodedPacket.workoutType)
        } else {
            XCTFail("Expected biometricUpdate case")
        }
    }

    // MARK: - MoodPacket Round-Trip

    func test_moodInput_roundTrip() throws {
        let packet = MoodPacket(
            moodLevel: 4,
            energyLevel: 3,
            timestamp: Date()
        )
        let message = WatchMessage.moodInput(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .moodInput(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.moodLevel, 4)
            XCTAssertEqual(decodedPacket.energyLevel, 3)
        } else {
            XCTFail("Expected moodInput case")
        }
    }

    // MARK: - PlaybackCommand Round-Trip

    func test_playbackCommand_roundTrip() throws {
        let command = PlaybackCommand(command: .skip)
        let message = WatchMessage.playbackCommand(command)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .playbackCommand(let decodedCmd) = decoded {
            XCTAssertEqual(decodedCmd.command, .skip)
        } else {
            XCTFail("Expected playbackCommand case")
        }
    }

    func test_playbackCommand_allCommands() throws {
        let commands: [PlaybackCommand.Command] = [.play, .pause, .skip, .previous]

        for cmd in commands {
            let message = WatchMessage.playbackCommand(PlaybackCommand(command: cmd))
            let dict = try message.toDictionary()
            let decoded = try WatchMessage.fromDictionary(dict)

            if case .playbackCommand(let decodedCmd) = decoded {
                XCTAssertEqual(decodedCmd.command, cmd, "Command \(cmd) should round-trip")
            } else {
                XCTFail("Expected playbackCommand case for \(cmd)")
            }
        }
    }

    // MARK: - CrownAdjustment Round-Trip

    func test_crownAdjustment_roundTrip() throws {
        let adjustment = CrownAdjustment(delta: 0.35, adjustmentType: "energy")
        let message = WatchMessage.crownAdjustment(adjustment)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .crownAdjustment(let decodedAdj) = decoded {
            XCTAssertEqual(decodedAdj.delta, 0.35, accuracy: 0.001)
            XCTAssertEqual(decodedAdj.adjustmentType, "energy")
        } else {
            XCTFail("Expected crownAdjustment case")
        }
    }

    // MARK: - NowPlayingPacket Round-Trip

    func test_nowPlayingUpdate_roundTrip() throws {
        let packet = NowPlayingPacket(
            songTitle: "Test Song",
            artistName: "Test Artist",
            artworkData: nil,
            isPlaying: true,
            progress: 0.45,
            duration: 240,
            explanation: "Great tempo match"
        )
        let message = WatchMessage.nowPlayingUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .nowPlayingUpdate(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.songTitle, "Test Song")
            XCTAssertEqual(decodedPacket.artistName, "Test Artist")
            XCTAssertNil(decodedPacket.artworkData)
            XCTAssertTrue(decodedPacket.isPlaying)
            XCTAssertEqual(decodedPacket.progress, 0.45, accuracy: 0.001)
            XCTAssertEqual(decodedPacket.duration, 240, accuracy: 0.1)
            XCTAssertEqual(decodedPacket.explanation, "Great tempo match")
        } else {
            XCTFail("Expected nowPlayingUpdate case")
        }
    }

    // MARK: - StatePacket Round-Trip

    func test_stateUpdate_roundTrip() throws {
        let packet = StatePacket(
            energyLevel: 0.7,
            calmLevel: 0.3,
            focusLevel: 0.8,
            heartRate: 68,
            currentContext: "focus",
            timestamp: Date()
        )
        let message = WatchMessage.stateUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .stateUpdate(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.energyLevel, 0.7, accuracy: 0.001)
            XCTAssertEqual(decodedPacket.calmLevel, 0.3, accuracy: 0.001)
            XCTAssertEqual(decodedPacket.focusLevel, 0.8, accuracy: 0.001)
            XCTAssertEqual(decodedPacket.heartRate, 68)
            XCTAssertEqual(decodedPacket.currentContext, "focus")
        } else {
            XCTFail("Expected stateUpdate case")
        }
    }

    // MARK: - ComplicationData Round-Trip

    func test_complicationUpdate_roundTrip() throws {
        let data = ComplicationData(
            songTitle: "Chill Track",
            artistName: "Ambient DJ",
            stateEmoji: "\u{1F3B5}",
            heartRate: 65,
            isPlaying: true,
            timestamp: Date()
        )
        let message = WatchMessage.complicationUpdate(data)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .complicationUpdate(let decodedData) = decoded {
            XCTAssertEqual(decodedData.songTitle, "Chill Track")
            XCTAssertEqual(decodedData.artistName, "Ambient DJ")
            XCTAssertEqual(decodedData.stateEmoji, "\u{1F3B5}")
            XCTAssertEqual(decodedData.heartRate, 65)
            XCTAssertTrue(decodedData.isPlaying)
        } else {
            XCTFail("Expected complicationUpdate case")
        }
    }

    // MARK: - Error Handling

    func test_fromDictionary_invalidData_throwsDecodingFailed() {
        let invalidDict: [String: Any] = ["wrong_key": "not data"]

        XCTAssertThrowsError(try WatchMessage.fromDictionary(invalidDict)) { error in
            XCTAssertTrue(error is WatchMessageError)
            if let watchError = error as? WatchMessageError {
                XCTAssertEqual(watchError, .decodingFailed)
            }
        }
    }

    func test_fromDictionary_corruptData_throws() {
        let corruptDict: [String: Any] = ["watchMessage": Data([0xFF, 0xFE, 0x00])]

        XCTAssertThrowsError(try WatchMessage.fromDictionary(corruptDict))
    }

    // MARK: - WatchMessageError

    func test_watchMessageError_hasErrorDescription() {
        XCTAssertNotNil(WatchMessageError.encodingFailed.errorDescription)
        XCTAssertNotNil(WatchMessageError.decodingFailed.errorDescription)
        XCTAssertNotNil(WatchMessageError.unknownMessageType.errorDescription)
    }

    // MARK: - BiometricPacket Edge Cases

    func test_biometricUpdate_workoutActive_roundTrip() throws {
        let packet = BiometricPacket(
            heartRate: 145.0,
            hrv: 28.0,
            isStationary: false,
            isInWorkout: true,
            workoutType: "running",
            timestamp: Date()
        )
        let message = WatchMessage.biometricUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .biometricUpdate(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.heartRate, 145.0)
            XCTAssertEqual(decodedPacket.hrv, 28.0)
            XCTAssertFalse(decodedPacket.isStationary)
            XCTAssertTrue(decodedPacket.isInWorkout)
            XCTAssertEqual(decodedPacket.workoutType, "running")
        } else {
            XCTFail("Expected biometricUpdate case")
        }
    }

    func test_biometricUpdate_nilHeartRateAndHrv_roundTrip() throws {
        let packet = BiometricPacket(
            heartRate: nil,
            hrv: nil,
            isStationary: true,
            isInWorkout: false,
            workoutType: nil,
            timestamp: Date()
        )
        let message = WatchMessage.biometricUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .biometricUpdate(let decodedPacket) = decoded {
            XCTAssertNil(decodedPacket.heartRate)
            XCTAssertNil(decodedPacket.hrv)
            XCTAssertTrue(decodedPacket.isStationary)
            XCTAssertFalse(decodedPacket.isInWorkout)
            XCTAssertNil(decodedPacket.workoutType)
        } else {
            XCTFail("Expected biometricUpdate case")
        }
    }

    // MARK: - NowPlayingPacket Edge Cases

    func test_nowPlayingUpdate_withArtworkData_roundTrip() throws {
        let artwork = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let packet = NowPlayingPacket(
            songTitle: "Song With Art",
            artistName: "Artist",
            artworkData: artwork,
            isPlaying: true,
            progress: 0.5,
            duration: 180,
            explanation: "Matching tempo"
        )
        let message = WatchMessage.nowPlayingUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .nowPlayingUpdate(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.songTitle, "Song With Art")
            XCTAssertEqual(decodedPacket.artistName, "Artist")
            XCTAssertNotNil(decodedPacket.artworkData)
            XCTAssertEqual(decodedPacket.artworkData, artwork)
            XCTAssertTrue(decodedPacket.isPlaying)
            XCTAssertEqual(decodedPacket.progress, 0.5, accuracy: 0.001)
            XCTAssertEqual(decodedPacket.duration, 180, accuracy: 0.1)
            XCTAssertEqual(decodedPacket.explanation, "Matching tempo")
        } else {
            XCTFail("Expected nowPlayingUpdate case")
        }
    }

    func test_nowPlayingUpdate_nilExplanation_roundTrip() throws {
        let packet = NowPlayingPacket(
            songTitle: "No Explanation Song",
            artistName: "Unknown Artist",
            artworkData: nil,
            isPlaying: false,
            progress: 0.0,
            duration: 300,
            explanation: nil
        )
        let message = WatchMessage.nowPlayingUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .nowPlayingUpdate(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.songTitle, "No Explanation Song")
            XCTAssertEqual(decodedPacket.artistName, "Unknown Artist")
            XCTAssertNil(decodedPacket.artworkData)
            XCTAssertFalse(decodedPacket.isPlaying)
            XCTAssertEqual(decodedPacket.progress, 0.0, accuracy: 0.001)
            XCTAssertEqual(decodedPacket.duration, 300, accuracy: 0.1)
            XCTAssertNil(decodedPacket.explanation)
        } else {
            XCTFail("Expected nowPlayingUpdate case")
        }
    }

    func test_nowPlayingUpdate_emptyStrings_roundTrip() throws {
        let packet = NowPlayingPacket(
            songTitle: "",
            artistName: "",
            artworkData: nil,
            isPlaying: false,
            progress: 0.0,
            duration: 0,
            explanation: ""
        )
        let message = WatchMessage.nowPlayingUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .nowPlayingUpdate(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.songTitle, "")
            XCTAssertEqual(decodedPacket.artistName, "")
            XCTAssertNil(decodedPacket.artworkData)
            XCTAssertFalse(decodedPacket.isPlaying)
            XCTAssertEqual(decodedPacket.progress, 0.0, accuracy: 0.001)
            XCTAssertEqual(decodedPacket.duration, 0, accuracy: 0.1)
            XCTAssertEqual(decodedPacket.explanation, "")
        } else {
            XCTFail("Expected nowPlayingUpdate case")
        }
    }

    // MARK: - MoodPacket Boundary Values

    func test_moodInput_boundaryLow_roundTrip() throws {
        let packet = MoodPacket(
            moodLevel: 1,
            energyLevel: 1,
            timestamp: Date()
        )
        let message = WatchMessage.moodInput(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .moodInput(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.moodLevel, 1)
            XCTAssertEqual(decodedPacket.energyLevel, 1)
        } else {
            XCTFail("Expected moodInput case")
        }
    }

    func test_moodInput_boundaryHigh_roundTrip() throws {
        let packet = MoodPacket(
            moodLevel: 5,
            energyLevel: 5,
            timestamp: Date()
        )
        let message = WatchMessage.moodInput(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .moodInput(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.moodLevel, 5)
            XCTAssertEqual(decodedPacket.energyLevel, 5)
        } else {
            XCTFail("Expected moodInput case")
        }
    }

    // MARK: - CrownAdjustment Edge Cases

    func test_crownAdjustment_negativeDelta_roundTrip() throws {
        let adjustment = CrownAdjustment(delta: -0.75, adjustmentType: "intensity")
        let message = WatchMessage.crownAdjustment(adjustment)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .crownAdjustment(let decodedAdj) = decoded {
            XCTAssertEqual(decodedAdj.delta, -0.75, accuracy: 0.001)
            XCTAssertEqual(decodedAdj.adjustmentType, "intensity")
        } else {
            XCTFail("Expected crownAdjustment case")
        }
    }

    func test_crownAdjustment_zeroDelta_roundTrip() throws {
        let adjustment = CrownAdjustment(delta: 0.0, adjustmentType: "energy")
        let message = WatchMessage.crownAdjustment(adjustment)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .crownAdjustment(let decodedAdj) = decoded {
            XCTAssertEqual(decodedAdj.delta, 0.0, accuracy: 0.001)
            XCTAssertEqual(decodedAdj.adjustmentType, "energy")
        } else {
            XCTFail("Expected crownAdjustment case")
        }
    }

    // MARK: - StatePacket Edge Cases

    func test_stateUpdate_nilHeartRateAndContext_roundTrip() throws {
        let packet = StatePacket(
            energyLevel: 0.5,
            calmLevel: 0.5,
            focusLevel: 0.5,
            heartRate: nil,
            currentContext: nil,
            timestamp: Date()
        )
        let message = WatchMessage.stateUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .stateUpdate(let decodedPacket) = decoded {
            XCTAssertEqual(decodedPacket.energyLevel, 0.5, accuracy: 0.001)
            XCTAssertEqual(decodedPacket.calmLevel, 0.5, accuracy: 0.001)
            XCTAssertEqual(decodedPacket.focusLevel, 0.5, accuracy: 0.001)
            XCTAssertNil(decodedPacket.heartRate)
            XCTAssertNil(decodedPacket.currentContext)
        } else {
            XCTFail("Expected stateUpdate case")
        }
    }

    // MARK: - ComplicationData Edge Cases

    func test_complicationUpdate_nilAndEmptyFields_roundTrip() throws {
        let data = ComplicationData(
            songTitle: nil,
            artistName: nil,
            stateEmoji: "",
            heartRate: nil,
            isPlaying: false,
            timestamp: Date()
        )
        let message = WatchMessage.complicationUpdate(data)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .complicationUpdate(let decodedData) = decoded {
            XCTAssertNil(decodedData.songTitle)
            XCTAssertNil(decodedData.artistName)
            XCTAssertEqual(decodedData.stateEmoji, "")
            XCTAssertNil(decodedData.heartRate)
            XCTAssertFalse(decodedData.isPlaying)
        } else {
            XCTFail("Expected complicationUpdate case")
        }
    }

    // MARK: - Timestamp Preservation

    func test_biometricUpdate_timestampPreservation() throws {
        let now = Date()
        let packet = BiometricPacket(
            heartRate: 80.0,
            hrv: 50.0,
            isStationary: false,
            isInWorkout: false,
            workoutType: nil,
            timestamp: now
        )
        let message = WatchMessage.biometricUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .biometricUpdate(let decodedPacket) = decoded {
            let timeDifference = abs(decodedPacket.timestamp.timeIntervalSince(now))
            XCTAssertLessThan(timeDifference, 1.0, "Decoded timestamp should be within 1 second of the original")
        } else {
            XCTFail("Expected biometricUpdate case")
        }
    }

    func test_stateUpdate_timestampPreservation() throws {
        let now = Date()
        let packet = StatePacket(
            energyLevel: 0.6,
            calmLevel: 0.4,
            focusLevel: 0.9,
            heartRate: 72,
            currentContext: "workout",
            timestamp: now
        )
        let message = WatchMessage.stateUpdate(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .stateUpdate(let decodedPacket) = decoded {
            let timeDifference = abs(decodedPacket.timestamp.timeIntervalSince(now))
            XCTAssertLessThan(timeDifference, 1.0, "Decoded timestamp should be within 1 second of the original")
        } else {
            XCTFail("Expected stateUpdate case")
        }
    }

    func test_moodInput_timestampPreservation() throws {
        let now = Date()
        let packet = MoodPacket(
            moodLevel: 3,
            energyLevel: 2,
            timestamp: now
        )
        let message = WatchMessage.moodInput(packet)

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .moodInput(let decodedPacket) = decoded {
            let timeDifference = abs(decodedPacket.timestamp.timeIntervalSince(now))
            XCTAssertLessThan(timeDifference, 1.0, "Decoded timestamp should be within 1 second of the original")
        } else {
            XCTFail("Expected moodInput case")
        }
    }

    // MARK: - Multiple Consecutive Encode/Decode Cycles

    func test_biometricUpdate_multipleEncodeDecode_maintainsIntegrity() throws {
        let original = BiometricPacket(
            heartRate: 95.0,
            hrv: 38.5,
            isStationary: false,
            isInWorkout: true,
            workoutType: "cycling",
            timestamp: Date()
        )
        var message = WatchMessage.biometricUpdate(original)

        // Perform 3 consecutive encode/decode cycles
        for _ in 0..<3 {
            let dict = try message.toDictionary()
            message = try WatchMessage.fromDictionary(dict)
        }

        if case .biometricUpdate(let finalPacket) = message {
            XCTAssertEqual(finalPacket.heartRate, 95.0)
            XCTAssertEqual(finalPacket.hrv, 38.5)
            XCTAssertFalse(finalPacket.isStationary)
            XCTAssertTrue(finalPacket.isInWorkout)
            XCTAssertEqual(finalPacket.workoutType, "cycling")
        } else {
            XCTFail("Expected biometricUpdate case after multiple cycles")
        }
    }

    func test_nowPlayingUpdate_multipleEncodeDecode_maintainsIntegrity() throws {
        let artwork = Data([0xAA, 0xBB, 0xCC, 0xDD])
        var message: WatchMessage = .nowPlayingUpdate(NowPlayingPacket(
            songTitle: "Cycle Test",
            artistName: "Encode Artist",
            artworkData: artwork,
            isPlaying: true,
            progress: 0.33,
            duration: 210,
            explanation: "Multi-cycle test"
        ))

        for _ in 0..<3 {
            let dict = try message.toDictionary()
            message = try WatchMessage.fromDictionary(dict)
        }

        if case .nowPlayingUpdate(let finalPacket) = message {
            XCTAssertEqual(finalPacket.songTitle, "Cycle Test")
            XCTAssertEqual(finalPacket.artistName, "Encode Artist")
            XCTAssertEqual(finalPacket.artworkData, artwork)
            XCTAssertTrue(finalPacket.isPlaying)
            XCTAssertEqual(finalPacket.progress, 0.33, accuracy: 0.001)
            XCTAssertEqual(finalPacket.duration, 210, accuracy: 0.1)
            XCTAssertEqual(finalPacket.explanation, "Multi-cycle test")
        } else {
            XCTFail("Expected nowPlayingUpdate case after multiple cycles")
        }
    }

    // MARK: - toDictionary Structure

    func test_toDictionary_producesNonEmptyDictWithCorrectKey() throws {
        let message = WatchMessage.requestNowPlaying

        let dict = try message.toDictionary()

        XCTAssertFalse(dict.isEmpty, "toDictionary should produce a non-empty dictionary")
        XCTAssertNotNil(dict["watchMessage"], "Dictionary should contain the 'watchMessage' key")
        XCTAssertTrue(dict["watchMessage"] is Data, "The 'watchMessage' value should be Data")
    }

    func test_toDictionary_biometricUpdate_containsWatchMessageKey() throws {
        let packet = BiometricPacket(
            heartRate: 60.0,
            hrv: 40.0,
            isStationary: true,
            isInWorkout: false,
            workoutType: nil,
            timestamp: Date()
        )
        let message = WatchMessage.biometricUpdate(packet)

        let dict = try message.toDictionary()

        XCTAssertFalse(dict.isEmpty)
        XCTAssertNotNil(dict["watchMessage"])
        XCTAssertTrue(dict["watchMessage"] is Data)
        XCTAssertEqual(dict.count, 1, "Dictionary should contain exactly one key")
    }

    // MARK: - requestNowPlaying Round-Trip

    func test_requestNowPlaying_roundTrip() throws {
        let message = WatchMessage.requestNowPlaying

        let dict = try message.toDictionary()
        let decoded = try WatchMessage.fromDictionary(dict)

        if case .requestNowPlaying = decoded {
            // success
        } else {
            XCTFail("Expected requestNowPlaying case")
        }
    }

    // MARK: - Application Context Keys

    func test_applicationContextKey_nowPlaying() {
        let message = WatchMessage.nowPlayingUpdate(NowPlayingPacket(
            songTitle: "T", artistName: "A", artworkData: nil,
            isPlaying: true, progress: 0, duration: 0, explanation: nil))
        XCTAssertEqual(message.applicationContextKey, "wm_nowPlaying")
    }

    func test_applicationContextKey_stateUpdate() {
        let message = WatchMessage.stateUpdate(StatePacket(
            energyLevel: 0.5, calmLevel: 0.5, focusLevel: 0.5,
            heartRate: nil, currentContext: nil, timestamp: Date()))
        XCTAssertEqual(message.applicationContextKey, "wm_state")
    }

    func test_applicationContextKey_complicationUpdate() {
        let message = WatchMessage.complicationUpdate(ComplicationData(
            songTitle: nil, artistName: nil, stateEmoji: "",
            heartRate: nil, isPlaying: false, timestamp: Date()))
        XCTAssertEqual(message.applicationContextKey, "wm_complication")
    }

    func test_applicationContextKey_watchToPhoneMessages_nil() {
        XCTAssertNil(WatchMessage.requestNowPlaying.applicationContextKey)
        let bio = WatchMessage.biometricUpdate(BiometricPacket(
            heartRate: 70, hrv: 40, isStationary: true, isInWorkout: false,
            workoutType: nil, timestamp: Date()))
        XCTAssertNil(bio.applicationContextKey)
    }

    // MARK: - toContextDictionary

    func test_toContextDictionary_usesTypeSpecificKey() throws {
        let packet = NowPlayingPacket(
            songTitle: "Song", artistName: "Artist", artworkData: nil,
            isPlaying: true, progress: 0.5, duration: 200, explanation: nil)
        let message = WatchMessage.nowPlayingUpdate(packet)

        let dict = try message.toContextDictionary()
        XCTAssertNotNil(dict["wm_nowPlaying"])
        XCTAssertNil(dict["watchMessage"], "Context dict should not use the realtime key")
    }

    func test_toContextDictionary_stateUsesStateKey() throws {
        let packet = StatePacket(
            energyLevel: 0.7, calmLevel: 0.3, focusLevel: 0.8,
            heartRate: 68, currentContext: "focus", timestamp: Date())
        let message = WatchMessage.stateUpdate(packet)

        let dict = try message.toContextDictionary()
        XCTAssertNotNil(dict["wm_state"])
        XCTAssertNil(dict["wm_nowPlaying"])
    }

    // MARK: - allFromContextDictionary

    func test_allFromContextDictionary_multipleKeys() throws {
        let nowPlaying = WatchMessage.nowPlayingUpdate(NowPlayingPacket(
            songTitle: "Song", artistName: "Artist", artworkData: nil,
            isPlaying: true, progress: 0.5, duration: 200, explanation: nil))
        let state = WatchMessage.stateUpdate(StatePacket(
            energyLevel: 0.7, calmLevel: 0.3, focusLevel: 0.8,
            heartRate: 68, currentContext: "focus", timestamp: Date()))

        // Merge both into a single context dict (simulating applicationContext)
        var merged: [String: Any] = [:]
        for (k, v) in try nowPlaying.toContextDictionary() { merged[k] = v }
        for (k, v) in try state.toContextDictionary() { merged[k] = v }

        let decoded = WatchMessage.allFromContextDictionary(merged)
        XCTAssertEqual(decoded.count, 2)

        let hasNowPlaying = decoded.contains { if case .nowPlayingUpdate = $0 { return true }; return false }
        let hasState = decoded.contains { if case .stateUpdate = $0 { return true }; return false }
        XCTAssertTrue(hasNowPlaying, "Should decode nowPlayingUpdate from context")
        XCTAssertTrue(hasState, "Should decode stateUpdate from context")
    }

    func test_allFromContextDictionary_emptyDict() {
        let decoded = WatchMessage.allFromContextDictionary([:])
        XCTAssertTrue(decoded.isEmpty)
    }

    func test_allFromContextDictionary_legacySingleKey() throws {
        // Test backwards compatibility with old single "watchMessage" key
        let message = WatchMessage.nowPlayingUpdate(NowPlayingPacket(
            songTitle: "Legacy", artistName: "Old", artworkData: nil,
            isPlaying: false, progress: 0, duration: 100, explanation: nil))
        let dict = try message.toDictionary() // uses "watchMessage" key

        let decoded = WatchMessage.allFromContextDictionary(dict)
        XCTAssertEqual(decoded.count, 1)
        if case .nowPlayingUpdate(let p) = decoded.first {
            XCTAssertEqual(p.songTitle, "Legacy")
        } else {
            XCTFail("Expected nowPlayingUpdate from legacy dict")
        }
    }
}
