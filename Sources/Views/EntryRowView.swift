import SwiftUI

struct EntryRowView: View {
    @Environment(AppModel.self) private var model
    var item: StandupItem

    @State private var editedDetails: String
    @State private var editedDate: Date
    @State private var editedCategory: Category
    @State private var editedCompleted: Bool
    @State private var isEditing: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var editFocusTrigger: Int = 0

    var onEditStart: () -> Void = {}

    init(item: StandupItem, onEditStart: @escaping () -> Void = {}) {
        self.item = item
        self.onEditStart = onEditStart
        _editedDetails = State(initialValue: item.details)
        _editedDate = State(initialValue: item.date)
        _editedCategory = State(initialValue: item.category)
        _editedCompleted = State(initialValue: item.completed)
    }

    var body: some View {
        Group {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
        .onChange(of: isEditing) { _, editing in
            if editing { onEditStart() }
        }
        .contextMenu {
            Button("Edit") { isEditing = true }
            Divider()
            Button("Delete", role: .destructive) {
                Task { await model.deleteItem(item) }
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await model.deleteItem(item) } }
        } message: {
            Text(item.details)
        }
    }

    private var displayView: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.completed ? .green : .secondary)
                .onTapGesture { toggleCompleted() }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.details)
                    .font(.body)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    Text(item.date.formatted(.dateTime.month(.wide).day().year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(categoryColor.opacity(0.15))
                        .foregroundStyle(categoryColor)
                        .cornerRadius(3)
                }
            }

            Spacer()

            Button("Edit") { isEditing = true }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var editingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DatePickerButton(selection: $editedDate)

                Picker("", selection: $editedCategory) {
                    ForEach(Category.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Toggle("Completed", isOn: $editedCompleted)
                    .toggleStyle(.checkbox)

                Spacer()

                Button("Delete", role: .destructive) { showDeleteConfirm = true }
                    .buttonStyle(.bordered)

                Button("Save") { saveEdit() }
                    .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    editedDetails = item.details
                    editedDate = item.date
                    editedCategory = item.category
                    editedCompleted = item.completed
                    isEditing = false
                }
                .buttonStyle(.bordered)
            }

            MarkdownTextEditorView(
                text: $editedDetails,
                focusTrigger: editFocusTrigger,
                minEditorHeight: 60,
                maxEditorHeight: 160,
                onSubmit: saveEdit
            )
            .onAppear { editFocusTrigger += 1 }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch item.category {
        case .standup: return .blue
        case .blocker: return .red
        case .gratitude: return .green
        }
    }

    private func toggleCompleted() {
        var updated = item
        updated.completed = !item.completed
        Task { await model.updateItem(updated) }
    }

    private func saveEdit() {
        var updated = item
        updated.details = editedDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.date = editedDate
        updated.category = editedCategory
        updated.completed = editedCompleted
        Task { await model.updateItem(updated) }
        isEditing = false
    }
}
