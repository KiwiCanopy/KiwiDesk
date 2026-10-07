import AppKit
import Testing

@testable import KiwiDeskCore

/// An unfocused App Bar item's text dims the way an idle Space
/// identifier does — the shelf's one `idleItemColor` (#1938),
/// on the title and the App Font glyph alike.
@Suite("App Bar idle text takes the Space Bar's idle ink")
@MainActor
struct AppBarIdleInkTests {
    private func makeView(
        active: Bool,
        glyph: String? = nil
    ) -> AppBarItemView {
        var style = AppBarLook()
        style.shelf.itemColor = "#EAF3EE"
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 32)
        )
        view.configure(
            id: WindowID(1),
            name: "Safari",
            text: "Downloads",
            icon: nil,
            glyph: glyph,
            count: 1,
            active: active,
            horizontal: true,
            style: style
        )
        return view
    }

    @Test("An unfocused item's title and glyph draw the idle ink")
    func unfocusedTextIsIdleInk() throws {
        for glyph in [nil, "A"] as [String?] {
            let view = makeView(active: false, glyph: glyph)
            let idle = NSColor(kiwiHex: view.style.idleItemColor)
            #expect(view.label.textColor == idle)
            #expect(view.glyphLabel.textColor == idle)
            #expect(
                view.label.textColor
                    != NSColor(kiwiHex: view.style.itemColor)
            )
        }
    }

    @Test("A focused or hovered item keeps its own ink")
    func focusedAndHoveredStayFull() {
        let focused = makeView(active: true)
        #expect(
            focused.label.textColor
                == NSColor(kiwiHex: focused.style.activeItemColor)
        )
        let hovered = makeView(active: false)
        hovered.isHovered = true
        hovered.applyColors()
        #expect(
            hovered.label.textColor
                == NSColor(kiwiHex: hovered.style.hoverItemColor)
        )
    }
}
