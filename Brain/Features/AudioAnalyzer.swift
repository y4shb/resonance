//
//  AudioAnalyzer.swift
//  Resonance
//
//  On-device audio analysis using AVAudioEngine for real-time feature extraction.
//  Extracts BPM, spectral energy, spectral centroid, and zero-crossing rate
//  to produce accurate audio features without relying on genre heuristics.
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

    /// Confidence in the analysis (0.0 - 1.0)
    let confidence: Double
}

// MARK: - Audio Analyzer

/// Analyzes audio files to extract BPM, energy, valence, and instrumentalness.
/// Uses AVAudioEngine with Accelerate framework for efficient on-device processing.
final class AudioAnalyzer {

    // MARK: - Constants

    private let sampleRate: Double = 44100
    private let bufferSize: AVAudioFrameCount = 4096
    private let minBPM: Double = 40
    private let maxBPM: Double = 220

    // MARK: - Analyze Audio URL

    /// Analyzes an audio file at the given URL and returns extracted features.
    /// This is a CPU-intensive operation and should be called from a background thread.
    func analyze(url: URL) async throws -> AudioAnalysisResult {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard frameCount > 0 else {
            return AudioAnalysisResult(
                bpm: 0, energy: 0.5, valence: 0.5,
                instrumentalness: 0.5, acousticDensity: 0.5, confidence: 0
            )
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioAnalyzerError.bufferCreationFailed
        }

        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData?[0] else {
            throw AudioAnalyzerError.noAudioData
        }

        let totalFrames = Int(buffer.frameLength)
        let actualSampleRate = format.sampleRate

        // Extract features using Accelerate for performance
        let energy = computeRMSEnergy(channelData, count: totalFrames)
        let zcr = computeZeroCrossingRate(channelData, count: totalFrames)
        let spectralCentroid = computeSpectralCentroid(channelData, count: totalFrames, sampleRate: actualSampleRate)
        let bpm = estimateBPM(channelData, count: totalFrames, sampleRate: actualSampleRate)

        // Normalize features to 0-1 range
        let normalizedEnergy = min(1.0, max(0.0, energy / 0.15))  // RMS of 0.15 = full energy
        let normalizedValence = min(1.0, max(0.0, spectralCentroid / 8000.0))  // Higher centroid = brighter = more positive
        let normalizedInstrumentalness = min(1.0, max(0.0, 1.0 - (zcr / 0.3)))  // Lower ZCR = more instrumental
        let normalizedAcousticDensity = min(1.0, max(0.0, (energy * 2.0 + (1.0 - normalizedInstrumentalness)) / 3.0))

        return AudioAnalysisResult(
            bpm: bpm,
            energy: normalizedEnergy,
            valence: normalizedValence,
            instrumentalness: normalizedInstrumentalness,
            acousticDensity: normalizedAcousticDensity,
            confidence: 0.85  // Audio analysis is significantly more accurate than genre heuristics (0.4)
        )
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
