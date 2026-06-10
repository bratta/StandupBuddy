import Foundation
import GRDB

struct TextReplacementEngine {
    private let dbQueue: DatabaseQueue

    // Injected for testability
    var dadJokeFetcher: @Sendable () async throws -> String = { try await DadJokeService.fetch() }
    var funFactFetcher: @Sendable () async throws -> String = { try await FunFactService.fetch() }
    var affirmationFetcher: @Sendable () async throws -> String = { try await AffirmationService.fetch() }

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func process(_ text: String, date: Date = .now, entryDate: Date? = nil) async throws -> String {
        let (dadJokeEnabled, formatDateEnabled, yesterdayEnabled, funFactEnabled, affirmationEnabled, emojiOfDayEnabled, entryDateEnabled) =
            try await dbQueue.read { db in (
                try Queries.setting(key: Setting.dadJokeEnabledKey, db: db),
                try Queries.setting(key: Setting.formatDateEnabledKey, db: db),
                try Queries.setting(key: Setting.yesterdayEnabledKey, db: db),
                try Queries.setting(key: Setting.funFactEnabledKey, db: db),
                try Queries.setting(key: Setting.affirmationEnabledKey, db: db),
                try Queries.setting(key: Setting.emojiOfDayEnabledKey, db: db),
                try Queries.setting(key: Setting.entryDateEnabledKey, db: db)
            ) }
        let customReplacements = try await dbQueue.read { db in try Queries.enabledReplacements().fetchAll(db) }

        var result = text

        // 1. {dad_joke}
        if dadJokeEnabled {
            result = try await replaceDadJokes(in: result)
        }

        // 2. {format_date('FMT')}
        if formatDateEnabled {
            result = replaceFormatDate(in: result, date: date)
        }

        // 3. {yesterday} / {yesterday('FMT')}
        if yesterdayEnabled {
            result = replaceYesterday(in: result, date: date)
        }

        // 4. {fun_fact}
        if funFactEnabled {
            result = try await replaceFunFacts(in: result)
        }

        // 5. {affirmation}
        if affirmationEnabled {
            result = try await replaceAffirmations(in: result)
        }

        // 6. {emoji_of_day}
        if emojiOfDayEnabled {
            result = replaceEmojiOfDay(in: result, date: date)
        }

        // 7. {entry_date} / {entry_date('FMT')}
        if entryDateEnabled {
            result = replaceEntryDate(in: result, entryDate: entryDate)
        }

        // 8. Custom regex replacements (in sortOrder)
        for replacement in customReplacements {
            result = applyCustomReplacement(replacement, to: result)
        }

        return result
    }

    private func replaceDadJokes(in text: String) async throws -> String {
        let token = "{dad_joke}"
        guard text.contains(token) else { return text }
        var result = text
        while result.contains(token) {
            let joke = try await dadJokeFetcher()
            if let range = result.range(of: token) {
                result.replaceSubrange(range, with: ":joy_cat: \(joke)")
            }
        }
        return result
    }

    private func replaceFormatDate(in text: String, date: Date) -> String {
        replaceDateTokens(pattern: #"\{(?:format_date|today)(?:\(([^)]+)\))?\}"#, in: text, date: date)
    }

    private func replaceYesterday(in text: String, date: Date) -> String {
        replaceDateTokens(pattern: #"\{(?:yesterday|previous)(?:\(([^)]+)\))?\}"#, in: text, date: previousWorkday(from: date))
    }

    // Replaces {entry_date} / {entry_date('FMT')} with the entry's own date.
    // When there is no entry context (entryDate == nil), the token is stripped to "".
    private func replaceEntryDate(in text: String, entryDate: Date?) -> String {
        let pattern = #"\{entry_date(?:\(([^)]+)\))?\}"#
        guard let entryDate else {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        }
        return replaceDateTokens(pattern: pattern, in: text, date: entryDate, defaultFormat: "%Y-%m-%d")
    }

    // Replaces all matches of a strftime-style token pattern with the formatted date.
    // Capture group 1 is an optional format string; falls back to `defaultFormat` when absent.
    // Trims surrounding quote chars to tolerate ASCII ' and macOS smart quotes ' '.
    private func replaceDateTokens(pattern: String, in text: String, date: Date, defaultFormat: String = "%A") -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        var result = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        let quotes = CharacterSet(charactersIn: "'\u{2018}\u{2019}\u{201C}\u{201D}\"")
        for match in matches.reversed() {
            let fmtRange = match.range(at: 1)
            let fmt = fmtRange.location != NSNotFound
                ? ns.substring(with: fmtRange).trimmingCharacters(in: quotes)
                : defaultFormat
            result = (result as NSString).replacingCharacters(in: match.range, with: StrftimeFormatter.format(date, fmt))
        }
        return result
    }

    private func previousWorkday(from date: Date) -> Date {
        let cal = Calendar.current
        var candidate = cal.startOfDay(for: date)
        repeat {
            candidate = cal.date(byAdding: .day, value: -1, to: candidate)!
            let weekday = cal.component(.weekday, from: candidate)
            if weekday != 1 && weekday != 7 { return candidate }
        } while true
    }

    private func replaceFunFacts(in text: String) async throws -> String {
        let token = "{fun_fact}"
        guard text.contains(token) else { return text }
        var result = text
        while result.contains(token) {
            let fact = try await funFactFetcher()
            if let range = result.range(of: token) {
                result.replaceSubrange(range, with: fact)
            }
        }
        return result
    }

    private func replaceAffirmations(in text: String) async throws -> String {
        let token = "{affirmation}"
        guard text.contains(token) else { return text }
        var result = text
        while result.contains(token) {
            let affirmation = try await affirmationFetcher()
            if let range = result.range(of: token) {
                result.replaceSubrange(range, with: affirmation)
            }
        }
        return result
    }

    private func replaceEmojiOfDay(in text: String, date: Date) -> String {
        guard text.contains("{emoji_of_day}") else { return text }
        let cal = Calendar.current
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let emoji = Self.dailyEmojis[(dayOfYear - 1) % Self.dailyEmojis.count]
        return text.replacingOccurrences(of: "{emoji_of_day}", with: emoji)
    }

    private static let dailyEmojis: [String] = [
        "🚀", "🌟", "💪", "🎯", "🔥", "✨", "🌈", "⚡️", "🎉", "🦋",
        "🌺", "🏆", "💡", "🎸", "🌊", "🦄", "🍀", "🎨", "🌙", "☀️",
        "🐝", "🎵", "🌻", "🦊", "🍕", "🌴", "🎭", "🔮", "🌸", "💫"
    ]

    private func applyCustomReplacement(_ replacement: CustomReplacement, to text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: replacement.pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement.template)
    }
}
