import Foundation
import GRDB

struct CustomReplacement: Codable, Identifiable, Sendable {
    var id: Int64?
    var name: String
    var pattern: String
    var template: String
    var enabled: Bool
    var sortOrder: Int

    init(id: Int64? = nil, name: String = "", pattern: String = "", template: String = "", enabled: Bool = true, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.template = template
        self.enabled = enabled
        self.sortOrder = sortOrder
    }
}

extension CustomReplacement: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "customReplacement"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let pattern = Column(CodingKeys.pattern)
        static let template = Column(CodingKeys.template)
        static let enabled = Column(CodingKeys.enabled)
        static let sortOrder = Column(CodingKeys.sortOrder)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
