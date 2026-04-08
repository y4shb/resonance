//
//  VocalDetector.swift
//  Resonance
//
//  Detects vocal presence in audio using spectral analysis of formant bands.
//  Vocals have characteristic energy patterns in the 300Hz-3.4kHz range
//  corresponding to human speech formants (F1-F3).
//
//  Uses a simple threshold classifier: if the ratio of energy in the vocal
//  formant bands vs total spectral energy exceeds 0.3, vocals are present.
//
//  Integrates with FeatureExtractor to add hasVocals to extracted features,
//  and with GuardFilters for focus-mode vocal filtering.
//

#if os(iOS)

import Accelerate
import AVFoundation
import Foundation

// MARK: - Vocal Detection Result

/// Result of vocal presence analysis on an audio segment.
struct VocalDetectionResult {
    /// Whether vocals were detected above the threshold
    let hasVocals: Bool

    /// Ratio of vocal-band energy to total energy (0.0-1.0)
    let vocalEnergyRatio: Double

    /// Confidence in the detection (0.0-1.0)
    let confidence: Double
}

// MARK: - Vocal Detector

/// Detects vocal presence in audio using spectral formant band analysis.
/// Human vocals concentrate energy in specific frequency bands (formants):
/// - F1: ~300-900Hz (vowel height)
/// - F2: ~900-2300Hz (vowel backness)
/// - F3: ~2300-3400Hz (speaker identity)
///
/// By measuring the proportion of total spectral energy that falls within
/// these bands, we can classify tracks as vocal or instrumental.
final class VocalDetector {

    // MARK: - Constants

    /// Lower bound of vocal formant range (Hz)
    private let vocalBandLowHz: Float = 300.0

    /// Upper bound of vocal formant range (Hz)
    private let vocalBandHighHz: Float = 3400.0

    /// Threshold for combined vocal score above which vocals are considered present.
    /// Uses both formant energy ratio and spectral flatness for reduced false positives.
    private let vocalThreshold = 0.3

    /// Spectral flatness threshold below which the formant band is considered harmonic
    /// (likely vocals) rather than noise-like (synths, percussion).
    /// Flatness = geometric_mean / arithmetic_mean of the spectrum (0=pure tone, 1=white noise).
    private let harmonicFlatnessThreshold: Double = 0.3

    /// FFT size for spectral analysis
    private let fftSize = 2048

    /// Number of FFT windows to average for stability
    private let windowsToAverage = 8

    /// Chunk size for file-based analysis (10 seconds at 44.1kHz)
    private let analysisChunkSize: AVAudioFrameCount = 44100 * 10

    // MARK: - File-Based Detection

    /// Analyzes an audio file for vocal presence using chunk-based reading.
    /// Samples multiple positions in the track for robust detection.
    ///
    /// - Parameter url: URL of the audio file to analyze.
    /// - Returns: A VocalDetectionResult with vocal presence classification.
    func detectVocals(in url: URL) throws -> VocalDetectionResult {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate
        let totalFrames = AVAudioFrameCount(audioFile.length)

        guard totalFrames > AVAudioFrameCount(fftSize) else {
            return VocalDetectionResult(
                hasVocals: false,
                vocalEnergyRatio: 0,
                confidence: 0
            )
        }

        // Sample from 3 positions: 25%, 50%, 75% of the track
        let samplePositions: [Double] = [0.25, 0.50, 0.75]
        var vocalRatios: [Double] = []

        var flatnessValues: [Double] = []

        for position in samplePositions {
            let framePosition = AVAudioFramePosition(Double(totalFrames) * position)
            let framesToRead = min(analysisChunkSize, totalFrames - AVAudioFrameCount(framePosition))

            guard framesToRead > AVAudioFrameCount(fftSize) else { continue }

            autoreleasepool {
                do {
                    let sampleFile = try AVAudioFile(forReading: url)
                    sampleFile.framePosition = framePosition

                    guard let buffer = AVAudioPCMBuffer(
                        pcmFormat: format,
                        frameCapacity: framesToRead
                    ) else { return }

                    try sampleFile.read(into: buffer, frameCount: framesToRead)

                    guard let channelData = buffer.floatChannelData?[0] else { return }
                    let count = Int(buffer.frameLength)

                    let ratio = computeVocalRatio(channelData, count: count, sampleRate: sampleRate)
                    vocalRatios.append(ratio)

                    let flatness = computeVocalBandFlatness(channelData, count: count, sampleRate: sampleRate)
                    flatnessValues.append(flatness)
                } catch {
                    logDebug(
                        "VocalDetector: failed to read sample at position \(position)",
                        category: .background
                    )
                }
            }
        }

        guard !vocalRatios.isEmpty else {
            return VocalDetectionResult(
                hasVocals: false,
                vocalEnergyRatio: 0,
                confidence: 0
            )
        }

        let avgRatio = vocalRatios.reduce(0, +) / Double(vocalRatios.count)
        let avgFlatness = flatnessValues.isEmpty
            ? 1.0
            : flatnessValues.reduce(0, +) / Double(flatnessValues.count)
        let confidence = min(1.0, Double(vocalRatios.count) / Double(samplePositions.count))

        // Combined decision: energy ratio must exceed threshold AND formant band
        // must show harmonic structure (low flatness). This eliminates false positives
        // from bass-heavy EDM and synth-lead tracks that have high formant energy
        // but noise-like (non-harmonic) spectral characteristics.
        let hasVocals = avgRatio > vocalThreshold && avgFlatness < harmonicFlatnessThreshold

        return VocalDetectionResult(
            hasVocals: hasVocals,
            vocalEnergyRatio: avgRatio,
            confidence: confidence
        )
    }

    // MARK: - Buffer-Based Detection

