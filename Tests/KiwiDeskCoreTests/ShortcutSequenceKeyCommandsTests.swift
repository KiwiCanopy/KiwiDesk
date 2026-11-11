import Foundation
import Testing

@testable import KiwiDeskCore

/// The key-at-a-time sequence verbs (#3174 ▸ Ruling): one verb
/// creates and extends, never replaces; end keys run commands only;
/// a write saves at once through `shortcut.set`'s door.
@Suite("Shortcut sequence key commands (#3174)", .serialized)
@MainActor
struct ShortcutSequenceKeyCommandsTests {
    private let leader = "ctrl+alt+space"

    private func run(
        _ core: KiwiCore,
        _ verb: String,
        _ args: [String]
    ) -> CommandResponse {
        core.execute("shortcut." + verb, args: args.map { .string($0) })
    }

    private func sequence(_ core: KiwiCore) -> KeyBinding? {
        core.guiConfigStore.load()?.layers.first(where: \.isDefault)?
            .sequences.first
    }

    private func focusLeft() throws -> String {
        guard
            case .success(let lua) = ShortcutCall.lua(
                "focus",
                [.string("left")]
            )
        else { throw CancellationError() }
        return lua
    }

    @Test("set makes the leader, the branch and the end key")
    func setCreates() throws {
        let core = try KeepFixture.core()
        let made = run(
            core,
            "set_sequence_key",
            [leader, "w,h", "focus", "left"]
        )
        #expect(made.isSuccess, "\(made.error ?? "")")
        let root = try #require(sequence(core))
        #expect(KeyCombo.equivalent(root.combo, leader))
        let branch = try #require(root.steps?.first)
        #expect(branch.isSequence && branch.combo == "w")
        let end = try #require(branch.steps?.first)
        #expect(end.combo == "h" && !end.isSequence)
        #expect(end.lua == (try focusLeft()))
        // A second key extends the same branch.
        #expect(
            run(core, "set_sequence_key", [leader, "w,l", "focus", "right"])
                .isSuccess
        )
        #expect(sequence(core)?.steps?.first?.steps?.count == 2)
        #expect(sequence(core)?.steps?.count == 1)
    }

    @Test("set replaces nothing and names why")
    func setRefuses() throws {
        let core = try KeepFixture.core()
        _ = run(core, "set_sequence_key", [leader, "w,h", "focus", "left"])
        let before = sequence(core)
        let taken = run(
            core,
            "set_sequence_key",
            [leader, "w,h", "focus", "right"]
        )
        #expect(
            taken.error
                == "w,h is already bound in this sequence; remove it first"
        )
        let through = run(
            core,
            "set_sequence_key",
            [leader, "w,h,j", "focus", "down"]
        )
        #expect(
            through.error
                == "w,h runs a command, so it opens no keys; remove it first"
        )
        #expect(sequence(core) == before)
    }

    @Test("admission is the router's: Hyper leaders, esc, the leader")
    func admission() throws {
        let core = try KeepFixture.core()
        #expect(
            run(core, "set_sequence_key", ["hyper+a", "w", "focus", "left"])
                .error == "a key sequence can't start on a Hyper chord"
        )
        let esc = run(
            core,
            "set_sequence_key",
            [leader, "escape", "focus", "left"]
        )
        #expect(esc.error?.hasPrefix("escape can't be a key") == true)
        #expect(
            !run(core, "set_sequence_key", [leader, leader, "focus", "left"])
                .isSuccess
        )
        #expect(sequence(core) == nil)
    }

    @Test("commands only: raw Lua and shortcut verbs are refused")
    func commandsOnly() throws {
        let core = try KeepFixture.core()
        for verb in ["exec", "shortcut.set", "delete_profile"] {
            let refused = run(
                core,
                "set_sequence_key",
                [leader, "w", verb, "x"]
            )
            #expect(refused.error?.hasSuffix("cannot be bound") == true)
        }
        #expect(sequence(core) == nil)
    }

    @Test("a leader another shortcut holds is refused")
    func leaderClash() throws {
        let core = try KeepFixture.core()
        #expect(
            run(core, "set", ["ctrl+alt+h", "focus", "left"]).isSuccess
        )
        let refused = run(
            core,
            "set_sequence_key",
            ["ctrl+alt+h", "w", "focus", "right"]
        )
        #expect(refused.error?.hasSuffix("; remove it first") == true)
        #expect(refused.error?.contains("runs") == true)
        #expect(sequence(core) == nil)
    }

    @Test("name labels a leader or branch and refuses an end key")
    func name() throws {
        let core = try KeepFixture.core()
        _ = run(core, "set_sequence_key", [leader, "w,h", "focus", "left"])
        #expect(
            run(core, "name_sequence_key", [leader, "", "Leader"])
                .isSuccess
        )
        #expect(
            run(
                core,
                "name_sequence_key",
                [leader, "w", "Windows", "macwindow"]
            )
            .isSuccess
        )
        let root = try #require(sequence(core))
        #expect(root.label == "Leader")
        #expect(root.steps?.first?.label == "Windows")
        #expect(root.steps?.first?.symbol == "macwindow")
        #expect(
            run(core, "name_sequence_key", [leader, "w,h", "Left"]).error?
                .hasPrefix("only a leader or a key that opens keys") == true
        )
        #expect(
            run(core, "name_sequence_key", [leader, "w", "W", "no.such.sym"])
                .error == "no.such.sym is not an SF Symbol name"
        )
        #expect(
            run(core, "name_sequence_key", ["ctrl+alt+k", "", "X"]).error
                == "no key sequence on control+option+k"
        )
    }

    @Test("remove takes one key with its keys, never the whole")
    func remove() throws {
        let core = try KeepFixture.core()
        _ = run(core, "set_sequence_key", [leader, "w,h", "focus", "left"])
        #expect(
            run(core, "set_sequence_key", [leader, "t", "toggle_floating"])
                .isSuccess
        )
        #expect(run(core, "remove_sequence_key", [leader, "w"]).isSuccess)
        #expect(sequence(core)?.steps?.map(\.combo) == ["t"])
        #expect(
            run(core, "remove_sequence_key", [leader, "w"]).error
                == "no key on w in this sequence"
        )
        #expect(
            run(core, "remove_sequence_key", [leader, ""]).error?
                .contains("shortcut.remove_sequence") == true
        )
    }

    @Test("one step holds one key per chord, held modifiers apart")
    func siblingRule() {
        let held = KeyBinding(combo: "ctrl+w", lua: "x")
        let step = [held, KeyBinding(combo: "w", lua: "y")]
        #expect(
            KeyBinding.stepKey(holding: "control+w", in: step)?.id
                == held.id
        )
        #expect(
            KeyBinding.stepKey(holding: "ctrl+w", in: step, besides: held.id)
                == nil
        )
        #expect(KeyBinding.stepKey(holding: "shift+w", in: step) == nil)
        #expect(KeyBinding.stepKey(holding: "", in: step) == nil)
    }

    @Test("registered as settings, safe for run")
    func registered() {
        for verb in [
            "set_sequence_key", "name_sequence_key", "remove_sequence_key",
        ] {
            let name = "shortcut." + verb
            #expect(!APIReference.destructive.contains(name))
            let entry = APIReference.entry(named: name)
            #expect(entry.map(APIReference.kind(of:)) == .setting)
        }
    }
}
