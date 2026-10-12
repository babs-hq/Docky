import SwiftUI
import PDFKit

/// Shows the flattened, signed copy exactly as it will be sent, with a Share button.
struct SignedPreviewView: View {
    let file: ExportedFile

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ReadOnlyPDFView(url: file.url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Signed Copy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: file.url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

/// A plain, non-interactive PDF viewer for a file on disk.
private struct ReadOnlyPDFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        PDFView.makeReader(document: PDFDocument(url: url))
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {}
}
