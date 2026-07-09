import Foundation
import Testing

@testable import KiwiDeskCore

/// `SpaceLuaArg.targetSpace(of:)` (#92): the strict inverse of
/// the catalog's authoring — it recognizes exactly the Lua the
/// GUI generates and nothing else.
@Suite("Space-targeting Lua parse (#92)")
struct SpaceLuaArgTargetTests {
    @Test("parses all three space-targeting calls")
    func parsesAllCalls() {
        for call in [
            "focus_space",
            "move_to_space",
            "move_to_space_and_follow",
        ] {
            let lua = "KiwiDesk.\(call)(\"6\")"
            #expect(
                SpaceLuaArg.targetSpace(of: lua)
                    == SpaceID("6")
            )
        }
    }

    @Test("move_to_space never matches inside _and_follow")
    func prefixDisambiguation() {
        let lua =
            "KiwiDesk.move_to_space_and_follow(\"mail\")"
        #expect(
            SpaceLuaArg.targetSpace(of: lua)
                == SpaceID("mail")
        )
    }

    @Test("round-trips a name the quoter had to escape")
    func escapedNameRoundTrip() {
        let name = "a\"b\\c\nd"
        let lua =
            "KiwiDesk.focus_space"
            + "(\(SpaceLuaArg.quote(name)))"
        #expect(
            SpaceLuaArg.targetSpace(of: lua)
                == SpaceID(name)
        )
    }

    @Test("rejects Lua the catalog never authors")
    func rejectsForeignLua() {
        let foreign = [
            // Bare-number arg: hand-written, outside GUI
            // management.
            "KiwiDesk.focus_space(2)",
            // Extra statement appended.
            "KiwiDesk.focus_space(\"2\"); print(1)",
            // Different call entirely.
            "KiwiDesk.focus(\"left\")",
            "KiwiDesk.reload_config()",
            // Unterminated / malformed quoting.
            "KiwiDesk.focus_space(\"2)",
            "KiwiDesk.focus_space(\"a\\q\")",
            "KiwiDesk.focus_space(\"a\" .. \"b\")",
            "",
        ]
        for lua in foreign {
            #expect(
                SpaceLuaArg.targetSpace(of: lua) == nil,
                "matched: \(lua)"
            )
        }
    }
}
