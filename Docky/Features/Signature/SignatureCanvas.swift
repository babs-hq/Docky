import SwiftUI
import PencilKit

/// Wraps PencilKit's PKCanvasView so SwiftUI can draw with finger or Apple Pencil.
struct SignatureCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.isScrollEnabled = false
        // Signatures are always dark ink on white paper, even in dark mode.
        canvas.backgroundColor = .white
        canvas.overrideUserInterfaceStyle = .light
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Runs when SwiftUI changes the drawing, e.g. after tapping Clear.
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Runs when the user draws: send the new strokes back to SwiftUI.
            drawing = canvasView.drawing
        }
    }
}

extension PKDrawing {
    /// Renders the strokes as a tightly cropped image with black ink.
    func signatureImage() -> UIImage? {
        guard !bounds.isEmpty else { return nil }

        var image: UIImage?
        // Without this, PencilKit renders black ink as white when the app is in dark mode.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = self.image(from: bounds.insetBy(dx: -8, dy: -8), scale: 3)
        }
        return image
    }
}
