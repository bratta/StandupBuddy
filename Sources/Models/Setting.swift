import Foundation
import GRDB

struct Setting: Codable, Identifiable, Sendable {
    var id: String  // used as the primary key (the key name)
    var value: String

    init(id: String, value: String) {
        self.id = id
        self.value = value
    }
}

extension Setting: FetchableRecord, PersistableRecord {
    static let databaseTableName = "setting"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let value = Column(CodingKeys.value)
    }
}

extension Setting {
    static let dadJokeEnabledKey = "dadJokeEnabled"
    static let formatDateEnabledKey = "formatDateEnabled"
    static let yesterdayEnabledKey = "yesterdayEnabled"
    static let funFactEnabledKey = "funFactEnabled"
    static let affirmationEnabledKey = "affirmationEnabled"
    static let emojiOfDayEnabledKey = "emojiOfDayEnabled"
    static let entryDateEnabledKey = "entryDateEnabled"
    static let showCompletedEntriesKey = "showCompletedEntries"

    // Calendar import — JSON array of enabled EKCalendar identifiers (empty = all calendars)
    static let enabledCalendarIdentifiersKey = "enabledCalendarIdentifiers"

    // Section header templates (empty string = use built-in default)
    static let previousHeaderKey = "previousHeader"
    static let todayHeaderKey = "todayHeader"
    static let blockersHeaderKey = "blockersHeader"
    static let openPRsHeaderKey = "openPRsHeader"
    static let gratitudeHeaderKey = "gratitudeHeader"

    static let previousHeaderDefault = "Previous"
    static let todayHeaderDefault = "Today"
    static let blockersHeaderDefault = "Blockers"
    static let openPRsHeaderDefault = "Open Pull Requests"
    static let gratitudeHeaderDefault = "Gratitude/Joy/Others"
}
