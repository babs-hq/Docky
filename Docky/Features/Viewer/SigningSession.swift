import PDFKit
import UIKit
import Observation

/// Everything that happens while the user is filling in one document.
/// All positions are in PDF page coordinates (origin bottom-left, y pointing up).
@Observable
final class SigningSession {
    let pdf: PDFDocument

    /// Content waiting to be placed by the user's next tap on the page.
    var pendingContent: FieldContent?

    private(set) var selectedField: FieldAnnotation?

    private let defaultSignatureWidth: CGFloat = 160
    private let defaultInitialsWidth: CGFloat = 60
    private let defaultTextHeight: CGFloat = 18
    private let minimumFieldWidth: CGFloat = 24
    private let minimumFieldHeight: CGFloat = 8

    init(pdf: PDFDocument) {
        self.pdf = pdf
    }

    // MARK: - Placing

    func place(_ content: FieldContent, centeredAt point: CGPoint, on page: PDFPage) {
        let field = FieldAnnotation(content: content, bounds: .zero)
        let size = defaultSize(for: field)
        let frame = CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )

        field.bounds = frame.clamped(to: pageBounds(page))
        page.addAnnotation(field)
        pendingContent = nil
        select(field)
    }

    /// Drawings start at a fixed width; text and checkmarks start at a fixed height (roughly 12pt type).
    private func defaultSize(for field: FieldAnnotation) -> CGSize {
        let ratio = field.aspectRatio
        switch field.content {
        case .signature:
            return CGSize(width: defaultSignatureWidth, height: defaultSignatureWidth / ratio)
        case .initials:
            return CGSize(width: defaultInitialsWidth, height: defaultInitialsWidth / ratio)
        case .text, .date, .checkmark:
            return CGSize(width: defaultTextHeight * ratio, height: defaultTextHeight)
        }
    }

    // MARK: - Selecting

    func select(_ field: FieldAnnotation?) {
        guard field !== selectedField else { return }

        selectedField?.isSelected = false
        selectedField?.setNeedsDisplay()

        field?.isSelected = true
        field?.setNeedsDisplay()

        selectedField = field
    }

    /// The topmost field under `point`. `tolerance` makes small fields easier to grab.
    func field(at point: CGPoint, on page: PDFPage, tolerance: CGFloat) -> FieldAnnotation? {
        page.annotations
            .reversed()
            .compactMap { $0 as? FieldAnnotation }
            .first { $0.bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point) }
    }

    // MARK: - Moving and resizing

    func move(_ field: FieldAnnotation, to origin: CGPoint) {
        guard let page = field.page else { return }
        let moved = CGRect(origin: origin, size: field.bounds.size)
        field.bounds = moved.clamped(to: pageBounds(page))
    }

    func resize(_ field: FieldAnnotation, toWidth proposedWidth: CGFloat) {
        guard let page = field.page else { return }
        let bounds = pageBounds(page)

        let smallestWidth = max(minimumFieldWidth, minimumFieldHeight * field.aspectRatio)
        let width = min(max(proposedWidth, smallestWidth), bounds.maxX - field.bounds.minX)
        let height = width / field.aspectRatio

        // Keep the top-left corner pinned. In page coordinates the top edge is maxY.
        let resized = CGRect(
            x: field.bounds.minX,
            y: field.bounds.maxY - height,
            width: width,
            height: height
        )
        field.bounds = resized.clamped(to: bounds)
    }

    // MARK: - Editing

    func updateSelectedField(with content: FieldContent) {
        guard let field = selectedField, let page = field.page else { return }
        field.updateContent(content)
        field.bounds = field.bounds.clamped(to: pageBounds(page))
        field.setNeedsDisplay()
    }

    // MARK: - Deleting

    func deleteSelectedField() {
        guard let field = selectedField else { return }
        // Shrinking the bounds first makes PDFKit clear the old area; removing alone leaves stale pixels.
        field.bounds = .zero
        field.page?.removeAnnotation(field)
        selectedField = nil
    }

    // MARK: - Helpers

    private func pageBounds(_ page: PDFPage) -> CGRect {
        page.bounds(for: .cropBox)
    }
}
