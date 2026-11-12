import Testing

@testable import KiwiDeskCore

/// What links a command to its docs (#3213): the names a heading
/// carries and the call a config writes.
@Suite("API reference docs links (#3213)")
struct APIReferenceDocsTests {
    @Test("a heading names its commands")
    func headingNames() {
        #expect(APIReference.commandNames(inHeading: "focus") == ["focus"])
        #expect(
            APIReference.commandNames(
                inHeading: "focus_space_previous / focus_space_next"
            ) == ["focus_space_previous", "focus_space_next"]
        )
        #expect(
            APIReference.commandNames(inHeading: "`KiwiDesk.exec`")
                == ["exec"]
        )
        #expect(
            APIReference.commandNames(
                inHeading: "save_profile, load_profile"
            ) == ["save_profile", "load_profile"]
        )
    }

    @Test("the Lua call spells the table, the name and the arguments")
    func luaCalls() throws {
        let focus = try #require(APIReference.entry(named: "focus"))
        #expect(
            APIReference.luaCall(for: focus) == "KiwiDesk.focus(direction)"
        )
        let width = try #require(
            APIReference.entry(named: "border.set_width")
        )
        let call = try #require(APIReference.luaCall(for: width))
        #expect(call.hasPrefix("border.set_width("))
        let move = try #require(APIReference.entry(named: "move_to_space"))
        #expect(
            APIReference.luaCall(for: move)
                == "KiwiDesk.move_to_space(space, window)"
        )
    }

    @Test("help's JSON carries the call")
    func helpCarriesTheCall() throws {
        let answer = APIReference.helpResponse(for: "focus")
        guard case .object(let fields)? = answer.data else {
            Issue.record("help answered no object")
            return
        }
        #expect(fields["lua"] == .string("KiwiDesk.focus(direction)"))
        let cliOnly = APIReference.helpResponse(
            for: APIReference.socketOnlyCommand
        )
        guard case .object(let bare)? = cliOnly.data else {
            Issue.record("help answered no object")
            return
        }
        #expect(bare["lua"] == nil)
    }

    @Test("a command Lua never registers has no call")
    func cliOnlyHasNoCall() throws {
        #expect(!APIReference.cliOnly.isEmpty)
        for name in APIReference.cliOnly {
            let entry = try #require(APIReference.entry(named: name))
            #expect(APIReference.luaCall(for: entry) == nil, "\(name)")
        }
        for entry in APIReference.entries where entry.channel != .cli {
            let call = try #require(APIReference.luaCall(for: entry))
            #expect(call.hasSuffix(")"))
            #expect(call.contains(entry.name + "("))
        }
    }
}
