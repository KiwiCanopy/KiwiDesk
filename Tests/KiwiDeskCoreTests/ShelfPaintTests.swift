import Foundation
import Testing

@testable import KiwiDeskCore

/// The welcome tour's live look (#1720) is written THROUGH: a
/// click lands on the running settings and in the live profile's
/// file alike, so a relaunch or a mid-step close keeps it and
/// nothing is left to commit, and Revert puts both back.
@Suite("The tour paints the shelf through to the profile (#1720)")
@MainActor
struct ShelfPaintTests {
    private func makeCore(saving name: String? = "Mine") -> KiwiCore {
        let core = makeTestCore()
        if let name {
            _ = core.execute("save_profile", args: [.string(name)])
        }
        return core
    }

    private func look(_ name: String) throws -> ShelfLook {
        try #require(LookCatalog.bundled(sizes: []).first { $0.name == name })
    }

    private func palette(
        _ core: KiwiCore,
        _ name: String
    ) throws -> ColorPalette {
        try #require(core.allPalettes.first { $0.name == name })
    }

    private func stored(_ core: KiwiCore) throws -> TilingSettings {
        let name = try #require(core.profiles.currentName)
        return try core.profiles.read(name: name).settings
    }

    @Test("a look lands live and in the profile, colours included")
    func lookWritesThrough() throws {
        let core = makeCore()
        let taskbar = try look("Taskbar")
        let slate = try palette(core, "Slate")

        core.paintShelf(look: taskbar, palette: slate)

        #expect(taskbar.isApplied(to: core.tiler.settings))
        #expect(slate.isApplied(to: core.tiler.settings))
        #expect(try stored(core) == core.tiler.settings)
    }

    @Test("a palette alone repaints the colours and keeps the shape")
    func paletteKeepsTheShape() throws {
        let core = makeCore()
        let taskbar = try look("Taskbar")
        core.paintShelf(look: taskbar, palette: try palette(core, "Slate"))
        let sunset = try palette(core, "Sunset")

        core.paintShelf(look: nil, palette: sunset)

        #expect(taskbar.isApplied(to: core.tiler.settings))
        #expect(sunset.isApplied(to: core.tiler.settings))
        #expect(try stored(core) == core.tiler.settings)
    }

    @Test("restore returns the live settings and the file alike")
    func restoreReturnsBoth() throws {
        let core = makeCore()
        let before = core.tiler.settings
        let baseline = core.shelfPaintBaseline()
        core.paintShelf(
            look: try look("Pill"),
            palette: try palette(core, "True Dark")
        )
        #expect(core.tiler.settings != before)

        core.restoreShelf(baseline)

        #expect(core.tiler.settings == before)
        #expect(try stored(core) == before)
    }

    /// The file write is a read-modify-write of what is STORED: a
    /// live setting the profile never kept is not adopted.
    @Test("the file takes the paint, never the rest of live")
    func fileKeepsItsOwnSettings() throws {
        let core = makeCore()
        let storedStep = try stored(core).resizeStep
        core.tiler.settings.resizeStep += 7

        core.paintShelf(look: try look("Taskbar"), palette: nil)

        #expect(try stored(core).resizeStep == storedStep)
    }

    @Test("with no saved profile live, the paint is live only")
    func noProfileIsLiveOnly() throws {
        let core = makeCore(saving: nil)
        #expect(core.profiles.currentName == nil)

        core.paintShelf(look: try look("Taskbar"), palette: nil)

        #expect(try look("Taskbar").isApplied(to: core.tiler.settings))
        #expect(core.profiles.list().isEmpty)
    }

    @Test("a restore is refused once another profile went live")
    func restoreSkipsAnotherProfile() throws {
        let core = makeCore(saving: "First")
        let baseline = core.shelfPaintBaseline()
        let taskbar = try look("Taskbar")
        core.paintShelf(look: taskbar, palette: nil)
        _ = core.execute("save_profile", args: [.string("Second")])
        let second = try core.profiles.read(name: "Second").settings

        #expect(!core.restoreShelf(baseline))

        #expect(try core.profiles.read(name: "Second").settings == second)

        #expect(taskbar.isApplied(to: core.tiler.settings))
        let first = try core.profiles.read(name: "First").settings
        #expect(taskbar.isApplied(to: first))
    }

    /// Revert paints back the look and palette keys alone: a
    /// setting changed and saved after the first paint stays.
    @Test("a restore leaves every other setting where it is")
    func restoreTouchesOnlyTheLook() throws {
        let core = makeCore()
        let baseline = core.shelfPaintBaseline()
        core.paintShelf(look: try look("Taskbar"), palette: nil)
        core.tiler.settings.resizeStep += 7
        _ = core.execute("save_profile", args: [.string("Mine")])
        let step = core.tiler.settings.resizeStep

        core.restoreShelf(baseline)

        #expect(core.tiler.settings.resizeStep == step)
        #expect(try stored(core).resizeStep == step)
        #expect(!(try look("Taskbar")).isApplied(to: core.tiler.settings))
    }

    /// `ShelfLook.apply` writes beyond a look's keys — every glass
    /// leaf, the per-layout App Bar indicators — so a Revert that
    /// painted a look back would level the user's own leaves.
    @Test("a restore keeps what a look writes beyond its keys")
    func restoreKeepsWhatThePaintReachedBeyond() throws {
        let core = makeCore(saving: nil)
        let glass = core.tiler.settings.kiwishelf.liquidGlass
        core.tiler.settings.stickyStyle.liquidGlass = !glass
        core.tiler.settings.monocle.appBar.activeIndicator = .outline
        _ = core.execute("save_profile", args: [.string("Mine")])
        let baseline = core.shelfPaintBaseline()
        core.paintShelf(look: nil, palette: try palette(core, "Sunset"))

        core.restoreShelf(baseline)

        for settings in [core.tiler.settings, try stored(core)] {
            #expect(settings.stickyStyle.liquidGlass == !glass)
            #expect(settings.monocle.appBar.activeIndicator == .outline)
        }
    }

    @Test("every paint and restore tells the GUI, on the write")
    func paintsAreAnnounced() throws {
        let core = makeCore()
        let taskbar = try look("Taskbar")
        var told: [Bool] = []
        core.onShelfPainted = { [unowned core] in
            let file = try? core.profiles.read(name: "Mine").settings
            told.append(
                taskbar.isApplied(to: core.tiler.settings)
                    && file.map(taskbar.isApplied(to:)) == true
            )
        }
        let baseline = core.shelfPaintBaseline()
        core.paintShelf(look: taskbar, palette: nil)
        core.restoreShelf(baseline)
        // Told after the write landed, live and in the file.
        #expect(told == [true, false])
    }
}
