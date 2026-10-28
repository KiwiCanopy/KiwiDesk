import AppKit
import Testing

@testable import KiwiDeskCore

/// A badge's dim tier: its number's alpha, since its disc stays
/// opaque (`BarBadgeFace`).
extension NSTextField {
    fileprivate var inkAlpha: CGFloat { textColor?.alphaComponent ?? 0 }
}

/// An App Bar group-count badge's number dims with its item — full ink
/// while the item is focused, hovered or fully on screen (#2234),
/// as the icon does, whatever the item draws.
@Suite("App Bar badge dims with its item")
@MainActor
struct AppBarBadgeDimTests {
    /// Pinned rather than read off the default (#660).
    private static let dim: CGFloat = 0.4

    private func makeView(
        active: Bool,
        glyph: String? = nil,
        visibility: BarVisibility = .hidden
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
            visibility: visibility,
            active: active,
            horizontal: true,
            style: style
        )
        return view
    }

    @Test("An unfocused item's badge takes the dim factor")
    func unfocusedBadgeDims() {
        #expect(makeView(active: false).badge.inkAlpha == Self.dim)
    }

    @Test("A glyph item's badge dims with its focus too")
    func glyphItemBadgeDims() {
        let view = makeView(active: false, glyph: "A")
        #expect(!view.glyphLabel.isHidden)
        #expect(view.badge.inkAlpha == Self.dim)
    }

    @Test("Only a fully visible unfocused item's badge is lit")
    func visibleBadgeLifts() {
        let lit = makeView(active: false, visibility: .visible)
        #expect(lit.badge.inkAlpha == 1)
        #expect(lit.iconView.alphaValue == 1)
        let partly = makeView(active: false, visibility: .partly(shown: nil))
        #expect(partly.badge.inkAlpha == Self.dim)
    }

    @Test("A hovered unfocused item's badge reads full ink")
    func hoveredBadgeLifts() {
        let view = makeView(active: false)
        view.isHovered = true
        view.applyColors()
        #expect(view.badge.inkAlpha == 1)
    }

    @Test("A focused item's badge reads full ink")
    func focusedBadgeFull() {
        #expect(makeView(active: true).badge.inkAlpha == 1)
    }

    @Test("A dimmed badge keeps its disc opaque")
    func dimmedDiscStaysOpaque() {
        let view = makeView(active: false)
        #expect(view.badge.inkAlpha == Self.dim)
        #expect(view.badge.alphaValue == 1)
        #expect(view.badge.layer?.borderWidth == BarBadgeFace.rimWidth)
    }
}
