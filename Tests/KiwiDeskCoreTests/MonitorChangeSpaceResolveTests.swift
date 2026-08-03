import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-676-\(UUID().uuidString)"
            )
    )
}

/// A display named `name` with a 100x100 frame, so its
/// fingerprint is `"<name>:100x100"`.
private func display(_ id: UInt32, _ name: String) -> Display {
    Display(
        id: DisplayID(id),
        name: name,
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
}

/// No `handleMonitorChange` exit may leave a space orphaned
/// (#676). Any display id churn (sleep, dock/undock — the #676
/// report was an AirPlay connect re-keying the built-in) has
/// already cleared `spaceDisplay` for every space on the old id
/// by the time the branch runs — so a branch that skips
/// `resolveSpaceDisplays()` leaves both bars' display keys
/// unresolvable, the trailing retile retires them, and nothing
/// heals. The `.countDefault`-already-current branch shipped
/// exactly that way: `markDirty()` only, the one branch of
/// seven with no resolve. The second test pins the dependency
/// the unconditional defer rests on: a repeated resolve over
/// unchanged inputs is a no-op.
@Suite("Monitor change space resolve (#676)", .serialized)
@MainActor
struct MonitorChangeSpaceResolveTests {
    @Test("count-default re-match of the current profile heals")
    func countDefaultAlreadyCurrentResolves() throws {
        let core = makeCore()
        core.state.workspaces.upsertDisplay(display(1, "A"))
        core.execute(
            "save_profile",
            args: [.string("known")]
        )
        #expect(core.profiles.currentName == "known")

        // The churn shape: the id changed, so the state fold
        // removed the old display — wiping `spaceDisplay` — and
        // upserted a fresh id whose fingerprint set matches no
        // saved set but keeps the count. The count's default IS
        // the current profile, so the branch used to do only
        // `markDirty()`.
        core.state.workspaces.removeDisplay(DisplayID(1))
        core.state.workspaces.upsertDisplay(display(7, "OTHER"))
        core.handleMonitorChange()
        #expect(core.profiles.currentName == "known")
        #expect(core.profiles.isDirty)

        // The heal: every space resolved onto the live display,
        // so the bars' display keys (`spaces(on:)` /
        // `currentSpace(on:)`) answer again.
        let spaces = core.state.workspaces.allSpaces
        #expect(!spaces.isEmpty)
        for space in spaces {
            #expect(
                core.state.workspaces.display(of: space.id)
                    == DisplayID(7)
            )
        }
        #expect(
            !core.state.workspaces.spaces(on: DisplayID(7))
                .isEmpty
        )
    }

    @Test("a repeated resolve over unchanged inputs is a no-op")
    func repeatedResolveIsANoOp() throws {
        // The dependency the unconditional defer rests on,
        // pinned with a test rather than a comment (tests.md):
        // six branches resolve in-branch and then again in the
        // defer, so a later side effect inside
        // `resolveSpaceDisplays` — an unconditional
        // reassignment, a rotation — would double-fire on all
        // of them with nothing to red but this.
        let core = makeCore()
        core.state.workspaces.upsertDisplay(display(1, "A"))
        core.execute(
            "save_profile",
            args: [.string("known")]
        )
        core.resolveSpaceDisplays()
        let first = core.state.workspaces.allSpaces.map {
            (
                $0.id,
                core.state.workspaces.display(of: $0.id)
            )
        }
        core.resolveSpaceDisplays()
        let second = core.state.workspaces.allSpaces.map {
            (
                $0.id,
                core.state.workspaces.display(of: $0.id)
            )
        }
        #expect(!first.isEmpty)
        #expect(first.map(\.0) == second.map(\.0))
        #expect(first.map(\.1) == second.map(\.1))
    }
}
