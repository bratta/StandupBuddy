import Foundation

/// A calendar available to the app via EventKit, flattened to a Sendable value so it can
/// cross actor boundaries (EKCalendar is not Sendable).
struct CalendarInfo: Identifiable, Sendable, Hashable {
    let id: String          // EKCalendar.calendarIdentifier
    let title: String
    let sourceTitle: String // EKCalendar.source.title — e.g. "Google", "iCloud", "On My Mac"
}

/// A single calendar event, flattened to a Sendable value.
struct CalendarEventInfo: Identifiable, Sendable, Hashable {
    let id: String          // EKEvent.eventIdentifier
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarTitle: String
}

/// A calendar attendee reduced to the two facts we need to decide whether the current user
/// declined an event. Pure value type so the filtering rule is unit-testable without EventKit.
struct CalendarAttendee: Sendable, Hashable {
    let isCurrentUser: Bool
    let isDeclined: Bool
}

/// True when the current user has declined the event (RSVP = declined).
func currentUserDeclined(_ attendees: [CalendarAttendee]) -> Bool {
    attendees.contains { $0.isCurrentUser && $0.isDeclined }
}

/// Encoding/decoding of the user's enabled-calendar selection, stored as a JSON array string
/// in the `setting` table.
enum EnabledCalendars {
    /// Decode the persisted selection. An empty/blank string means "never chosen" and defaults
    /// to every available calendar so import works out of the box. A non-empty value (even
    /// "[]") is an explicit choice and is respected verbatim.
    static func decode(_ json: String, available: [String]) -> Set<String> {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Set(available) }
        guard let data = trimmed.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return Set(available)
        }
        return Set(ids)
    }

    /// Encode the selection as a sorted JSON array string for stable persistence.
    static func encode(_ ids: Set<String>) -> String {
        let sorted = ids.sorted()
        guard let data = try? JSONEncoder().encode(sorted),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
