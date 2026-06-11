import Foundation
import GRDB

struct Queries {
    // MARK: - StandupItem

    static func pagedItems(page: Int, pageSize: Int = 20, category: Category? = nil, showCompleted: Bool = true) -> QueryInterfaceRequest<StandupItem> {
        var request = StandupItem.order(
            StandupItem.Columns.date.desc,
            StandupItem.Columns.createdAt.desc
        )
        if let category {
            request = request.filter(StandupItem.Columns.category == category.rawValue)
        }
        if !showCompleted {
            request = request.filter(StandupItem.Columns.completed == false)
        }
        return request.limit(pageSize, offset: page * pageSize)
    }

    static func itemCount(category: Category? = nil, showCompleted: Bool = true) -> SQLRequest<Int> {
        if let category {
            if !showCompleted {
                return SQLRequest(sql: "SELECT COUNT(*) FROM standupItem WHERE category = ? AND completed = 0", arguments: [category.rawValue])
            }
            return SQLRequest(sql: "SELECT COUNT(*) FROM standupItem WHERE category = ?", arguments: [category.rawValue])
        }
        if !showCompleted {
            return SQLRequest(sql: "SELECT COUNT(*) FROM standupItem WHERE completed = 0")
        }
        return SQLRequest(sql: "SELECT COUNT(*) FROM standupItem")
    }

    static func items(forDate date: Date, category: Category) -> QueryInterfaceRequest<StandupItem> {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let start = fmt.string(from: startOfDay)
        let end = fmt.string(from: endOfDay)
        return StandupItem
            .filter(StandupItem.Columns.category == category.rawValue)
            .filter(StandupItem.Columns.date >= start && StandupItem.Columns.date < end)
            .order(StandupItem.Columns.date.asc, StandupItem.Columns.createdAt.asc)
    }

    static func hasItems(forDate date: Date, category: Category, db: Database) throws -> Bool {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let start = fmt.string(from: startOfDay)
        let end = fmt.string(from: endOfDay)
        return try StandupItem
            .filter(StandupItem.Columns.category == category.rawValue)
            .filter(StandupItem.Columns.date >= start && StandupItem.Columns.date < end)
            .fetchCount(db) > 0
    }

    static func openItems(category: Category) -> QueryInterfaceRequest<StandupItem> {
        StandupItem
            .filter(StandupItem.Columns.category == category.rawValue)
            .filter(StandupItem.Columns.completed == false)
            .order(StandupItem.Columns.date.asc, StandupItem.Columns.createdAt.asc)
    }

    // MARK: - Settings

    static func setting(key: String, default defaultValue: Bool = true, db: Database) throws -> Bool {
        let row = try Row.fetchOne(db, sql: "SELECT value FROM setting WHERE id = ?", arguments: [key])
        guard let row else { return defaultValue }
        return row["value"] == "true"
    }

    static func settingString(key: String, db: Database) throws -> String {
        let row = try Row.fetchOne(db, sql: "SELECT value FROM setting WHERE id = ?", arguments: [key])
        return row?["value"] ?? ""
    }

    // MARK: - RepositoryConfig

    static func allRepos() -> QueryInterfaceRequest<RepositoryConfig> {
        RepositoryConfig.order(RepositoryConfig.Columns.sortOrder.asc)
    }

    // MARK: - CustomReplacement

    static func enabledReplacements() -> QueryInterfaceRequest<CustomReplacement> {
        CustomReplacement
            .filter(CustomReplacement.Columns.enabled == true)
            .order(CustomReplacement.Columns.sortOrder.asc)
    }

    static func allReplacements() -> QueryInterfaceRequest<CustomReplacement> {
        CustomReplacement.order(CustomReplacement.Columns.sortOrder.asc)
    }

}
