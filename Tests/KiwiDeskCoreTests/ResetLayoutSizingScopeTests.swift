import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Which Spaces `reset_layout_sizing` reaches (#764, owner ruling
/// 2026-09-21): the active one by default, one named by id, or
/// every Space for `all` — and nothing for an id that does not
/// exist. Display pinned (#531).
@Suite("reset_layout_sizing scope (#764)", .serialized)
@MainActor
struct ResetLayoutSizingScopeTests {
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Two Spaces, each with a session ratio and a stack weight;
    /// Space 1 is the active one.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-reset-scope-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.state.workspaces.ensureSpace(one)
        core.state.workspaces.ensureSpace(two)
        for space in [one, two] {
            core.state.workspaces.withSpace(space) {
                $0.sessionRatios.splitRatioH = 0.7
                $0.stackWeights[WindowID(9)] = 2
            }
        }
        #expect(core.state.workspaces.activeSpace == one)
        return core
    }

    private func isReset(_ space: SpaceID, on core: KiwiCore) -> Bool {
        guard let space = core.state.workspaces[space] else {
            return false
        }
        return space.sessionRatios == SessionRatios()
            && space.stackWeights.isEmpty
    }

    @Test("No argument resets the active Space alone")
    func defaultIsTheActiveSpace() {
        let core = makeCore()
        #expect(core.execute("reset_layout_sizing").isSuccess)
        #expect(isReset(one, on: core))
        #expect(!isReset(two, on: core))
    }

    @Test("A Space id resets that Space alone")
    func namedSpace() {
        let core = makeCore()
        #expect(
            core.execute("reset_layout_sizing", args: [.string("2")])
                .isSuccess
        )
        #expect(!isReset(one, on: core))
        #expect(isReset(two, on: core))
    }

    @Test("`all` resets every Space")
    func allSpaces() {
        let core = makeCore()
        #expect(
            core.execute("reset_layout_sizing", args: [.string("all")])
                .isSuccess
        )
        #expect(isReset(one, on: core))
        #expect(isReset(two, on: core))
    }

    @Test("An unknown id is refused and touches nothing")
    func unknownSpaceIsRefused() {
        let core = makeCore()
        let response = core.execute(
            "reset_layout_sizing",
            args: [.string("9")]
        )
        #expect(!response.isSuccess)
        #expect(response.error?.contains("unknown space") == true)
        #expect(!isReset(one, on: core))
        #expect(!isReset(two, on: core))
    }
}
