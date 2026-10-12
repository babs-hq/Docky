import PDFKit

extension PDFView {
    /// A PDFView set up for comfortable reading: fit to width, scrolling top to bottom.
    static func makeReader(document: PDFDocument?) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .secondarySystemBackground
        pdfView.document = document
        return pdfView
    }
}
