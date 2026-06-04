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

        var lines: [String] = []

        // Previous
        lines.append("*Previous:*")
        if prevItems.isEmpty {
            lines.append("* None")
        } else {
            for item in prevItems {
                let text = try await textEngine.process(item.details, date: previousDate ?? today)
                lines.append("* \(text)")
            }
        }

        // Today
        lines.append("*Today:*")
        if todayItems.isEmpty {
            lines.append("* None")
        } else {
            for item in todayItems {
                let text = try await textEngine.process(item.details, date: today)
                lines.append("* \(text)")
            }
        }

        // Blockers
        lines.append("*Blockers:*")
        if blockerItems.isEmpty {
            lines.append("* None")
        } else {
            for item in blockerItems {
                let text = try await textEngine.process(item.details, date: today)
                lines.append("* \(text)")
            }
        }

        // Open Pull Requests
        lines.append("*Open Pull Requests:*")
        if prs.isEmpty {
            lines.append("* None")
        } else {
            for pr in prs {
                lines.append("* \(pr.displayName): [\(pr.title)](\(pr.url))")
            }
        }

        // Gratitude/Joy/Others
        lines.append("*Gratitude/Joy/Others:*")
        if gratitudeItems.isEmpty {
            lines.append("* None")
        } else {
            for item in gratitudeItems {
                let text = try await textEngine.process(item.details, date: today)
                lines.append("* \(text)")
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
