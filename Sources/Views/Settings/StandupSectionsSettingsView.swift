import SwiftUI
import AppKit

struct StandupSectionsSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
                    GridRow {
                        Text("Show")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(alignment: .center)
                        Text("Section")
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

                    sectionRow(
                        placeholder: Setting.previousHeaderDefault,
                        value: model.previousHeader,
                        headerKey: Setting.previousHeaderKey,
                        enabled: model.previousEnabled,
                        enabledKey: Setting.previousEnabledKey
                    )
                    sectionRow(
                        placeholder: Setting.todayHeaderDefault,
                        value: model.todayHeader,
                        headerKey: Setting.todayHeaderKey,
                        enabled: model.todayEnabled,
                        enabledKey: Setting.todayEnabledKey
                    )
                    sectionRow(
                        placeholder: Setting.blockersHeaderDefault,
                        value: model.blockersHeader,
                        headerKey: Setting.blockersHeaderKey,
                        enabled: model.blockersEnabled,
                        enabledKey: Setting.blockersEnabledKey
                    )
                    sectionRow(
                        placeholder: Setting.openPRsHeaderDefault,
                        value: model.openPRsHeader,
                        headerKey: Setting.openPRsHeaderKey,
                        enabled: model.openPRsEnabled,
                        enabledKey: Setting.openPRsEnabledKey
                    )
                    sectionRow(
                        placeholder: Setting.gratitudeHeaderDefault,
                        value: model.gratitudeHeader,
                        headerKey: Setting.gratitudeHeaderKey,
                        enabled: model.gratitudeEnabled,
                        enabledKey: Setting.gratitudeEnabledKey
                    )
                }
                .padding(.vertical, 4)
            } header: {
                Text("Standup Sections")
            } footer: {
                Text("Disabled sections are hidden from the preview and excluded from generated standups. Leave the custom header blank to use the default. Text replacements like {yesterday} and {format_date('%A')} are supported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func sectionRow(placeholder: String, value: String, headerKey: String, enabled: Bool, enabledKey: String) -> some View {
        GridRow {
            Toggle("", isOn: Binding(
                get: { enabled },
                set: { v in Task { await model.setSetting(key: enabledKey, value: v) } }
            ))
            .labelsHidden()
            .frame(alignment: .center)

            Text(placeholder)
                .foregroundStyle(enabled ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LeadingTextField(text: Binding(
                get: { value },
                set: { v in Task { await model.setStringSetting(key: headerKey, value: v) } }
            ))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .opacity(enabled ? 1 : 0.4)
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
