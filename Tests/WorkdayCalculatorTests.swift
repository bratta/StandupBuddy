import Testing
import Foundation
import GRDB
@testable import StandupBuddy

@Suite("WorkdayCalculator")
struct WorkdayCalculatorTests {
    func makeDB(items: [StandupItem] = []) throws -> DatabaseQueue {
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
            for var item in items { try item.insert(d) }
        }
        return db
    }

    func monday(_ offset: Int = 0) -> Date {
        // 2025-06-02 is a Monday
        let base = DateComponents(calendar: .current, year: 2025, month: 6, day: 2).date!
        return Calendar.current.date(byAdding: .day, value: offset, to: base)!
    }

    @Test("skips Saturday and Sunday to reach Friday")
    func skipsWeekend() throws {
        let friday = monday(-3)  // 2025-05-30
        let item = StandupItem(date: friday, details: "test", category: .standup)
        let db = try makeDB(items: [item])
        let calc = WorkdayCalculator(dbQueue: db)
        // calling from Monday 2025-06-02 → previous workday with entries is Friday 2025-05-30
        let result = try calc.previousWorkday(from: monday(0))
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.isDate(result!, inSameDayAs: friday))
    }

    @Test("skips empty days to find last day with entries")
    func skipsEmptyDays() throws {
        let tuesday = monday(-6)  // previous week Tuesday
        let item = StandupItem(date: tuesday, details: "last entry", category: .standup)
        // Wednesday/Thursday/Friday have no entries
        let db = try makeDB(items: [item])
        let calc = WorkdayCalculator(dbQueue: db)
        let result = try calc.previousWorkday(from: monday(0))
        #expect(result != nil)
        #expect(Calendar.current.isDate(result!, inSameDayAs: tuesday))
    }

    @Test("returns nil when no entries exist within bound")
    func returnsNilWhenEmpty() throws {
        let db = try makeDB()
        let calc = WorkdayCalculator(dbQueue: db)
        let result = try calc.previousWorkday(from: monday(0))
        #expect(result == nil)
    }
}
