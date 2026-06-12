import Foundation

/// The markdown dialect Standup Buddy emits and renders.
///
/// Slack uses a `mrkdwn` variant (single-asterisk bold, underscore italics, single-tilde
/// strikethrough, `<url|text>` links, and no underline). GitHub-Flavored Markdown (GFM) uses the
/// more familiar CommonMark-derived tokens. This type is the single source of truth for those
/// tokens so the editor toolbar, the generator, and the previews all agree.
enum MarkdownFlavor: String, CaseIterable, Sendable, Identifiable {
    case slack
    case github

    var id: String { rawValue }

    /// Used for the settings picker and the output window badge.
    var displayName: String {
        switch self {
        case .slack: return "Slack mrkdwn"
        case .github: return "GitHub-Flavored Markdown"
        }
    }

    // MARK: - Wrap tokens

    var bold: (prefix: String, suffix: String) {
        switch self {
        case .slack: return ("*", "*")
        case .github: return ("**", "**")
        }
    }

    var italic: (prefix: String, suffix: String) {
        switch self {
        case .slack: return ("_", "_")
        case .github: return ("*", "*")
        }
    }

    var strikethrough: (prefix: String, suffix: String) {
        switch self {
        case .slack: return ("~", "~")
        case .github: return ("~~", "~~")
        }
    }

    /// `nil` when the flavor has no underline (Slack) — drives the toolbar button's disabled state.
    var underline: (prefix: String, suffix: String)? {
        switch self {
        case .slack: return nil
        case .github: return ("<u>", "</u>")
        }
    }

    /// Identical across both flavors, centralized so callers don't hardcode the tokens.
    var inlineCode: (prefix: String, suffix: String) { ("`", "`") }
    var codeBlock: (prefix: String, suffix: String) { ("```\n", "\n```") }

    // MARK: - Composite formatting

    func link(text: String, url: String) -> String {
        switch self {
        case .slack: return "<\(url)|\(text)>"
        case .github: return "[\(text)](\(url))"
        }
    }

    /// A bold-wrapped section header, e.g. `*Today:*` (Slack) or `**Today:**` (GitHub).
    func header(_ title: String) -> String {
        let (prefix, suffix) = bold
        return "\(prefix)\(title):\(suffix)"
    }

    // MARK: - Preview conversion

    /// Rewrites source into GFM so MarkdownUI (a GFM/CommonMark renderer) displays it correctly.
    ///
    /// GitHub source is already GFM and returned unchanged. Slack source has its bold, strikethrough,
    /// and link tokens rewritten; underscore italics already read as italics in GFM. Fenced code
    /// blocks and inline code spans are left untouched so placeholders (e.g. `{dad_joke}`) survive.
    func renderableGFM(from source: String) -> String {
        guard self == .slack else { return source }

        var lines: [String] = []
        var inFence = false
        for line in source.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inFence.toggle()
                lines.append(line)
            } else if inFence {
                lines.append(line)
            } else {
                lines.append(Self.convertInline(line))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Converts Slack inline tokens to GFM on a single line, skipping backtick code spans.
    private static func convertInline(_ line: String) -> String {
        let ns = line as NSString
        guard let codeSpan = try? NSRegularExpression(pattern: "`[^`]*`") else {
            return applyTokenConversions(line)
        }
        let matches = codeSpan.matches(in: line, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return applyTokenConversions(line) }

        var output = ""
        var cursor = 0
        for match in matches {
            let before = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            output += applyTokenConversions(before)
            output += ns.substring(with: match.range)  // code span passed through verbatim
            cursor = match.range.location + match.range.length
        }
        output += applyTokenConversions(ns.substring(from: cursor))
        return output
    }

    /// Applies the Slack→GFM token rewrites to a plain (code-free) text segment.
    private static func applyTokenConversions(_ text: String) -> String {
        var result = text
        // Links first: <url|text> → [text](url), then bare <url> → url
        result = replace(result, pattern: "<([^>|\\s]+)\\|([^>]+)>", template: "[$2]($1)")
        result = replace(result, pattern: "<([^>|\\s]+)>", template: "$1")
        // Strikethrough: ~x~ → ~~x~~
        result = replace(result, pattern: "~(\\S[^~\\n]*?)~", template: "~~$1~~")
        // Bold: *x* → **x** (requires non-space first char so leading "* " bullets are not matched)
        result = replace(result, pattern: "\\*(\\S[^*\\n]*?)\\*", template: "**$1**")
        return result
    }

    private static func replace(_ text: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: ns.length),
            withTemplate: template
        )
    }
}
