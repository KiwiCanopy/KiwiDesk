import CoreGraphics

/// Screen adjacency flags for viewport overhang and window parking
/// (#878, #881).
public struct ScreenNeighbors: Sendable, Equatable {
    public var left: Bool
    public var right: Bool
    public var top: Bool
    public var bottom: Bool

    public init(
        left: Bool = false,
        right: Bool = false,
        top: Bool = false,
        bottom: Bool = false
    ) {
        self.left = left
        self.right = right
        self.top = top
        self.bottom = bottom
    }

    /// Detects screen neighbors around screen in AX visible frame coordinates
    /// (#410, #878).
    public static func detect(
        around screen: CGRect,
        among others: [CGRect]
    ) -> ScreenNeighbors {
        func overlapsY(_ other: CGRect) -> Bool {
            other.minY < screen.maxY && other.maxY > screen.minY
        }
        func overlapsX(_ other: CGRect) -> Bool {
            other.minX < screen.maxX && other.maxX > screen.minX
        }
        var found = ScreenNeighbors()
        for other in others {
            if other.maxX <= screen.minX + 1, overlapsY(other) {
                found.left = true
            }
            if other.minX >= screen.maxX - 1, overlapsY(other) {
                found.right = true
            }
            if other.maxY <= screen.minY + 1, overlapsX(other) {
                found.top = true
            }
            if other.minY >= screen.maxY - 1, overlapsX(other) {
                found.bottom = true
            }
        }
        return found
    }
}
