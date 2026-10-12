import Foundation
import PDFKit

/// A PDF the user has opened, ready to view and sign.
struct OpenedDocument: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let pdf: PDFDocument
}
