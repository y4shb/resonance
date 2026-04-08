//
//  RealtimeBPMVerifier.swift
//  Resonance
//
//  Real-time BPM verification using spectral flux onset detection.
//  Duty-cycles 1 second of analysis every 10 seconds to verify the stored
//  BPM against what is actually playing. If the verified BPM differs from
//  the stored metadata BPM by more than the threshold, the Song entity
//  is updated.
//
//  Uses vDSP/Accelerate for efficient FFT-based spectral flux computation.
//

#if os(iOS)

import Accelerate
import AVFoundation
import CoreData
import Foundation

// MARK: - Realtime BPM Verifier

/// Verifies BPM in real time during playback using spectral flux onset detection.
/// Duty-cycles analysis (1s every 10s) to minimize CPU/battery impact.
final class RealtimeBPMVerifier {

    // MARK: - Constants

    /// How often to run a verification cycle (seconds)
    private let dutyCycleInterval: TimeInterval = 10.0

    /// Duration of each analysis window (seconds)
    private let analysisWindowSeconds = 1.0

    /// BPM difference threshold before triggering an update
    private let bpmDeltaThreshold = 5.0

    /// FFT size for spectral flux computation
    private let fftSize = 2048

    /// Hop size between FFT frames
    private let hopSize = 512

    /// Valid BPM range
    private let minBPM = 40.0
    private let maxBPM = 220.0

    // MARK: - State

    /// Lock protecting mutable state accessed from audio, main, and background threads.
    private let lock = NSLock()

    /// Timer controlling duty-cycled analysis
    private var dutyCycleTimer: Timer?

    /// Whether verification is currently active
    private(set) var isActive = false

    /// The song currently being verified
    private var currentSongObjectID: NSManagedObjectID?

    /// Stored BPM to compare against
    private var storedBPM = 0.0

    /// Recent verified BPM measurements for averaging
    private var recentMeasurements: [Double] = []

    /// Maximum number of measurements to keep for averaging
    private let maxMeasurements = 5

    /// Audio tap node for capturing playback audio
    private weak var audioEngine: AVAudioEngine?

    /// Whether an audio tap is currently installed
    private var hasTapInstalled = false

    /// Persistence controller for updating Song entities
    private let persistence: PersistenceController

    // MARK: - Spectral Flux State

    /// Previous frame's magnitude spectrum for flux computation
    private var previousMagnitudes: [Float]?

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    deinit {
        stop()
    }

    // MARK: - Start / Stop

    /// Begins real-time BPM verification for the given song.
    /// Call when a new song starts playing.
    func start(
        songObjectID: NSManagedObjectID,
        storedBPM: Double,
        audioEngine: AVAudioEngine
    ) {
        stop()

        lock.lock()
        self.currentSongObjectID = songObjectID
        self.storedBPM = storedBPM
        self.audioEngine = audioEngine
        self.recentMeasurements.removeAll()
        self.previousMagnitudes = nil
        self.isActive = true
        lock.unlock()

        logInfo(
            "RealtimeBPMVerifier: started for song (stored BPM: \(Int(storedBPM)))",
            category: .background
        )

        dutyCycleTimer = Timer.scheduledTimer(
            withTimeInterval: dutyCycleInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performVerificationCycle()
        }
    }

    /// Stops BPM verification. Call when playback stops or song changes.
    func stop() {
        dutyCycleTimer?.invalidate()
        dutyCycleTimer = nil

        // Remove any installed tap before clearing state
        removeAudioTap()

        lock.lock()
        isActive = false
        currentSongObjectID = nil
        previousMagnitudes = nil
        recentMeasurements.removeAll()
        lock.unlock()
    }

    /// Removes the audio tap from the mixer node if one is installed.
    /// Safe to call even if no tap is installed.
    private func removeAudioTap() {
        lock.lock()
        let engine = audioEngine
        let tapInstalled = hasTapInstalled
        lock.unlock()

        guard tapInstalled, let engine = engine else { return }

        let outputNode = engine.mainMixerNode
        outputNode.removeTap(onBus: 0)

        lock.lock()
        hasTapInstalled = false
        lock.unlock()
    }

