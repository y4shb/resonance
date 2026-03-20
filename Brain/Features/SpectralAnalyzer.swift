//
//  SpectralAnalyzer.swift
//  Resonance
//
//  Spectral feature extraction for audio analysis. Computes four key
//  spectral descriptors per audio frame or chunk:
//
//  - Spectral centroid:  Brightness / "center of mass" of the spectrum.
//  - Spectral rolloff:   Frequency below which a given percentile (85%)
//                        of spectral energy is concentrated.
//  - Spectral flux:      Frame-to-frame change in the magnitude spectrum,
//                        indicating onsets and transients.
//  - MFCCs:              Mel-frequency cepstral coefficients capturing
//                        timbral shape (coefficients 1-12).
//
//  Uses FFTProcessor and MelFilterbank to avoid duplicated FFT boilerplate.
//  All heavy lifting uses vDSP/Accelerate for efficient vectorized math.
//

#if os(iOS)

import Accelerate
import Foundation

// MARK: - Spectral Features

/// A snapshot of spectral descriptors for a single analysis window.
internal struct SpectralFeatures {

    // MARK: - Properties

    /// Spectral centroid in Hz (brightness).
    internal let centroid: Float

    /// Spectral rolloff frequency in Hz.
    internal let rolloff: Float

    /// Spectral flux (onset strength, non-negative).
    internal let flux: Float

    /// Mel-frequency cepstral coefficients (typically 12 values).
    internal let mfccs: [Float]

    // MARK: - Normalization Constants

    /// Maximum centroid frequency for normalization (Hz).
    private static let centroidNormalizationMax: Float = 10_000.0

    /// Nyquist frequency at 44100 Hz sample rate for rolloff normalization.
    private static let rolloffNormalizationMax: Float = 22_050.0

    // MARK: - Normalized Values

    /// Spectral centroid normalised to 0-1, mapping 0-10000 Hz.
    internal var normalizedCentroid: Float {
        return min(1.0, max(0.0, centroid / Self.centroidNormalizationMax))
    }

    /// Spectral rolloff normalised to 0-1, mapping 0-sampleRate/2.
    /// Uses a fixed 22050 Hz upper bound (Nyquist at 44100 Hz).
    internal var normalizedRolloff: Float {
        return min(1.0, max(0.0, rolloff / Self.rolloffNormalizationMax))
    }
}

// MARK: - Spectral Analyzer

/// Extracts spectral features from raw audio samples.
///
/// Provides two entry points:
/// - ``analyzeFrame(_:count:offset:previousMagnitudes:)``: single-frame
///   analysis where the caller manages overlap and previous-magnitude tracking.
/// - ``analyzeChunk(_:count:)``: multi-frame analysis with 50% overlap
///   that averages features across the chunk for a stable estimate.
///
/// - Important: This class owns an `FFTProcessor` and `MelFilterbank`
///   with mutable scratch buffers. Do not call analysis methods concurrently
///   from multiple threads on the same instance.
internal final class SpectralAnalyzer {

    // MARK: - Constants

    /// Default FFT frame size.
    private static let defaultFFTSize: Int = 2048

    /// Default audio sample rate in Hz.
    private static let defaultSampleRate: Double = 44_100.0

    /// Default number of mel filterbank channels.
    private static let defaultNumMelFilters: Int = 26

    /// Default number of MFCC coefficients (excluding c0).
    private static let defaultNumMFCCs: Int = 12

    /// Default energy percentile for spectral rolloff.
    private static let defaultRolloffPercentile: Float = 0.85

    /// Overlap divisor for chunk analysis (2 = 50% overlap).
    private static let chunkOverlapDivisor: Int = 2

    /// Floor value for log-mel energy computation to avoid log(0).
    private static let logFloor: Float = 1e-10

    // MARK: - Configuration

    /// FFT frame size (power of 2).
    private let fftSize: Int

    /// Audio sample rate in Hz.
    private let sampleRate: Double

    /// Number of MFCC coefficients to return (excluding c0).
    private let numMFCCs: Int

    /// Percentile for spectral rolloff (0.0-1.0).
    private let rolloffPercentile: Float

    /// Frequency resolution per FFT bin in Hz.
    private let binWidth: Float

    // MARK: - Sub-components

    /// Shared FFT processor with pre-allocated buffers.
    private let fftProcessor: FFTProcessor

    /// Pre-computed mel-scale filterbank.
    private let melFilterbank: MelFilterbank

    /// Pre-allocated DCT-II transform for MFCC computation.
    /// Created once at init to avoid per-frame allocation overhead.
    private let dctTransform: vDSP.DCT?

    // MARK: - Initialization

