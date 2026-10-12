import CoreGraphics

extension CGRect {
    /// Moves this rectangle (without resizing it) so it sits fully inside `container`.
    func clamped(to container: CGRect) -> CGRect {
        var rect = self
        rect.origin.x = min(max(rect.minX, container.minX), container.maxX - rect.width)
        rect.origin.y = min(max(rect.minY, container.minY), container.maxY - rect.height)
        return rect
    }
}
