import Foundation
import Testing

@testable import KiwiDeskCore

/// How long a stack flip lives (#2771): the session, ended by an
/// explicit apply, a config load, the global setter and the #634
/// reset for every Space, and by the override setter and the
/// Space's drop for one; a Desktop binding's apply, a mode change
/// and a sizing reset keep it, and a renumber carries it.
@Suite("Stack flip lifetime (#2771)", .serialized)
@MainActor
struct StackFlipLifetimeTests {
    private let verb = "stack.toggle_stack_position"

    /// A core with Spaces 1 and 2 flipped on Desktops 10 and 11.
    private func flipped() throws -> KiwiCore {
        let core = try KeepFixture.core()
        core.state.workspaces.ensureSpace("2", mode: .stack)
        for desktop: SkyLight.SpaceID in [10, 11] {
            core.desktopMemory.shownSpaces = ["Main": desktop]
            _ = core.execute(verb, args: [.string("1")])
            _ = core.execute(verb, args: [.string("2")])
        }
        #expect(flips(core) == 4)
        return core
    }

    private func flips(_ core: KiwiCore) -> Int {
        core.desktopMemory.stackFlips.values.reduce(0) { $0 + $1.count }
    }

    @Test("stack.set_stack_position ends every flip")
    func globalSetterClears() throws {
        let core = try flipped()
        _ = core.execute("stack.set_stack_position", args: [.string("left")])
        #expect(flips(core) == 0)
    }

    @Test("the override setter ends one Space's, on every Desktop")
    func overrideSetterClearsOne() throws {
        let core = try flipped()
        _ = core.execute(
            "stack.set_stack_position_override",
            args: [.string("1"), .string("bottom")]
        )
        #expect(flips(core) == 2)
        for desktop: SkyLight.SpaceID in [10, 11] {
            #expect(core.desktopMemory.stackFlips[desktop]?["1"] == nil)
            #expect(core.desktopMemory.stackFlips[desktop]?["2"] == .left)
        }
    }

    @Test("another Space's override setter keeps this one's")
    func otherFieldKeeps() throws {
        let core = try flipped()
        _ = core.execute(
            "stack.set_master_count_override",
            args: [.string("1"), .number(2)]
        )
        #expect(flips(core) == 4)
    }

    @Test("load_profile ends every flip")
    func loadClears() throws {
        let core = try flipped()
        KeepFixture.load("Work", core)
        #expect(flips(core) == 0)
    }

    @Test("an in-effect re-apply ends every flip; an event keeps it")
    func applyCauses() throws {
        let core = try flipped()
        let work = try core.profiles.read(name: "Work")
        core.apply(profile: work, cause: .event)
        #expect(flips(core) == 4)
        core.apply(profile: work, cause: .monitorChange)
        #expect(flips(core) == 4)
        core.apply(profile: work, cause: .explicit)
        #expect(flips(core) == 0)
    }

    @Test("a forced Standard apply ends every flip; an unforced keeps")
    func composedApply() throws {
        let core = try flipped()
        let display = try #require(core.state.workspaces.allDisplays.first)
        let composed = try #require(
            ProfileComposition.compose(
                displays: [display],
                mainID: display.id
            )
        )
        core.apply(composed: composed, forceRetile: false)
        #expect(flips(core) > 0)
        core.apply(composed: composed, forceRetile: true)
        #expect(flips(core) == 0)
    }

    @Test("a Settings save of the live profile ends every flip")
    func settingsSaveClears() throws {
        let core = try flipped()
        core.applyProfileScopedState(from: core.loadGuiConfig())
        #expect(flips(core) == 0)
    }

    @Test("a config reload ends every flip")
    func reloadClears() throws {
        // No profile, so no re-apply clears them on the load's way.
        let core = try KeepFixture.core(gui: false)
        core.desktopMemory.stackFlips = [10: ["1": .left]]
        core.loadConfig()
        #expect(flips(core) == 0)
    }

    @Test("a mode change and reset_layout_sizing keep it")
    func modeAndSizingKeep() throws {
        let core = try flipped()
        _ = core.execute("set_mode", args: [.string("bsp")])
        _ = core.execute("reset_layout_sizing", args: [.string("all")])
        #expect(flips(core) == 4)
    }

    @Test("a renumber carries the flip; the drop ends it")
    func renumberAndDrop() throws {
        let core = try flipped()
        core.rekeyStackFlips("2", to: "7")
        #expect(core.desktopMemory.stackFlips[10]?["7"] == .left)
        #expect(core.desktopMemory.stackFlips[10]?["2"] == nil)
        core.state.workspaces.ensureSpace("7", mode: .stack)
        core.forwardWindows(of: "7", to: "1")
        #expect(flips(core) == 2)
        #expect(core.desktopMemory.stackFlips[11]?["7"] == nil)
    }

    @Test("the #634 reset ends every flip")
    func resetClears() throws {
        let core = try flipped()
        core.discardSavedArrangement()
        #expect(flips(core) == 0)
    }
}
