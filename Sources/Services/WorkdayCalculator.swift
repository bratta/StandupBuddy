import Foundation
import GRDB

struct WorkdayCalculator {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func previousWorkday(from today: Date = .now) throws -> Date? {
        let cal = Calendar.current

        func isWeekend(_ date: Date) -> Bool {
            let weekday = cal.component(.weekday, from: date)
            return weekday == 1 || weekday == 7
        }

        var candidate = cal.startOfDay(for: today)
        let limit = 365
        for _ in 0..<limit {
            candidate = cal.date(byAdding: .day, value: -1, to: candidate)!
            if isWeekend(candidate) { continue }
            let hasEntries = try dbQueue.read { db in
                try Queries.hasItems(forDate: candidate, category: .standup, db: db)
            }
            if hasEntries { return candidate }
        }
        return nil
    }
}
