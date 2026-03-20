//
//  CircadianContextInference.swift
//  Resonance
//
//  Extension on CircadianProfileManager providing circadian-aware activity
//  context inference. Replaces static hour boundaries with the user's learned
//  wake/sleep landmarks to determine morning, pre-sleep, commute, work, and
//  relaxation contexts.
//

import Foundation

// MARK: - Circadian Context Inference

extension CircadianProfileManager {

    /// Infers an activity context based on the user's learned circadian landmarks
    /// (typicalWakeHour, typicalSleepHour) rather than hardcoded hour boundaries.
    ///
    /// - Parameters:
    ///   - hour: Current hour of day (0-23).
    ///   - isWeekend: Whether today is a weekend day.
    /// - Returns: The inferred ActivityContext.
    func circadianActivityContext(forHour hour: Int, isWeekend: Bool) -> ActivityContext {
        guard let profile = currentProfile, profile.isMature else {
            // Fall back to static inference when the profile is not yet mature
            return staticActivityContext(forHour: hour, isWeekend: isWeekend)
        }

        let wakeHour = profile.typicalWakeHour
        let sleepHour = profile.typicalSleepHour
        let preSleepStart = (sleepHour - CircadianConstants.preSleepLeadHours + 24) % 24
        let morningEnd = (wakeHour + CircadianConstants.morningWindowHours) % 24

        // Pre-sleep: within 2 hours of typical sleep time, or after sleep hour
        if hoursBetween(hour, sleepHour) <= CircadianConstants.preSleepLeadHours
            && isHourInRange(hour, from: preSleepStart, to: sleepHour) {
            return .preSleep
        }

        // Sleeping hours: between sleep and wake
        if isHourInRange(hour, from: sleepHour, to: wakeHour) {
            return .preSleep
        }

        // Morning: first 2 hours after wake
        if isHourInRange(hour, from: wakeHour, to: morningEnd) {
            return .morning
        }

        // Commute windows (weekdays only): 1-2 hours after morning, and 1-2 hours before pre-sleep
        if !isWeekend {
            let commuteAMStart = morningEnd
            let commuteAMEnd = (morningEnd + 2) % 24
            if isHourInRange(hour, from: commuteAMStart, to: commuteAMEnd) {
                return .commute
            }

            let commutePMStart = (preSleepStart - 2 + 24) % 24
            let commutePMEnd = preSleepStart
            if isHourInRange(hour, from: commutePMStart, to: commutePMEnd) {
                return .commute
            }
        }

        // Work hours (weekdays) or relaxation (weekends)
        if isWeekend {
            return .relaxation
        } else {
            return .work
        }
    }

    /// Static (non-personalized) activity context, matching the original
    /// inferContextFromTimeOfDay behavior. Used as a fallback when the
    /// circadian profile is not yet mature.
    private func staticActivityContext(forHour hour: Int, isWeekend: Bool) -> ActivityContext {
        if hour >= 22 || hour < 5 {
            return .preSleep
        }
        if hour >= 5 && hour < 7 {
            return .morning
        }
        if hour >= 7 && hour < 9 {
            return isWeekend ? .morning : .commute
        }
        if hour >= 9 && hour < 17 {
            return isWeekend ? .relaxation : .work
        }
        if hour >= 17 && hour < 19 {
            return isWeekend ? .relaxation : .commute
        }
        // 19:00-22:00
        return .relaxation
    }

    // MARK: - Circular Hour Helpers

    /// Calculates the shortest distance between two hours on a 24-hour clock.
    /// For example, hoursBetween(23, 1) returns 2, hoursBetween(1, 23) returns 2.
    func hoursBetween(_ h1: Int, _ h2: Int) -> Int {
        let diff = abs(h1 - h2)
        return min(diff, 24 - diff)
    }

    /// Checks whether `hour` falls within the circular range [from, to).
    /// Handles midnight crossing. For example, isHourInRange(23, from: 22, to: 2) is true.
    private func isHourInRange(_ hour: Int, from: Int, to: Int) -> Bool {
        if from <= to {
            return hour >= from && hour < to
        } else {
            // Range crosses midnight
            return hour >= from || hour < to
        }
    }
}
