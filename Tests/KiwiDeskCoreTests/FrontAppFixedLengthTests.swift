import AppKit
import Testing

@testable import KiwiDeskCore

/// The front-app segment's fixed length (#2086, owner ruling): its
/// name draws in a slot sized from the title cap, so a focus change
/// to an app with a shorter or longer name moves no frame — and a
/// show that moves none redraws content alone, never the run.
@Suite("Front-app fixed length (#2086)", .serialized)
@MainActor
struct FrontAppFixedLengthTests {
    init() { LiquidGlassGate.override = { false } }

    private static let strip = CGRect(x: 0, y: 0, width: 900, height: 28)

    private static func app(
        _ name: String,
        focused: Bool,
        title: String? = nil
    ) -> SpaceBarItemView.App {
        var app = SpaceBarItemView.App(
            name: name,
            icon: nil,
            glyph: nil,
            focused: focused,
            count: 1
        )
        app.title = title
        return app
    }

    private static func items(
        _ apps: [SpaceBarItemView.App]
    ) -> [SpaceBarOverlay.Item] {
        [
            SpaceBarOverlay.Item(
                space: SpaceID("1"),
                spaceGlyph: .text("1", tinted: true),
                apps: apps,
                active: true,
                after: .none
            ),
            SpaceBarOverlay.Item(
                space: SpaceID("2"),
                spaceGlyph: .text("2", tinted: true),
                apps: [],
                active: false,
                after: .none
            ),
        ]
    }

    private static var look: SpaceBarLook {
        var look = SpaceBarLook()
        look.showFrontApp = true
        look.liquidGlass = false
        look.backgroundStyle = .plain
        // Centred, where a run that changed length would re-centre.
        look.alignment = .center
        return look
    }

    private static var redraws: Int {
        WorkMeter.shared.snapshot(reset: false).counts.barContentRedraws
    }

    private func show(
        _ overlay: SpaceBarOverlay,
        _ items: [SpaceBarOverlay.Item],
        front: SpaceBarItemView.App
    ) {
        overlay.show(
            items: items,
            frontApp: front,
            strip: Self.strip,
            style: Self.look,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
    }

    private func frames(_ overlay: SpaceBarOverlay) -> [CGRect] {
        [
            overlay.contentFrame, overlay.plateFrame,
            overlay.itemRun.frame, overlay.frontName.frame,
            overlay.frontBox.frame,
        ] + overlay.itemViews.map(\.frame)
    }

    @Test("A focus change to a longer or shorter name moves no frame")
    func focusChangeMovesNothing() {
        let overlay = SpaceBarOverlay()
        var renders = 0
        overlay.onRendered = { renders += 1 }
        show(
            overlay,
            Self.items([
                Self.app("Notes", focused: true),
                Self.app("Web", focused: false),
            ]),
            front: Self.app("Notes", focused: true, title: "Memo")
        )
        let before = frames(overlay)
        let counted = Self.redraws
        show(
            overlay,
            Self.items([
                Self.app("Notes", focused: false),
                Self.app("Web", focused: true),
            ]),
            front: Self.app(
                "Web",
                focused: true,
                title: "A much longer window title than the cap"
            )
        )
        #expect(frames(overlay) == before)
        #expect(Self.redraws == counted + 1, "content alone")
        #expect(
            overlay.frontName.stringValue
                == "A much longer window title than the cap"
        )
        #expect(overlay.itemViews[0].apps.map(\.focused) == [false, true])
        #expect(renders == 2, "the shelf still re-reads its hover")
    }

    @Test("A show that changes an item's length renders in full")
    func lengthChangeRendersInFull() {
        let overlay = SpaceBarOverlay()
        show(
            overlay,
            Self.items([Self.app("Notes", focused: true)]),
            front: Self.app("Notes", focused: true, title: "Memo")
        )
        let before = overlay.itemViews[0].frame
        let counted = Self.redraws
        show(
            overlay,
            Self.items([
                Self.app("Notes", focused: true),
                Self.app("Web", focused: false),
            ]),
            front: Self.app("Notes", focused: true, title: "Memo")
        )
        #expect(Self.redraws == counted, "a frame pass")
        #expect(overlay.itemViews[0].frame != before)
    }

    @Test("The name slot is the cap in the bar font, never the name")
    func slotIsTheCap() {
        let overlay = SpaceBarOverlay()
        show(
            overlay,
            Self.items([]),
            front: Self.app("Notes", focused: true, title: "Memo")
        )
        let slot = SpaceBarOverlay.titleSlot(
            Self.look,
            depth: Self.strip.height
        )
        #expect(overlay.frontName.frame.width == slot)
        var wider = Self.look
        wider.bar.frontAppTitleCap = 40
        #expect(
            SpaceBarOverlay.titleSlot(wider, depth: Self.strip.height)
                > slot
        )
    }
}