    // MARK: - Verification Cycle

    /// Performs a single 1-second analysis cycle.
    /// Captures audio, computes spectral flux onsets, estimates BPM,
    /// and compares against stored metadata.
    private func performVerificationCycle() {
        lock.lock()
        let active = isActive
        let engine = audioEngine
        lock.unlock()

        guard active,
              let engine = engine,
              engine.isRunning else {
            return
        }

        // Remove any existing tap before installing a new one to prevent
        // "bus already has a tap" crash
        removeAudioTap()

        let outputNode = engine.mainMixerNode
        let format = outputNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let framesToCapture = AVAudioFrameCount(analysisWindowSeconds * sampleRate)

        guard let captureBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: framesToCapture
        ) else {
            return
        }

        // Install a tap to capture 1 second of audio
        var captured = false
        lock.lock()
        hasTapInstalled = true
        lock.unlock()

        outputNode.installTap(onBus: 0, bufferSize: framesToCapture, format: format) {
            [weak self] buffer, _ in
            guard let self = self, !captured else { return }
            captured = true

            // Copy buffer data
            guard let sourceData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)

            guard let destData = captureBuffer.floatChannelData?[0] else { return }
            let copyCount = min(frameCount, Int(framesToCapture))
            destData.update(from: sourceData, count: copyCount)
            captureBuffer.frameLength = AVAudioFrameCount(copyCount)

            // Analyze on background queue
            DispatchQueue.global(qos: .utility).async {
                self.analyzeBuffer(captureBuffer, sampleRate: sampleRate)
            }

