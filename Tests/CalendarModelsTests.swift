import Testing
import Foundation
@testable import StandupBuddy

@Suite("Calendar declined filter")
struct CalendarDeclinedFilterTests {
    @Test("Declined when current user's RSVP is declined")
    func currentUserDeclined_true() {
        let attendees = [
            CalendarAttendee(isCurrentUser: false, isDeclined: true),
            CalendarAttendee(isCurrentUser: true, isDeclined: true),
        ]
        #expect(currentUserDeclined(attendees) == true)
    }

    @Test("Not declined when current user accepted")
    func currentUserDeclined_falseWhenAccepted() {
        let attendees = [
            CalendarAttendee(isCurrentUser: true, isDeclined: false),
            CalendarAttendee(isCurrentUser: false, isDeclined: true),
        ]
        #expect(currentUserDeclined(attendees) == false)
    }

    @Test("Not declined when current user not among attendees")
    func currentUserDeclined_falseWhenNoCurrentUser() {
        let attendees = [
            CalendarAttendee(isCurrentUser: false, isDeclined: true),
        ]
        #expect(currentUserDeclined(attendees) == false)
    }

    @Test("Not declined for an event with no attendees")
    func currentUserDeclined_falseWhenEmpty() {
        #expect(currentUserDeclined([]) == false)
    }
}

@Suite("Enabled calendars persistence")
struct EnabledCalendarsTests {
    @Test("Empty string defaults to all available calendars")
    func decode_emptyMeansAll() {
        let result = EnabledCalendars.decode("", available: ["a", "b", "c"])
        #expect(result == Set(["a", "b", "c"]))
    }

    @Test("Whitespace-only string defaults to all available calendars")
    func decode_blankMeansAll() {
        let result = EnabledCalendars.decode("   \n", available: ["a", "b"])
        #expect(result == Set(["a", "b"]))
    }

    @Test("Explicit empty array means none selected")
    func decode_emptyArrayMeansNone() {
        let result = EnabledCalendars.decode("[]", available: ["a", "b"])
        #expect(result.isEmpty)
    }

    @Test("Explicit selection is respected verbatim")
    func decode_explicitSelection() {
        let result = EnabledCalendars.decode("[\"a\",\"c\"]", available: ["a", "b", "c"])
        #expect(result == Set(["a", "c"]))
    }

    @Test("Malformed JSON falls back to all available calendars")
    func decode_malformedFallsBackToAll() {
        let result = EnabledCalendars.decode("not json", available: ["a", "b"])
        #expect(result == Set(["a", "b"]))
    }

    @Test("Encode/decode round-trips a selection")
    func encodeDecode_roundTrip() {
        let ids: Set<String> = ["x", "y", "z"]
        let json = EnabledCalendars.encode(ids)
        let decoded = EnabledCalendars.decode(json, available: ["x", "y", "z", "w"])
        #expect(decoded == ids)
    }

    @Test("Encode produces a sorted array for stable persistence")
    func encode_isSorted() {
        let json = EnabledCalendars.encode(["c", "a", "b"])
        #expect(json == "[\"a\",\"b\",\"c\"]")
    }
}
