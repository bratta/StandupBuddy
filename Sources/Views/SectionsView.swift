import SwiftUI
import MarkdownUI

struct SectionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Markdown(highlightedMarkdown)
                    .markdownTheme(.quickPreview)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 30)
            }
            .background(Color.cardSurface)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(Color.softBorder)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                Text("Quick preview · text replacement placeholders shown as-is · no API calls made")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Color.bgRaised)
        }
        .task { await model.loadSectionItems() }
    }

    private var highlightedMarkdown: String {
        let raw = buildMarkdown()
        guard let regex = try? NSRegularExpression(pattern: #"\{[^}\n]+\}"#) else { return raw }
        let ns = raw as NSString
        return regex.stringByReplacingMatches(
            in: raw,
            range: NSRange(location: 0, length: ns.length),
            withTemplate: "`$0`"
        )
    }

    private func buildMarkdown() -> String {
        var lines: [String] = []

        if model.previousEnabled {
            let header = model.previousHeader.isEmpty ? Setting.previousHeaderDefault : model.previousHeader
            if !lines.isEmpty { lines.append("") }
            lines.append("*\(header):*")
            if model.previousItems.isEmpty {
                lines.append("* None")
            } else {
                for item in model.previousItems { lines.append("* \(item.details)") }
            }
        }

        if model.todayEnabled {
            let header = model.todayHeader.isEmpty ? Setting.todayHeaderDefault : model.todayHeader
            if !lines.isEmpty { lines.append("") }
            lines.append("*\(header):*")
            if model.todayItems.isEmpty {
                lines.append("* None")
            } else {
                for item in model.todayItems { lines.append("* \(item.details)") }
            }
        }

        if model.blockersEnabled {
            let header = model.blockersHeader.isEmpty ? Setting.blockersHeaderDefault : model.blockersHeader
            if !lines.isEmpty { lines.append("") }
            lines.append("*\(header):*")
            if model.blockerItems.isEmpty {
                lines.append("* None")
            } else {
                for item in model.blockerItems { lines.append("* \(item.details)") }
            }
        }

        if model.openPRsEnabled {
            let header = model.openPRsHeader.isEmpty ? Setting.openPRsHeaderDefault : model.openPRsHeader
            if !lines.isEmpty { lines.append("") }
            lines.append("*\(header):*")
            lines.append("* (fetched live on Generate)")
        }

        if model.gratitudeEnabled {
            let header = model.gratitudeHeader.isEmpty ? Setting.gratitudeHeaderDefault : model.gratitudeHeader
            if !lines.isEmpty { lines.append("") }
            lines.append("*\(header):*")
            if model.gratitudeItems.isEmpty {
                lines.append("* None")
            } else {
                for item in model.gratitudeItems { lines.append("* \(item.details)") }
            }
        }

        if lines.isEmpty {
            return "*(No sections enabled)*"
        }

        return lines.joined(separator: "\n")
    }
}

private extension Theme {
    nonisolated(unsafe) static let quickPreview = Theme()
        .text { ForegroundColor(.textPrimary); FontSize(14) }
        .emphasis { FontStyle(.italic); ForegroundColor(.amber) }
        .link { ForegroundColor(.linkBlue) }
        .code {
            ForegroundColor(.tokVar)
            BackgroundColor(Color.tokVar.opacity(0.12))
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
        }
}
