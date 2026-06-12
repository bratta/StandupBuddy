import SwiftUI
import MarkdownUI

private enum OutputTab: String, CaseIterable {
    case text = "Text"
    case preview = "Preview"

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .preview: return "eye"
        }
    }

    // Active label color — neutral for Text, blue-tinted for Preview
    var activeColor: Color {
        switch self {
        case .text: return .textPrimary
        case .preview: return Color(red: 0.612, green: 0.753, blue: 0.961)  // #9CC0F5
        }
    }
}

struct GeneratePreviewSheet: View {
    @Environment(AppModel.self) private var model

    @State private var output: String = ""
    @State private var isLoading: Bool = true
    @State private var error: String? = nil
    @State private var copied: Bool = false
    @State private var selectedTab: OutputTab = .preview

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingContent
            } else if let err = error {
                errorContent(err)
            } else {
                toolbar
                Divider()
                    .overlay(Color.softBorder)
                bodyContent
                Divider()
                    .overlay(Color.softBorder)
                footer
            }
        }
        .task { await generate() }
        .onReceive(NotificationCenter.default.publisher(for: .generateStandup)) { _ in
            Task { await generate() }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ZStack {
            HStack {
                Spacer()
                tabSwitcher
                Spacer()
            }
            HStack {
                Spacer()
                Text("GitHub-Flavored Markdown")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.trailing, 18)
            }
        }
        .padding(.vertical, 12)
        .background(Color.bgRaised)
    }

    private var tabSwitcher: some View {
        HStack(spacing: 3) {
            ForEach(OutputTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(red: 0.188, green: 0.165, blue: 0.157))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.softBorder, lineWidth: 1)
                )
        )
    }

    private func tabButton(for tab: OutputTab) -> some View {
        let isActive = selectedTab == tab
        return Button { selectedTab = tab } label: {
            HStack(spacing: 7) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(isActive ? tab.activeColor : Color.codeText)
            .padding(.vertical, 6)
            .padding(.leading, 13)
            .padding(.trailing, 15)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(LinearGradient(
                            colors: [
                                Color(red: 0.290, green: 0.259, blue: 0.247),
                                Color(red: 0.231, green: 0.200, blue: 0.192)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: isActive)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        switch selectedTab {
        case .text:
            textBody
        case .preview:
            previewBody
        }
    }

    private var textBody: some View {
        ScrollView {
            Text(output)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(Color.codeText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 22)
                .padding(.horizontal, 26)
                .padding(.bottom, 26)
        }
        .background(Color.cardSurface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewBody: some View {
        ScrollView {
            Markdown(output)
                .markdownTheme(.standupOutput)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)
                .padding(.horizontal, 28)
                .padding(.bottom, 30)
        }
        .background(Color.cardSurface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            footerMetaLabel
            Spacer()
            copyButton
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 18)
        .background(Color.bgRaised)
    }

    @ViewBuilder
    private var footerMetaLabel: some View {
        switch selectedTab {
        case .text:
            HStack(spacing: 0) {
                Text("\(output.components(separatedBy: "\n").count)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.codeText)
                Text(" lines · Markdown source")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
        case .preview:
            Text("Rendered preview · links open in browser")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.textTertiary)
        }
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(output, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.7))
                copied = false
            }
        } label: {
            Label(
                copied ? "Copied!" : "Copy to Clipboard",
                systemImage: copied ? "checkmark" : "doc.on.doc"
            )
        }
        .buttonStyle(CopyButtonStyle(isSuccess: copied))
        .disabled(output.isEmpty)
    }

    // MARK: - Loading / Error

    private var loadingContent: some View {
        VStack {
            Spacer()
            ProgressView("Generating...")
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.cardSurface)
    }

    private func errorContent(_ message: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(message)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.cardSurface)
    }

    // MARK: - Generate

    private func generate() async {
        output = ""
        error = nil
        isLoading = true
        guard let dbQueue = model.dbQueue else {
            self.error = "No database available."
            isLoading = false
            return
        }
        let svc = GenerateService(dbQueue: dbQueue)
        do {
            output = try await svc.generate()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Copy Button Style

private struct CopyButtonStyle: ButtonStyle {
    let isSuccess: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .background(
                LinearGradient(
                    colors: isSuccess
                        ? [Color(red: 0.247, green: 0.702, blue: 0.416), Color(red: 0.180, green: 0.620, blue: 0.361)]
                        : [Color(red: 0.231, green: 0.490, blue: 0.902), Color(red: 0.180, green: 0.420, blue: 0.839)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

// MARK: - MarkdownUI Theme

private extension Theme {
    nonisolated(unsafe) static let standupOutput = Theme()
        .text {
            ForegroundColor(.textPrimary)
            FontSize(14)
        }
        .strong {
            FontWeight(.bold)
            ForegroundColor(.amber)
        }
        .link {
            ForegroundColor(.linkBlue)
        }
}
