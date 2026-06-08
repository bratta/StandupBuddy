import SwiftUI

struct TextReplacementSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showAddSheet = false
    @State private var editingReplacement: CustomReplacement? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                if model.customReplacements.isEmpty {
                    Text("No custom replacements. Click + to add one.")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(model.customReplacements) { rep in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rep.name).font(.headline)
                                Text("Pattern: \(rep.pattern)").font(.system(size: 12.0, design: .monospaced)).foregroundStyle(.secondary)
                                Text("\(rep.template)").font(.system(size: 18.0, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !rep.enabled {
                                Text("Disabled")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Button("Edit") { editingReplacement = rep }
                                .buttonStyle(.plain)
                                .font(.caption)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await model.deleteReplacement(rep) }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Label("Add Replacement", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .padding()
            }
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