    /// Analyzes a pre-loaded audio buffer for vocal presence.
    /// Useful for real-time or already-loaded audio data.
    ///
    /// - Parameters:
    ///   - data: Pointer to float audio samples.
    ///   - count: Number of samples.
    ///   - sampleRate: Sample rate of the audio.
    /// - Returns: A VocalDetectionResult.
    func detectVocals(
        in data: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> VocalDetectionResult {
        let ratio = computeVocalRatio(data, count: count, sampleRate: sampleRate)

        return VocalDetectionResult(
            hasVocals: ratio > vocalThreshold,
            vocalEnergyRatio: ratio,
            confidence: count >= fftSize * windowsToAverage ? 0.9 : 0.6
        )
    }

    // MARK: - Core Spectral Analysis

    /// Computes the ratio of spectral energy in vocal formant bands (300Hz-3.4kHz)
    /// relative to total spectral energy, averaged over multiple FFT windows.
    private func computeVocalRatio(
        _ data: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> Double {
        guard count >= fftSize else { return 0.0 }

        let log2n = vDSP_Length(Int(log2(Double(fftSize))))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return 0.0
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let binWidth = Float(sampleRate) / Float(fftSize)
        let vocalLowBin = Int(vocalBandLowHz / binWidth)
        let vocalHighBin = min(fftSize / 2 - 1, Int(vocalBandHighHz / binWidth))

        // Prepare Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        let numWindows = min(windowsToAverage, (count - fftSize) / (fftSize / 2) + 1)
        guard numWindows > 0 else { return 0.0 }

        var totalVocalEnergy: Double = 0
        var totalFullEnergy: Double = 0

        // Analyze multiple overlapping windows and average
        let hopForWindows = max(1, (count - fftSize) / max(1, numWindows - 1))

        for w in 0..<numWindows {
            let offset = min(w * hopForWindows, count - fftSize)

            var realPart = [Float](repeating: 0, count: fftSize / 2)
            var imagPart = [Float](repeating: 0, count: fftSize / 2)
            var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

            // Window the data
            var windowed = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(data.advanced(by: offset), 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

            // Pack into split complex form
            for i in 0..<(fftSize / 2) {
                realPart[i] = windowed[2 * i]
                imagPart[i] = windowed[2 * i + 1]
            }

            // Forward FFT
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            // Compute magnitude spectrum
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

            // Accumulate vocal and total energy
            var windowVocalEnergy: Float = 0
            var windowTotalEnergy: Float = 0

            for i in 0..<(fftSize / 2) {
                windowTotalEnergy += magnitudes[i]
                if i >= vocalLowBin && i <= vocalHighBin {
                    windowVocalEnergy += magnitudes[i]
                }
            }

            totalVocalEnergy += Double(windowVocalEnergy)
            totalFullEnergy += Double(windowTotalEnergy)
        }

        guard totalFullEnergy > 0 else { return 0.0 }
        return totalVocalEnergy / totalFullEnergy
    }

    // MARK: - Spectral Flatness (Harmonic vs Noise Discriminator)

    /// Computes spectral flatness within the vocal formant band (300Hz-3.4kHz).
    /// Flatness = geometric_mean / arithmetic_mean of magnitude values.
    /// Pure tones (vocals) → flatness ≈ 0; white noise (synths) → flatness ≈ 1.
    ///
    /// This discriminates vocal harmonics from noise-like energy (synth leads,
    /// hi-hats, distorted guitars) that can produce false positives in the
    /// energy-ratio-only detector.
    ///
    /// - Parameters:
    ///   - data: Pointer to raw float audio samples.
    ///   - count: Number of samples.
    ///   - sampleRate: Sample rate of the audio.
    /// - Returns: Spectral flatness in the vocal band (0.0 = harmonic, 1.0 = noise-like).
    private func computeVocalBandFlatness(
        _ data: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> Double {
        guard count >= fftSize else { return 1.0 }

        let log2n = vDSP_Length(Int(log2(Double(fftSize))))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return 1.0
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let binWidth = Float(sampleRate) / Float(fftSize)
        let vocalLowBin = Int(vocalBandLowHz / binWidth)
        let vocalHighBin = min(fftSize / 2 - 1, Int(vocalBandHighHz / binWidth))
        let bandSize = vocalHighBin - vocalLowBin + 1

        guard bandSize > 0 else { return 1.0 }

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Use a sample from the middle of the data
        let midOffset = max(0, (count - fftSize) / 2)

        var realPart = [Float](repeating: 0, count: fftSize / 2)
        var imagPart = [Float](repeating: 0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(data.advanced(by: midOffset), 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        for i in 0..<(fftSize / 2) {
            realPart[i] = windowed[2 * i]
            imagPart[i] = windowed[2 * i + 1]
        }

        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Extract vocal band magnitudes (add small epsilon to avoid log(0))
        let epsilon: Float = 1e-10
        var bandMags = [Float](repeating: 0, count: bandSize)
        for i in 0..<bandSize {
            bandMags[i] = max(epsilon, magnitudes[vocalLowBin + i])
        }

        // Geometric mean via exp(mean(log(x)))
        var logBand = [Float](repeating: 0, count: bandSize)
        var n = Int32(bandSize)
        vvlogf(&logBand, bandMags, &n)

        var logMean: Float = 0
        vDSP_meanv(logBand, 1, &logMean, vDSP_Length(bandSize))
        let geometricMean = exp(logMean)

        // Arithmetic mean
        var arithmeticMean: Float = 0
        vDSP_meanv(bandMags, 1, &arithmeticMean, vDSP_Length(bandSize))

        guard arithmeticMean > epsilon else { return 1.0 }

        return Double(min(1.0, max(0.0, geometricMean / arithmeticMean)))
    }
}

#endif
