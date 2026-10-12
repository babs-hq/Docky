import SwiftUI
import PDFKit

/// Wraps PDFKit's UIKit-based PDFView so SwiftUI can display it,
/// and turns touches into signing actions.
struct PDFKitView: UIViewRepresentable {
    let session: SigningSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView.makeReader(document: session.pdf)
        context.coordinator.attachGestures(to: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Only swap documents if SwiftUI hands us a different one.
        if pdfView.document !== session.pdf {
            pdfView.document = session.pdf
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let session: SigningSession
        private weak var pdfView: PDFView?
        private weak var dragGesture: UIPanGestureRecognizer?
        private var activeDrag: ActiveDrag?

        private enum DragKind {
            case move(grabOffset: CGSize)
            case resize
        }

        private struct ActiveDrag {
            let field: FieldAnnotation
            let kind: DragKind
        }

        init(session: SigningSession) {
            self.session = session
        }

        func attachGestures(to pdfView: PDFView) {
            self.pdfView = pdfView

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.delegate = self
            pdfView.addGestureRecognizer(tap)

            let drag = UIPanGestureRecognizer(target: self, action: #selector(handleDrag))
            drag.delegate = self
            pdfView.addGestureRecognizer(drag)
            dragGesture = drag

            // A touch that becomes a drag must never also count as a tap.
            tap.require(toFail: drag)
        }

        // MARK: - Gestures

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let (page, point) = pageLocation(at: gesture.location(in: pdfView)) else { return }

            if let content = session.pendingContent {
                session.place(content, centeredAt: point, on: page)
            } else {
                session.select(session.field(at: point, on: page, tolerance: touchTolerance))
            }
        }

        @objc private func handleDrag(_ gesture: UIPanGestureRecognizer) {
            guard let pdfView else { return }

            switch gesture.state {
            case .began:
                guard let (page, start) = pageLocation(at: dragStartPoint(of: gesture)),
                      let field = session.field(at: start, on: page, tolerance: touchTolerance) else { return }

                session.select(field)
                if isNearResizeHandle(start, of: field) {
                    activeDrag = ActiveDrag(field: field, kind: .resize)
                } else {
                    let offset = CGSize(
                        width: start.x - field.bounds.minX,
                        height: start.y - field.bounds.minY
                    )
                    activeDrag = ActiveDrag(field: field, kind: .move(grabOffset: offset))
                }

            case .changed:
                guard let activeDrag, let page = activeDrag.field.page else { return }
                // Convert using the field's own page so it never jumps to a neighbouring page.
                let point = pdfView.convert(gesture.location(in: pdfView), to: page)

                switch activeDrag.kind {
                case .move(let grabOffset):
                    let origin = CGPoint(x: point.x - grabOffset.width, y: point.y - grabOffset.height)
                    session.move(activeDrag.field, to: origin)
                case .resize:
                    session.resize(activeDrag.field, toWidth: point.x - activeDrag.field.bounds.minX)
                }

            default:
                activeDrag = nil
            }
        }

        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let drag = gestureRecognizer as? UIPanGestureRecognizer, drag === dragGesture else {
                return true
            }
            // Only drag when the finger starts on a field; otherwise let the PDF scroll.
            guard let (page, start) = pageLocation(at: dragStartPoint(of: drag)) else { return false }
            return session.field(at: start, on: page, tolerance: touchTolerance) != nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // PDFView's scrolling waits until we've decided whether this is a field drag.
            gestureRecognizer === dragGesture && otherGestureRecognizer is UIPanGestureRecognizer
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Let our tap work alongside PDFView's built-in taps.
            gestureRecognizer is UITapGestureRecognizer
        }

        // MARK: - Coordinate helpers

        /// Converts a point in screen (view) coordinates into a page and a point on that page.
        private func pageLocation(at viewPoint: CGPoint) -> (PDFPage, CGPoint)? {
            guard let pdfView, let page = pdfView.page(for: viewPoint, nearest: true) else { return nil }
            return (page, pdfView.convert(viewPoint, to: page))
        }

        /// A pan only reports itself after the finger has moved a little,
        /// so step back by the translation to find where the touch began.
        private func dragStartPoint(of gesture: UIPanGestureRecognizer) -> CGPoint {
            let location = gesture.location(in: pdfView)
            let translation = gesture.translation(in: pdfView)
            return CGPoint(x: location.x - translation.x, y: location.y - translation.y)
        }

        /// About 16 screen points, converted to page units so it feels the same at any zoom.
        private var touchTolerance: CGFloat {
            16 / (pdfView?.scaleFactor ?? 1)
        }

        private func isNearResizeHandle(_ point: CGPoint, of field: FieldAnnotation) -> Bool {
            let handle = field.resizeHandle
            return hypot(point.x - handle.x, point.y - handle.y) < touchTolerance * 1.5
        }
    }
}
