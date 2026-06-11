import Foundation

extension String {
    /// Collapses newlines in third-party API text so it renders as a single Slack bullet.
    func flattenedForSlack() -> String {
        components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
