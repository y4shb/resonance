//
//  CalendarContextService.swift
//  Resonance
//
//  Reads upcoming calendar events via EventKit and provides context shifts
//  for the AI DJ: ramp-up before meetings, recovery after, and deep work
//  suggestions during free blocks. Polls every 60 seconds.
//
//  Does NOT override biometric signals — nudges energy/focus via
//  ContextCollector.pendingCalendarShift, which StateEngine reads
//  during synthesizeStateVector().
//

#if os(iOS)

import EventKit
import Foundation
import Observation

// MARK: - Calendar Context Shift

/// Describes an upcoming or recent calendar-driven context change.
struct CalendarContextShift: Sendable {
    enum Kind: Sendable {
        /// 15 minutes before a meeting: ramp focus and energy
        case focusRampUp
        /// 5 minutes after a long meeting: shift to recovery
        case recovery
        /// 2+ hour free block detected: suggest deep work session
        case deepWorkSuggestion
    }

    let kind: Kind
    let eventTitle: String?
    let minutesUntil: Int?
}

// MARK: - Calendar Context Service

/// Monitors the user's calendar and publishes context shifts that influence
/// the AI DJ's song selection. Uses EKEventStore with 60-second polling.
///
/// Permission: requires NSCalendarsFullAccessUsageDescription in Info.plist.
/// Request access via `requestAccessAndStart()` — typically called on first
/// session start, not at cold launch.
@MainActor
@Observable
final class CalendarContextService {

    // MARK: - Published State

    /// The current calendar-derived context shift, if any.
    private(set) var upcomingShift: CalendarContextShift?

    /// Whether calendar access has been granted.
    private(set) var isAuthorized = false

    // MARK: - Private State

    private let store = EKEventStore()
    nonisolated(unsafe) private var pollTask: Task<Void, Never>?

    /// Timestamp of the last meeting end, for recovery detection.
    private var lastMeetingEndTime: Date?

    // MARK: - Constants

    /// Minutes before a meeting to trigger focus ramp-up.
    private let rampUpMinutes = 15.0

    /// Minutes after a meeting to trigger recovery mode.
    private let recoveryMinutes = 5.0

    /// Minimum free block duration (hours) to suggest deep work.
    private let deepWorkMinimumHours = 2.0

    /// Polling interval in seconds.
    private let pollInterval: TimeInterval = 60

    // MARK: - Lifecycle

    deinit {
        pollTask?.cancel()
    }

    // MARK: - Public API

    /// Requests EventKit access and starts the polling loop.
    func requestAccessAndStart() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            isAuthorized = granted
            if granted {
                startPolling()
                logInfo("CalendarContextService: access granted, polling started", category: .general)
            } else {
                logWarning("CalendarContextService: calendar access denied", category: .general)
            }
        } catch {
            logError("CalendarContextService: access request failed", error: error, category: .general)
        }
    }

    /// Stops the polling loop.
    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.evaluate()
                try? await Task.sleep(for: .seconds(self?.pollInterval ?? 60))
            }
        }
    }

    // MARK: - Evaluation

    private func evaluate() {
        let now = Date()

        // Check for upcoming meetings (within rampUpMinutes)
        let lookahead = now.addingTimeInterval(rampUpMinutes * 60 + 5 * 60) // 20 min window
        let predicate = store.predicateForEvents(
            withStart: now, end: lookahead, calendars: nil
        )
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }

        // Priority 1: Focus ramp-up before an upcoming meeting
        if let next = events.first {
            let minutesAway = next.startDate.timeIntervalSince(now) / 60

            if minutesAway <= rampUpMinutes {
                upcomingShift = CalendarContextShift(
                    kind: .focusRampUp,
                    eventTitle: next.title,
                    minutesUntil: Int(minutesAway)
                )
                return
            }
        }

        // Priority 2: Recovery after a meeting ended recently
        if let meetingEnd = lastMeetingEndTime {
            let minutesSinceEnd = now.timeIntervalSince(meetingEnd) / 60
            if minutesSinceEnd <= recoveryMinutes {
                upcomingShift = CalendarContextShift(
                    kind: .recovery,
                    eventTitle: nil,
                    minutesUntil: nil
                )
                return
            }
        }

        // Track meetings that just ended
        let recentPredicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-10 * 60), end: now, calendars: nil
        )
        let recentEvents = store.events(matching: recentPredicate)
            .filter { !$0.isAllDay && $0.endDate <= now && $0.endDate > now.addingTimeInterval(-recoveryMinutes * 60) }

        if let justEnded = recentEvents.last {
            // Only trigger recovery for meetings that lasted > 15 minutes
            let meetingDuration = justEnded.endDate.timeIntervalSince(justEnded.startDate) / 60
            if meetingDuration > 15 {
                lastMeetingEndTime = justEnded.endDate
                upcomingShift = CalendarContextShift(
                    kind: .recovery,
                    eventTitle: justEnded.title,
                    minutesUntil: nil
                )
                return
            }
        }

        // Priority 3: Deep work suggestion when 2+ hour free block exists
        let deepWorkLookahead = now.addingTimeInterval(3 * 3600)
        let deepPredicate = store.predicateForEvents(
            withStart: now, end: deepWorkLookahead, calendars: nil
        )
        let upcomingEvents = store.events(matching: deepPredicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        if let nextEvent = upcomingEvents.first {
            let hoursUntil = nextEvent.startDate.timeIntervalSince(now) / 3600
            if hoursUntil >= deepWorkMinimumHours {
                upcomingShift = CalendarContextShift(
                    kind: .deepWorkSuggestion,
                    eventTitle: nil,
                    minutesUntil: Int(hoursUntil * 60)
                )
                return
            }
        } else if upcomingEvents.isEmpty {
            // No events in the next 3 hours — suggest deep work
            upcomingShift = CalendarContextShift(
                kind: .deepWorkSuggestion,
                eventTitle: nil,
                minutesUntil: nil
            )
            return
        }

        // No shift detected
        upcomingShift = nil
    }

    // MARK: - Context Message for UI

    /// Returns a human-readable message for the explanation bar.
    var contextMessage: String? {
        guard let shift = upcomingShift else { return nil }
        switch shift.kind {
        case .focusRampUp:
            let title = shift.eventTitle ?? "your next meeting"
            let mins = shift.minutesUntil.map { " in \($0) min" } ?? ""
            return "Preparing you for \(title)\(mins)"
        case .recovery:
            return "Meeting just ended — shifting to recovery mode"
        case .deepWorkSuggestion:
            return "2+ hour free block — try a Deep Work session"
        }
    }
}

#endif
