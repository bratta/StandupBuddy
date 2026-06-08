import SwiftUI

struct EntryFormView: View {
    @Environment(AppModel.self) private var model

    @State private var date: Date = .now
    @State private var details: String = ""
    @State private var category: Category = .standup
    @FocusState private var detailsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DatePickerButton(selection: $date)

                Picker("Category", selection: $category) {
                    ForEach(Category.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Spacer()

                Button("Add") { addItem() }
                    .buttonStyle(.borderedProminent)
                    .disabled(details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            TextEditor(text: $details)
                .font(.body.monospaced())
                .disableAutocorrection(true)
                .focused($detailsFocused)
                .frame(minHeight: 72, maxHeight: 120)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                .overlay(alignment: .topLeading) {
                    if details.isEmpty && !detailsFocused {
                        Text("Details (markdown supported)")
                            .foregroundStyle(.secondary)
                            .padding(EdgeInsets(top: 12, leading: 10, bottom: 0, trailing: 0))
                            .allowsHitTesting(false)
                    }
                }
                .onKeyPress(phases: .down) { press in
                    guard press.key == .return, press.modifiers.contains(.command) else { return .ignored }
                    addItem()
                    return .handled
                }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            detailsFocused = true
        }
    }

    private func addItem() {
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = StandupItem(date: date, details: trimmed, category: category, completed: false)
        Task { await model.addItem(item) }
        details = ""
        date = .now
        category = .standup
        detailsFocused = true
    }
}
