import UIKit

/// What a field placed on a PDF page shows.
enum FieldContent {
    case signature(UIImage)
    case initials(UIImage)
    case text(String)
    case date(Date)
    case checkmark

    /// The drawing a signature or initials field shows, or nil for text-based fields.
    var image: UIImage? {
        switch self {
        case .signature(let image), .initials(let image):
            image
        case .text, .date, .checkmark:
            nil
        }
    }

    /// The words a text-based field draws, or nil for a drawing.
    var displayText: String? {
        switch self {
        case .signature, .initials:
            nil
        case .text(let text):
            text
        case .date(let date):
            date.formatted(date: .long, time: .omitted)
        case .checkmark:
            "✓"
        }
    }

    /// Whether the Edit button applies: text can be retyped and dates re-picked.
    var isEditable: Bool {
        switch self {
        case .text, .date:
            true
        case .signature, .initials, .checkmark:
            false
        }
    }
}
