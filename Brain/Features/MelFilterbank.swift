//
//  MelFilterbank.swift
//  Resonance
//
//  Pre-computed mel-scale triangular filterbank for MFCC extraction.
//  Converts a linear-frequency magnitude spectrum into mel-frequency
//  band energies using overlapping triangular filters spaced uniformly
//  on the mel scale.
//
//  Mel scale: mel = 2595 * log10(1 + hz / 700)
//  Inverse:    hz = 700 * (10^(mel / 2595) - 1)
//
//  Uses vDSP_dotpr for efficient per-filter dot products.
//

#if os(iOS)

import Accelerate
import Foundation

// MARK: - Mel Filterbank

/// A pre-computed mel-scale triangular filterbank.
///
/// Initialisation builds `numFilters` triangular filters whose center
/// frequencies are evenly spaced on the mel scale between 0 Hz and
/// `sampleRate / 2`. Calling `apply(to:)` projects a magnitude spectrum
/// onto these filters, producing mel-frequency band energies suitable
/// for MFCC computation.
///
/// - Note: Filter weights are computed once at init and reused for all
///   subsequent `apply(to:)` calls.
internal final class MelFilterbank {

    // MARK: - Constants

    /// Mel scale conversion constant (Hz reference frequency).
    private static let melReferenceHz: Double = 700.0

    /// Mel scale conversion constant (logarithmic scaling factor).
    private static let melScaleFactor: Double = 2595.0

    /// Default number of triangular mel filters.
    private static let defaultNumFilters: Int = 26

    // MARK: - Properties

    /// Number of triangular mel filters.
    internal let numFilters: Int

    /// Number of unique FFT magnitude bins (fftSize / 2).
    private let numBins: Int

    /// Filter weights stored as an array of arrays.
    /// Each inner array has `numBins` elements (one weight per FFT bin).
    private let filters: [[Float]]

    // MARK: - Mel Scale Conversions

    /// Converts a frequency in Hz to the mel scale.
    ///
    /// - Parameter hz: Frequency in Hertz.
    /// - Returns: Corresponding mel-scale value.
    private static func hzToMel(_ hz: Double) -> Double {
        return melScaleFactor * log10(1.0 + hz / melReferenceHz)
    }

    /// Converts a mel-scale value back to Hz.
    ///
    /// - Parameter mel: Mel-scale value.
    /// - Returns: Corresponding frequency in Hertz.
    private static func melToHz(_ mel: Double) -> Double {
        return melReferenceHz * (pow(10.0, mel / melScaleFactor) - 1.0)
    }

    // MARK: - Initialization

    /// Creates a mel filterbank with pre-computed triangular filter weights.
    ///
    /// - Parameters:
    ///   - fftSize: The FFT size used to produce the magnitude spectrum.
    ///   - sampleRate: Audio sample rate in Hz.
    ///   - numFilters: Number of triangular mel filters. Defaults to 26.
    init(fftSize: Int, sampleRate: Double, numFilters: Int = MelFilterbank.defaultNumFilters) {
        self.numFilters = numFilters
        self.numBins = fftSize / 2

        let melLow = MelFilterbank.hzToMel(0.0)
        let melHigh = MelFilterbank.hzToMel(sampleRate / 2.0)

        // Compute numFilters + 2 evenly spaced mel points
        // (extra 2 for the left edge of the first filter and right edge of the last)
        let numPoints = numFilters + 2
        var melPoints = [Double](repeating: 0, count: numPoints)
        let melStep = (melHigh - melLow) / Double(numPoints - 1)

        for i in 0..<numPoints {
            melPoints[i] = melLow + Double(i) * melStep
        }

        // Convert mel points to FFT bin indices
        let binWidth = sampleRate / Double(fftSize)
        var binIndices = [Int](repeating: 0, count: numPoints)

        for i in 0..<numPoints {
            let hz = MelFilterbank.melToHz(melPoints[i])
            binIndices[i] = Int(floor(hz / binWidth))
        }

        // Build triangular filters
        var builtFilters = [[Float]]()
        builtFilters.reserveCapacity(numFilters)

        for m in 0..<numFilters {
            var filter = [Float](repeating: 0, count: fftSize / 2)

            let left = binIndices[m]
            let center = binIndices[m + 1]
            let right = binIndices[m + 2]

            // Rising slope: left -> center
            if center > left {
                for k in left...center where k < fftSize / 2 {
                    filter[k] = Float(k - left) / Float(center - left)
                }
            }

            // Falling slope: center -> right
            if right > center {
                for k in center...right where k < fftSize / 2 {
                    filter[k] = Float(right - k) / Float(right - center)
                }
            }

            builtFilters.append(filter)
        }

        self.filters = builtFilters
    }

    // MARK: - Apply Filterbank

    /// Projects a magnitude spectrum onto the mel filterbank.
    ///
    /// Uses `vDSP_dotpr` for efficient per-filter dot products.
    ///
    /// - Parameter magnitudes: Squared magnitude spectrum with `numBins`
    ///   elements (output of `FFTProcessor.computeMagnitudes`).
    /// - Returns: Array of `numFilters` mel-band energies. Returns zeros
    ///   if `magnitudes` has fewer than `numBins` elements.
    internal func apply(to magnitudes: [Float]) -> [Float] {
        guard magnitudes.count >= numBins else {
            return [Float](repeating: 0, count: numFilters)
        }

        var melEnergies = [Float](repeating: 0, count: numFilters)

        for m in 0..<numFilters {
            var energy: Float = 0
            vDSP_dotpr(
                magnitudes, 1,
                filters[m], 1,
                &energy,
                vDSP_Length(numBins)
            )
            melEnergies[m] = energy
        }

        return melEnergies
    }
}

#endif
