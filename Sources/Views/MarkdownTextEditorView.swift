import SwiftUI
import AppKit

// Bridges toolbar actions to the underlying NSTextView
@MainActor
final class TextEditorBridge {
    weak var textView: MarkdownNSTextView?

    func wrapSelection(prefix: String, suffix: String) {
        guard let tv = textView else { return }
        let sel = tv.selectedRange()
        let ns = tv.string as NSString
        let selected = sel.length > 0 ? ns.substring(with: sel) : ""
        let replacement = prefix + selected + suffix
        guard tv.shouldChangeText(in: sel, replacementString: replacement) else { return }
        tv.replaceCharacters(in: sel, with: replacement)
        tv.didChangeText()
        let cursorPos = selected.isEmpty
            ? sel.location + (prefix as NSString).length
            : sel.location + (replacement as NSString).length
        tv.setSelectedRange(NSRange(location: cursorPos, length: 0))
    }

    func insertAtCursor(_ text: String) {
        guard let tv = textView else { return }
        let sel = tv.selectedRange()
        guard tv.shouldChangeText(in: sel, replacementString: text) else { return }
        tv.replaceCharacters(in: sel, with: text)
        tv.didChangeText()
        tv.setSelectedRange(NSRange(location: sel.location + (text as NSString).length, length: 0))
    }

    // Returns (selectedText, range) — range is cursor position when nothing is selected
    func captureSelection() -> (text: String, range: NSRange) {
        guard let tv = textView else { return ("", NSRange(location: 0, length: 0)) }
        let sel = tv.selectedRange()
        let text = sel.length > 0 ? (tv.string as NSString).substring(with: sel) : ""
        return (text, sel)
    }

    func replaceRange(_ range: NSRange, with text: String) {
        guard let tv = textView else { return }
        guard tv.shouldChangeText(in: range, replacementString: text) else { return }
        tv.replaceCharacters(in: range, with: text)
        tv.didChangeText()
        tv.setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
    }

    func focus() {
        textView?.window?.makeFirstResponder(textView)
    }
}

// Intercepts Cmd+Return
final class MarkdownNSTextView: NSTextView {
    var onCmdReturn: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && event.modifierFlags.contains(.command) {
            onCmdReturn?()
            return
        }
        super.keyDown(with: event)
    }
}

// NSViewRepresentable that hosts the MarkdownNSTextView
struct MarkdownInnerView: NSViewRepresentable {
    @Binding var text: String
    let bridge: TextEditorBridge
    let placeholder: String
    var focusTrigger: Int
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let tv = MarkdownNSTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 4, height: 6)
        tv.string = text
        tv.drawsBackground = false

        // Placeholder label
        if !placeholder.isEmpty {
            let ph = NSTextField(labelWithString: placeholder)
            ph.textColor = .placeholderTextColor
            ph.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ph.isBordered = false
            ph.drawsBackground = false
            ph.isEditable = false
            ph.tag = 999
            ph.translatesAutoresizingMaskIntoConstraints = false
            tv.addSubview(ph)
            NSLayoutConstraint.activate([
                ph.topAnchor.constraint(equalTo: tv.topAnchor, constant: 6),
                ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: 6)
            ])
            ph.isHidden = !text.isEmpty
        }

        let coord = context.coordinator
        tv.onCmdReturn = { [weak coord] in coord?.parent.onSubmit?() }

        bridge.textView = tv

        let sv = NSScrollView()
        sv.documentView = tv
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.drawsBackground = false
        tv.autoresizingMask = [.width]
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true

        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard let tv = sv.documentView as? MarkdownNSTextView else { return }
        bridge.textView = tv
        context.coordinator.parent = self

        if tv.string != text {
            let sel = tv.selectedRange()
            tv.string = text
            let len = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: min(sel.location, len), length: 0))
        }

        if let ph = tv.viewWithTag(999) as? NSTextField {
            ph.isHidden = !text.isEmpty
        }

        if focusTrigger != context.coordinator.lastFocusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownInnerView
        var lastFocusTrigger: Int = -1

        init(_ parent: MarkdownInnerView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            if let ph = tv.viewWithTag(999) as? NSTextField {
                ph.isHidden = !tv.string.isEmpty
            }
        }
    }
}