            // Remove tap after capture
            DispatchQueue.main.async { [weak self] in
                self?.removeAudioTap()
            }
        }
    }

    // MARK: - Analysis

    /// Analyzes a captured audio buffer using spectral flux onset detection
    /// to estimate BPM.
    private func analyzeBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        let verifiedBPM = estimateBPMViaSpectralFlux(
            channelData,
            count: frameCount,
            sampleRate: sampleRate
        )

        guard verifiedBPM > 0 else { return }

        lock.lock()
        recentMeasurements.append(verifiedBPM)
        if recentMeasurements.count > maxMeasurements {
            recentMeasurements.removeFirst()
        }

        // Need at least 2 measurements for a reliable average
        guard recentMeasurements.count >= 2 else {
            lock.unlock()
            return
        }

        let avgBPM = recentMeasurements.reduce(0, +) / Double(recentMeasurements.count)
        let currentStoredBPM = storedBPM
        lock.unlock()

        let delta = abs(avgBPM - currentStoredBPM)

        logDebug(
            "RealtimeBPMVerifier: verified=\(Int(avgBPM)), stored=\(Int(currentStoredBPM)), "
            + "delta=\(String(format: "%.1f", delta))",
            category: .background
        )

        if delta > bpmDeltaThreshold {
            updateSongBPM(verifiedBPM: avgBPM)
        }
    }

    // MARK: - Spectral Flux BPM Estimation

    /// Estimates BPM using spectral flux onset detection.
    /// Spectral flux measures frame-to-frame changes in the magnitude spectrum,
    /// producing onset peaks that correspond to beats.
    private func estimateBPMViaSpectralFlux(
        _ data: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> Double {
        guard count > fftSize else { return 0 }

        let log2n = vDSP_Length(Int(log2(Double(fftSize))))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return 0
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let numFrames = (count - fftSize) / hopSize
        guard numFrames > 2 else { return 0 }

        var onsetStrength = [Float](repeating: 0, count: numFrames)
        var prevMagnitudes = [Float](repeating: 0, count: fftSize / 2)

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        for frame in 0..<numFrames {
            let offset = frame * hopSize

            var realPart = [Float](repeating: 0, count: fftSize / 2)
            var imagPart = [Float](repeating: 0, count: fftSize / 2)
            var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

            // Window the frame
            var windowed = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(data.advanced(by: offset), 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

            // Pack into split complex
            for i in 0..<(fftSize / 2) {
                realPart[i] = windowed[2 * i]
                imagPart[i] = windowed[2 * i + 1]
            }

            // Forward FFT
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            // Compute magnitudes
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

            // Spectral flux: sum of positive differences from previous frame
            if frame > 0 {
                var flux: Float = 0
                for i in 0..<(fftSize / 2) {
                    let diff = magnitudes[i] - prevMagnitudes[i]
                    if diff > 0 { flux += diff }
                }
                onsetStrength[frame] = flux
            }

            prevMagnitudes = magnitudes
        }

        // Autocorrelation on onset strength to find beat period
        let minLag = Int(60.0 / maxBPM * sampleRate / Double(hopSize))
        let maxLag = min(numFrames / 2, Int(60.0 / minBPM * sampleRate / Double(hopSize)))

        guard maxLag > minLag else { return 0 }

        var bestLag = minLag
        var bestCorrelation: Float = -Float.infinity

        for lag in minLag..<maxLag {
            var correlation: Float = 0
            let length = min(numFrames - lag, numFrames / 2)
            guard length > 0 else { continue }

            vDSP_dotpr(
                onsetStrength, 1,
                Array(onsetStrength[lag..<(lag + length)]), 1,
                &correlation,
                vDSP_Length(length)
            )

            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        let rawBPM = 60.0 / (Double(bestLag) * Double(hopSize) / sampleRate)

        // Octave correction: check half-lag and double-lag for comparable correlation.
        // Prefer the BPM closest to 120 (musical norm center) to resolve octave ambiguity.
        let musicalCenter = 120.0
        let octaveThreshold: Float = 0.80
        var bestBPM = rawBPM

        let halfLag = bestLag / 2
        if halfLag >= minLag {
            let length = min(numFrames - halfLag, numFrames / 2)
            if length > 0 {
                var corr: Float = 0
                vDSP_dotpr(onsetStrength, 1,
                           Array(onsetStrength[halfLag..<(halfLag + length)]), 1,
                           &corr, vDSP_Length(length))
                if corr >= bestCorrelation * octaveThreshold {
                    let halfBPM = 60.0 / (Double(halfLag) * Double(hopSize) / sampleRate)
                    if halfBPM >= minBPM && halfBPM <= maxBPM
                        && abs(halfBPM - musicalCenter) < abs(bestBPM - musicalCenter) {
                        bestBPM = halfBPM
                    }
                }
            }
        }

        let doubleLag = bestLag * 2
        if doubleLag <= maxLag {
            let length = min(numFrames - doubleLag, numFrames / 2)
            if length > 0 {
                var corr: Float = 0
                vDSP_dotpr(onsetStrength, 1,
                           Array(onsetStrength[doubleLag..<(doubleLag + length)]), 1,
                           &corr, vDSP_Length(length))
                if corr >= bestCorrelation * octaveThreshold {
                    let doubleBPM = 60.0 / (Double(doubleLag) * Double(hopSize) / sampleRate)
                    if doubleBPM >= minBPM && doubleBPM <= maxBPM
                        && abs(doubleBPM - musicalCenter) < abs(bestBPM - musicalCenter) {
                        bestBPM = doubleBPM
                    }
                }
            }
        }

        return min(maxBPM, max(minBPM, bestBPM))
    }

    // MARK: - Core Data Update

    /// Updates the Song entity's BPM if the verified value differs significantly.
    private func updateSongBPM(verifiedBPM: Double) {
        lock.lock()
        guard let objectID = currentSongObjectID else {
            lock.unlock()
            return
        }

        let roundedBPM = (verifiedBPM * 10).rounded() / 10
        storedBPM = roundedBPM
        lock.unlock()

        logInfo(
            "RealtimeBPMVerifier: updating BPM to \(Int(roundedBPM))",
            category: .background
        )

        persistence.performBackgroundTask { context in
            do {
                guard let song = try context.existingObject(with: objectID) as? Song else {
                    logWarning(
                        "RealtimeBPMVerifier: song not found for BPM update",
                        category: .background
                    )
                    return
                }

                song.bpm = roundedBPM

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                logError(
                    "RealtimeBPMVerifier: failed to update BPM",
                    error: error,
                    category: .background
                )
            }
        }
    }
}

#endif
