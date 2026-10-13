import Foundation
import Testing

@testable import KiwiDeskCore

/// The destructive register (#1685): `kiwidesk mcp` sends every
/// command it lists to the tool MCP clients confirm, and every
/// other command to the one they may run unasked. A command
/// missing from it is run without asking the user.
///
/// No guard can read whether a verb loses something, so the net
/// is the verb's NAME: a command whose last word starts with a
/// destructive verb is in the register or ruled out below. A
/// destructive verb named otherwise (`set_*` that drops a file)
/// is outside this net and is review's.
@Suite("destructive command register")
struct APIDestructiveCensusTests {
    /// Verb prefixes that read as losing something.
    static let destructiveVerbs = [
        "delete", "remove", "close", "reset", "clear", "reload",
        "load", "save", "import", "restore", "discard", "forget",
        "kill", "quit", "prepare_restart", "drop", "overwrite",
        "apply", "replace", "rename", "bind", "unbind",
    ]

    /// Commands whose name reads destructive and which lose
    /// nothing, each with its reason.
    static let ruledSafe: [String: String] = [:]

    @Test("every registered name is a command a caller can run")
    func membersAreCommands() {
        let runnable = Set(
            APIReference.entries.filter { $0.command != nil }
                .map(\.qualifiedName)
        )
        #expect(!APIReference.destructive.isEmpty)
        for name in APIReference.destructive {
            let message =
                "\(name) is in the destructive register but is "
                + "no command"
            #expect(runnable.contains(name), "\(message)")
        }
    }

    @Test("a verb named like a destructive one is ruled")
    func destructiveNamesAreRuled() {
        let runnable = APIReference.entries.filter {
            $0.command != nil
        }
        #expect(!runnable.isEmpty)
        for entry in runnable {
            let verb = entry.name
            guard
                Self.destructiveVerbs.contains(where: {
                    verb == $0 || verb.hasPrefix($0 + "_")
                })
            else { continue }
            let name = entry.qualifiedName
            let message =
                "\(name) reads destructive: add it to "
                + "APIReference.destructive or rule it safe here"
            #expect(
                APIReference.destructive.contains(name)
                    || Self.ruledSafe[name] != nil,
                "\(message)"
            )
        }
    }

    @Test("ruled-safe entries name commands outside the register")
    func ruledSafeIsDisjoint() {
        for name in Self.ruledSafe.keys {
            #expect(!APIReference.destructive.contains(name))
            #expect(APIReference.entry(named: name) != nil)
        }
    }

    @Test("the listing carries the flag, by name and by alias")
    func listingCarriesTheFlag() throws {
        let response = APIReference.helpResponse(for: "delete_space")
        guard case .object(let entry)? = response.data else {
            Issue.record("expected an object payload")
            return
        }
        #expect(entry["destructive"] == .bool(true))
        let safe = APIReference.helpResponse(for: "focus")
        guard case .object(let other)? = safe.data else {
            Issue.record("expected an object payload")
            return
        }
        #expect(other["destructive"] == .bool(false))
        #expect(APIReference.isDestructive("delete_space"))
        #expect(!APIReference.isDestructive("focus"))
        // A Lua spelling resolves to its command, so it reads
        // that command's flag.
        let alias = try #require(
            APIReference.entries.first {
                !$0.aliases.isEmpty && $0.command != nil
            }
        )
        for name in alias.aliases {
            #expect(
                APIReference.entry(named: name)?.qualifiedName
                    == alias.qualifiedName
            )
            #expect(
                APIReference.isDestructive(name)
                    == APIReference.isDestructive(alias)
            )
        }
    }
}
