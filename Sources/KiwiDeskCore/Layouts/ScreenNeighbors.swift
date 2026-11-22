import CoreGraphics

/// Screen adjacency flags for viewport overhang and window parking
/// (#878, #881).
public struct ScreenNeighbors: Sendable, Equatable {
    public var left: Bool
    public var right: Bool
    public var top: Bool
    public var bottom: Bool
    /// The corner a park takes, scored over the screen rects
    /// (`TilingEngine.optimalHideCorner(for:among:)`, #3335);
    /// bottom-right, a lone screen's, where no rects were read.
    var parkCorner: TilingEngine.HideCorner = .bottomRight

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

    /// Neighbors around an area of a split screen (#3517 ruling 31):
    /// the edge flags read the area among every area and unsplit
    /// screen, while the park corner is scored over the PHYSICAL
    /// screens alone, so an area's inner edge never moves a park
    /// (ruling 6).
    public static func detect(
        around area: CGRect,
        among areas: [CGRect],
        parkingOn screen: CGRect,
        among screens: [CGRect]
    ) -> ScreenNeighbors {
        var found = detect(around: area, among: areas)
        found.parkCorner = TilingEngine.optimalHideCorner(
            for: screen,
            among: screens
        )
        return found
    }

    /// Detects screen neighbors around screen in AX visible frame coordinates
    /// (#410, #878), and scores its park corner (#3335).
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
        found.parkCorner = TilingEngine.optimalHideCorner(
            for: screen,
            among: others
        )
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
