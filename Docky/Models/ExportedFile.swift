import Foundation

/// A copy written to disk, ready to preview and share.
struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
    let isSigned: Bool
}
