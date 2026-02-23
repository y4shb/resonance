//
//  TimeInterval+Formatting.swift
//  Resonance
//
//  Shared formatting utilities for TimeInterval
//

import Foundation

extension TimeInterval {
    /// Formats the time interval as "m:ss" (e.g. "3:07").
    /// Negative or non-finite values are treated as 0.
    var formattedMinutesSeconds: String {
        let totalSeconds = Int(max(0, self.isFinite ? self : 0))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
