import UIKit
import Observation

enum SignatureStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "The drawing couldn't be converted to an image."
        }
    }
}

/// The handwritten marks a user can save and reuse.
enum SignatureKind: String, CaseIterable, Identifiable {
    case signature
    case initials

    var id: Self { self }

    var title: String {
        switch self {
        case .signature: "Signature"
        case .initials: "Initials"
        }
    }

    /// "signature.png" keeps the same name as before, so existing saved signatures still load.
    var fileName: String {
        "\(rawValue).png"
    }
}

/// Saves the user's signature and initials on this device so they can be reused on any document.
@Observable
final class SignatureStore {
    private(set) var images: [SignatureKind: UIImage] = [:]

    private let directory: URL

    init(directory: URL = .applicationSupportDirectory) {
        self.directory = directory
        for kind in SignatureKind.allCases {
            // percentEncoded: false keeps spaces as spaces ("Application Support"), not "%20".
            images[kind] = UIImage(contentsOfFile: fileURL(for: kind).path(percentEncoded: false))
        }
    }

    var signature: UIImage? { images[.signature] }
    var initials: UIImage? { images[.initials] }

    func image(for kind: SignatureKind) -> UIImage? {
        images[kind]
    }

    func save(_ image: UIImage, as kind: SignatureKind) throws {
        guard let data = image.pngData() else {
            throw SignatureStoreError.encodingFailed
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Encrypted on disk and unreadable while the device is locked.
        try data.write(to: fileURL(for: kind), options: [.atomic, .completeFileProtection])

        images[kind] = image
    }

    func delete(_ kind: SignatureKind) throws {
        let url = fileURL(for: kind)
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: url)
        }
        images[kind] = nil
    }

    private func fileURL(for kind: SignatureKind) -> URL {
        directory.appending(path: kind.fileName)
    }
}
