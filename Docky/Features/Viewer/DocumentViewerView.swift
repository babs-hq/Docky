import SwiftUI

struct DocumentViewerView: View {
    let document: OpenedDocument

    @Environment(SignatureStore.self) private var signatureStore
    @Environment(SignatureLock.self) private var signatureLock
    @AppStorage("fullName") private var savedName = ""

    @State private var session: SigningSession
    @State private var isShowingSignature = false
    @State private var textPrompt: TextPrompt?
    @State private var draftText = ""
    @State private var isEditingDate = false
    @State private var dateToEdit = Date.now
    @State private var exportedFile: ExportedFile?
    @State private var exportErrorMessage = ""
    @State private var isShowingExportError = false

    /// The kinds of text the user can be asked to type.
    private enum TextPrompt {
        case name
        case text
        case edit

        var title: String {
            switch self {
            case .name: "Your Full Name"
            case .text: "Add Text"
            case .edit: "Edit Text"
            }
        }

        var confirmLabel: String {
            self == .edit ? "Save" : "Place"
        }

        /// Names capitalize every word ("Ada Lovelace"); other text reads like a sentence.
        var capitalization: TextInputAutocapitalization {
            self == .name ? .words : .sentences
        }
    }

    init(document: OpenedDocument) {
        self.document = document
        _session = State(initialValue: SigningSession(pdf: document.pdf))
    }

    var body: some View {
        PDFKitView(session: session)
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                if let content = session.pendingContent {
                    placementBanner(for: content)
                }
            }
            .safeAreaInset(edge: .bottom) {
                finishButton
            }
            .navigationTitle(document.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $isShowingSignature) {
                MySignatureView()
            }
            .sheet(isPresented: $isEditingDate) {
                DateFieldEditor(date: dateToEdit) { newDate in
                    session.updateSelectedField(with: .date(newDate))
                }
            }
            .alert(
                textPrompt?.title ?? "",
                isPresented: isShowingTextPrompt,
                presenting: textPrompt
            ) { prompt in
                TextField("Type here", text: $draftText)
                    .textInputAutocapitalization(prompt.capitalization)
                Button("Cancel", role: .cancel) {}
                Button(prompt.confirmLabel) {
                    submitText(for: prompt)
                }
            }
            .sheet(item: $exportedFile) { file in
                SignedPreviewView(file: file)
            }
            .alert("Couldn't Create Signed Copy", isPresented: $isShowingExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage)
            }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let field = session.selectedField {
            ToolbarItem(placement: .primaryAction) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    session.deleteSelectedField()
                }
            }
            if field.content.isEditable {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit", systemImage: "pencil") {
                        edit(field)
                    }
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu("Add Field", systemImage: "plus.circle") {
                Button("Signature", systemImage: "signature") {
                    addDrawing(.signature)
                }
                Button("Initials", systemImage: "pencil.line") {
                    addDrawing(.initials)
                }
                Button("Name", systemImage: "person") {
                    draftText = savedName
                    textPrompt = .name
                }
                Button("Date", systemImage: "calendar") {
                    startPlacing(.date(.now))
                }
                Button("Text", systemImage: "textformat") {
                    draftText = ""
                    textPrompt = .text
                }
                Button("Checkmark", systemImage: "checkmark.square") {
                    startPlacing(.checkmark)
                }
                Divider()
                Button("Signature & Initials", systemImage: "pencil.and.scribble") {
                    manageSignature()
                }
            }
        }
    }

    // MARK: - Finish button

    /// Lives outside the toolbar because toolbar buttons show only their icon,
    /// and the screen's main action needs its words.
    private var finishButton: some View {
        Button {
            finish()
        } label: {
            Label("Finish & Share", systemImage: "checkmark.seal")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Placement banner

    private func placementBanner(for content: FieldContent) -> some View {
        HStack {
            Label(placementMessage(for: content), systemImage: "hand.tap")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("Cancel") {
                session.pendingContent = nil
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private func placementMessage(for content: FieldContent) -> String {
        switch content {
        case .signature: "Tap where you want to sign"
        case .initials: "Tap where your initials should go"
        case .text: "Tap where the text should go"
        case .date: "Tap where the date should go"
        case .checkmark: "Tap the box to tick"
        }
    }

    // MARK: - Actions

    private func startPlacing(_ content: FieldContent) {
        session.select(nil)
        session.pendingContent = content
    }

    /// Places the saved signature or initials, asking for Face ID first if the lock is on.
    private func addDrawing(_ kind: SignatureKind) {
        Task {
            guard await signatureLock.unlock() else { return }
            guard let image = signatureStore.image(for: kind) else {
                // Nothing saved yet: ask the user to draw it first.
                isShowingSignature = true
                return
            }
            switch kind {
            case .signature: startPlacing(.signature(image))
            case .initials: startPlacing(.initials(image))
            }
        }
    }

    private func manageSignature() {
        Task {
            guard await signatureLock.unlock() else { return }
            isShowingSignature = true
        }
    }

    private func finish() {
        // Deselect first, or the blue selection border would be flattened into the signed copy.
        session.select(nil)
        session.pendingContent = nil

        do {
            let url = try SignedPDFExporter.export(session.pdf, named: document.name)
            exportedFile = ExportedFile(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
            isShowingExportError = true
        }
    }

    private func edit(_ field: FieldAnnotation) {
        switch field.content {
        case .signature, .initials, .checkmark:
            break
        case .text(let text):
            draftText = text
            textPrompt = .edit
        case .date(let date):
            dateToEdit = date
            isEditingDate = true
        }
    }

    private func submitText(for prompt: TextPrompt) {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        switch prompt {
        case .name:
            savedName = text
            startPlacing(.text(text))
        case .text:
            startPlacing(.text(text))
        case .edit:
            session.updateSelectedField(with: .text(text))
        }
    }

    /// Bridges the optional `textPrompt` to the true/false binding an alert needs.
    private var isShowingTextPrompt: Binding<Bool> {
        Binding(
            get: { textPrompt != nil },
            set: { isShowing in
                if !isShowing { textPrompt = nil }
            }
        )
    }
}
