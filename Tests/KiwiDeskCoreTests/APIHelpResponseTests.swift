import Foundation
import Testing

@testable import KiwiDeskCore

/// What `help` / `list_commands` answer (#1033).
///
/// Before this, both answered the same 6.9 KB array of 262 bare
/// names whatever they were asked — the argument was read and
/// dropped on the floor.
@Suite("help and list_commands")
struct APIHelpResponseTests {
    @Test("with no name, the listing is grouped and counted")
    func listing() throws {
        let response = APIReference.helpResponse()
        #expect(response.isSuccess)
        guard case .object(let payload)? = response.data else {
            Issue.record("expected an object payload")
            return
        }
        #expect(
            payload["commands"]?.numberValue
                == Double(APIReference.allCommands.count)
        )
        guard case .array(let groups)? = payload["groups"] else {
            Issue.record("expected a groups array")
            return
        }
        #expect(
            groups.count
                == APIReference.namespaces.count + 1,
            "one group per namespace table, plus KiwiDesk"
        )
    }

    @Test("with a name, one record answers")
    func oneRecord() {
        let response = APIReference.helpResponse(
            for: "scroll.set_anchor"
        )
        #expect(response.isSuccess)
        guard case .object(let entry)? = response.data else {
            Issue.record("expected an object payload")
            return
        }
        #expect(entry["group"]?.stringValue == "scroll")
        #expect(entry["name"]?.stringValue == "set_anchor")
        #expect(
            entry["command"]?.stringValue == "scroll.set_anchor"
        )
        #expect(entry["channel"]?.stringValue == "both")
    }

    @Test("an enum argument carries its decoder's cases")
    func choiceValuesAreDerived() {
        let response = APIReference.helpResponse(
            for: "scroll.set_anchor"
        )
        guard case .object(let entry)? = response.data,
            case .array(let arguments)? = entry["arguments"],
            case .object(let anchor)? = arguments.first,
            case .array(let values)? = anchor["values"]
        else {
            Issue.record("expected one enum argument")
            return
        }
        // Read off the decoder, so this cannot be a second
        // spelling: the expectation names the same type the
        // parser calls `init(rawValue:)` on.
        #expect(
            values.compactMap(\.stringValue)
                == ScrollingParams.Anchor.allCases.map(\.rawValue)
        )
        #expect(
            anchor["value_type"]?.stringValue
                == "ScrollingParams.Anchor"
        )
    }

    @Test("an unknown name fails with a suggestion")
    func unknownName() {
        let response = APIReference.helpResponse(for: "focsu")
        #expect(!response.isSuccess)
        #expect(response.error?.contains("focus") == true)
    }

    @Test("help suggests Lua-only names, did-you-mean does not")
    func helpSuggestionReachesLuaOnly() {
        // #37 keeps `suggestion` to what the caller's channel can
        // invoke; a help lookup has no such limit, and pointing
        // at `bind` is the useful answer.
        #expect(APIReference.helpSuggestion(for: "bnid") == "bind")
        #expect(APIReference.suggestion(for: "bnid") != "bind")
    }

    @Test("an alias is a name help answers to")
    func aliasLookup() {
        let response = APIReference.helpResponse(
            for: "list_commands"
        )
        #expect(response.isSuccess)
        guard case .object(let entry)? = response.data else {
            Issue.record("expected an object payload")
            return
        }
        #expect(entry["command"]?.stringValue == "help")
    }

}

/// The dispatcher half: `help` used to ignore its argument, so
/// `list_commands focus` answered with all 262 names (#1033).
@Suite("help through the dispatcher", .serialized)
@MainActor
struct APIHelpDispatchTests {
    @Test("the dispatcher reads the argument it used to drop")
    func dispatcherRoutesTheName() {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-help-\(UUID().uuidString)"
                )
        )
        let listing = core.execute("list_commands")
        guard case .object(let all)? = listing.data else {
            Issue.record("expected a grouped listing")
            return
        }
        #expect(all["groups"] != nil)

        let one = core.execute(
            "help",
            args: [.string("scroll.set_anchor")]
        )
        guard case .object(let entry)? = one.data else {
            Issue.record("expected one record")
            return
        }
        #expect(entry["group"]?.stringValue == "scroll")
    }
}
