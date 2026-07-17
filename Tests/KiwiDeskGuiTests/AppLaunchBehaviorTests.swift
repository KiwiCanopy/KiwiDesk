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
