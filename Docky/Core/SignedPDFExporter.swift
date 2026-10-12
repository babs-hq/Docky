import PDFKit
import UIKit

enum SignedPDFExporter {
    /// Writes a flattened copy of `document` to a temporary file and returns its location.
    /// The original file is never modified. `isSigned` adds " (Signed)" to the file name.
    static func export(_ document: PDFDocument, named name: String, isSigned: Bool) throws -> URL {
        // A unique folder per export lets the file keep a friendly name without clashing.
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fileName = isSigned ? "\(name) (Signed).pdf" : "\(name).pdf"
        let fileURL = folder.appending(path: fileName)
        let data = flatten(document, title: name)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        return fileURL
    }

    /// Draws every page, including the placed fields, into a brand-new PDF.
    /// The fields become part of the page content, so they can no longer be moved or removed.
    static func flatten(_ document: PDFDocument, title: String) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "Docky",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: .zero, format: format)

        return renderer.pdfData { context in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }

                let size = displaySize(of: page)
                context.beginPage(withBounds: CGRect(origin: .zero, size: size), pageInfo: [:])

                let cgContext = context.cgContext
                cgContext.saveGState()
                // UIKit's PDF context has y pointing down; PDF pages expect y pointing up.
                cgContext.translateBy(x: 0, y: size.height)
                cgContext.scaleBy(x: 1, y: -1)
                // Apply the page's crop and rotation once, so the page content and every
                // field are drawn in the same coordinate space. (`page.draw(with:to:)` rotates
                // the content but not our custom fields, which misplaces them on rotated pages.)
                page.transform(cgContext, for: .cropBox)
                if let pageRef = page.pageRef {
                    cgContext.drawPDFPage(pageRef)
                }
                for annotation in page.annotations {
                    annotation.draw(with: .cropBox, in: cgContext)
                }
                cgContext.restoreGState()
            }
        }
    }

    /// The page size as a reader sees it: pages rotated sideways swap width and height.
    private static func displaySize(of page: PDFPage) -> CGSize {
        let size = page.bounds(for: .cropBox).size
        return page.rotation % 180 == 0 ? size : CGSize(width: size.height, height: size.width)
    }
}
