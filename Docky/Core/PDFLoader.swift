import Foundation
import PDFKit

enum PDFLoaderError: LocalizedError {
    case unreadable
    case locked

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "This file couldn't be opened as a PDF."
        case .locked:
            "This PDF is password-protected. Password support is coming soon."
        }
    }
}

enum PDFLoader {
    /// Reads a user-picked file into a PDFDocument.
    static func load(from url: URL) throws -> PDFDocument {
        // Files picked outside our sandbox need temporary permission to read.
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Read the bytes now, while we have access, so the document
        // doesn't depend on the file later.
        guard let data = try? Data(contentsOf: url),
              let document = PDFDocument(data: data) else {
            throw PDFLoaderError.unreadable
        }

        guard !document.isLocked else {
            throw PDFLoaderError.locked
        }

        return document
    }
}
