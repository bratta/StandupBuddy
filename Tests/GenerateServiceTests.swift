import Testing
import Foundation
import GRDB
@testable import StandupBuddy

@Suite("GenerateService")
struct GenerateServiceTests {
    static let monday = DateComponents(calendar: .current, year: 2025, month: 6, day: 2).date!
    static let friday = DateComponents(calendar: .current, year: 2025, month: 5, day: 30).date!

    func makeDB(standupItems: [(Date, String)] = [], blockers: [String] = [], gratitude: [String] = []) throws -> DatabaseQueue {
        let db = try DatabaseQueue()
        try db.write { d in
            try d.create(table: "standupItem") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull()
                t.column("details", .text).notNull()
                t.column("category", .text).notNull()
                t.column("completed", .boolean).notNull()
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
            try d.create(table: "repositoryConfig") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("owner", .text).notNull()
                t.column("name", .text).notNull()
                t.column("displayName", .text).notNull()
                t.column("sortOrder", .integer).notNull()
            }
            try d.create(table: "customReplacement") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("pattern", .text).notNull()
                t.column("template", .text).notNull()
                t.column("enabled", .boolean).notNull()
                t.column("sortOrder", .integer).notNull()
            }
            try d.create(table: "holiday") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull()
                t.column("name", .text).notNull()
            }
            try d.create(table: "ptoRange") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("startDate", .text).notNull()
                t.column("endDate", .text).notNull()
                t.column("note", .text).notNull()
            }
            try d.create(table: "setting") { t in
                t.primaryKey("id", .text)
                t.column("value", .text).notNull()
            }
            try d.execute(sql: "INSERT INTO setting (id, value) VALUES (?, ?)", arguments: [Setting.dadJokeEnabledKey, "false"])
            try d.execute(sql: "INSERT INTO setting (id, value) VALUES (?, ?)", arguments: [Setting.formatDateEnabledKey, "false"])

            for (date, detail) in standupItems {
                var item = StandupItem(date: date, details: detail, category: .standup)
                try item.insert(d)
            }
            for detail in blockers {
                var item = StandupItem(date: Self.monday, details: detail, category: .blocker)
                try item.insert(d)
            }
            for detail in gratitude {
                var item = StandupItem(date: Self.monday, details: detail, category: .gratitude)
                try item.insert(d)
            }
        }
        return db
    }

    @Test("empty database produces all-None output")
    func allNoneOutput() async throws {
        let db = try makeDB()
        var svc = GenerateService(dbQueue: db)
        svc.prFetcher = { _ in [] }
        let output = try await svc.generate(today: Self.monday)
        #expect(output.contains("**Previous:**\n* None"))
        #expect(output.contains("**Today:**\n* None"))
        #expect(output.contains("**Blockers:**\n* None"))
        #expect(output.contains("**Open Pull Requests:**\n* None"))
        #expect(output.contains("**Gratitude/Joy/Others:**\n* None"))
    }

    @Test("today and previous items appear in correct sections")
    func todayAndPrevious() async throws {
        let db = try makeDB(standupItems: [
            (Self.friday, "Friday task"),
            (Self.monday, "Monday task")
        ])
        var svc = GenerateService(dbQueue: db)
        svc.prFetcher = { _ in [] }
        let output = try await svc.generate(today: Self.monday)
        #expect(output.contains("**Previous:**\n* Friday task"))
        #expect(output.contains("**Today:**\n* Monday task"))
    }

    @Test("open blockers and gratitude appear")
    func blockersAndGratitude() async throws {
        let db = try makeDB(blockers: ["Waiting on PR review"], gratitude: ["Great team!"])
        var svc = GenerateService(dbQueue: db)
        svc.prFetcher = { _ in [] }
        let output = try await svc.generate(today: Self.monday)
        #expect(output.contains("**Blockers:**\n* Waiting on PR review"))
        #expect(output.contains("**Gratitude/Joy/Others:**\n* Great team!"))
    }

    @Test("pull requests are listed with display name")
    func pullRequestsListed() async throws {
        let db = try makeDB()
        // Need at least one configured repo for PRs to be fetched
        try await db.write { d in
            var repo = RepositoryConfig(owner: "org", name: "repo", displayName: "My Repo", sortOrder: 0)
            try repo.insert(d)
        }
        var svc = GenerateService(dbQueue: db)
        svc.prFetcher = { _ in [PullRequest(title: "Fix the thing", url: "https://github.com/org/repo/pull/1", displayName: "My Repo")] }
        let output = try await svc.generate(today: Self.monday)
        #expect(output.contains("* My Repo: [Fix the thing](https://github.com/org/repo/pull/1)"))
    }
}
