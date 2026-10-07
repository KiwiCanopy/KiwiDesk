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
    @Test("A long title is cut in the row and whole in its tooltip")
    func longTitleIsCut() {
        LocalizationManager.shared.select("en")
        let long = String(
            repeating: "x",
            count: SpaceBarWindowMenu.titleCap + 5
        )
        let row = SpaceBarWindowMenu.Row(
            window: WindowID(9),
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
                .init(
                    window: WindowID(9),
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
                .init(
                    window: WindowID(9),
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
                .init(
                    window: WindowID(9),
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
                .init(
                    window: WindowID(9),
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
}
