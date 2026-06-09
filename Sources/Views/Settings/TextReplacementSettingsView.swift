import SwiftUI

// MARK: - Preview computation

private let previewSample = "123456"

private func sampleInput(pattern: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"\([^)]*\)"#) else { return pattern }
    let ns = pattern as NSString
    let range = regex.rangeOfFirstMatch(in: pattern, range: NSRange(location: 0, length: ns.length))
    guard range.location != NSNotFound else { return pattern }
    return ns.replacingCharacters(in: range, with: previewSample)
}

private func resolveTemplate(_ template: String) -> (label: String, url: String?) {
    func sub(_ s: String) -> String {
        guard let re = try? NSRegularExpression(pattern: #"\$\d+"#) else { return s }
        let ns = s as NSString
        return re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: ns.length), withTemplate: previewSample)
    }
    guard let regex = try? NSRegularExpression(pattern: #"^\[([^\]]*)\]\(([^)]*)\)$"#) else {
        return (sub(template), nil)
    }
    let ns = template as NSString
    guard let m = regex.firstMatch(in: template, range: NSRange(location: 0, length: ns.length)),
          m.numberOfRanges == 3,
          let lr = Range(m.range(at: 1), in: template),
          let ur = Range(m.range(at: 2), in: template) else {
        return (sub(template), nil)
    }
    return (sub(String(template[lr])), sub(String(template[ur])))
}

// MARK: - Syntax highlighting (AttributedString-based)

private let monoFont        = Font.system(size: 13, design: .monospaced)
private let monoFontBold    = Font.system(size: 13, weight: .bold, design: .monospaced)
private let monoFontSemi    = Font.system(size: 13, weight: .semibold, design: .monospaced)

private func segment(_ text: String, color: Color, font: Font = monoFont) -> AttributedString {
    var s = AttributedString(text)
    s.foregroundColor = color
    s.font = font
    return s
}

private func highlightedPattern(_ src: String) -> Text {
    let ns = src as NSString
    let matches = (try? NSRegularExpression(pattern: #"\([^)]*\)"#))?
        .matches(in: src, range: NSRange(location: 0, length: ns.length)) ?? []
    var out = AttributedString()
    var last = src.startIndex
    for m in matches {
        guard let r = Range(m.range, in: src) else { continue }
        if last < r.lowerBound {
            out += segment(String(src[last..<r.lowerBound]), color: .codeText)
        }
        out += segment(String(src[r]), color: .tokGroup, font: monoFontSemi)
        last = r.upperBound
    }
    if last < src.endIndex {
        out += segment(String(src[last...]), color: .codeText)
    }
    return Text(out)
}

private func highlightedTemplate(_ src: String) -> Text {
    func dollarRun(_ s: String, base: Color) -> AttributedString {
        let ns = s as NSString
        let matches = (try? NSRegularExpression(pattern: #"\$\d+"#))?
            .matches(in: s, range: NSRange(location: 0, length: ns.length)) ?? []
        var out = AttributedString()
        var last = s.startIndex
        for m in matches {
            guard let r = Range(m.range, in: s) else { continue }
            if last < r.lowerBound {
                out += segment(String(s[last..<r.lowerBound]), color: base)
            }
            out += segment(String(s[r]), color: .tokVar, font: monoFontBold)
            last = r.upperBound
        }
        if last < s.endIndex {
            out += segment(String(s[last...]), color: base)
        }
        return out
    }

    let ns = src as NSString
    guard let m = (try? NSRegularExpression(pattern: #"^\[([^\]]*)\]\(([^)]*)\)$"#))?
        .firstMatch(in: src, range: NSRange(location: 0, length: ns.length)),
          m.numberOfRanges == 3,
          let lr = Range(m.range(at: 1), in: src),
          let ur = Range(m.range(at: 2), in: src) else {
        return Text(dollarRun(src, base: .tokLabel))
    }
    var out = segment("[", color: .tokPunc)
    out += dollarRun(String(src[lr]), base: .tokLabel)
    out += segment("](", color: .tokPunc)
    out += dollarRun(String(src[ur]), base: .tokUrl)
    out += segment(")", color: .tokPunc)
    return Text(out)
}

// MARK: - Field label

private func fieldLabel(_ text: String, accent: Bool = false) -> Text {
    Text(text.uppercased())
        .font(.system(size: 10.5, weight: .bold))
        .tracking(0.9)
        .foregroundStyle(accent ? Color.accentColor : Color.textTertiary)
}

// MARK: - Main view

struct TextReplacementSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showAddSheet = false
    @State private var editingReplacement: CustomReplacement? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Replacements")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .tracking(0.2)
                    Text("Match text in your entries and rewrite it into links when you Generate.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.bottom, 20)

                if model.customReplacements.isEmpty {
                    Text("No custom replacements. Click + to add one.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)
                        .italic()
                } else {
                    VStack(spacing: 14) {
                        ForEach(model.customReplacements) { rep in
                            ReplacementCard(replacement: rep) {
                                editingReplacement = rep
                            } onDelete: {
                                Task { await model.deleteReplacement(rep) }
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: 7) {
                            Text("+").font(.system(size: 16, weight: .bold))
                            Text("Add Replacement").font(.system(size: 13.5, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                    }
                    .buttonStyle(AddButtonStyle())
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAddSheet) {
            ReplacementFormSheet(replacement: nil) { rep in
                Task { await model.addReplacement(rep) }
            }
        }
        .sheet(item: $editingReplacement) { rep in
            ReplacementFormSheet(replacement: rep) { updated in
                Task { await model.updateReplacement(updated) }
            }
        }
    }
}

// MARK: - Rule card

private struct ReplacementCard: View {
    let replacement: CustomReplacement
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(replacement.name)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if !replacement.enabled {
                    Text("Disabled")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.trailing, 6)
                }
                Button("Edit", action: onEdit)
                    .buttonStyle(EditButtonStyle())
            }
            .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("Match")
                    highlightedPattern(replacement.pattern)
                        .lineLimit(1)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 11)
                        .background(Color.codeSurface, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.softBorder))
                }
                .frame(width: 150, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("Output template")
                    highlightedTemplate(replacement.template)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.codeSurface, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.softBorder))
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            CardPreview(replacement: replacement)
                .padding(.top, 15)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder))
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Card preview section

private struct CardPreview: View {
    let replacement: CustomReplacement

    private var input: String { sampleInput(pattern: replacement.pattern) }
    private var resolved: (label: String, url: String?) { resolveTemplate(replacement.template) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.softBorder)
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("Preview", accent: true)

                HStack(alignment: .center, spacing: 12) {
                    Text(input)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color.inputChipBg, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.softBorder))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)

                    PreviewLinkChip(label: resolved.label, url: resolved.url)
                }
            }
            .padding(.top, 14)
        }
    }
}

