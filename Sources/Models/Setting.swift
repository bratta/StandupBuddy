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
}
