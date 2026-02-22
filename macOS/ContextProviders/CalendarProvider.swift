//
//  CalendarProvider.swift
//  ResonanceMac
//
//  Reads EventKit calendar data to detect ongoing meetings
//  and upcoming events for context inference.
//

#if os(macOS)

import Foundation
import EventKit
import Combine

/// Provides calendar event context from macOS Calendar.
final class CalendarProvider: ObservableObject {

    @Published private(set) var hasOngoingMeeting: Bool = false
    @Published private(set) var minutesUntilNextEvent: Double?
    @Published private(set) var nextEventType: CalendarEventType?

    private let eventStore = EKEventStore()
    private var pollTimer: Timer?
    private var isAuthorized = false

    init() {
        logInfo("CalendarProvider initialized", category: .general)
    }

    deinit {
        pollTimer?.invalidate()
    }

    /// Requests calendar access and starts polling.
    func startMonitoring() {
        Task {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    self.isAuthorized = granted
                    if granted {
                        self.refreshCalendarState()
                        self.pollTimer = Timer.scheduledTimer(
                            withTimeInterval: 60,
                            repeats: true
                        ) { [weak self] _ in
                            self?.refreshCalendarState()
                        }
                        logInfo("CalendarProvider: access granted, monitoring started", category: .general)
                    } else {
                        logWarning("CalendarProvider: calendar access denied", category: .general)
                    }
                }
            } catch {
                logError("CalendarProvider: failed to request access", error: error, category: .general)
            }
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Private

    private func refreshCalendarState() {
        guard isAuthorized else { return }

        let now = Date()
        let lookAheadEnd = Calendar.current.date(byAdding: .hour, value: 2, to: now)!

        let predicate = eventStore.predicateForEvents(
            withStart: now.addingTimeInterval(-300), // 5 min ago (catch ongoing)
            end: lookAheadEnd,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        // Check for ongoing event
        let ongoing = events.first { event in
            event.startDate <= now && event.endDate > now
        }
        hasOngoingMeeting = ongoing != nil

        // Find next upcoming event
        let upcoming = events.first { $0.startDate > now }
        if let next = upcoming {
            minutesUntilNextEvent = next.startDate.timeIntervalSince(now) / 60.0
            nextEventType = classifyEvent(next)
        } else {
            minutesUntilNextEvent = nil
            nextEventType = nil
        }
    }

    private func classifyEvent(_ event: EKEvent) -> CalendarEventType {
        let title = event.title?.lowercased() ?? ""

        if title.contains("meeting") || title.contains("call") ||
           title.contains("sync") || title.contains("standup") ||
           title.contains("1:1") || title.contains("interview") {
            return .meeting
        }

        if title.contains("focus") || title.contains("deep work") ||
           title.contains("blocked") || title.contains("heads down") {
            return .focus
        }

        if event.isAllDay {
            return .allDay
        }

        if event.hasAlarms {
            return .reminder
        }

        return .personal
    }
}

#endif
