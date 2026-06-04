import Foundation
import GRDB

struct TextReplacementEngine {
    private let dbQueue: DatabaseQueue

    // Injected for testability
    var dadJokeFetcher: @Sendable () async throws -> String = { try await DadJokeService.fetch() }

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func process(_ text: String, date: Date = .now) async throws -> String {
        let dadJokeEnabled = try await dbQueue.read { db in try Queries.setting(key: Setting.dadJokeEnabledKey, db: db) }
        let formatDateEnabled = try await dbQueue.read { db in try Queries.setting(key: Setting.formatDateEnabledKey, db: db) }
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

        // 3. Custom regex replacements (in sortOrder)
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
        // Capture everything between the parens; trim surrounding quote chars afterward
        // so the regex tolerates ASCII ' and macOS smart quotes ' ' that TextEditor inserts
        let pattern = #"\{format_date\(([^)]+)\)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        var result = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches.reversed() {
            let fullRange = match.range
            let fmtRange = match.range(at: 1)
            var fmt = ns.substring(with: fmtRange)
            let quotes = CharacterSet(charactersIn: "'\u{2018}\u{2019}\u{201C}\u{201D}\"")
            fmt = fmt.trimmingCharacters(in: quotes)
            let formatted = StrftimeFormatter.format(date, fmt)
            result = (result as NSString).replacingCharacters(in: fullRange, with: formatted)
        }
        return result
    }

    private func applyCustomReplacement(_ replacement: CustomReplacement, to text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: replacement.pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement.template)
    }
}
