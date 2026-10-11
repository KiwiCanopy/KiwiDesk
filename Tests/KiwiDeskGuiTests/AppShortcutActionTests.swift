import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The app-action encoding (#334): `appCommand` and its
/// two inverses (`appBundleID` / `appShortcutAction`) round-trip
/// both verbs, and non-app Lua stays unmatched.
@Suite("App action")
struct AppShortcutActionTests {
    @Test("open-or-focus round-trips through focus_or_spawn")
    func openOrFocusRoundTrip() {
        let lua = KeybindingCatalog.appCommand(
            "com.apple.safari",
            action: .openOrFocus
        )
        #expect(lua == "KiwiDesk.focus_or_spawn(\"com.apple.safari\")")
        #expect(
            KeybindingCatalog.appBundleID(from: lua)
                == "com.apple.safari"
        )
        #expect(
            KeybindingCatalog.appShortcutAction(from: lua)
                == .openOrFocus
        )
    }

    @Test("open-new round-trips through spawn_new")
    func openNewRoundTrip() {
        let lua = KeybindingCatalog.appCommand(
            "com.apple.terminal",
            action: .openNew
        )
        #expect(
            lua == "KiwiDesk.spawn_new(\"com.apple.terminal\")"
        )
        #expect(
            KeybindingCatalog.appBundleID(from: lua)
                == "com.apple.terminal"
        )
        #expect(
            KeybindingCatalog.appShortcutAction(from: lua)
                == .openNew
        )
    }

    @Test("gather round-trips through gather (#1510)")
    func gatherRoundTrip() {
        let lua = KeybindingCatalog.appCommand(
            "com.apple.notes",
            action: .gather
        )
        #expect(lua == "KiwiDesk.gather(\"com.apple.notes\")")
        #expect(
            KeybindingCatalog.appShortcutAction(from: lua) == .gather
        )
    }

    @Test("action defaults to open-or-focus")
    func defaultAction() {
        // The parameterless call keeps the pre-#334 meaning, so
        // existing call sites author open-or-focus unchanged.
        #expect(
            KeybindingCatalog.appCommand("com.a.b")
                == "KiwiDesk.focus_or_spawn(\"com.a.b\")"
        )
    }

    @Test("every action verb is a real API command")
    func verbsExistInAPIReference() {
        // The GUI hardcodes these verb strings to author and parse
        // `lua`; `APIReference` is their single source of truth.
        // Pin the two so a pre-release rename (§5 allows them) can't
        // silently orphan the GUI into authoring a dead verb — the
        // round-trip tests above check the GUI against itself and
        // would stay green through such a drift.
        let known = Set(APIReference.commands.map(\.lua))
        for action in AppShortcutAction.allCases {
            #expect(known.contains(action.verb))
        }
    }

    // MARK: - Taken / available actions (add-row seed, grey-out)

    private func appBinding(
        _ bundleID: String,
        _ action: AppShortcutAction
    ) -> KeyBinding {
        KeyBinding(
            lua: KeybindingCatalog.appCommand(
                bundleID,
                action: action
            ),
            kind: .application
        )
    }

    @Test("seed skips a action already bound for the app")
    func seedSkipsTaken() {
        let bindings = [appBinding("com.a", .openOrFocus)]
        // Re-adding com.a lands on the free action, not a
        // duplicate default.
        #expect(
            KeybindingCatalog.firstAvailableAction(
                for: "com.a",
                in: bindings
            ) == .openNew
        )
        // A fresh app takes the default first.
        #expect(
            KeybindingCatalog.firstAvailableAction(
                for: "com.b",
                in: bindings
            ) == .openOrFocus
        )
    }

    @Test("every action bound ⇒ no available action")
    func fullyBound() {
        let bindings = [
            appBinding("com.a", .openOrFocus),
            appBinding("com.a", .openNew),
            appBinding("com.a", .gather),
        ]
        #expect(
            KeybindingCatalog.firstAvailableAction(
                for: "com.a",
                in: bindings
            ) == nil
        )
    }

    @Test("takenActions excludes the edited row")
    func takenExcludesSelf() {
        let row = appBinding("com.a", .openNew)
        // Only the row itself binds com.a; excluding it leaves the
        // set empty, so its own action isn't greyed against it.
        #expect(
            KeybindingCatalog.takenActions(
                for: "com.a",
                in: [row],
                excluding: row.id
            ).isEmpty
        )
        #expect(
            KeybindingCatalog.takenActions(
                for: "com.a",
                in: [row]
            ) == [.openNew]
        )
    }

    @Test("re-pick keeps a free action, else takes the first free")
    func assignmentAction() {
        // The edited row lives in the array and is genuinely
        // excluded (its old com.b binding must not count against
        // the com.a target); another row holds com.a / Open New.
        let edited = appBinding("com.b", .openOrFocus)
        let bindings = [appBinding("com.a", .openNew), edited]
        // Preferred (.openNew) is taken by the other row ⇒ fall to
        // the first free (.openOrFocus): no collision.
        #expect(
            KeybindingCatalog.actionForAssignment(
                to: "com.a",
                preferred: .openNew,
                in: bindings,
                excluding: edited.id
            ) == .openOrFocus
        )
        // Preferred is free ⇒ preserved.
        #expect(
            KeybindingCatalog.actionForAssignment(
                to: "com.a",
                preferred: .openOrFocus,
                in: bindings,
                excluding: edited.id
            ) == .openOrFocus
        )
        // Fresh app ⇒ preferred preserved (the edited row's own
        // old com.b binding is excluded, so it doesn't interfere).
        #expect(
            KeybindingCatalog.actionForAssignment(
                to: "com.b",
                preferred: .openNew,
                in: bindings,
                excluding: edited.id
            ) == .openNew
        )
    }

    @Test("non-app Lua matches neither inverse")
    func nonAppLua() {
        for lua in [
            "KiwiDesk.focus(\"left\")",
            "KiwiDesk.reload_config()",
            // An embedded quote is escaped content the menu never
            // authors — stays unmatched.
            "KiwiDesk.focus_or_spawn(\"a\"b\")",
        ] {
            #expect(KeybindingCatalog.appBundleID(from: lua) == nil)
            #expect(
                KeybindingCatalog.appShortcutAction(from: lua)
                    == nil
            )
        }
    }
}
