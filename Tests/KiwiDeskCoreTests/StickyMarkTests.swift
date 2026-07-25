import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The sticky-mark diff-sync (#414): one mark per sticky
/// window, retired when the window stops being sticky or goes
/// away — `BorderManager`'s contract at marker scale.
@Suite("Sticky mark manager", .serialized)
@MainActor
struct StickyMarkManagerTests {
    private func spec(_ id: UInt32) -> StickyMarkManager.Spec {
        StickyMarkManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

    @Test("Sync shows exactly the desired set")
    func syncDiff() {
        let manager = StickyMarkManager()
        manager.sync([spec(1), spec(2)])
        #expect(
            manager.markedWindows == [WindowID(1), WindowID(2)]
        )
        manager.sync([spec(2)])
        #expect(manager.markedWindows == [WindowID(2)])
        manager.sync([])
        #expect(manager.markedWindows.isEmpty)
    }

    @Test("Clear retires every mark")
    func clearAll() {
        let manager = StickyMarkManager()
        manager.sync([spec(1)])
        manager.clear()
        #expect(manager.markedWindows.isEmpty)
    }

    @Test("Flash keeps the set; an unmarked window is a no-op")
    func flashContract() {
        let manager = StickyMarkManager()
        manager.sync([spec(1)])
        // Marked window flashes (#421); an unmarked one must
        // not create a mark or crash.
        let fmt = "Home space %1$@"
        manager.flash(
            WindowID(1),
            format: fmt,
            mark: .text("1"),
            delay: 0
        )
        manager.flash(
            WindowID(2),
            format: fmt,
            mark: .symbol("star"),
            delay: 0
        )
        #expect(manager.markedWindows == [WindowID(1)])
    }
}

/// The home-space pill's geometry (#421): the plate grows to fit
/// the name, capped so a long name truncates instead of sprawling.
@Suite("Sticky mark plate", .serialized)
@MainActor
struct StickyMarkPlateTests {
    @Test("A name expands the plate past the collapsed square")
    func expands() {
        let plate = StickyMarkPlate()
        #expect(
            plate.prepare(format: "Home %1$@", mark: .text("Work"))
                > StickyMarkPlate.size
        )
    }

    @Test("A symbol mark also expands (renders inline)")
    func symbolExpands() {
        let plate = StickyMarkPlate()
        #expect(
            plate.prepare(format: "Home %1$@", mark: .symbol("star"))
                > StickyMarkPlate.size
        )
    }

    @Test("A long name caps at the max pill width")
    func caps() {
        let plate = StickyMarkPlate()
        let width = plate.prepare(
            format: "%1$@",
            mark: .text(String(repeating: "W", count: 120))
        )
        #expect(width == StickyMarkPlate.maxWidth)
    }
}

/// The driver (#414): every sticky window wears the mark on
/// every space; the `sticky.mark` toggle retires them all.
@Suite("Sticky mark driver", .serialized)
@MainActor
struct StickyMarkDriverTests {
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
        core.state.setSticky(WindowID(1), .global)
        core.updateStickyMarks()
        #expect(
            core.stickyMarks.markedWindows == [WindowID(1)]
        )
    }

    @Test("Inactive-space sticky windows keep their mark")
    func marksAcrossSpaces() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setSticky(WindowID(1), .global)
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.activate(SpaceID(2))
        core.updateStickyMarks()
        #expect(
            core.stickyMarks.markedWindows == [WindowID(1)]
        )
    }

    @Test("sticky.mark off retires every mark")
    func markGate() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setSticky(WindowID(1), .global)
        core.updateStickyMarks()
        #expect(!core.stickyMarks.markedWindows.isEmpty)
        core.tiler.settings.stickyStyle.mark = false
        core.updateStickyMarks()
        #expect(core.stickyMarks.markedWindows.isEmpty)
    }

    @Test("An unsticky flip retires the mark on the next sync")
    func unstickyRetires() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.setSticky(WindowID(1), .global)
        core.updateStickyMarks()
        core.state.setSticky(WindowID(1), .none)
        core.updateStickyMarks()
        #expect(core.stickyMarks.markedWindows.isEmpty)
    }
}
