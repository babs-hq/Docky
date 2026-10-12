import SwiftUI

struct DocumentViewerView: View {
    let document: OpenedDocument

    @Environment(SignatureStore.self) private var signatureStore
    @AppStorage("fullName") private var savedName = ""

    @State private var session: SigningSession
    @State private var isShowingSignature = false
    @State private var textPrompt: TextPrompt?
    @State private var draftText = ""
    @State private var isEditingDate = false
    @State private var dateToEdit = Date.now

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
            if field.content.displayText != nil {
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
                    addSignature()
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
                Divider()
                Button("Manage Signature", systemImage: "pencil.and.scribble") {
                    isShowingSignature = true
                }
            }
        }
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
        case .image: "Tap where you want to sign"
        case .text: "Tap where the text should go"
        case .date: "Tap where the date should go"
        }
    }

    // MARK: - Actions

    private func startPlacing(_ content: FieldContent) {
        session.select(nil)
        session.pendingContent = content
    }

    private func addSignature() {
        guard let signature = signatureStore.signature else {
            // No saved signature yet: ask the user to draw one first.
            isShowingSignature = true
            return
        }
        startPlacing(.image(signature))
    }

    private func edit(_ field: FieldAnnotation) {
        switch field.content {
        case .image:
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
