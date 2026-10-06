import AppKit
import Testing

@testable import KiwiDeskCore

/// The shelf border fixture `ShelfBorderDrawingTests` and
/// `ShelfBorderPlateTests` share: a border with a width and a
/// colour no default carries, and the one stroke check.
@MainActor
enum ShelfBorderFixture {
    static let width: CGFloat = 3
    static let color = "#FF000080"

    static func bordered(
        _ shelf: KiwiShelf = KiwiShelf(),
        on: Bool = true
    ) -> KiwiShelf {
        var shelf = shelf
        shelf.border = on
        shelf.borderWidth = width
        shelf.borderColor = color
        return shelf
    }

    static func boxed(glass: Bool) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.backgroundStyle = .boxed
        shelf.liquidGlass = glass
        return shelf
    }

    /// `view` strokes the shelf's border: shown, at the width, in
    /// the colour, on frame `frame`.
    static func expectStroke(
        _ view: NSView,
        frame: CGRect,
        _ comment: Comment? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(!view.isHidden, comment, sourceLocation: sourceLocation)
        #expect(
            view.layer?.borderWidth == width,
            comment,
            sourceLocation: sourceLocation
        )
        #expect(
            view.layer?.borderColor == NSColor(kiwiHex: color).cgColor,
            comment,
            sourceLocation: sourceLocation
        )
        #expect(
            view.layer?.backgroundColor == nil,
            comment,
            sourceLocation: sourceLocation
        )
        #expect(view.frame == frame, comment, sourceLocation: sourceLocation)
    }
}