// The full editor: toolbar + text view
struct MarkdownTextEditorView: View {
    @Binding var text: String
    var placeholder: String = ""
    var focusTrigger: Int = 0
    var minEditorHeight: CGFloat = 72
    var maxEditorHeight: CGFloat = 120
    var onSubmit: (() -> Void)? = nil

    @Environment(AppModel.self) private var model
    @State private var bridge = TextEditorBridge()
    @State private var showLinkPopover = false
    @State private var linkURL = ""
    @State private var pendingLinkText = ""
    @State private var pendingLinkRange = NSRange(location: 0, length: 0)

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))

            Divider()

            MarkdownInnerView(
                text: $text,
                bridge: bridge,
                placeholder: placeholder,
                focusTrigger: focusTrigger,
                onSubmit: onSubmit
            )
            .frame(minHeight: minEditorHeight, maxHeight: maxEditorHeight)
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 1) {
            toolbarBtn(systemImage: "bold", tip: "Bold") {
                bridge.wrapSelection(prefix: "**", suffix: "**")
            }
            toolbarBtn(systemImage: "italic", tip: "Italic") {
                bridge.wrapSelection(prefix: "*", suffix: "*")
            }
            toolbarBtn(systemImage: "underline", tip: "Underline") {
                bridge.wrapSelection(prefix: "<u>", suffix: "</u>")
            }
            toolbarBtn(systemImage: "strikethrough", tip: "Strikethrough") {
                bridge.wrapSelection(prefix: "~~", suffix: "~~")
            }

            toolbarDivider

            toolbarBtn(systemImage: "link", tip: "Insert Link") {
                let captured = bridge.captureSelection()
                pendingLinkText = captured.text
                pendingLinkRange = captured.range
                linkURL = ""
                showLinkPopover = true
            }
            .popover(isPresented: $showLinkPopover, arrowEdge: .bottom) {
                linkPopover
            }

            toolbarCodeBtn(label: "`", tip: "Inline Code") {
                bridge.wrapSelection(prefix: "`", suffix: "`")
            }
            toolbarCodeBtn(label: "```", tip: "Code Block") {
                bridge.wrapSelection(prefix: "```\n", suffix: "\n```")
            }

            toolbarDivider

            replacementsMenu

            Spacer()
        }
    }

    private func toolbarBtn(systemImage: String, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .padding(3)
        .help(tip)
        .contentShape(Rectangle())
    }

    private func toolbarCodeBtn(label: String, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: 20)
                .padding(.horizontal, 3)
        }
        .buttonStyle(.plain)
        .padding(3)
        .help(tip)
        .contentShape(Rectangle())
    }

    private var toolbarDivider: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var replacementsMenu: some View {
        Menu {
            Section("Built-in Replacements") {
                Button("{dad_joke}") { bridge.insertAtCursor("{dad_joke}") }
                Button("{yesterday}") { bridge.insertAtCursor("{yesterday}") }
                Button("{fun_fact}") { bridge.insertAtCursor("{fun_fact}") }
                Button("{affirmation}") { bridge.insertAtCursor("{affirmation}") }
                Button("{emoji_of_day}") { bridge.insertAtCursor("{emoji_of_day}") }
                Button("{format_date('')}") { bridge.insertAtCursor("{format_date('')}") }
            }
            if !model.customReplacements.isEmpty {
                Divider()
                Section("Custom Replacements") {
                    ForEach(model.customReplacements) { rep in
                        Button(rep.name) { bridge.insertAtCursor(rep.pattern) }
                    }
                }
            }
        } label: {
            Label("Insert Replacement", systemImage: "text.badge.plus")
                .labelStyle(.iconOnly)
                .frame(width: 20, height: 20)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(3)
        .help("Insert Text Replacement")
    }

    private var linkPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insert Link").font(.headline)
            TextField("https://", text: $linkURL)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 280)
                .onSubmit { confirmLink() }
            HStack {
                Spacer()
                Button("Cancel") { showLinkPopover = false }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Insert") { confirmLink() }
                    .buttonStyle(.borderedProminent)
                    .disabled(linkURL.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }

    private func confirmLink() {
        let display = pendingLinkText.isEmpty ? "link" : pendingLinkText
        bridge.replaceRange(pendingLinkRange, with: "[\(display)](\(linkURL))")
        showLinkPopover = false
        linkURL = ""
        bridge.focus()
    }
}
