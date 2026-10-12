import SwiftUI

/// Lets the user draw, redraw, or delete their saved signature and initials.
struct MySignatureView: View {
    @Environment(SignatureStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var kindBeingDrawn: SignatureKind?
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        NavigationStack {
            Form {
                ForEach(SignatureKind.allCases) { kind in
                    Section {
                        slot(for: kind)
                    } header: {
                        Text(kind.title)
                    } footer: {
                        if kind == SignatureKind.allCases.last {
                            Text("Saved on this device only.")
                        }
                    }
                }
            }
            .navigationTitle("Signature & Initials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $kindBeingDrawn) { kind in
                SignaturePadView(title: "Draw \(kind.title)") { image in
                    save(image, as: kind)
                }
                // Swiping down to draw would otherwise close the sheet.
                .interactiveDismissDisabled()
            }
            .alert("Signature Error", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private func slot(for kind: SignatureKind) -> some View {
        if let image = store.image(for: kind) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: kind == .signature ? 110 : 60)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))

            Button("Draw New \(kind.title)") { kindBeingDrawn = kind }
            Button("Delete \(kind.title)", role: .destructive) { delete(kind) }
        } else {
            Button("Draw \(kind.title)", systemImage: "pencil.and.scribble") {
                kindBeingDrawn = kind
            }
        }
    }

    private func save(_ image: UIImage, as kind: SignatureKind) {
        do {
            try store.save(image, as: kind)
        } catch {
            show(error)
        }
    }

    private func delete(_ kind: SignatureKind) {
        do {
            try store.delete(kind)
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
    MySignatureView()
        .environment(SignatureStore())
}
