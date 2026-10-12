import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @State private var isImporterPresented = false
    @State private var openedDocument: OpenedDocument?
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No Documents", systemImage: "doc.text")
            } description: {
                Text("Open a PDF to sign it, add the date, and fill in your name.")
            } actions: {
                Button("Open PDF") {
                    isImporterPresented = true
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Docky")
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.pdf]
            ) { result in
                handleImport(result)
            }
            .navigationDestination(item: $openedDocument) { document in
                DocumentViewerView(document: document)
            }
            .alert("Couldn't Open PDF", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let pdf = try PDFLoader.load(from: url)
            openedDocument = OpenedDocument(
                name: url.deletingPathExtension().lastPathComponent,
                pdf: pdf
            )
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }
}

#Preview {
    HomeView()
        .environment(SignatureStore())
}
