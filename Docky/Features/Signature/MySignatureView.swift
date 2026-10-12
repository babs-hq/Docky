import SwiftUI

struct MySignatureView: View {
    @Environment(SignatureStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isDrawing = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        NavigationStack {
            Group {
                if let signature = store.signature {
                    VStack(spacing: 20) {
                        Image(uiImage: signature)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 140)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))

                        Text("Saved on this device only.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Draw New Signature") { isDrawing = true }
                            .buttonStyle(.bordered)

                        Button("Delete Signature", role: .destructive) { delete() }

                        Spacer()
                    }
                    .padding()
                } else {
                    ContentUnavailableView {
                        Label("No Signature", systemImage: "signature")
                    } description: {
                        Text("Draw your signature once and reuse it on any document.")
                    } actions: {
                        Button("Draw Signature") { isDrawing = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("My Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isDrawing) {
                SignaturePadView { image in
                    save(image)
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

    private func save(_ image: UIImage) {
        do {
            try store.save(image)
        } catch {
            show(error)
        }
    }

    private func delete() {
        do {
            try store.delete()
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
