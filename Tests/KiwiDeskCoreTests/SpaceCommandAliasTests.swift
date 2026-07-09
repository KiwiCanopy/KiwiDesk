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

    @Test("The long move aliases route to the move handler")
    func moveAliasesDispatch() {
        let core = makeCore()
        core.state.workspaces.add(WindowID(1), to: SpaceID("1"))
        core.state.workspaces.activate(SpaceID("1"))
        core.state.workspaces.focus(WindowID(1), in: SpaceID("1"))
        // Long alias moves the focused window to space 2.
        #expect(
            core.execute(
                "move_to_virtual_space",
                args: [.string("2")]
            ).isSuccess
        )
        #expect(
            core.state.workspaces.space(of: WindowID(1))
                == SpaceID("2")
        )
        // Long alias + follow moves it on and switches there.
        core.state.workspaces.activate(SpaceID("2"))
        #expect(
            core.execute(
                "move_to_virtual_space_and_follow",
                args: [.string("3")]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("3"))
    }

    @Test("APIReference pins the space aliases to their one source")
    func apiReferenceMatchesAliasSource() {
        func command(for lua: String) -> String? {
            APIReference.commands.first { $0.lua == lua }?.command
        }
        // Both the canonical and its legacy alias register, and
        // both resolve to the canonical dispatcher command — so
        // the registry can't drift from `spaceCommandAliases`.
        for (canonical, alias) in SpaceLuaArg.spaceCommandAliases {
            #expect(command(for: canonical) == canonical)
            #expect(command(for: alias) == canonical)
        }
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