    /// Creates a spectral analyzer.
    ///
    /// - Parameters:
    ///   - fftSize: FFT frame size. Defaults to 2048.
    ///   - sampleRate: Sample rate in Hz. Defaults to 44100.
    ///   - numMelFilters: Number of mel filterbank channels. Defaults to 26.
    ///   - numMFCCs: Number of MFCC coefficients (1-based). Defaults to 12.
    ///   - rolloffPercentile: Energy percentile for rolloff. Defaults to 0.85.
    /// - Returns: `nil` if the underlying `FFTProcessor` cannot be created.
    init?(
        fftSize: Int = SpectralAnalyzer.defaultFFTSize,
        sampleRate: Double = SpectralAnalyzer.defaultSampleRate,
        numMelFilters: Int = SpectralAnalyzer.defaultNumMelFilters,
        numMFCCs: Int = SpectralAnalyzer.defaultNumMFCCs,
        rolloffPercentile: Float = SpectralAnalyzer.defaultRolloffPercentile
    ) {
        guard let processor = FFTProcessor(fftSize: fftSize) else { return nil }

        self.fftSize = fftSize
        self.sampleRate = sampleRate
        self.numMFCCs = numMFCCs
        self.rolloffPercentile = rolloffPercentile
        self.binWidth = Float(sampleRate) / Float(fftSize)
        self.fftProcessor = processor
        self.melFilterbank = MelFilterbank(
            fftSize: fftSize,
            sampleRate: sampleRate,
            numFilters: numMelFilters
        )

        // Pre-allocate DCT transform once to avoid per-frame overhead.
        // If creation fails, computeMFCCs will return zeroed coefficients.
        self.dctTransform = vDSP.DCT(
            count: numMelFilters,
            transformType: .II
        )
    }

    // MARK: - Single Frame Analysis

    /// Analyzes a single FFT frame and returns spectral features.
    ///
    /// - Parameters:
    ///   - data: Pointer to raw audio samples.
    ///   - count: Total number of available samples.
    ///   - offset: Sample index at which this frame begins.
    ///   - previousMagnitudes: Magnitude spectrum of the preceding frame,
    ///     used for spectral flux. Pass `nil` for the first frame.
    /// - Returns: A tuple of `(features, magnitudes)` where `magnitudes`
    ///   should be passed as `previousMagnitudes` on the next call, or
    ///   `nil` if the frame could not be computed.
    internal func analyzeFrame(
        _ data: UnsafePointer<Float>,
        count: Int,
        offset: Int,
        previousMagnitudes: [Float]?
    ) -> (features: SpectralFeatures, magnitudes: [Float])? {
        guard offset + fftSize <= count else { return nil }

        guard let magnitudes = fftProcessor.computeMagnitudes(data, offset: offset) else {
            return nil
        }

        let centroid = computeSpectralCentroid(magnitudes)
        let rolloff = computeSpectralRolloff(magnitudes)
        let flux = computeSpectralFlux(magnitudes, previous: previousMagnitudes)
        let mfccs = computeMFCCs(magnitudes)

        let features = SpectralFeatures(
            centroid: centroid,
            rolloff: rolloff,
            flux: flux,
            mfccs: mfccs
        )

        return (features, magnitudes)
    }

    // MARK: - Chunk Analysis

    /// Analyzes a chunk of audio using 50% overlapping windows and returns
    /// averaged spectral features.
    ///
    /// - Parameters:
    ///   - data: Pointer to raw audio samples.
    ///   - count: Number of samples in the chunk.
    /// - Returns: Averaged `SpectralFeatures` across all windows in the
    ///   chunk, or `nil` if the chunk is too short.
    internal func analyzeChunk(
        _ data: UnsafePointer<Float>,
        count: Int
    ) -> SpectralFeatures? {
        guard count >= fftSize else { return nil }

        let hopSize = fftSize / Self.chunkOverlapDivisor
        let numFrames = (count - fftSize) / hopSize + 1
        guard numFrames > 0 else { return nil }

        var sumCentroid: Float = 0
        var sumRolloff: Float = 0
        var sumFlux: Float = 0
        var sumMFCCs = [Float](repeating: 0, count: numMFCCs)
        var previousMagnitudes: [Float]?
        var validFrames: Int = 0

        for frame in 0..<numFrames {
            let offset = frame * hopSize

            guard let result = analyzeFrame(
                data,
                count: count,
                offset: offset,
                previousMagnitudes: previousMagnitudes
            ) else {
                continue
            }

            sumCentroid += result.features.centroid
            sumRolloff += result.features.rolloff
            sumFlux += result.features.flux

            let coeffCount = min(numMFCCs, result.features.mfccs.count)
            for i in 0..<coeffCount {
                sumMFCCs[i] += result.features.mfccs[i]
            }

            previousMagnitudes = result.magnitudes
            validFrames += 1
        }

        guard validFrames > 0 else { return nil }

        let divisor = Float(validFrames)
        let avgMFCCs = sumMFCCs.map { $0 / divisor }

        return SpectralFeatures(
            centroid: sumCentroid / divisor,
            rolloff: sumRolloff / divisor,
            flux: sumFlux / divisor,
            mfccs: avgMFCCs
        )
    }

