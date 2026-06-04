import SwiftUI

struct GitHubSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var pat: String = ""
    @State private var patSaved: Bool = false
    @State private var patError: String? = nil
    @State private var showAddRepo = false
    @State private var editingRepo: RepositoryConfig? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Personal Access Token") {
                    HStack {
                        SecureField("Paste your GitHub PAT here", text: $pat)
                            .textFieldStyle(.roundedBorder)
                        Button(patSaved ? "Saved!" : "Save") { savePAT() }
                            .buttonStyle(.borderedProminent)
                            .disabled(pat.isEmpty)
                    }
                    if let err = patError {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                    Button("Clear Token", role: .destructive) { clearPAT() }
                        .font(.caption)
                }
            }
            .formStyle(.grouped)

            Divider()

            Text("Repositories")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            List {
                if model.repos.isEmpty {
                    Text("No repositories. Click + to add one.")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(model.repos) { repo in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.displayName).font(.headline)
                                Text("\(repo.owner)/\(repo.name)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Edit") { editingRepo = repo }
                                .buttonStyle(.plain)
                                .font(.caption)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await model.deleteRepo(repo) }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                Spacer()
                Button(action: { showAddRepo = true }) {
                    Label("Add Repository", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
        .sheet(isPresented: $showAddRepo) {
            RepoFormSheet(repo: nil) { r in Task { await model.addRepo(r) } }
        }
        .sheet(item: $editingRepo) { repo in
            RepoFormSheet(repo: repo) { r in Task { await model.updateRepo(r) } }
        }
        .task { loadPAT() }
    }

    private func loadPAT() {
        pat = (try? KeychainService.loadPAT()) ?? ""
    }

    private func savePAT() {
        do {
            try KeychainService.savePAT(pat)
            patError = nil
            patSaved = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                patSaved = false
            }
        } catch {
            patError = error.localizedDescription
        }
    }

    private func clearPAT() {
        KeychainService.deletePAT()
        pat = ""
        patSaved = false
    }
}

struct RepoFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let repo: RepositoryConfig?
    let onSave: (RepositoryConfig) -> Void

    @State private var owner: String
    @State private var name: String
    @State private var displayName: String
    @State private var sortOrder: Int

    init(repo: RepositoryConfig?, onSave: @escaping (RepositoryConfig) -> Void) {
        self.repo = repo
        self.onSave = onSave
        _owner = State(initialValue: repo?.owner ?? "")
        _name = State(initialValue: repo?.name ?? "")
        _displayName = State(initialValue: repo?.displayName ?? "")
        _sortOrder = State(initialValue: repo?.sortOrder ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(repo == nil ? "Add Repository" : "Edit Repository")
                .font(.title2).bold()

            Form {
                TextField("Owner (e.g. octocat)", text: $owner)
                TextField("Repository name (e.g. hello-world)", text: $name)
                TextField("Display name (e.g. Hello World)", text: $displayName)
                TextField("Sort Order", value: $sortOrder, format: .number)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(owner.isEmpty || name.isEmpty || displayName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func save() {
        var r = repo ?? RepositoryConfig()
        r.owner = owner
        r.name = name
        r.displayName = displayName
        r.sortOrder = sortOrder
        onSave(r)
        dismiss()
    }
}
