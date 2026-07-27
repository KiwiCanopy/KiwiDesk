import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// The `space_bar.set_*` dispatch surface (#293): writes land on
/// `tiler.settings.spaceBarStyle`, invalid values fail, and the
/// namespace is registered.
@Suite("Space bar commands", .serialized)
@MainActor
struct SpaceBarCommandTests {
    @Test("space_bar.set_* writes the global style")
    func writes() {
        let core = makeCore()
        #expect(
            core.execute(
                "space_bar.set_enabled",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.enabled)
        #expect(
            core.execute(
                "space_bar.set_edge",
                args: [.string("bottom")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.spaceBarStyle.edge == .bottom
        )
        #expect(
            core.execute(
                "space_bar.set_focused_item_color",
                args: [.string("#123456")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.spaceBarStyle.focusedItemColor
                == "#123456"
        )
        #expect(
            core.execute(
                "space_bar.set_hide_empty",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.hideEmpty)
    }

    @Test("Invalid values are rejected")
    func validation() {
        let core = makeCore()
        #expect(
            !core.execute(
                "space_bar.set_edge",
                args: [.string("start")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "space_bar.set_item_color",
                args: [.string("red")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "space_bar.set_wibble",
                args: [.bool(true)]
            ).isSuccess
        )
    }

    @Test("The space_bar namespace is registered")
    func namespaceRegistered() {
        let commands = APIReference.namespaces["space_bar"]
        #expect(commands != nil)
        // The registered verb list mirrors the CodingKeys —
        // every field has a `set_<key>` and nothing else.
        let expected = Set(
            SpaceBarStyle.CodingKeys.allCases.map {
                "set_\($0.stringValue)"
            }
        )
        #expect(Set(commands ?? []) == expected)
    }
}
