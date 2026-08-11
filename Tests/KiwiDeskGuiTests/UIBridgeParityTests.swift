import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The UI-bridge verb family is four hand-mirrored lists — a
/// `UIBridgeHooks` field, a `lua.register` call, an
/// `APIReference.luaOnly` entry, and the `AppDelegate` wiring —
/// and a verb missing any one of them fails in a way nothing
/// else sees: it registers and does nothing, or it never
/// registers and `help()` still advertises it. Both are silent,
/// and a per-verb unit test cannot catch either, because such a
/// test assigns the hook itself.
///
/// So the roster is DERIVED from the struct's own fields
/// (`parity-tests.md`: prefer reflection over a hand-listed
/// mirror) and the other three lists are held against it. The
/// field-name convention is the join: `onOpenSettings` names
/// `open_settings`, stated on `UIBridgeHooks` itself.
///
/// Stated limit, the one reflection cannot close: `Mirror`
/// reports a closure field's label but not a callable value, so
/// this cannot fire a verb and observe the hook — it proves each
/// list NAMES the verb, not that the wiring closure does the
/// right thing. `OpenSettingsVerbTests` / `ShowShortcutsVerbTests`
/// own that half, one verb at a time.
@Suite("UI-bridge verb parity")
@MainActor
struct UIBridgeParityTests {
    /// `onOpenSettings` -> `open_settings`.
    private func verbName(forField label: String) -> String {
        let stem =
            label.hasPrefix("on")
            ? String(label.dropFirst(2)) : label
        var verb = ""
        for character in stem {
            if character.isUppercase, !verb.isEmpty {
                verb.append("_")
            }
            verb.append(Character(character.lowercased()))
        }
        return verb
    }

    private var verbs: [String] {
        Mirror(reflecting: UIBridgeHooks())
            .children
            .compactMap(\.label)
            .map(verbName(forField:))
    }

    @Test("Every hook field names a Lua-only verb")
    func hooksAreListedAsLuaOnly() {
        let verbs = verbs
        // The roster is reflected, so it is empty if the struct
        // ever stops reporting fields — which would pass every
        // assertion below by having nothing to check.
        #expect(verbs.count >= 2)
        for verb in verbs {
            #expect(
                APIReference.luaOnly.contains(verb),
                Comment(rawValue: verb)
            )
            // A UI-bridge verb raises a hook and returns no
            // `CommandResponse`, so it must NOT be dispatchable
            // from the CLI or the IPC socket.
            #expect(
                !APIReference.dispatchable.contains(verb),
                Comment(rawValue: verb)
            )
        }
    }

    @Test("Every hook field is registered on the Lua table")
    func hooksAreRegistered() throws {
        // Each test repeats the floor rather than leaning on a
        // sibling's: a `--filter` run names one, and a roster
        // reflection stopped reporting would leave that one
        // passing over nothing.
        #expect(verbs.count >= 2)
        let source = try SourceScan.stripComments(
            String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDeskCore/Lua/"
                            + "KiwiCore+LuaAPI.swift"
                    ),
                encoding: .utf8
            )
        )
        for verb in verbs {
            #expect(
                source.contains("lua.register(\"\(verb)\")"),
                Comment(rawValue: verb)
            )
        }
    }

    @Test("Every hook field is wired by the app delegate")
    func hooksAreWired() throws {
        #expect(verbs.count >= 2)
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var wired = ""
        for file in try SourceScan.swiftSources(under: root) {
            wired += SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
        }
        for field in Mirror(reflecting: UIBridgeHooks())
            .children.compactMap(\.label)
        {
            // Keyed on the ASSIGNMENT, not the mention: a hook
            // named in a comment or read back somewhere is not
            // a hook the app answers.
            #expect(
                wired.contains("uiBridge.\(field) ="),
                Comment(rawValue: field)
            )
        }
    }
}
