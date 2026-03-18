//
//  AudioAnalyzer.swift
//  Resonance
//
//  On-device audio analysis using chunk-based processing for memory-safe
//  feature extraction. Extracts BPM, spectral energy, spectral centroid,
//  zero-crossing rate, and vocal presence to produce accurate audio features
//  without relying on genre heuristics.
//
//  Uses chunk-based reading (10-second windows) instead of loading entire
//  tracks into memory, preventing OOM on long tracks.
//
//  Replaces genre-based lookup tables with actual audio analysis.
//  Runs as a BGProcessingTask on first library import.
//

#if os(iOS)

import AVFoundation
import Accelerate
import Foundation

// MARK: - Audio Analysis Result

/// Results from analyzing an audio track.
struct AudioAnalysisResult {
    /// Estimated beats per minute (40-220 BPM range)
    let bpm: Double

    /// Spectral energy level (0.0 - 1.0)
    let energy: Double

    /// Spectral centroid as a proxy for brightness/valence (0.0 - 1.0)
    let valence: Double

    /// Zero-crossing rate as a proxy for instrumentalness (0.0 - 1.0)
    let instrumentalness: Double

    /// Acoustic density estimate (0.0 - 1.0)
    let acousticDensity: Double

    /// Whether vocals are detected in the track
    let hasVocals: Bool

    /// Confidence in the analysis (0.0 - 1.0)
    let confidence: Double
}

// MARK: - Audio Analyzer

/// Analyzes audio files to extract BPM, energy, valence, and instrumentalness.
/// Uses chunk-based processing with Accelerate framework for memory-safe,
/// efficient on-device analysis.
final class AudioAnalyzer {

    // MARK: - Constants

    private let sampleRate: Double = 44100
    private let bufferSize: AVAudioFrameCount = 4096
    private let minBPM: Double = 40
    private let maxBPM: Double = 220

    /// 10 seconds of audio per chunk at 44.1kHz
    private let chunkSize: AVAudioFrameCount = 44100 * 10

    /// Duration in seconds of the middle segment used for BPM estimation
    private let bpmSegmentSeconds: Double = 30

    // MARK: - Analyze Audio URL

    /// Analyzes an audio file at the given URL and returns extracted features.
    /// Uses chunk-based reading to avoid loading entire tracks into memory.
    /// This is a CPU-intensive operation and should be called from a background thread.
    func analyze(url: URL) async throws -> AudioAnalysisResult {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let totalFrameCount = AVAudioFrameCount(audioFile.length)
        let actualSampleRate = format.sampleRate

        guard totalFrameCount > 0 else {
            return AudioAnalysisResult(
                bpm: 0, energy: 0.5, valence: 0.5,
                instrumentalness: 0.5, acousticDensity: 0.5,
                hasVocals: false, confidence: 0
            )
        }

        // Accumulate per-chunk feature values
        var chunkEnergies: [Double] = []
        var chunkZCRs: [Double] = []
        var chunkCentroids: [Double] = []
        var chunkVocalRatios: [Double] = []
        var framesRead: AVAudioFrameCount = 0

        // Read and process audio in chunks to prevent OOM
        while framesRead < totalFrameCount {
            try autoreleasepool {
                let remaining = totalFrameCount - framesRead
                let framesToRead = min(chunkSize, remaining)

                guard let chunkBuffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: framesToRead
                ) else {
                    throw AudioAnalyzerError.bufferCreationFailed
                }

                try audioFile.read(into: chunkBuffer, frameCount: framesToRead)

                guard let channelData = chunkBuffer.floatChannelData?[0] else {
                    throw AudioAnalyzerError.noAudioData
                }

                let count = Int(chunkBuffer.frameLength)
                guard count > 0 else { return }

                chunkEnergies.append(computeRMSEnergy(channelData, count: count))
                chunkZCRs.append(computeZeroCrossingRate(channelData, count: count))
                chunkCentroids.append(
                    computeSpectralCentroid(channelData, count: count, sampleRate: actualSampleRate)
                )
                chunkVocalRatios.append(
                    computeVocalEnergyRatio(channelData, count: count, sampleRate: actualSampleRate)
                )

                framesRead += framesToRead
            }
        }

        guard !chunkEnergies.isEmpty else {
            return AudioAnalysisResult(
                bpm: 0, energy: 0.5, valence: 0.5,
                instrumentalness: 0.5, acousticDensity: 0.5,
                hasVocals: false, confidence: 0
            )
        }

