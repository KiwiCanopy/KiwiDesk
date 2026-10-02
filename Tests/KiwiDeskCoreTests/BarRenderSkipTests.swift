import AppKit
import Testing

@testable import KiwiDeskCore

/// An identical show draws nothing (#1901): a Space switch, its
/// focus report and its activation each refresh the bars, and the
/// repeats cost a full render apiece. Each overlay skips a show
/// whose input equals the last one drawn, draws a changed one, and
/// draws again after `invalidateRender` — the door for a draw-time
/// read outside the input.
@Suite("Bar render skip (#1901)", .serialized)
@MainActor
struct BarRenderSkipTests {
    init() { LiquidGlassGate.override = { false } }

    private static let strip = CGRect(x: 0, y: 0, width: 900, height: 28)

    private static func appItems(_ title: String) -> [AppBarOverlay.Item] {
        (1...3).map {
            AppBarOverlay.Item(
                id: WindowID(UInt32($0)),
                text: "\(title) \($0)",
                icon: nil
            )
        }
    }

    private static func spaceItems(active: String) -> [SpaceBarOverlay.Item] {
        ["1", "2", "3"].map {
            SpaceBarOverlay.Item(
                space: SpaceID($0),
                spaceGlyph: .text($0, tinted: true),
                apps: [],
                active: $0 == active,
                after: .none
            )
        }
    }

    private static let marks = StateMarkColors(
        sticky: "#ffffff",
        floating: "#ffffff"
    )

    @Test("The App Bar draws a changed show and skips a repeat")
    func appBarSkipsRepeats() {
        let overlay = AppBarOverlay()
        var renders = 0
        overlay.onRendered = { renders += 1 }
        var look = AppBarLook()
        look.shelf.liquidGlass = false
        func show(_ title: String) {
            overlay.show(
                items: Self.appItems(title),
                activeIndex: 0,
                strip: Self.strip,
                style: look,
                capAxis: 2000
            )
        }
        show("A")
        let first = renders
        #expect(first > 0)
        show("A")
        #expect(renders == first)
        show("B")
        #expect(renders > first)
        let second = renders
        overlay.invalidateRender()
        show("B")
        #expect(renders > second)
    }

    @Test("The Space Bar draws a changed show and skips a repeat")
    func spaceBarSkipsRepeats() {
        let overlay = SpaceBarOverlay()
        var renders = 0
        overlay.onRendered = { renders += 1 }
        var look = SpaceBarLook()
        look.liquidGlass = false
        func show(_ active: String) {
            overlay.show(
                items: Self.spaceItems(active: active),
                strip: Self.strip,
                style: look,
                stateMarkColors: Self.marks
            )
        }
        show("1")
        let first = renders
        #expect(first > 0)
        show("1")
        #expect(renders == first)
        show("2")
        #expect(renders > first)
        let second = renders
        overlay.invalidateRender()
        show("2")
        #expect(renders > second)
    }

    @Test("A shown shelf skips a repeated lay-out until invalidated")
    func shelfSkipsRepeats() {
        let overlay = ShelfOverlay()
        let section = NSView()
        func show() {
            overlay.show(
                strip: Self.strip,
                edge: .top,
                shelf: KiwiShelf(),
                sheen: 0,
                sections: [
                    .init(
                        view: section,
                        slot: Self.strip,
                        plate: .zero,
                        content: .zero
                    )
                ]
            )
        }
        show()
        let laid = overlay.stripView.frame
        #expect(laid.size == Self.strip.size)
        // A lay-out would put the strip view back where it was.
        overlay.stripView.frame = .zero
        show()
        #expect(overlay.stripView.frame == .zero)
        overlay.invalidateRender()
        show()
        #expect(overlay.stripView.frame == laid)
    }
}
