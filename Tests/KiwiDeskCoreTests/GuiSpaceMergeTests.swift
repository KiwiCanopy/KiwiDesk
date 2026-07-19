import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-merge-\(UUID().uuidString)"
            )
    )
}

/// `mergeLiveSpaces` is the dashboard's save-time freshness net:
/// spaces that appeared live after the model was seeded are
/// appended (so the save's prune can't drop them and snap focus
/// to the first space), while staged user deletions stay
/// authoritative.
@Suite("GUI save-time space merge", .serialized)
@MainActor
struct GuiSpaceMergeTests {
    @Test("A live space unknown to the model is appended")
    func appendsLiveNewSpace() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        core.mergeLiveSpaces(
            into: &config,
            seededWith: [SpaceID("1")]
        )
        #expect(config.spaces == [SpaceID("1"), SpaceID("2")])
    }

    @Test("A staged deletion is not resurrected")
    func keepsStagedDeletion() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        var config = GuiConfig()
        // Seeded with both; the user deleted "2" this session.
        config.spaces = [SpaceID("1")]
        core.mergeLiveSpaces(
            into: &config,
            seededWith: [SpaceID("1"), SpaceID("2")]
        )
        #expect(config.spaces == [SpaceID("1")])
    }

    @Test("An appended space carries its live layout mode")
    func appendedSpaceKeepsMode() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("3"))
        core.state.workspaces.setMode(SpaceID("3"), .monocle)
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        core.mergeLiveSpaces(
            into: &config,
            seededWith: [SpaceID("1")]
        )
        #expect(config.spaceModes[SpaceID("3")] == .monocle)
    }

    @Test("Staged order and additions survive the merge")
    func stagedEditsStayAuthoritative() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.state.workspaces.ensureSpace(SpaceID("new"))
        var config = GuiConfig()
        // User reordered and added "gui" in the Spaces tab.
        config.spaces = [
            SpaceID("2"), SpaceID("1"), SpaceID("gui"),
        ]
        core.mergeLiveSpaces(
            into: &config,
            seededWith: [SpaceID("1"), SpaceID("2")]
        )
        #expect(
            config.spaces == [
                SpaceID("2"), SpaceID("1"), SpaceID("gui"),
                SpaceID("new"),
            ]
        )
    }

    @Test("A fresh model with no live drift merges to a no-op")
    func noDriftNoChange() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        let before = config
        core.mergeLiveSpaces(
            into: &config,
            seededWith: [SpaceID("1")]
        )
        #expect(config == before)
    }
}
