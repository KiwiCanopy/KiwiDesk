import AppKit
import Testing

@testable import KiwiDeskCore

/// An App Bar group-count badge dims with the icon it hangs on —
/// full ink only while the item is focused or hovered, as the
/// Space Bar's badges read.
@Suite("App Bar badge dims with its item")
@MainActor
struct AppBarBadgeDimTests {
    private func makeView(active: Bool) -> AppBarItemView {
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 32)
        )
        view.configure(
            id: WindowID(1),
            name: "Safari",
            text: "Downloads",
            icon: nil,
            glyph: nil,
            count: 3,
            active: active,
            horizontal: true,
            style: AppBarLook()
        )
        return view
    }

    @Test("An unfocused item's badge takes the icon's dim")
    func unfocusedBadgeDims() {
        let view = makeView(active: false)
        #expect(view.badge.alphaValue < 1)
        #expect(view.badge.alphaValue == view.iconView.alphaValue)
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
