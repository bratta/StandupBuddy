import Foundation
import GRDB
import Observation

@Observable
@MainActor
final class AppModel {
    private let manager: DatabaseManager

    var dbQueue: DatabaseQueue? { manager.database?.dbQueue }

    // Data entry list state
    var items: [StandupItem] = []
    var totalItemCount: Int = 0
    var currentPage: Int = 0
    let pageSize: Int = 20

    // Section view state
    var previousItems: [StandupItem] = []
    var todayItems: [StandupItem] = []
    var blockerItems: [StandupItem] = []
    var gratitudeItems: [StandupItem] = []

    // Settings
    var dadJokeEnabled: Bool = true
    var formatDateEnabled: Bool = true
    var yesterdayEnabled: Bool = true
    var funFactEnabled: Bool = true
    var affirmationEnabled: Bool = true
    var emojiOfDayEnabled: Bool = true
    var entryDateEnabled: Bool = true
    var repos: [RepositoryConfig] = []
    var customReplacements: [CustomReplacement] = []
    var categoryFilter: Category? = nil

    // Section header templates (empty = use built-in default)
    var previousHeader: String = ""
    var todayHeader: String = ""
    var blockersHeader: String = ""
    var openPRsHeader: String = ""
    var gratitudeHeader: String = ""

    init(manager: DatabaseManager) {
        self.manager = manager
    }

    var pageCount: Int {
        max(1, Int(ceil(Double(totalItemCount) / Double(pageSize))))
    }

    // MARK: - Load

    func loadAll() async {
        await loadItems()
        await loadSectionItems()
        await loadSettings()
        await loadRepos()
        await loadCustomReplacements()
    }

    func loadItems() async {
        guard let dbQueue else { return }
        do {
            let page = currentPage
            let size = pageSize
            let filter = categoryFilter
            let count = try await dbQueue.read { db in try Int.fetchOne(db, Queries.itemCount(category: filter)) ?? 0 }
            let fetched = try await dbQueue.read { db in
                try Queries.pagedItems(page: page, pageSize: size, category: filter).fetchAll(db)
            }
            totalItemCount = count
            items = fetched
        } catch {}
    }

    func loadSectionItems() async {
        guard let dbQueue else { return }
        do {
            let today = Date.now
            let calc = WorkdayCalculator(dbQueue: dbQueue)
            let prevDate = try calc.previousWorkday(from: today)

            previousItems = try await dbQueue.read { db in
                guard let pd = prevDate else { return [] }
                return try Queries.items(forDate: pd, category: .standup).fetchAll(db)
            }
            todayItems = try await dbQueue.read { db in
                try Queries.items(forDate: today, category: .standup).fetchAll(db)
            }
            blockerItems = try await dbQueue.read { db in
                try Queries.openItems(category: .blocker).fetchAll(db)
            }
            gratitudeItems = try await dbQueue.read { db in
                try Queries.openItems(category: .gratitude).fetchAll(db)
            }
        } catch {}
    }

    func loadSettings() async {
        guard let dbQueue else { return }
        do {
            (dadJokeEnabled, formatDateEnabled, yesterdayEnabled, funFactEnabled, affirmationEnabled, emojiOfDayEnabled, entryDateEnabled) =
                try await dbQueue.read { db in (
                    try Queries.setting(key: Setting.dadJokeEnabledKey, db: db),
                    try Queries.setting(key: Setting.formatDateEnabledKey, db: db),
                    try Queries.setting(key: Setting.yesterdayEnabledKey, db: db),
                    try Queries.setting(key: Setting.funFactEnabledKey, db: db),
                    try Queries.setting(key: Setting.affirmationEnabledKey, db: db),
                    try Queries.setting(key: Setting.emojiOfDayEnabledKey, db: db),
                    try Queries.setting(key: Setting.entryDateEnabledKey, db: db)
                ) }
            (previousHeader, todayHeader, blockersHeader, openPRsHeader, gratitudeHeader) =
                try await dbQueue.read { db in (
                    try Queries.settingString(key: Setting.previousHeaderKey, db: db),
                    try Queries.settingString(key: Setting.todayHeaderKey, db: db),
                    try Queries.settingString(key: Setting.blockersHeaderKey, db: db),
                    try Queries.settingString(key: Setting.openPRsHeaderKey, db: db),
                    try Queries.settingString(key: Setting.gratitudeHeaderKey, db: db)
                ) }
        } catch {}
    }