// MARK: - Link chip

private struct PreviewLinkChip: View {
    let label: String
    let url: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .underline(color: Color.accentLine)
                    .lineLimit(1)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
            }
            if let url {
                Text(url)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 11)
        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.accentLine))
    }
}

// MARK: - Button styles

private struct EditButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EditButtonBody(configuration: configuration)
    }
}

private struct EditButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                isHovered ? Color.accentColor.opacity(0.16) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .onHover { isHovered = $0 }
    }
}

private struct AddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AddButtonBody(configuration: configuration)
    }
}

private struct AddButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentDeep],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .brightness(isHovered ? 0.05 : 0)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Replacement form sheet

struct ReplacementFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let replacement: CustomReplacement?
    let onSave: (CustomReplacement) -> Void

    @State private var name: String
    @State private var pattern: String
    @State private var template: String
    @State private var enabled: Bool
    @State private var sortOrder: Int
    @State private var patternError: String? = nil

    init(replacement: CustomReplacement?, onSave: @escaping (CustomReplacement) -> Void) {
        self.replacement = replacement
        self.onSave = onSave
        _name = State(initialValue: replacement?.name ?? "")
        _pattern = State(initialValue: replacement?.pattern ?? "")
        _template = State(initialValue: replacement?.template ?? "")
        _enabled = State(initialValue: replacement?.enabled ?? true)
        _sortOrder = State(initialValue: replacement?.sortOrder ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(replacement == nil ? "Add Replacement" : "Edit Replacement")
                .font(.title2).bold()

            Form {
                TextField("Name", text: $name)
                TextField("Regex Pattern", text: $pattern)
                    .font(.body.monospaced())
                if let err = patternError {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
                Section("Template (use $1, $2 for captures)") {
                    TextEditor(text: $template)
                        .font(.body.monospaced())
                        .frame(minHeight: 80)
                }
                TextField("Sort Order", value: $sortOrder, format: .number)
                Toggle("Enabled", isOn: $enabled)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || pattern.isEmpty)
            }
        }
        .padding()
        .frame(width: 640)
    }

    private func save() {
        do {
            _ = try NSRegularExpression(pattern: pattern)
            patternError = nil
        } catch {
            patternError = "Invalid regex: \(error.localizedDescription)"
            return
        }
        var rep = replacement ?? CustomReplacement()
        rep.name = name
        rep.pattern = pattern
        rep.template = template
        rep.enabled = enabled
        rep.sortOrder = sortOrder
        onSave(rep)
        dismiss()
    }
}
