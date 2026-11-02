import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A stack flip belongs to the Desktop its screen shows (#2771),
/// read from `DesktopMemory.shownSpaces` — the map each switch
/// files at its head — and never a WindowServer read.
@Suite("Stack flip per Desktop (#2771)", .serialized)
@MainActor
struct StackFlipDesktopTests {
    private let verb = "stack.toggle_stack_position"

    private func core() throws -> KiwiCore {
        let core = try KeepFixture.core()
        core.setSpaceMode("1", .stack)
        return core
    }

    private func show(
        _ core: KiwiCore,
        _ shown: [String: SkyLight.SpaceID],
        user: Bool = true
    ) {
        core.desktopMemory.shownSpaces = shown
        core.desktopMemory.shownUserSpaces = shown.mapValues { _ in user }
    }

    @Test("shared mode: one non-screen key, a flip per Desktop")
    func sharedModeFlipsOneDesktop() throws {
        let core = try core()
        // "Displays have separate Spaces" off: the one key is the
        // managed-display id, which names no screen's UUID.
        show(core, ["Main": 10])
        #expect(core.execute(verb).isSuccess)
        #expect(core.drawnStackPosition(of: "1") == .left)
        show(core, ["Main": 11])
        #expect(core.stackFlip(of: "1") == nil)
        #expect(core.drawnStackPosition(of: "1") == .right)
        show(core, ["Main": 10])
        #expect(core.drawnStackPosition(of: "1") == .left)
        #expect(core.desktopMemory.stackFlips[10]?["1"] == .left)
        #expect(core.desktopMemory.stackFlips[11] == nil)
    }

    @Test("two Desktops each keep their own flip")
    func twoDesktopsTwoFlips() throws {
        let core = try core()
        show(core, ["Main": 10])
        _ = core.execute(verb)
        show(core, ["Main": 11])
        _ = core.execute(verb)
        _ = core.execute(verb)
        #expect(core.desktopMemory.stackFlips[11] == nil)
        #expect(core.desktopMemory.stackFlips[10]?["1"] == .left)
    }

    @Test("separate Spaces: the Space's own screen names the Desktop")
    func separateModeReadsTheScreen() throws {
        let core = try core()
        let display = DisplayID(1)
        core.state.workspaces.assign("1", to: display)
        NativeSpaces.displayUUIDOverride = { $0 == display ? "UUID-A" : nil }
        defer { NativeSpaces.displayUUIDOverride = nil }
        show(core, ["UUID-A": 20, "UUID-B": 30])
        #expect(core.stackFlipDesktop(of: "1") == .shown(20))
        #expect(core.execute(verb).isSuccess)
        #expect(core.desktopMemory.stackFlips[20]?["1"] == .left)
        show(core, ["UUID-A": 21, "UUID-B": 30])
        #expect(core.drawnStackPosition(of: "1") == .right)
    }

    @Test("a screen showing no user Desktop refuses the toggle")
    func fullScreenRefuses() throws {
        let core = try core()
        show(core, ["Main": 10], user: false)
        let refused = core.execute(verb)
        #expect(!refused.isSuccess)
        #expect(core.desktopMemory.stackFlips.isEmpty)
        #expect(core.stackFlip(of: "1") == nil)
    }

    @Test("no SkyLight reading keeps one Desktop-less entry")
    func noReadingIsOneEntry() throws {
        let core = try core()
        show(core, [:])
        #expect(core.stackFlipDesktop(of: "1") == .shown(nil))
        #expect(core.execute(verb).isSuccess)
        #expect(core.desktopMemory.stackFlips[nil]?["1"] == .left)
    }

    @Test("the render reads the flip through the engine's door")
    func renderReadsTheFlip() throws {
        let core = try core()
        show(core, ["Main": 10])
        _ = core.execute(verb)
        #expect(core.tiler.stackFlip("1") == .left)
        let space = try #require(core.state.workspaces["1"])
        let context = core.tiler.settings.context(
            bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            space: space,
            sticky: [],
            stackFlip: core.tiler.stackFlip("1")
        )
        #expect(context.stack.stackPosition == .left)
        show(core, ["Main": 11])
        #expect(core.tiler.stackFlip("1") == nil)
    }
}