        // Aggregate features across chunks
        let avgEnergy = chunkEnergies.reduce(0, +) / Double(chunkEnergies.count)
        let avgZCR = chunkZCRs.reduce(0, +) / Double(chunkZCRs.count)
        let avgCentroid = chunkCentroids.reduce(0, +) / Double(chunkCentroids.count)
        let avgVocalRatio = chunkVocalRatios.reduce(0, +) / Double(chunkVocalRatios.count)

        // BPM: use a representative 30-second middle segment
        let bpm = try estimateBPMFromMiddleSegment(
            url: url,
            format: format,
            totalFrameCount: totalFrameCount,
            sampleRate: actualSampleRate
        )

        // Normalize features to 0-1 range
        let normalizedEnergy = min(1.0, max(0.0, avgEnergy / 0.15))
        let normalizedValence = min(1.0, max(0.0, avgCentroid / 8000.0))
        let normalizedInstrumentalness = min(1.0, max(0.0, 1.0 - (avgZCR / 0.3)))
        let normalizedAcousticDensity = min(1.0, max(0.0,
            (avgEnergy * 2.0 + (1.0 - normalizedInstrumentalness)) / 3.0
        ))
        let hasVocals = avgVocalRatio > 0.3

        return AudioAnalysisResult(
            bpm: bpm,
            energy: normalizedEnergy,
            valence: normalizedValence,
            instrumentalness: normalizedInstrumentalness,
            acousticDensity: normalizedAcousticDensity,
            hasVocals: hasVocals,
            confidence: 0.85
        )
    }

    // MARK: - BPM Middle Segment Estimation

    /// Reads a 30-second segment from the middle of the track for BPM estimation.
    /// This avoids loading the entire track while providing a representative sample.
    private func estimateBPMFromMiddleSegment(
        url: URL,
        format: AVAudioFormat,
        totalFrameCount: AVAudioFrameCount,
        sampleRate: Double
    ) throws -> Double {
        let segmentFrames = AVAudioFrameCount(bpmSegmentSeconds * sampleRate)
        let framesToRead = min(segmentFrames, totalFrameCount)

        // Seek to the middle of the track
        let midStart = totalFrameCount > framesToRead
            ? AVAudioFramePosition((totalFrameCount - framesToRead) / 2)
            : 0

        let bpmFile = try AVAudioFile(forReading: url)
        bpmFile.framePosition = midStart

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
            return 120.0
        }

        try bpmFile.read(into: buffer, frameCount: framesToRead)

        guard let channelData = buffer.floatChannelData?[0] else {
            return 120.0
        }

        return estimateBPM(channelData, count: Int(buffer.frameLength), sampleRate: sampleRate)
    }

    // MARK: - RMS Energy (using Accelerate)

    private func computeRMSEnergy(_ data: UnsafePointer<Float>, count: Int) -> Double {
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(count))
        return Double(rms)
    }

    // MARK: - Zero Crossing Rate

    private func computeZeroCrossingRate(_ data: UnsafePointer<Float>, count: Int) -> Double {
        guard count > 1 else { return 0 }

        var crossings = 0
        for i in 1..<count {
            if (data[i] >= 0 && data[i - 1] < 0) || (data[i] < 0 && data[i - 1] >= 0) {
                crossings += 1
            }
        }

        return Double(crossings) / Double(count)
    }

    // MARK: - Spectral Centroid (using Accelerate FFT)

    private func computeSpectralCentroid(_ data: UnsafePointer<Float>, count: Int, sampleRate: Double) -> Double {
        let fftSize = 2048
        guard count >= fftSize else { return 4000.0 }  // Default mid-range

        // Take a sample from the middle of the track
        let midOffset = max(0, (count - fftSize) / 2)

        // Setup FFT
        guard let fftSetup = vDSP_create_fftsetup(vDSP_Length(Int(log2(Double(fftSize)))), FFTRadix(kFFTRadix2)) else {
            return 4000.0
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var realPart = [Float](repeating: 0, count: fftSize / 2)
        var imagPart = [Float](repeating: 0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

        // Copy and window the data
        var windowed = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            windowed[i] = data[midOffset + i]
        }

        // Apply Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Pack real samples into split-complex form for vDSP_fft_zrip:
        // even-indexed samples go to realp, odd-indexed to imagp.
        for i in 0..<(fftSize / 2) {
            realPart[i] = windowed[2 * i]
            imagPart[i] = windowed[2 * i + 1]
        }
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(Int(log2(Double(fftSize)))), FFTDirection(FFT_FORWARD))

        // Compute magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Compute spectral centroid = sum(f * magnitude) / sum(magnitude)
        let binWidth = Float(sampleRate) / Float(fftSize)
        var weightedSum: Float = 0
        var totalMag: Float = 0

        for i in 0..<(fftSize / 2) {
            let freq = Float(i) * binWidth
            weightedSum += freq * magnitudes[i]
            totalMag += magnitudes[i]
        }

        guard totalMag > 0 else { return 4000.0 }
        return Double(weightedSum / totalMag)
    }

    // MARK: - Vocal Energy Ratio

    /// Computes the ratio of energy in vocal formant bands (300Hz-3.4kHz) vs total energy.
    /// Vocals have characteristic formant patterns concentrated in this range.
    private func computeVocalEnergyRatio(
        _ data: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> Double {
        let fftSize = 2048
        guard count >= fftSize else { return 0.0 }

        let midOffset = max(0, (count - fftSize) / 2)

        guard let fftSetup = vDSP_create_fftsetup(
            vDSP_Length(Int(log2(Double(fftSize)))),
            FFTRadix(kFFTRadix2)
        ) else {
            return 0.0
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var realPart = [Float](repeating: 0, count: fftSize / 2)
        var imagPart = [Float](repeating: 0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

        var windowed = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            windowed[i] = data[midOffset + i]
        }

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        for i in 0..<(fftSize / 2) {
            realPart[i] = windowed[2 * i]
            imagPart[i] = windowed[2 * i + 1]
        }
        vDSP_fft_zrip(
            fftSetup, &splitComplex, 1,
            vDSP_Length(Int(log2(Double(fftSize)))),
            FFTDirection(FFT_FORWARD)
        )

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        let binWidth = Float(sampleRate) / Float(fftSize)
        let vocalLowBin = Int(300.0 / binWidth)
        let vocalHighBin = min(fftSize / 2, Int(3400.0 / binWidth))

        var vocalEnergy: Float = 0
        var totalEnergy: Float = 0

        for i in 0..<(fftSize / 2) {
            totalEnergy += magnitudes[i]
            if i >= vocalLowBin && i <= vocalHighBin {
                vocalEnergy += magnitudes[i]
            }
        }

        guard totalEnergy > 0 else { return 0.0 }
        return Double(vocalEnergy / totalEnergy)
    }

    // MARK: - BPM Estimation via Onset Detection

    private func estimateBPM(_ data: UnsafePointer<Float>, count: Int, sampleRate: Double) -> Double {
        // Use energy-based onset detection with autocorrelation
        let hopSize = 512
        let frameSize = 1024
        let numFrames = (count - frameSize) / hopSize

        guard numFrames > 10 else { return 120.0 }  // Default if track is too short

        // Compute frame energies
        var energies = [Float](repeating: 0, count: numFrames)
        for i in 0..<numFrames {
            let offset = i * hopSize
            var energy: Float = 0
            vDSP_svesq(data.advanced(by: offset), 1, &energy, vDSP_Length(frameSize))
            energies[i] = energy / Float(frameSize)
        }

        // Compute onset strength (difference of energy)
        var onsetStrength = [Float](repeating: 0, count: numFrames - 1)
        for i in 0..<(numFrames - 1) {
            onsetStrength[i] = max(0, energies[i + 1] - energies[i])
        }

        // Autocorrelation to find periodicity
        let onsetCount = onsetStrength.count
        let minLag = Int(60.0 / maxBPM * sampleRate / Double(hopSize))
        let maxLag = min(onsetCount / 2, Int(60.0 / minBPM * sampleRate / Double(hopSize)))

        guard maxLag > minLag else { return 120.0 }

        var bestLag = minLag
        var bestCorrelation: Float = -Float.infinity

        for lag in minLag..<maxLag {
            var correlation: Float = 0
            let length = min(onsetCount - lag, onsetCount / 2)
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

        let bpm = 60.0 / (Double(bestLag) * Double(hopSize) / sampleRate)
        return min(maxBPM, max(minBPM, bpm))
    }
}

// MARK: - Errors

enum AudioAnalyzerError: LocalizedError {
    case bufferCreationFailed
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed: return "Failed to create audio buffer"
        case .noAudioData: return "No audio data available for analysis"
        }
    }
}

#endif
