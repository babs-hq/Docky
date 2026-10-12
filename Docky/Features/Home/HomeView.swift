import SwiftUI
import UniformTypeIdentifiers
import VisionKit

struct HomeView: View {
    @State private var isImporterPresented = false
    @State private var openedDocument: OpenedDocument?
    @State private var errorMessage = ""
    @State private var isShowingError = false
    @State private var isShowingSettings = false
    @State private var isScannerPresented = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No Documents", systemImage: "doc.text")
            } description: {
                Text("Open a PDF or scan a paper document to sign it, add the date, and fill in your name.")
            } actions: {
                Button("Open PDF") {
                    isImporterPresented = true
                }
                .buttonStyle(.borderedProminent)

                // Hidden on devices without a usable camera, including the Simulator.
                if VNDocumentCameraViewController.isSupported {
                    Button("Scan Document", systemImage: "doc.viewfinder") {
                        isScannerPresented = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .fullScreenCover(isPresented: $isScannerPresented) {
                DocumentScannerView(
                    onFinish: { scan in
                        isScannerPresented = false
                        openScan(scan)
                    },
                    onCancel: {
                        isScannerPresented = false
                    },
                    onError: { error in
                        isScannerPresented = false
                        show(error)
                    }
                )
                .ignoresSafeArea()
            }
            .navigationTitle("Docky")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
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
        // A PDF sent from another app, e.g. Mail → Share → Docky.
        .onOpenURL { url in
            open(url)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            open(url)
        case .failure(let error):
            show(error)
        }
    }

    /// The one place a PDF gets opened, whether it came from the file picker or another app.
    private func open(_ url: URL) {
        do {
            let pdf = try PDFLoader.load(from: url)
            openedDocument = OpenedDocument(
                name: url.deletingPathExtension().lastPathComponent,
                pdf: pdf
            )
        } catch {
            show(error)
        }
    }

    private func openScan(_ scan: VNDocumentCameraScan) {
        do {
            let pdf = try ScannedPDFBuilder.makePDF(from: scan)
            // e.g. "Scan Oct 12, 2026" (follows the device's region). No "/" or ":", so it's safe as a file name.
            let date = Date.now.formatted(.dateTime.day().month(.abbreviated).year())
            openedDocument = OpenedDocument(name: "Scan \(date)", pdf: pdf)
        } catch {
            show(error)
        }
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}

#Preview {
    HomeView()
        .environment(SignatureStore())
        .environment(SignatureLock())
}
