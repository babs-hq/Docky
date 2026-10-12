import PDFKit
import UIKit
import VisionKit

enum ScannedPDFBuilderError: LocalizedError {
    case emptyScan

    var errorDescription: String? {
        switch self {
        case .emptyScan:
            "The scan didn't contain any pages."
        }
    }
}

/// Turns scanned page photos into a PDF that the rest of Docky treats like any opened file.
enum ScannedPDFBuilder {
    /// US Letter width in points. Each page keeps its scanned shape.
    private static let pageWidth: CGFloat = 612

    static func makePDF(from scan: VNDocumentCameraScan) throws -> PDFDocument {
        let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
        return try makePDF(from: images)
    }

    static func makePDF(from images: [UIImage]) throws -> PDFDocument {
        let document = PDFDocument()
        for image in images where image.size.width > 0 {
            let pageHeight = pageWidth * image.size.height / image.size.width
            let options: [PDFPage.ImageInitializationOption: Any] = [
                .mediaBox: NSValue(cgRect: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)),
                .upscaleIfSmaller: true,
                // Keeps a multi-page scan to a size that's easy to email.
                .compressionQuality: 0.7,
            ]
            if let page = PDFPage(image: image, options: options) {
                document.insert(page, at: document.pageCount)
            }
        }

        // Save and reload, so scanned pages are real PDF pages, exactly like a file opened from Files.
        guard document.pageCount > 0,
              let data = document.dataRepresentation(),
              let reloaded = PDFDocument(data: data) else {
            throw ScannedPDFBuilderError.emptyScan
        }
        return reloaded
    }
}
