import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The app-launch behavior encoding (#334): `appCommand` and its
/// two inverses (`appBundleID` / `appLaunchBehavior`) round-trip
/// both verbs, and non-app Lua stays unmatched.
@Suite("App launch behavior")
struct AppLaunchBehaviorTests {
    @Test("open-or-focus round-trips through pull_or_spawn")
    func openOrFocusRoundTrip() {
        let lua = KeybindingCatalog.appCommand(
            "com.apple.safari",
            behavior: .openOrFocus
        )
        #expect(lua == "KiwiDesk.pull_or_spawn(\"com.apple.safari\")")
        #expect(
            KeybindingCatalog.appBundleID(from: lua)
                == "com.apple.safari"
        )
        #expect(
            KeybindingCatalog.appLaunchBehavior(from: lua)
                == .openOrFocus
        )
    }

    @Test("open-new round-trips through spawn_new")
    func openNewRoundTrip() {
        let lua = KeybindingCatalog.appCommand(
            "com.apple.terminal",
            behavior: .openNew
        )
        #expect(
            lua == "KiwiDesk.spawn_new(\"com.apple.terminal\")"
        )
        #expect(
            KeybindingCatalog.appBundleID(from: lua)
                == "com.apple.terminal"
        )
        #expect(
            KeybindingCatalog.appLaunchBehavior(from: lua)
                == .openNew
        )
    }

    @Test("behavior defaults to open-or-focus")
    func defaultBehavior() {
        // The parameterless call keeps the pre-#334 meaning, so
        // existing call sites author open-or-focus unchanged.
        #expect(
            KeybindingCatalog.appCommand("com.a.b")
                == "KiwiDesk.pull_or_spawn(\"com.a.b\")"
        )
    }

    @Test("every behavior verb is a real API command")
    func verbsExistInAPIReference() {
        // The GUI hardcodes these verb strings to author and parse
        // `lua`; `APIReference` is their single source of truth.
        // Pin the two so a pre-release rename (§5 allows them) can't
        // silently orphan the GUI into authoring a dead verb — the
        // round-trip tests above check the GUI against itself and
        // would stay green through such a drift.
        let known = Set(APIReference.commands.map(\.lua))
        for behavior in AppLaunchBehavior.allCases {
            #expect(known.contains(behavior.verb))
        }
    }

    // MARK: - Taken / available behaviors (add-row seed, grey-out)

    private func appBinding(
        _ bundleID: String,
        _ behavior: AppLaunchBehavior
    ) -> KeyBinding {
        KeyBinding(
            lua: KeybindingCatalog.appCommand(
                bundleID,
                behavior: behavior
            ),
            kind: .application
        )
    }

    @Test("seed skips a behavior already bound for the app")
    func seedSkipsTaken() {
        let bindings = [appBinding("com.a", .openOrFocus)]
        // Re-adding com.a lands on the free behavior, not a
        // duplicate default.
        #expect(
            KeybindingCatalog.firstAvailableBehavior(
                for: "com.a",
                in: bindings
            ) == .openNew
        )
        // A fresh app takes the default first.
        #expect(
            KeybindingCatalog.firstAvailableBehavior(
                for: "com.b",
                in: bindings
            ) == .openOrFocus
        )
    }

    @Test("both behaviors bound ⇒ no available behavior")
    func fullyBound() {
        let bindings = [
            appBinding("com.a", .openOrFocus),
            appBinding("com.a", .openNew),
        ]
        #expect(
            KeybindingCatalog.firstAvailableBehavior(
                for: "com.a",
                in: bindings
            ) == nil
        )
    }

    @Test("takenBehaviors excludes the edited row")
    func takenExcludesSelf() {
        let row = appBinding("com.a", .openNew)
        // Only the row itself binds com.a; excluding it leaves the
        // set empty, so its own behavior isn't greyed against it.
        #expect(
            KeybindingCatalog.takenBehaviors(
                for: "com.a",
                in: [row],
                excluding: row.id
            ).isEmpty
        )
        #expect(
            KeybindingCatalog.takenBehaviors(
                for: "com.a",
                in: [row]
            ) == [.openNew]
        )
    }

    @Test("re-pick keeps a free behavior, else takes the first free")
    func assignmentBehavior() {
        // The edited row lives in the array and is genuinely
        // excluded (its old com.b binding must not count against
        // the com.a target); another row holds com.a / Open New.
        let edited = appBinding("com.b", .openOrFocus)
        let bindings = [appBinding("com.a", .openNew), edited]
        // Preferred (.openNew) is taken by the other row ⇒ fall to
        // the first free (.openOrFocus): no collision.
        #expect(
            KeybindingCatalog.behaviorForAssignment(
                to: "com.a",
                preferred: .openNew,
                in: bindings,
                excluding: edited.id
            ) == .openOrFocus
        )
        // Preferred is free ⇒ preserved.
        #expect(
            KeybindingCatalog.behaviorForAssignment(
                to: "com.a",
                preferred: .openOrFocus,
                in: bindings,
                excluding: edited.id
            ) == .openOrFocus
        )
        // Fresh app ⇒ preferred preserved (the edited row's own
        // old com.b binding is excluded, so it doesn't interfere).
        #expect(
            KeybindingCatalog.behaviorForAssignment(
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
            "KiwiDesk.pull_or_spawn(\"a\"b\")",
        ] {
            #expect(KeybindingCatalog.appBundleID(from: lua) == nil)
            #expect(
                KeybindingCatalog.appLaunchBehavior(from: lua)
                    == nil
            )
        }
    }
}
