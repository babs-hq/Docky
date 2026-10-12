import SwiftUI
import PencilKit

struct SignaturePadView: View {
    var onSave: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack(alignment: .bottom) {
                    SignatureCanvas(drawing: $drawing)

                    VStack(spacing: 6) {
                        Rectangle()
                            .fill(.gray.opacity(0.4))
                            .frame(height: 1)
                        Text("Sign above the line")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .allowsHitTesting(false)
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.separator)
                }

                Text("Use your finger or Apple Pencil.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Draw Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                        .disabled(drawing.strokes.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear", role: .destructive) {
                        drawing = PKDrawing()
                    }
                    .disabled(drawing.strokes.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let image = drawing.signatureImage() {
            onSave(image)
        }
        dismiss()
    }
}

#Preview {
    SignaturePadView { _ in }
}
