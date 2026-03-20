//
//  FFTProcessor.swift
//  Resonance
//
//  Shared FFT utility that extracts the duplicated FFT boilerplate from
//  AudioAnalyzer, VocalDetector, and RealtimeBPMVerifier into a single
//  reusable component.
//
//  Pre-allocates working buffers (window, windowed samples, split-complex
//  real/imag parts) so callers avoid per-frame allocation overhead.
//
//  Uses vDSP/Accelerate for efficient FFT computation with Hann windowing.
//

#if os(iOS)

import Accelerate
import Foundation

// MARK: - FFT Processor

/// Reusable FFT processor that pre-allocates buffers and provides magnitude
/// spectrum computation from raw audio samples.
///
/// Pre-allocates working buffers (window, windowed samples, split-complex
/// real/imag parts) so callers avoid per-frame allocation overhead.
///
/// - Important: This class holds mutable working buffers. Callers must
///   ensure that `computeMagnitudes` is not invoked concurrently from
///   multiple threads. For concurrent use, create one instance per thread.
internal final class FFTProcessor {

    // MARK: - Constants

    /// Default FFT frame size.
    private static let defaultFFTSize: Int = 2048

    // MARK: - Configuration

    /// Number of samples per FFT frame (must be a power of 2).
    internal let fftSize: Int

    /// Half the FFT size; number of unique frequency bins.
    internal let halfSize: Int

    /// log2 of fftSize, required by vDSP FFT routines.
    private let log2n: vDSP_Length

    // MARK: - Pre-allocated Buffers

    /// Hann window coefficients, computed once at init.
    private var window: [Float]

    /// Scratch buffer for windowed input samples.
    private var windowedBuffer: [Float]

    /// Real part of the split-complex representation.
    private var realPart: [Float]

    /// Imaginary part of the split-complex representation.
    private var imagPart: [Float]

    /// Pre-allocated buffer for magnitude output, reused across calls.
    private var magnitudesBuffer: [Float]

    /// vDSP FFT setup object (opaque, reusable).
    private let fftSetup: FFTSetup

    // MARK: - Initialization

    /// Creates an FFT processor with the given frame size.
    ///
    /// - Parameter fftSize: Number of samples per FFT frame. Must be a power
    ///   of 2. Defaults to 2048.
    /// - Returns: `nil` if `fftSize` is not a positive power of 2 or if
    ///   the vDSP FFT setup cannot be created.
    init?(fftSize: Int = FFTProcessor.defaultFFTSize) {
        guard fftSize > 0, fftSize & (fftSize - 1) == 0 else { return nil }

        self.fftSize = fftSize
        self.halfSize = fftSize / 2
        self.log2n = vDSP_Length(Int(log2(Double(fftSize))))

        guard let setup = vDSP_create_fftsetup(
            vDSP_Length(Int(log2(Double(fftSize)))),
            FFTRadix(kFFTRadix2)
        ) else {
            return nil
        }
        self.fftSetup = setup

        // Pre-allocate all working buffers
        self.window = [Float](repeating: 0, count: fftSize)
        self.windowedBuffer = [Float](repeating: 0, count: fftSize)
        self.realPart = [Float](repeating: 0, count: fftSize / 2)
        self.imagPart = [Float](repeating: 0, count: fftSize / 2)
        self.magnitudesBuffer = [Float](repeating: 0, count: fftSize / 2)

        // Compute Hann window once
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - Public API

    /// Computes the magnitude spectrum of a single FFT frame starting at the
    /// given offset in the input data.
    ///
    /// - Parameters:
    ///   - data: Pointer to raw float audio samples. The caller must ensure
    ///     at least `offset + fftSize` samples are accessible.
    ///   - offset: Sample index at which the frame begins.
    /// - Returns: Array of `halfSize` magnitude-squared values, one per
    ///   frequency bin. Returns a copy so callers own the data.
    internal func computeMagnitudes(_ data: UnsafePointer<Float>, offset: Int) -> [Float]? {
        // Apply Hann window to the frame
        vDSP_vmul(
            data.advanced(by: offset), 1,
            window, 1,
            &windowedBuffer, 1,
            vDSP_Length(fftSize)
        )

        // Pack windowed samples into split-complex form for vDSP_fft_zrip:
        // even-indexed samples -> realp, odd-indexed samples -> imagp.
        for i in 0..<halfSize {
            realPart[i] = windowedBuffer[2 * i]
            imagPart[i] = windowedBuffer[2 * i + 1]
        }

        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

        // Forward FFT (in-place)
        vDSP_fft_zrip(
            fftSetup, &splitComplex, 1,
            log2n, FFTDirection(FFT_FORWARD)
        )

        // Compute squared magnitudes into the pre-allocated buffer
        vDSP_zvmags(&splitComplex, 1, &magnitudesBuffer, 1, vDSP_Length(halfSize))

        // Return a copy so callers own the data and the buffer can be reused
        return Array(magnitudesBuffer)
    }
}

#endif
