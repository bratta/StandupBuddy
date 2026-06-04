import Foundation
@preconcurrency import GRDB

struct StandupItem: Codable, Identifiable, Sendable {
    var id: Int64?
    var date: Date
    var details: String
    var category: Category
    var completed: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        date: Date = .now,
        details: String = "",
        category: Category = .standup,
        completed: Bool = false
    ) {
        self.id = id
        self.date = date
        self.details = details
        self.category = category
        self.completed = completed
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension StandupItem: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "standupItem"
    static let databaseDateEncodingStrategy = DatabaseDateEncodingStrategy.iso8601

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let date = Column(CodingKeys.date)
        static let details = Column(CodingKeys.details)
        static let category = Column(CodingKeys.category)
        static let completed = Column(CodingKeys.completed)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    mutating func willSave(_ db: Database) throws {
        if id != nil { updatedAt = .now }
    }
}
