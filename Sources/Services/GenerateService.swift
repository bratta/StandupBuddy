import Foundation
import GRDB

struct GenerateService {
    private let dbQueue: DatabaseQueue
    private let textEngine: TextReplacementEngine
    private let workdayCalc: WorkdayCalculator

    // Injected for testability
    var prFetcher: ([RepositoryConfig]) async throws -> [PullRequest] = { repos in
        try await GitHubService.fetchOpenPRs(repos: repos)
    }

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
        self.textEngine = TextReplacementEngine(dbQueue: dbQueue)
        self.workdayCalc = WorkdayCalculator(dbQueue: dbQueue)
    }

    func generate(today: Date = .now) async throws -> String {
        let repos = try await dbQueue.read { db in try Queries.allRepos().fetchAll(db) }
        let previousDate = try workdayCalc.previousWorkday(from: today)

        let prevItems: [StandupItem]
        if let pd = previousDate {
            prevItems = (try? await dbQueue.read { db in try Queries.items(forDate: pd, category: .standup).fetchAll(db) }) ?? []
        } else {
            prevItems = []
        }

        let todayItems = (try? await dbQueue.read { db in
            try Queries.items(forDate: today, category: .standup).fetchAll(db)
        }) ?? []

        let blockerItems = (try? await dbQueue.read { db in
            try Queries.openItems(category: .blocker).fetchAll(db)
        }) ?? []

        let gratitudeItems = (try? await dbQueue.read { db in
            try Queries.openItems(category: .gratitude).fetchAll(db)
        }) ?? []

        let prs = await fetchPRsSafely(repos: repos)

        let (rawPrevHeader, rawTodayHeader, rawBlockersHeader, rawPRsHeader, rawGratHeader) =
            try await dbQueue.read { db in (
                try Queries.settingString(key: Setting.previousHeaderKey, db: db),
                try Queries.settingString(key: Setting.todayHeaderKey, db: db),
                try Queries.settingString(key: Setting.blockersHeaderKey, db: db),
                try Queries.settingString(key: Setting.openPRsHeaderKey, db: db),
                try Queries.settingString(key: Setting.gratitudeHeaderKey, db: db)
            ) }

        let (previousEnabled, todayEnabled, blockersEnabled, openPRsEnabled, gratitudeEnabled) =
            try await dbQueue.read { db in (
                try Queries.setting(key: Setting.previousEnabledKey, db: db),
                try Queries.setting(key: Setting.todayEnabledKey, db: db),
                try Queries.setting(key: Setting.blockersEnabledKey, db: db),
                try Queries.setting(key: Setting.openPRsEnabledKey, db: db),
                try Queries.setting(key: Setting.gratitudeEnabledKey, db: db)
            ) }

        let prevHeader = rawPrevHeader.isEmpty ? Setting.previousHeaderDefault : try await textEngine.process(rawPrevHeader, date: today)
        let todayHeader = rawTodayHeader.isEmpty ? Setting.todayHeaderDefault : try await textEngine.process(rawTodayHeader, date: today)
        let blockersHeader = rawBlockersHeader.isEmpty ? Setting.blockersHeaderDefault : try await textEngine.process(rawBlockersHeader, date: today)
        let prsHeader = rawPRsHeader.isEmpty ? Setting.openPRsHeaderDefault : try await textEngine.process(rawPRsHeader, date: today)
        let gratHeader = rawGratHeader.isEmpty ? Setting.gratitudeHeaderDefault : try await textEngine.process(rawGratHeader, date: today)

        var lines: [String] = []

        // Previous
        if previousEnabled {
            lines.append("*\(prevHeader):*")
            if prevItems.isEmpty {
                lines.append("* None")
            } else {
                for item in prevItems {
                    let text = try await textEngine.process(item.details, date: previousDate ?? today, entryDate: item.date)
                    lines.append("* \(text)")
                }
            }
        }

        // Today
        if todayEnabled {
            lines.append("*\(todayHeader):*")
            if todayItems.isEmpty {
                lines.append("* None")
            } else {
                for item in todayItems {
                    let text = try await textEngine.process(item.details, date: today, entryDate: item.date)
                    lines.append("* \(text)")
                }
            }
        }

        // Blockers
        if blockersEnabled {
            lines.append("*\(blockersHeader):*")
            if blockerItems.isEmpty {
                lines.append("* None")
            } else {
                for item in blockerItems {
                    let text = try await textEngine.process(item.details, date: today, entryDate: item.date)
                    lines.append("* \(text)")
                }
            }
        }

        // Open Pull Requests
        if openPRsEnabled {
            lines.append("*\(prsHeader):*")
            if prs.isEmpty {
                lines.append("* None")
            } else {
                for pr in prs {
                    lines.append("* \(pr.displayName): [\(pr.title)](\(pr.url))")
                }
            }
        }

        // Gratitude/Joy/Others
        if gratitudeEnabled {
            lines.append("*\(gratHeader):*")
            if gratitudeItems.isEmpty {
                lines.append("* None")
            } else {
                for item in gratitudeItems {
                    let text = try await textEngine.process(item.details, date: today, entryDate: item.date)
                    lines.append("* \(text)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func fetchPRsSafely(repos: [RepositoryConfig]) async -> [PullRequest] {
        guard !repos.isEmpty else { return [] }
        do {
            return try await prFetcher(repos)
        } catch {
            return []
        }
    }
}
