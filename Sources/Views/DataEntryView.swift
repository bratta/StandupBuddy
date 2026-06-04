import SwiftUI

struct DataEntryView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedFilter: Category? = nil

    var body: some View {
        VStack(spacing: 0) {
            EntryFormView()
                .padding([.horizontal, .top])

            Divider().padding(.top, 8)

            Picker("Category", selection: $selectedFilter) {
                Text("All").tag(Category?.none)
                ForEach(Category.allCases, id: \.self) { cat in
                    Text(cat.displayName).tag(Category?.some(cat))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: selectedFilter) { _, newValue in
                Task { await model.setFilter(newValue) }
            }

            Divider()

            if model.items.isEmpty {
                ContentUnavailableView("No entries yet", systemImage: "list.bullet.clipboard")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(model.items) { item in
                            EntryRowView(item: item, onEditStart: {
                                proxy.scrollTo(item.id, anchor: .top)
                            })
                            .listRowSeparator(.visible)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: model.totalItemCount) { _, _ in
                        if let firstId = model.items.first?.id {
                            proxy.scrollTo(firstId, anchor: .top)
                        }
                    }
                }

                paginationBar
            }
        }
    }

    private var paginationBar: some View {
        HStack(spacing: 12) {
            Button(action: { Task { await model.goToPage(0) } }) {
                Image(systemName: "chevron.backward.2")
            }
            .disabled(model.currentPage == 0)

            Button(action: { Task { await model.goToPage(model.currentPage - 1) } }) {
                Image(systemName: "chevron.backward")
            }
            .disabled(model.currentPage == 0)

            Text("Page \(model.currentPage + 1) of \(model.pageCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 80)

            Button(action: { Task { await model.goToPage(model.currentPage + 1) } }) {
                Image(systemName: "chevron.forward")
            }
            .disabled(model.currentPage >= model.pageCount - 1)

            Button(action: { Task { await model.goToPage(model.pageCount - 1) } }) {
                Image(systemName: "chevron.forward.2")
            }
            .disabled(model.currentPage >= model.pageCount - 1)
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 6)
        .padding(.horizontal)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
