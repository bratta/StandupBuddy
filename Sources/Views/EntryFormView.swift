import SwiftUI

struct EntryFormView: View {
    @Environment(AppModel.self) private var model

    @State private var date: Date = .now
    @State private var details: String = ""
    @State private var category: Category = .standup
    @State private var focusTrigger: Int = 0

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

            MarkdownTextEditorView(
                text: $details,
                placeholder: "Details (markdown supported)",
                focusTrigger: focusTrigger,
                minEditorHeight: 72,
                maxEditorHeight: 120,
                onSubmit: addItem
            )
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            focusTrigger += 1
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
        focusTrigger += 1
    }
}
