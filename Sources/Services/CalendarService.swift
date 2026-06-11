import EventKit
import Foundation

/// Wraps a single `EKEventStore`. EventKit types (`EKEvent`/`EKCalendar`/`EKParticipant`) are
/// not `Sendable`, so this stays on the main actor and only ever hands back the Sendable DTOs
/// in `CalendarModels.swift`.
@MainActor
final class CalendarService {
    private let store = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var isAuthorized: Bool {
        authorizationStatus == .fullAccess
    }

    /// Prompts for (or confirms) full calendar access. Returns whether access was granted.
    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// All event calendars the user has configured in macOS (iCloud, Google, Exchange, …),
    /// sorted by account then title for a stable grouped display.
    func availableCalendars() -> [CalendarInfo] {
        store.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, sourceTitle: $0.source.title) }
            .sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }
    }

    /// Today's events from the enabled calendars, excluding events the current user declined,
    /// sorted by start time.
    func todayEvents(enabledIdentifiers: Set<String>) -> [CalendarEventInfo] {
        guard isAuthorized else { return [] }

        let calendars = store.calendars(for: .event).filter { enabledIdentifiers.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }

        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
            .filter { event in
                let attendees = (event.attendees ?? []).map {
                    CalendarAttendee(isCurrentUser: $0.isCurrentUser, isDeclined: $0.participantStatus == .declined)
                }
                return !currentUserDeclined(attendees)
            }
            .map { event in
                CalendarEventInfo(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "(No title)",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title
                )
            }
            .sorted { $0.start < $1.start }
    }
}
