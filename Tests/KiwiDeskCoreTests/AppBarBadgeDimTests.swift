import AppKit
import Testing

@testable import KiwiDeskCore

/// An App Bar group-count badge dims with its item's focus —
/// full ink only while the item is focused or hovered, as the
/// Space Bar's badges read, whatever the item draws.
@Suite("App Bar badge dims with its item")
@MainActor
struct AppBarBadgeDimTests {
    /// Pinned rather than read off the default (#660).
    private static let dim: CGFloat = 0.4

    private func makeView(
        active: Bool,
        glyph: String? = nil
    ) -> AppBarItemView {
        var style = AppBarLook()
        style.shelf.dimFactor = Self.dim
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 32)
        )
        view.configure(
            id: WindowID(1),
            name: "Safari",
            text: "Downloads",
            icon: nil,
            glyph: glyph,
            count: 3,
            active: active,
            horizontal: true,
            style: style
        )
        return view
    }

    @Test("An unfocused item's badge takes the dim factor")
    func unfocusedBadgeDims() {
        #expect(makeView(active: false).badge.alphaValue == Self.dim)
    }

    @Test("A glyph item's badge dims with its focus too")
    func glyphItemBadgeDims() {
        let view = makeView(active: false, glyph: "A")
        #expect(!view.glyphLabel.isHidden)
        #expect(view.badge.alphaValue == Self.dim)
    }

    @Test("A hovered unfocused item's badge reads full ink")
    func hoveredBadgeLifts() {
        let view = makeView(active: false)
        view.isHovered = true
        view.applyColors()
        #expect(view.badge.alphaValue == 1)
    }

    @Test("A focused item's badge reads full ink")
    func focusedBadgeFull() {
        #expect(makeView(active: true).badge.alphaValue == 1)
    }
}
