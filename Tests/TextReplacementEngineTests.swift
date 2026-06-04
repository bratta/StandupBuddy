import Testing
import Foundation
import GRDB
@testable import StandupBuddy

@Suite("TextReplacementEngine")
struct TextReplacementEngineTests {
    func makeDB(settings: [String: String] = [:], replacements: [CustomReplacement] = []) throws -> DatabaseQueue {
        let db = try DatabaseQueue()
        try db.write { d in
            try d.create(table: "setting") { t in
                t.primaryKey("id", .text)
                t.column("value", .text).notNull()
            }
            try d.create(table: "customReplacement") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("pattern", .text).notNull()
                t.column("template", .text).notNull()
                t.column("enabled", .boolean).notNull()
                t.column("sortOrder", .integer).notNull()
            }
            let defaults: [String: String] = [
                Setting.dadJokeEnabledKey: "true",
                Setting.formatDateEnabledKey: "true"
            ]
            let merged = defaults.merging(settings) { _, new in new }
            for (k, v) in merged {
                try d.execute(sql: "INSERT OR REPLACE INTO setting (id, value) VALUES (?, ?)", arguments: [k, v])
            }
            for var r in replacements { try r.insert(d) }
        }
        return db
    }

    @Test("format_date replaces with day name")
    func formatDate() async throws {
        let db = try makeDB(settings: [Setting.dadJokeEnabledKey: "false"])
        var engine = TextReplacementEngine(dbQueue: db)
        engine.dadJokeFetcher = { "stub" }
        // Use a fixed date (Monday)
        let monday = DateComponents(calendar: .current, year: 2025, month: 6, day: 2).date!
        let result = try await engine.process("It's {format_date('%A')} today.", date: monday)
        #expect(result == "It's Monday today.")
    }

    @Test("custom regex replacement with capture group")
    func customRegexReplacement() async throws {
        let rep = CustomReplacement(name: "LM Ticket", pattern: #"LM-(\d+)"#, template: "[LM $1](https://example.com/$1)", enabled: true, sortOrder: 0)
        let db = try makeDB(settings: [Setting.dadJokeEnabledKey: "false", Setting.formatDateEnabledKey: "false"], replacements: [rep])
        var engine = TextReplacementEngine(dbQueue: db)
        engine.dadJokeFetcher = { "stub" }
        let result = try await engine.process("Working on LM-12345 today.", date: .now)
        #expect(result == "Working on [LM 12345](https://example.com/12345) today.")
    }

    @Test("disabled tokens are left untouched")
    func disabledTokensPassthrough() async throws {
        let db = try makeDB(settings: [Setting.dadJokeEnabledKey: "false", Setting.formatDateEnabledKey: "false"])
        var engine = TextReplacementEngine(dbQueue: db)
        engine.dadJokeFetcher = { Issue.record("dad_joke should not be called"); return "stub" }
        let input = "See {dad_joke} and {format_date('%A')} here"
        let result = try await engine.process(input, date: .now)
        #expect(result == input)
    }

    @Test("dad_joke replaced with joy_cat prefix")
    func dadJokeReplacement() async throws {
        let db = try makeDB(settings: [Setting.formatDateEnabledKey: "false"])
        var engine = TextReplacementEngine(dbQueue: db)
        engine.dadJokeFetcher = { "Why don't eggs tell jokes? They'd crack up." }
        let result = try await engine.process("Here is {dad_joke}!", date: .now)
        #expect(result == "Here is :joy_cat: Why don't eggs tell jokes? They'd crack up.!")
    }
}
