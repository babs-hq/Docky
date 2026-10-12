import UIKit

/// What a field placed on a PDF page shows.
enum FieldContent {
    case image(UIImage)
    case text(String)
    case date(Date)

    /// The words a text-based field draws, or nil for an image.
    var displayText: String? {
        switch self {
        case .image:
            nil
        case .text(let text):
            text
        case .date(let date):
            date.formatted(date: .long, time: .omitted)
        }
    }
}