    func loadRepos() async {
        guard let dbQueue else { return }
        do {
            repos = try await dbQueue.read { db in try Queries.allRepos().fetchAll(db) }
        } catch {}
    }

    func loadCustomReplacements() async {
        guard let dbQueue else { return }
        do {
            customReplacements = try await dbQueue.read { db in try Queries.allReplacements().fetchAll(db) }
        } catch {}
    }

    // MARK: - Mutations

    func addItem(_ item: StandupItem) async {
        guard let dbQueue else { return }
        do {
            let copy = item
            try await dbQueue.write { db in
                var mutable = copy
                try mutable.insert(db)
            }
            currentPage = 0
            await loadItems()
            await loadSectionItems()
        } catch {}
    }

    func updateItem(_ item: StandupItem) async {
        guard let dbQueue else { return }
        do {
            let copy = item
            try await dbQueue.write { db in
                var mutable = copy
                try mutable.update(db)
            }
            await loadItems()
            await loadSectionItems()
        } catch {}
    }

    func deleteItem(_ item: StandupItem) async {
        guard let dbQueue else { return }
        do {
            let copy = item
            try await dbQueue.write { db in try copy.delete(db) }
            if currentPage > 0 && items.count == 1 {
                currentPage -= 1
            }
            await loadItems()
            await loadSectionItems()
        } catch {}
    }

    func goToPage(_ page: Int) async {
        currentPage = max(0, min(page, pageCount - 1))
        await loadItems()
    }

    func setFilter(_ category: Category?) async {
        categoryFilter = category
        currentPage = 0
        await loadItems()
    }

    // MARK: - Setting mutations

    func setSetting(key: String, value: Bool) async {
        guard let dbQueue else { return }
        do {
            let s = Setting(id: key, value: value ? "true" : "false")
            try await dbQueue.write { db in try s.save(db) }
            await loadSettings()
        } catch {}
    }

    func setStringSetting(key: String, value: String) async {
        guard let dbQueue else { return }
        do {
            let s = Setting(id: key, value: value)
            try await dbQueue.write { db in try s.save(db) }
            await loadSettings()
        } catch {}
    }

    // MARK: - Repo mutations

    func addRepo(_ repo: RepositoryConfig) async {
        guard let dbQueue else { return }
        do {
            let copy = repo
            try await dbQueue.write { db in
                var mutable = copy
                try mutable.insert(db)
            }
            await loadRepos()
        } catch {}
    }

    func updateRepo(_ repo: RepositoryConfig) async {
        guard let dbQueue else { return }
        do {
            let copy = repo
            try await dbQueue.write { db in
                var mutable = copy
                try mutable.update(db)
            }
            await loadRepos()
        } catch {}
    }

    func deleteRepo(_ repo: RepositoryConfig) async {
        guard let dbQueue else { return }
        do {
            let copy = repo
            try await dbQueue.write { db in try copy.delete(db) }
            await loadRepos()
        } catch {}
    }

    // MARK: - Custom replacement mutations

    func addReplacement(_ r: CustomReplacement) async {
        guard let dbQueue else { return }
        do {
            let copy = r
            try await dbQueue.write { db in
                var mutable = copy
                try mutable.insert(db)
            }
            await loadCustomReplacements()
        } catch {}
    }

    func updateReplacement(_ r: CustomReplacement) async {
        guard let dbQueue else { return }
        do {
            let copy = r
            try await dbQueue.write { db in
                var mutable = copy
                try mutable.update(db)
            }
            await loadCustomReplacements()
        } catch {}
    }

    func deleteReplacement(_ r: CustomReplacement) async {
        guard let dbQueue else { return }
        do {
            let copy = r
            try await dbQueue.write { db in try copy.delete(db) }
            await loadCustomReplacements()
        } catch {}
    }

}