    // MARK: - Spectral Centroid

    /// Computes the spectral centroid (brightness) of a magnitude spectrum.
    ///
    /// centroid = sum(f_i * m_i) / sum(m_i)
    ///
    /// Uses `vDSP_dotpr` for the weighted sum and `vDSP_sve` for the
    /// total magnitude.
    private func computeSpectralCentroid(_ magnitudes: [Float]) -> Float {
        let halfSize = magnitudes.count

        // Build frequency vector: [0 * binWidth, 1 * binWidth, ...]
        var frequencies = [Float](repeating: 0, count: halfSize)
        for i in 0..<halfSize {
            frequencies[i] = Float(i) * binWidth
        }

        // Weighted sum: sum(freq * magnitude)
        var weightedSum: Float = 0
        vDSP_dotpr(
            frequencies, 1,
            magnitudes, 1,
            &weightedSum,
            vDSP_Length(halfSize)
        )

        // Total magnitude
        var totalMag: Float = 0
        vDSP_sve(magnitudes, 1, &totalMag, vDSP_Length(halfSize))

        guard totalMag > 0 else { return 0 }
        return weightedSum / totalMag
    }

    // MARK: - Spectral Rolloff

    /// Computes the spectral rolloff frequency -- the frequency bin below
    /// which `rolloffPercentile` (e.g. 85%) of the total spectral energy
    /// is concentrated.
    ///
    /// Iterates through a cumulative sum of magnitudes to find the bin.
    private func computeSpectralRolloff(_ magnitudes: [Float]) -> Float {
        let halfSize = magnitudes.count

        // Total energy
        var totalEnergy: Float = 0
        vDSP_sve(magnitudes, 1, &totalEnergy, vDSP_Length(halfSize))

        guard totalEnergy > 0 else { return 0 }

        let threshold = totalEnergy * rolloffPercentile
        var cumulative: Float = 0

        for i in 0..<halfSize {
            cumulative += magnitudes[i]
            if cumulative >= threshold {
                return Float(i) * binWidth
            }
        }

        // If we never reached the threshold, return Nyquist
        return Float(halfSize) * binWidth
    }

    // MARK: - Spectral Flux

    /// Computes the spectral flux between the current and previous magnitude
    /// spectra. Flux measures onset strength as the sum of positive
    /// (half-wave rectified) magnitude differences.
    ///
    /// Uses `vDSP_vsub` for element-wise subtraction, `vDSP_vthres` for
    /// half-wave rectification (clamping negatives to zero), and `vDSP_sve`
    /// for the final summation.
    private func computeSpectralFlux(
        _ magnitudes: [Float],
        previous: [Float]?
    ) -> Float {
        guard let previous = previous,
              previous.count == magnitudes.count else {
            return 0
        }

        let halfSize = magnitudes.count

        // diff = magnitudes - previous
        var diff = [Float](repeating: 0, count: halfSize)
        vDSP_vsub(previous, 1, magnitudes, 1, &diff, 1, vDSP_Length(halfSize))

        // Half-wave rectify: clamp negative values to zero
        var zero: Float = 0
        vDSP_vthres(diff, 1, &zero, &diff, 1, vDSP_Length(halfSize))

        // Sum the rectified differences
        var flux: Float = 0
        vDSP_sve(diff, 1, &flux, vDSP_Length(halfSize))

        return flux
    }

    // MARK: - MFCCs

    /// Computes mel-frequency cepstral coefficients from a magnitude spectrum.
    ///
    /// Pipeline:
    /// 1. Apply mel filterbank to get mel-band energies.
    /// 2. Take the natural log of each band energy (with floor to avoid log(0)).
    /// 3. Apply a type-II DCT to decorrelate the log-mel energies.
    /// 4. Return coefficients 1 through `numMFCCs` (c0 is energy, excluded).
    private func computeMFCCs(_ magnitudes: [Float]) -> [Float] {
        // Step 1: Mel filterbank
        let melEnergies = melFilterbank.apply(to: magnitudes)

        // Step 2: Log of mel energies (floor to avoid log(0))
        let logMelEnergies = melEnergies.map { value -> Float in
            return logf(max(value, Self.logFloor))
        }

        // Step 3: DCT-II to produce cepstral coefficients
        guard let dct = dctTransform else {
            return [Float](repeating: 0, count: numMFCCs)
        }

        let cepstralCoeffs = dct.transform(logMelEnergies)

        // Step 4: Return coefficients 1 through numMFCCs (skip c0)
        let endIndex = min(numMFCCs + 1, cepstralCoeffs.count)
        guard endIndex > 1 else {
            return [Float](repeating: 0, count: numMFCCs)
        }

        return Array(cepstralCoeffs[1..<endIndex])
    }
}

#endif
