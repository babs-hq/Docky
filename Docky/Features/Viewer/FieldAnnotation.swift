import PDFKit
import UIKit

/// A field (signature, name, date, or text) placed on a PDF page. Its bounds are in page coordinates.
final class FieldAnnotation: PDFAnnotation {
    private(set) var content: FieldContent
    var isSelected = false

    /// Text is laid out at this size, then scaled to fill the field's bounds.
    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 20),
        .foregroundColor: UIColor.black,
    ]
    private static let textPadding: CGFloat = 2

    init(content: FieldContent, bounds: CGRect) {
        self.content = content
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Size

    /// The size the content looks right at before scaling. Its shape decides the aspect ratio.
    var naturalSize: CGSize {
        if let image = content.image {
            return image.size
        }
        let textSize = (content.displayText ?? "").size(withAttributes: Self.textAttributes)
        return CGSize(
            width: ceil(textSize.width) + Self.textPadding * 2,
            height: ceil(textSize.height) + Self.textPadding * 2
        )
    }

    var aspectRatio: CGFloat {
        naturalSize.width / naturalSize.height
    }

    /// The drag handle used for resizing sits at the bottom-right corner.
    /// PDF page coordinates start at the bottom-left, so "bottom" is minY.
    var resizeHandle: CGPoint {
        CGPoint(x: bounds.maxX, y: bounds.minY)
    }

    // MARK: - Editing

    /// Swaps in new content, keeping the top-left corner and height (so text stays the same size).
    func updateContent(_ newContent: FieldContent) {
        content = newContent
        let height = bounds.height
        bounds = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: height * aspectRatio,
            height: height
        )
    }

    // MARK: - Drawing

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        context.saveGState()

        if let cgImage = content.image?.cgImage {
            context.draw(cgImage, in: bounds)
        } else if let text = content.displayText {
            drawText(text, in: context)
        }

        if isSelected {
            drawSelection(in: context)
        }
        context.restoreGState()
    }

    /// PDFKit only repaints an annotation when it sees a change it understands, like new bounds.
    /// It doesn't know about our own properties (such as `isSelected`), so we re-assign the
    /// bounds to mark this area as needing a repaint.
    func setNeedsDisplay() {
        let currentBounds = bounds
        bounds = .zero
        bounds = currentBounds
    }

    private func drawText(_ text: String, in context: CGContext) {
        let scale = bounds.width / naturalSize.width

        context.saveGState()
        // PDF pages have y pointing up, but text drawing expects y pointing down.
        // Move the origin to the field's top-left corner, then flip y (and scale to fit).
        context.translateBy(x: bounds.minX, y: bounds.maxY)
        context.scaleBy(x: scale, y: -scale)

        UIGraphicsPushContext(context)
        text.draw(
            at: CGPoint(x: Self.textPadding, y: Self.textPadding),
            withAttributes: Self.textAttributes
        )
        UIGraphicsPopContext()

        context.restoreGState()
    }

    private func drawSelection(in context: CGContext) {
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))

        // Keep the handle in proportion on short text fields.
        let handleSize = min(10, bounds.height / 2)
        let handle = CGRect(
            x: bounds.maxX - handleSize,
            y: bounds.minY,
            width: handleSize,
            height: handleSize
        )
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fillEllipse(in: handle)
    }
}
