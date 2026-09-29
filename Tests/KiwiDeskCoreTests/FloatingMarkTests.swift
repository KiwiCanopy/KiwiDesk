import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The floating mark (#1799): a window SET floating wears the
/// floating glyph where it shows — the flag, never
/// `EffectiveFloat` — beside sticky's on one plate, sticky
/// outermost; the ruling is `docs/design-decisions.md` ▸ Floating
/// is not self-evident.
@Suite("Floating mark driver", .serialized)
@MainActor
struct FloatingMarkDriverTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-float-mark-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(_ core: KiwiCore, _ raw: UInt32) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: 1,
                    appName: "App\(raw)"
                )
            )
        )
    }

    private func kinds(
        _ core: KiwiCore,
        _ raw: UInt32
    ) -> [StickyMarkManager.Glyph.Kind]? {
        core.stickyMarkSpecs()
            .first { $0.window == WindowID(raw) }?
            .glyphs.map(\.kind)
    }

    @Test("A window set floating wears the floating glyph")
    func flaggedFloat() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        core.state.setFloating(WindowID(1), true)
        #expect(kinds(core, 1) == [.floating])
        #expect(kinds(core, 2) == nil)
    }

    @Test("A floating-mode member wears nothing; a flagged one does")
    func floatingModeSpace() throws {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.setMode(space, .floating)
        core.state.setFloating(WindowID(2), true)
        #expect(kinds(core, 1) == nil)
        #expect(kinds(core, 2) == [.floating])
    }

    @Test("A float on a hidden space wears no mark")
    func hiddenSpace() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setFloating(WindowID(1), true)
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.activate(SpaceID(2))
        #expect(kinds(core, 1) == nil)
    }

    @Test("A sticky float carries both glyphs, sticky outermost")
    func stickyFloat() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setFloating(WindowID(1), true)
        core.state.setSticky(WindowID(1), .global)
        #expect(kinds(core, 1) == [.sticky, .floating])
        // Sticky shows everywhere, so its floating glyph does too.
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.activate(SpaceID(2))
        #expect(kinds(core, 1) == [.sticky, .floating])
    }

    @Test("Each switch retires only its own glyph")
    func independentSwitches() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setFloating(WindowID(1), true)
        core.state.setSticky(WindowID(1), .global)
        core.tiler.settings.floatingStyle.mark = false
        #expect(kinds(core, 1) == [.sticky])
        core.tiler.settings.floatingStyle.mark = true
        core.tiler.settings.stickyStyle.mark = false
        #expect(kinds(core, 1) == [.floating])
    }

    @Test("The floating glyph takes floating.color")
    func floatingColor() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setFloating(WindowID(1), true)
        core.tiler.settings.floatingStyle.color = "#E8A33D"
        let glyph = core.stickyMarkSpecs().first?.glyphs.first
        #expect(glyph == .floating(color: "#E8A33D"))
    }

    @Test("floating.set_mark writes the switch")
    func setMarkCommand() {
        let core = makeCore()
        #expect(core.tiler.settings.floatingStyle.mark)
        let off = core.execute(
            "floating.set_mark",
            args: [.bool(false)]
        )
        #expect(off.isSuccess)
        #expect(!core.tiler.settings.floatingStyle.mark)
        let bad = core.execute(
            "floating.set_mark",
            args: [.string("no")]
        )
        #expect(!bad.isSuccess)
    }
}

/// The plate's two slots (#1799): the pills are sticky's, and the
/// inner glyph drops first on a narrow window.
@Suite("Floating mark plate", .serialized)
@MainActor
struct FloatingMarkPlateTests {
    @Test("A floating-only plate draws no refusal pill")
    func pillsAreSticky() {
        let manager = StickyMarkManager()
        manager.sync([
            StickyMarkManager.Spec(
                window: WindowID(1),
                frame: CGRect(x: 0, y: 0, width: 400, height: 300),
                glyphs: [.floating()],
                glass: false
            ),
            StickyMarkManager.Spec(
                window: WindowID(2),
                frame: CGRect(x: 0, y: 0, width: 400, height: 300),
                glyphs: [.sticky(), .floating()],
                glass: false
            ),
        ])
        let drawn = { (raw: UInt32) in
            manager.flash(
                WindowID(raw),
                format: "%1$@",
                mark: .text(""),
                delay: 0
            )
        }
        #expect(!drawn(1))
        #expect(drawn(2))
    }

    @Test("The inner glyph drops first, the outer never")
    func fitting() {
        let wide = StickyMarkPlate.fittingSlots(2, windowWidth: 400)
        let narrow = StickyMarkPlate.fittingSlots(2, windowWidth: 100)
        let tiny = StickyMarkPlate.fittingSlots(2, windowWidth: 10)
        #expect(wide == 2)
        #expect(narrow == 1)
        #expect(tiny == 1)
        #expect(StickyMarkPlate.fittingSlots(1, windowWidth: 400) == 1)
    }

    @Test("A second glyph widens the pill by one square")
    func pillMakesRoom() {
        let plate = StickyMarkPlate()
        let one = plate.prepare(format: "%1$@", mark: .text("Work"))
        plate.setInner(
            NSImage(
                systemSymbolName: FloatingStyle.symbolName,
                accessibilityDescription: nil
            ),
            hex: ""
        )
        let two = plate.prepare(format: "%1$@", mark: .text("Work"))
        #expect(two == one + StickyMarkPlate.size)
    }
}
