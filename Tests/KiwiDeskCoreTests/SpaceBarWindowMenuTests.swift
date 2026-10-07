import AppKit
import Testing

@testable import KiwiDeskCore

/// The rows `SpaceBarWindowMenu.make` builds (#1528, #1947): a
/// glyph's rows are one app's titles under an app header; `+n`'s
/// mix apps and name each. The click routing is
/// `SpaceBarGlyphClickTests`'.
@Suite("Space bar window menu rows")
@MainActor
struct SpaceBarWindowMenuTests {
    private static func row(
        _ window: WindowID,
        app: String,
        title: String,
        icon: NSImage?,
        enabled: Bool
    ) -> SpaceBarWindowMenu.Row {
        SpaceBarWindowMenu.Row(
            row: BarWindowRow(
                window: window,
                pid: 1,
                app: app,
                title: title,
                icon: icon
            ),
            enabled: enabled
        )
    }

    @Test("A long title is cut in the row and whole in its tooltip")
    func longTitleIsCut() {
        LocalizationManager.shared.select("en")
        let long = String(
            repeating: "x",
            count: SpaceBarWindowMenu.titleCap + 5
        )
        let row = Self.row(
            WindowID(9),
            app: "Web",
            title: long,
            icon: nil,
            enabled: false
        )
        let menu = SpaceBarWindowMenu.make([row], kind: .overflow) {
            _ in
        }
        let item = menu.items[0]
        #expect(item.title.hasSuffix("…"))
        #expect(item.toolTip == long)
        #expect(!item.isEnabled)
        let short = SpaceBarWindowMenu.make(
            [
                Self.row(
                    WindowID(9),
                    app: "Web",
                    title: "",
                    icon: nil,
                    enabled: true
                )
            ],
            kind: .overflow
        ) { _ in }
        #expect(short.items[0].isEnabled)
        #expect(short.items[0].title == "Web")
        #expect(short.items[0].toolTip == nil)
        let titled = SpaceBarWindowMenu.make(
            [
                Self.row(
                    WindowID(9),
                    app: "Web",
                    title: "Inbox",
                    icon: nil,
                    enabled: true
                )
            ],
            kind: .overflow
        ) { _ in }
        #expect(titled.items[0].toolTip == nil)
    }

    @Test("A glyph's untitled window takes a placeholder row")
    func untitledGlyphRow() {
        LocalizationManager.shared.select("en")
        let menu = SpaceBarWindowMenu.make(
            [
                Self.row(
                    WindowID(9),
                    app: "Web",
                    title: "",
                    icon: NSImage(size: NSSize(width: 32, height: 32)),
                    enabled: true
                )
            ],
            kind: .glyph
        ) { _ in }
        #expect(menu.items.map(\.title) == ["Web", "Untitled Window"])
        #expect(menu.items[1].image == nil)
    }

    @Test("A glyph row caps a long title, whole in its tooltip")
    func glyphRowCapsALongTitle() {
        LocalizationManager.shared.select("en")
        let long = String(
            repeating: "x",
            count: SpaceBarWindowMenu.titleCap + 5
        )
        let menu = SpaceBarWindowMenu.make(
            [
                Self.row(
                    WindowID(9),
                    app: "Web",
                    title: long,
                    icon: nil,
                    enabled: true
                )
            ],
            kind: .glyph
        ) { _ in }
        #expect(menu.items[1].title.hasSuffix("…"))
        #expect(menu.items[1].toolTip == long)
    }

    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    /// #1850: the list pops as a context menu at its cell, so the
    /// event lands on the cell's lower-left corner in its window —
    /// VoiceOver's press and the peek's "N more" (#1946).
    @Test("The glyph menu's event sits at its cell's lower-left corner")
    func contextEventSitsAtTheCell() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        #expect(window.windowNumber > 0)
        let cell = NSView(frame: NSRect(x: 30, y: 8, width: 20, height: 20))
        let flipped = FlippedView(
            frame: NSRect(x: 60, y: 8, width: 20, height: 20)
        )
        window.contentView?.addSubview(cell)
        window.contentView?.addSubview(flipped)
        let event = try #require(
            SpaceBarGlyphActions.contextEvent(at: cell)
        )
        #expect(event.type == .rightMouseDown)
        #expect(event.windowNumber == window.windowNumber)
        #expect(event.locationInWindow == NSPoint(x: 30, y: 8))
        let corner = SpaceBarGlyphActions.contextEvent(at: flipped)
        #expect(corner?.locationInWindow == NSPoint(x: 60, y: 8))
        #expect(
            SpaceBarGlyphActions.contextEvent(at: NSView()) == nil
        )
    }
}
