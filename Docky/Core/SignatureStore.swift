import UIKit
import Observation

enum SignatureStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "The signature couldn't be converted to an image."
        }
    }
}

/// Saves the user's signature on this device so it can be reused on any document.
@Observable
final class SignatureStore {
    private(set) var signature: UIImage?

    private let fileURL: URL

    init(directory: URL = .applicationSupportDirectory) {
        fileURL = directory.appending(path: "signature.png")
        // percentEncoded: false keeps spaces as spaces ("Application Support"), not "%20".
        signature = UIImage(contentsOfFile: fileURL.path(percentEncoded: false))
    }

    func save(_ image: UIImage) throws {
        guard let data = image.pngData() else {
            throw SignatureStoreError.encodingFailed
        }

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Encrypted on disk and unreadable while the device is locked.
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])

        signature = image
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: fileURL)
        }
        signature = nil
    }
}
