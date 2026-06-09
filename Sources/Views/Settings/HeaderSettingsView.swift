import SwiftUI
import AppKit

struct HeaderSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
                    GridRow {
                        Text("Default Header")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Custom Header")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, 6)

                    Divider()
                        .gridCellUnsizedAxes(.horizontal)

                    headerRow(
                        placeholder: Setting.previousHeaderDefault,
                        value: model.previousHeader,
                        key: Setting.previousHeaderKey
                    )
                    headerRow(
                        placeholder: Setting.todayHeaderDefault,
                        value: model.todayHeader,
                        key: Setting.todayHeaderKey
                    )
                    headerRow(
                        placeholder: Setting.blockersHeaderDefault,
                        value: model.blockersHeader,
                        key: Setting.blockersHeaderKey
                    )
                    headerRow(
                        placeholder: Setting.openPRsHeaderDefault,
                        value: model.openPRsHeader,
                        key: Setting.openPRsHeaderKey
                    )
                    headerRow(
                        placeholder: Setting.gratitudeHeaderDefault,
                        value: model.gratitudeHeader,
                        key: Setting.gratitudeHeaderKey
                    )
                }
                .padding(.vertical, 4)
            } header: {
                Text("Section Headers")
            } footer: {
                Text("Leave blank to use the default. Text replacements like {yesterday} and {format_date('%A')} are supported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func headerRow(placeholder: String, value: String, key: String) -> some View {
        GridRow {
            Text(placeholder)
                .frame(maxWidth: .infinity, alignment: .leading)
            LeadingTextField(text: Binding(
                get: { value },
                set: { v in Task { await model.setStringSetting(key: key, value: v) } }
            ))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 4)
    }
}

private struct LeadingTextField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBezeled = false
        field.drawsBackground = false
        field.alignment = .left
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) { _text = text }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                text = field.stringValue
            }
        }
    }
}
