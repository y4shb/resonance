//
//  DominantColorExtractor.swift
//  Resonance
//
//  Extracts the dominant color from album artwork using CoreImage's CIAreaAverage
//  filter for efficient GPU-accelerated analysis. Results are cached per song ID
//  to avoid recomputation on repeated access.
//
//  P2-21: Album Art Ambient Glow (color extraction component)
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - Dominant Color Extractor

/// Extracts and caches the dominant color from album artwork images.
///
/// Uses `CIAreaAverage` for GPU-accelerated color analysis, which is significantly
/// faster than manual pixel iteration for large images. Results are cached by a
/// caller-supplied key (typically the song's Apple Music ID) to avoid redundant
/// extraction when revisiting songs.
@MainActor
final class DominantColorExtractor {
    // MARK: - Singleton

    /// Shared extractor instance. Thread-safe via `@MainActor` isolation.
    static let shared = DominantColorExtractor()

    // MARK: - Cache

    /// Maps a cache key (e.g., Apple Music ID) to its extracted dominant color.
    private var cache: [String: Color] = [:]

    /// Maximum number of entries to retain in the cache.
    /// Older entries are evicted in FIFO order when exceeded.
    private let maxCacheSize = 50

    /// Insertion-ordered keys for FIFO eviction.
    private var cacheOrder: [String] = []

    /// CoreImage context reused across extractions for performance.
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Returns the cached dominant color for the given key, if available.
    func cachedColor(forKey key: String) -> Color? {
        cache[key]
    }

    /// Extracts the dominant color from a `UIImage`.
    ///
    /// - Parameters:
    ///   - image: The source image (typically album artwork).
    ///   - cacheKey: A stable identifier for caching (e.g., song Apple Music ID).
    /// - Returns: The dominant `Color`, or nil if extraction fails.
    func extractDominantColor(from image: UIImage, cacheKey: String) -> Color? {
        // Return cached result if available
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let ciImage = CIImage(image: image) else { return nil }

        let color = extractUsingAreaAverage(ciImage)
        if let color {
            storeInCache(color, forKey: cacheKey)
        }
        return color
    }

    /// Extracts the dominant color from raw image `Data`.
    ///
    /// - Parameters:
    ///   - data: The raw image data (JPEG, PNG, etc.).
    ///   - cacheKey: A stable identifier for caching.
    /// - Returns: The dominant `Color`, or nil if extraction fails.
    func extractDominantColor(from data: Data, cacheKey: String) -> Color? {
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let uiImage = UIImage(data: data) else { return nil }
        return extractDominantColor(from: uiImage, cacheKey: cacheKey)
    }

    /// Clears the entire color cache.
    func clearCache() {
        cache.removeAll()
        cacheOrder.removeAll()
    }

    // MARK: - Core Extraction

    /// Uses `CIAreaAverage` to compute a single average color for the entire image.
    /// This is GPU-accelerated via CoreImage and avoids per-pixel iteration.
    private func extractUsingAreaAverage(_ ciImage: CIImage) -> Color? {
        let extent = ciImage.extent

        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return nil }

        // The output is a single-pixel image; read its RGBA values.
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        )

        let red = Double(bitmap[0]) / 255.0
        let green = Double(bitmap[1]) / 255.0
        let blue = Double(bitmap[2]) / 255.0

        return Color(red: red, green: green, blue: blue)
    }

    // MARK: - Cache Management

    private func storeInCache(_ color: Color, forKey key: String) {
        // Evict oldest entry if at capacity
        if cache.count >= maxCacheSize, let oldest = cacheOrder.first {
            cache.removeValue(forKey: oldest)
            cacheOrder.removeFirst()
        }

        cache[key] = color
        // Only append if not already present (avoid duplicating on re-extraction)
        if !cacheOrder.contains(key) {
            cacheOrder.append(key)
        }
    }
}
