import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The sticky-mark diff-sync (#414): one chip per sticky
/// window, retired when the window stops being sticky or goes
/// away — `BorderManager`'s contract at marker scale.
@Suite("Sticky indicator manager", .serialized)
@MainActor
struct StickyIndicatorManagerTests {
    private func spec(_ id: UInt32) -> StickyIndicatorManager.Spec {
        StickyIndicatorManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

    @Test("Sync shows exactly the desired set")
    func syncDiff() {
        let manager = StickyIndicatorManager()
        manager.sync([spec(1), spec(2)])
        #expect(
            manager.markedWindows == [WindowID(1), WindowID(2)]
        )
        manager.sync([spec(2)])
        #expect(manager.markedWindows == [WindowID(2)])
        manager.sync([])
        #expect(manager.markedWindows.isEmpty)
    }

    @Test("Clear retires every chip")
    func clearAll() {
        let manager = StickyIndicatorManager()
        manager.sync([spec(1)])
        manager.clear()
        #expect(manager.markedWindows.isEmpty)
    }

    @Test("Flash keeps the set; an unmarked window is a no-op")
    func flashContract() {
        let manager = StickyIndicatorManager()
        manager.sync([spec(1)])
        // Marked window flashes (#421); an unmarked one must
        // not create a chip or crash.
        let fmt = "Home space %1$@"
        manager.flash(WindowID(1), format: fmt, mark: .text("1"))
        manager.flash(WindowID(2), format: fmt, mark: .symbol("star"))
        #expect(manager.markedWindows == [WindowID(1)])
    }
}

/// The home-space pill's geometry (#421): the plate grows to fit
/// the name, capped so a long name truncates instead of sprawling.
@Suite("Sticky indicator pill", .serialized)
@MainActor
struct StickyIndicatorPlateTests {
    @Test("A name expands the plate past the collapsed square")
    func expands() {
        let plate = StickyIndicatorPlate()
        #expect(
            plate.prepare(format: "Home %1$@", mark: .text("Work"))
                > StickyIndicatorPlate.size
        )
    }

    @Test("A symbol mark also expands (renders inline)")
    func symbolExpands() {
        let plate = StickyIndicatorPlate()
        #expect(
            plate.prepare(format: "Home %1$@", mark: .symbol("star"))
                > StickyIndicatorPlate.size
        )
    }

    @Test("A long name caps at the max pill width")
    func caps() {
        let plate = StickyIndicatorPlate()
        let width = plate.prepare(
            format: "%1$@",
            mark: .text(String(repeating: "W", count: 120))
        )
        #expect(width == StickyIndicatorPlate.maxWidth)
    }
}

/// The driver (#414): every sticky window wears the chip on
/// every space; the `sticky.indicator` toggle retires them all.
@Suite("Sticky indicator driver", .serialized)
@MainActor
struct StickyIndicatorDriverTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-glyph-\(UUID().uuidString)"
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

    @Test("Only sticky windows wear the mark")
    func stickyOnly() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        core.state.setSticky(WindowID(1), true)
        core.updateStickyIndicators()
        #expect(
            core.stickyIndicators.markedWindows == [WindowID(1)]
        )
    }

    @Test("Inactive-space sticky windows keep their mark")
    func marksAcrossSpaces() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setSticky(WindowID(1), true)
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.activate(SpaceID(2))
        core.updateStickyIndicators()
        #expect(
            core.stickyIndicators.markedWindows == [WindowID(1)]
        )
    }

    @Test("sticky.indicator off retires every mark")
    func indicatorGate() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setSticky(WindowID(1), true)
        core.updateStickyIndicators()
        #expect(!core.stickyIndicators.markedWindows.isEmpty)
        core.tiler.settings.stickyStyle.indicator = false
        core.updateStickyIndicators()
        #expect(core.stickyIndicators.markedWindows.isEmpty)
    }

    @Test("An unsticky flip retires the mark on the next sync")
    func unstickyRetires() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setSticky(WindowID(1), true)
        core.updateStickyIndicators()
        core.state.setSticky(WindowID(1), false)
        core.updateStickyIndicators()
        #expect(core.stickyIndicators.markedWindows.isEmpty)
    }
}
