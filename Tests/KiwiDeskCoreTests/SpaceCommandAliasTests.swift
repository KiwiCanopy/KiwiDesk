import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-alias-\(UUID().uuidString)"
            )
    )
}

/// Bare `space` is the canonical command vocabulary; the
/// `*_virtual_space` forms stay as compatibility aliases (#42) —
/// both dispatch to the same handler, but only the short form is
/// surfaced as canonical.
@MainActor
struct SpaceCommandAliasTests {
    @Test("Both focus forms dispatch to the same handler")
    func focusAliasDispatches() {
        let core = makeCore()
        _ = core.execute(
            "focus_virtual_space",
            args: [.string("2")]
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        _ = core.execute("focus_space", args: [.string("3")])
        #expect(core.state.workspaces.activeSpace == SpaceID("3"))
    }

    @Test("The long aliases resolve to the short command")
    func aliasesResolveToCanonical() {
        func command(for lua: String) -> String? {
            APIReference.commands.first { $0.lua == lua }?.command
        }
        #expect(
            command(for: "focus_virtual_space") == "focus_space"
        )
        #expect(
            command(for: "move_to_virtual_space") == "move_to_space"
        )
        #expect(
            command(for: "move_to_virtual_space_and_follow")
                == "move_to_space_and_follow"
        )
        // The canonical forms map to themselves.
        #expect(command(for: "focus_space") == "focus_space")
    }

    @Test("Did-you-mean surfaces only the canonical short forms")
    func dispatchableIsCanonical() {
        let names = APIReference.dispatchable
        #expect(names.contains("focus_space"))
        #expect(names.contains("move_to_space"))
        #expect(names.contains("move_to_space_and_follow"))
        // The long aliases never surface as suggestions.
        #expect(!names.contains("focus_virtual_space"))
        #expect(!names.contains("move_to_virtual_space"))
    }
}
