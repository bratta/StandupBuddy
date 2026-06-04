import SwiftUI

struct APIConsoleView: View {
    private let logger = APILogger.shared
    @State private var showSuccessful = false

    private var filteredEntries: [APILogEntry] {
        showSuccessful ? logger.entries : logger.entries.filter { $0.level != .success }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Show successful requests", isOn: $showSuccessful)
                Spacer()
                Button("Clear") { logger.clear() }
                    .disabled(logger.entries.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if logger.entries.isEmpty {
                ContentUnavailableView {
                    Label("No API Requests", systemImage: "network")
                } description: {
                    Text("No API requests have been logged yet. Try generating a standup.")
                }
            } else if filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label("No Warnings or Errors", systemImage: "checkmark.circle")
                } description: {
                    Text("All \(logger.entries.count) request\(logger.entries.count == 1 ? "" : "s") succeeded. Enable \"Show successful requests\" to see them.")
                }
            } else {
                List(filteredEntries) { entry in
                    APILogEntryRow(entry: entry)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 620, minHeight: 400)
    }
}

private struct APILogEntryRow: View {
    let entry: APILogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.level.systemImage)
                .foregroundStyle(entry.level.color)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.source)
                        .fontWeight(.semibold)

                    Text(entry.method)
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    if let code = entry.statusCode {
                        Text(String(code))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(entry.level.color)
                    }

                    Spacer()

                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(entry.message)
                    .font(.callout)
                    .foregroundStyle(entry.level == .success ? .primary : entry.level.color)
            }
        }
        .padding(.vertical, 3)
    }
}

private extension APILogLevel {
    var systemImage: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
