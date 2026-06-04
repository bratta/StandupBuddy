import Foundation
import GRDB

struct RepositoryConfig: Codable, Identifiable, Sendable {
    var id: Int64?
    var owner: String
    var name: String
    var displayName: String
    var sortOrder: Int

    init(id: Int64? = nil, owner: String = "", name: String = "", displayName: String = "", sortOrder: Int = 0) {
        self.id = id
        self.owner = owner
        self.name = name
        self.displayName = displayName
        self.sortOrder = sortOrder
    }

    var fullName: String { "\(owner)/\(name)" }
}

extension RepositoryConfig: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "repositoryConfig"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let owner = Column(CodingKeys.owner)
        static let name = Column(CodingKeys.name)
        static let displayName = Column(CodingKeys.displayName)
        static let sortOrder = Column(CodingKeys.sortOrder)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
