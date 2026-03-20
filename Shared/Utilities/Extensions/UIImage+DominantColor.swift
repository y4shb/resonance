//
//  UIImage+DominantColor.swift
//  Resonance
//
//  Extracts the dominant color from a UIImage for UI accent tinting.
//  Uses Core Graphics pixel sampling for efficient on-device analysis.
//

#if canImport(UIKit)
import UIKit

extension UIImage {
    /// Extracts the dominant color from the image by sampling pixels.
    /// Returns nil if the image cannot be analyzed.
    func dominantColor() -> UIColor? {
        // Scale down to a tiny image for fast analysis
        let targetSize = CGSize(width: 10, height: 10)
        guard let cgImage = resized(to: targetSize)?.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        guard totalPixels > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: totalPixels * bytesPerPixel)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &pixelData,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Accumulate color channels, skipping very dark and very light pixels
        var rTotal: CGFloat = 0
        var gTotal: CGFloat = 0
        var bTotal: CGFloat = 0
        var count: CGFloat = 0

        for i in 0..<totalPixels {
            let offset = i * bytesPerPixel
            let r = CGFloat(pixelData[offset]) / 255.0
            let g = CGFloat(pixelData[offset + 1]) / 255.0
            let b = CGFloat(pixelData[offset + 2]) / 255.0

            // Skip near-black and near-white pixels
            let brightness = (r + g + b) / 3.0
            if brightness < 0.1 || brightness > 0.9 { continue }

            // Skip very desaturated pixels (grays)
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
            if saturation < 0.15 { continue }

            rTotal += r
            gTotal += g
            bTotal += b
            count += 1
        }

        guard count > 0 else {
            // Fallback: average all pixels if no colorful ones found
            for i in 0..<totalPixels {
                let offset = i * bytesPerPixel
                rTotal += CGFloat(pixelData[offset]) / 255.0
                gTotal += CGFloat(pixelData[offset + 1]) / 255.0
                bTotal += CGFloat(pixelData[offset + 2]) / 255.0
            }
            count = CGFloat(totalPixels)
            guard count > 0 else { return nil }
            return UIColor(red: rTotal / count, green: gTotal / count, blue: bTotal / count, alpha: 1.0)
        }

        return UIColor(red: rTotal / count, green: gTotal / count, blue: bTotal / count, alpha: 1.0)
    }

    /// Resizes the image to the given size.
    private func resized(to targetSize: CGSize) -> UIImage? {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        guard let cgImage = self.cgImage,
              let colorSpace = cgImage.colorSpace,
              let ctx = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        guard let resizedCG = ctx.makeImage() else { return nil }
        return UIImage(cgImage: resizedCG)
    }
}
#endif
