import CoreGraphics

/// Where the pocket sits (#2678): on KiwiShelf, since it is a
/// section of the shelf on a bar's edge and a handle on an empty
/// one.
extension KiwiShelf {
    static let defaultPocketPosition: CGFloat = 82

    /// `value` within 0...100; a non-finite one takes the default.
    public static func clampPocketPosition(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, min(value, 100)) : defaultPocketPosition
    }

    /// Whether the pocket takes the end of a bar's edge rather
    /// than its start: 50 % and above lean to the end.
    public var pocketLeansEnd: Bool { pocketPosition >= 50 }

    /// The depth of the pocket's handle at rest (#2784): a whole
    /// point, which lands on a pixel at 1x and 2x. A bar's handle
    /// is its own hairline (`ShelfHandleSpec.depth(of:)`, #3349).
    public static let hiddenDepth: CGFloat = 11

    /// What the pocket's handle reserves (#2784): the shelf's own
    /// rule with the handle's depth in place of `thickness`, so its
    /// windows stand their outer gap clear of the kiwis.
    public var hiddenReservation: CGFloat {
        outerMargin + Self.hiddenDepth + innerMargin
    }
}
