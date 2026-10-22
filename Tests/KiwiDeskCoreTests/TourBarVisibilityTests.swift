import Foundation
import Testing

@testable import KiwiDeskCore

/// The tour's bars step (#2515) writes when the bars show THROUGH,
/// live and into the live profile's file like the looks step's
/// paint (#1720), and each step's Revert reaches its own leaves
/// alone: a look never carries the visibility (#761).
@Suite("The tour sets the bars' visibility through (#2515)")
@MainActor
struct TourBarVisibilityTests {
    private func makeCore(saving name: String? = "Mine") -> KiwiCore {
        let core = makeTestCore()
        core.tiler.settings.setEveryBarVisibility(.always)
        if let name {
            _ = core.execute("save_profile", args: [.string(name)])
        }
        return core
    }

    private func stored(_ core: KiwiCore) throws -> TilingSettings {
        let name = try #require(core.profiles.currentName)
        return try core.profiles.read(name: name).settings
    }

    private func look(_ name: String) throws -> ShelfLook {
        try #require(
            LookCatalog.bundled(sizes: []).first { $0.name == name }
        )
    }

    @Test("a pick lands live and in the profile on every bar")
    func pickWritesThrough() throws {
        let core = makeCore()
        #expect(core.setBarVisibility(.hidden))
        #expect(core.tiler.settings.uniformBarVisibility == .hidden)
        #expect(try stored(core).uniformBarVisibility == .hidden)
    }

    @Test("a pick every bar already reads writes nothing")
    func noOpWritesNothing() {
        let core = makeCore()
        var writes = 0
        core.onLiveProfileWritten = { _, _ in writes += 1 }
        #expect(!core.setBarVisibility(.always))
        #expect(writes == 0)
        #expect(core.setBarVisibility(.auto))
        #expect(writes == 1)
    }

    @Test("restore returns the visibility live and in the file")
    func restoreReturnsBoth() throws {
        let core = makeCore()
        let baseline = core.tourBaseline()
        core.setBarVisibility(.auto)
        #expect(core.restoreBarVisibility(baseline))
        #expect(core.tiler.settings.uniformBarVisibility == .always)
        #expect(try stored(core).uniformBarVisibility == .always)
    }

    @Test("the bars' revert leaves a look painted since alone")
    func barsRevertKeepsTheLook() throws {
        let core = makeCore()
        let baseline = core.tourBaseline()
        core.setBarVisibility(.hidden)
        let taskbar = try look("Taskbar")
        core.paintShelf(look: taskbar, palette: nil)
        core.restoreBarVisibility(baseline)
        #expect(taskbar.isApplied(to: core.tiler.settings))
        #expect(taskbar.isApplied(to: try stored(core)))
        #expect(core.tiler.settings.uniformBarVisibility == .always)
    }

    @Test("the looks' revert leaves a visibility picked since alone")
    func looksRevertKeepsTheVisibility() throws {
        let core = makeCore()
        let baseline = core.tourBaseline()
        core.paintShelf(look: try look("Taskbar"), palette: nil)
        core.setBarVisibility(.hidden)
        core.restoreShelf(baseline)
        #expect(core.tiler.settings.uniformBarVisibility == .hidden)
        #expect(try stored(core).uniformBarVisibility == .hidden)
    }

    @Test("a restore is refused once another profile went live")
    func restoreSkipsAnotherProfile() throws {
        let core = makeCore(saving: "First")
        let baseline = core.tourBaseline()
        core.setBarVisibility(.hidden)
        _ = core.execute("save_profile", args: [.string("Second")])
        #expect(!core.restoreBarVisibility(baseline))
        let second = try core.profiles.read(name: "Second").settings
        #expect(second.uniformBarVisibility == .hidden)
    }

    @Test("with no saved profile live, the pick is live only")
    func noProfileIsLiveOnly() {
        let core = makeCore(saving: nil)
        core.setBarVisibility(.auto)
        #expect(core.tiler.settings.uniformBarVisibility == .auto)
        #expect(core.profiles.list().isEmpty)
    }

    @Test("the hold reaches the revealer")
    func holdIsWired() {
        let core = makeTestCore()
        core.holdBarsRevealed(true)
        #expect(core.shelves.reveal.heldOpen)
        core.holdBarsRevealed(false)
        #expect(!core.shelves.reveal.heldOpen)
    }
}
