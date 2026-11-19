import Foundation

/// A screen as a label names it (#2792): its own name, and its
/// position where another connected screen shares that name
/// (`ScreenShiftPlan.namePositions`), which the GUI words as
/// "Twin (left)" — twins are named by position everywhere
/// (#3502).
public struct ScreenLabel: Sendable, Equatable {
    public let name: String
    /// Nil while the name is unique among the connected screens.
    public let twinPosition: ScreenNamePosition?

    public init(name: String, twinPosition: ScreenNamePosition? = nil) {
        self.name = name
        self.twinPosition = twinPosition
    }
}
