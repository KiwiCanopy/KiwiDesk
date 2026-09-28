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
        try #require(LookCatalog.bundled().first { $0.name == name })
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

    @Test("a restore never writes a profile that went live since")
    func restoreSkipsAnotherProfile() throws {
        let core = makeCore(saving: "First")
        let baseline = core.shelfPaintBaseline()
        core.paintShelf(look: try look("Taskbar"), palette: nil)
        _ = core.execute("save_profile", args: [.string("Second")])
        let second = try stored(core)

        core.restoreShelf(baseline)

        #expect(try core.profiles.read(name: "Second").settings == second)
    }
}
