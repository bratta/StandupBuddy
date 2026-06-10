import SwiftUI

struct GeneratePreviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var output: String = ""
    @State private var isLoading: Bool = true
    @State private var error: String? = nil
    @State private var copied: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Standup Output")
                    .font(.title2)
                    .bold()
            }
            .padding()

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Generating...")
                Spacer()
            } else if let err = error {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(err)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    Text(output)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }

            Divider()

            HStack {
                Spacer()
                Button(copied ? "Copied!" : "Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || output.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .task { await generate() }
        .onReceive(NotificationCenter.default.publisher(for: .generateStandup)) { _ in
            Task { await generate() }
        }
    }

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
