import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-monocle-raise-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// A Monocle focus change is a raise and nothing else (#2099):
/// the flip (#1391) is gone, its verbs retired with no alias, and
/// a stored config that still carries its keys loads as before.
@Suite("Monocle focus is a raise (#2099)")
@MainActor
struct MonocleRaiseTests {
    /// Both flip verbs answer as retired and name why, so an
    /// `init.lua` that still calls them reports a Config Issue
    /// rather than a bare unknown command.
    @Test("the flip's verbs are retired with a reason")
    func flipVerbsRetire() {
        let core = makeCore()
        for (verb, arg) in [
            ("animations.set_on_monocle_focus", JSONValue.bool(true)),
            ("animations.set_monocle_flip_duration", .number(450)),
        ] {
            let response = core.execute(verb, args: [arg])
            #expect(!response.isSuccess, "\(verb)")
            #expect(
                response.error?.contains("plays no flip") == true,
                "\(verb)"
            )
            #expect(APIReference.retired[verb] == .some(nil))
        }
    }

    /// No migration: a 2.x file's `on_monocle_focus` and
    /// `monocle_flip_duration` decode as unknown keys, cost none
    /// of the leaves beside them, and are not written back.
    @Test("stored flip keys load and are dropped on save")
    func storedFlipKeysAreIgnored() throws {
        let stored = """
            {"on_monocle_focus": false, "monocle_flip_duration": 300,
             "duration": 220, "on_shelf": false}
            """
        let decoded = try JSONDecoder().decode(
            AnimationSettings.self,
            from: Data(stored.utf8)
        )
        #expect(decoded.durationMS == 220)
        #expect(!decoded.onShelf)
        let written = try String(
            decoding: JSONEncoder().encode(decoded),
            as: UTF8.self
        )
        #expect(!written.contains("monocle"))
    }

    /// A step lands its focus in the same call: nothing is owed
    /// to a later landing, so the next command reads the window
    /// the step brought to the front.
    @Test("a Monocle step focuses at once")
    func stepFocusesAtOnce() {
        let core = makeCore()
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        #expect(
            core.execute(
                "set_mode",
                args: [.string(space.raw), .string("monocle")]
            ).isSuccess
        )
        #expect(core.activeSpace?.mode == .monocle)
        core.state.workspaces.focus(WindowID(1), in: space)
        #expect(
            core.execute("focus", args: [.string("right")]).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(2))
        #expect(core.state.workspaces.lastFocused == WindowID(2))
    }
}
