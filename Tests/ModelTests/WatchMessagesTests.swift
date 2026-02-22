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
}
