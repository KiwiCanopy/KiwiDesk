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
        // The name itself centres in its slot; the slot, the icon
        // and the chip around them never move.
        [
            overlay.contentFrame, overlay.plateFrame,
            overlay.itemRun.frame, overlay.frontIcon.frame,
            overlay.frontBox.frame,
            CGRect(x: overlay.frontNameEnd, y: 0, width: 0, height: 0),
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
        let start = overlay.frontIcon.frame.maxX + SpaceBarItemView.pad
        #expect(abs(overlay.frontNameEnd - start - slot) < 0.5)
        var wider = Self.look
        wider.bar.frontAppTitleCap = 40
        #expect(
            SpaceBarOverlay.titleSlot(wider, depth: Self.strip.height)
                > slot
        )
    }

    /// A short name's INK centres on its slot, the icon never
    /// moving (owner ruling on #2086, option B); a long one fills
    /// the slot from its start and cuts. A script face, where the
    /// ink and the advance do not share a centre — in the system
    /// face they do to under a point, which a slot-wide centred
    /// frame would pass.
    @Test("A short name centres its ink in its slot; a long one fills")
    func shortNameCentres() throws {
        let overlay = SpaceBarOverlay()
        var look = Self.look
        look.shelf.fontFamily = "Apple Chancery"
        let slot = SpaceBarOverlay.titleSlot(look, depth: Self.strip.height)
        let place = { (title: String) in
            overlay.show(
                items: Self.items([]),
                frontApp: Self.app("Notes", focused: true, title: title),
                strip: Self.strip,
                style: look,
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        }
        // Ink offset from the advance's centre, opposite ways.
        for title in ["Tf", "fly"] {
            place(title)
            let name = overlay.frontName
            let start = overlay.frontNameEnd - slot
            let metrics = BarTextGlyph.metrics(of: name)
            let ink = metrics.inkSpan(in: name.frame)
            let mid = (ink.lowerBound + ink.upperBound) / 2
            #expect(abs(mid - (start + slot / 2)) < 0.5, "\(title)")
            // The two centres differ in this face, so the clause
            // tells the ink's from the advance's.
            let inkOff = metrics.ink.midX - metrics.advance / 2
            try #require(abs(inkOff) >= 0.5, "\(title)")
        }
        place(String(repeating: "A long title ", count: 6))
        let name = overlay.frontName.frame
        #expect(abs(name.minX - (overlay.frontNameEnd - slot)) < 0.5)
        #expect(abs(name.width - slot) < 0.5)
    }
}
