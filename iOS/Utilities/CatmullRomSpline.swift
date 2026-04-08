//
//  CatmullRomSpline.swift
//  Resonance
//
//  Shared Catmull-Rom spline interpolation used by MoodForecastView,
//  ForecastPreviewArc, and MoodTrajectoryOverlayView for smooth curve
//  rendering through discrete control points.
//

#if os(iOS)
import CoreGraphics

// MARK: - Catmull-Rom Spline

/// Utility for generating smooth curves through discrete control points.
enum CatmullRomSpline {

    /// Generates smooth curve points using Catmull-Rom spline interpolation.
    ///
    /// - Parameters:
    ///   - controlPoints: The original points the curve must pass through.
    ///   - granularity: Number of interpolated points between each control point pair.
    /// - Returns: A dense array of points forming a smooth curve.
    static func interpolate(
        through controlPoints: [CGPoint],
        granularity: Int = 20
    ) -> [CGPoint] {
        guard controlPoints.count >= 2 else { return controlPoints }

        var result: [CGPoint] = []

        for i in 0..<controlPoints.count - 1 {
            let p0 = i > 0 ? controlPoints[i - 1] : controlPoints[i]
            let p1 = controlPoints[i]
            let p2 = controlPoints[i + 1]
            let p3 = i + 2 < controlPoints.count ? controlPoints[i + 2] : controlPoints[i + 1]

            for t in 0..<granularity {
                let tNorm = CGFloat(t) / CGFloat(granularity)
                let point = evaluate(p0: p0, p1: p1, p2: p2, p3: p3, t: tNorm)
                result.append(point)
            }
        }

        // Add the final point
        if let last = controlPoints.last {
            result.append(last)
        }

        return result
    }

    /// Evaluates a single point on a Catmull-Rom spline segment.
    ///
    /// - Parameters:
    ///   - p0: Point before the segment start.
    ///   - p1: Segment start point.
    ///   - p2: Segment end point.
    ///   - p3: Point after the segment end.
    ///   - t: Interpolation parameter (0.0 to 1.0).
    /// - Returns: The interpolated point on the curve.
    static func evaluate(
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        let x = 0.5 * (
            (2.0 * p1.x) +
            (-p0.x + p2.x) * t +
            (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 +
            (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3
        )

        let y = 0.5 * (
            (2.0 * p1.y) +
            (-p0.y + p2.y) * t +
            (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 +
            (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3
        )

        return CGPoint(x: x, y: y)
    }
}
#endif
