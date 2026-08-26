import Foundation
import Testing

@testable import KiwiDeskCore

/// Every command has a record, and every record has a command
/// (#1033).
///
/// **This is the guard that makes #1033 phase 2 mechanical.**
/// The record tables are a second listing of names that already
/// exist in `commands`, `namespaces` and `luaOnly`, which is the
/// shape `parity-tests.md` sends to a forget-proof test: the key
/// sets are derived from the name tables by reflection here, so
/// a record written for a command that does not exist, a
/// namespace function that gains no record, or a record filed
/// under the wrong table all red — none of which the compiler
/// can see, because both sides are `String` keys.
///
/// It runs in both directions on purpose. Missing-only would
/// pass a table full of invented names; extra-only would pass an
/// empty table.
@Suite("API record census")
struct APIRecordCensusTests {
    /// "in A but not B" both ways, as one message.
    private func difference(
        _ left: Set<String>,
        _ leftLabel: String,
        _ right: Set<String>,
        _ rightLabel: String
    ) -> String {
        "\(leftLabel): \(left.subtracting(right).sorted()); "
            + "\(rightLabel): \(right.subtracting(left).sorted())"
    }

    @Test("every dispatcher verb has a record, and vice versa")
    func dispatcherVerbs() {
        let verbs = Set(APIReference.commands.map(\.command))
            .union([APIReference.socketOnlyCommand])
        let records = Set(APIReference.coreRecords.keys)
        let message = difference(
            verbs,
            "verbs with no record",
            records,
            "records for no verb"
        )
        #expect(verbs == records, "\(message)")
    }

    @Test("the two core record files do not overlap")
    func coreRecordFilesAreDisjoint() {
        // `coreRecords` merges them, so a verb recorded twice
        // would satisfy the census above while one of the two
        // records is silently unreachable.
        let both = APIReference.duplicateCoreRecordKeys
        #expect(both.isEmpty, "recorded twice: \(both.sorted())")
    }

    @Test("every namespace table has a record table")
    func namespaceTables() {
        let tables = Set(APIReference.namespaces.keys)
        let records = Set(APIReference.namespaceRecords.keys)
        let message = difference(
            tables,
            "tables with no records",
            records,
            "record tables with no namespace"
        )
        #expect(tables == records, "\(message)")
    }

    @Test("a record's group matches the table it lives in")
    func namespaceFunctions() {
        for (table, functions) in APIReference.namespaces {
            let declared = Set(functions)
            let records = Set(
                APIReference.namespaceRecords[table]?
                    .map(\.key) ?? []
            )
            let message =
                "\(table) — "
                + difference(
                    declared,
                    "functions with no record",
                    records,
                    "records for no function"
                )
            #expect(declared == records, "\(message)")
        }
    }

    @Test("every Lua-only entry point has a record")
    func luaOnlyEntryPoints() {
        let declared = Set(APIReference.luaOnly)
        let records = Set(APIReference.luaOnlyRecords.keys)
        let message = difference(
            declared,
            "entry points with no record",
            records,
            "records for no entry point"
        )
        #expect(declared == records, "\(message)")
    }

    @Test("the listing covers the whole surface, once each")
    func listingIsTotal() {
        let names = APIReference.entries.map(\.qualifiedName)
        let repeated = names.filter { name in
            names.filter { $0 == name }.count > 1
        }
        #expect(
            Set(names).count == names.count,
            "listed twice: \(Set(repeated).sorted())"
        )
        // `allCommands` is the pre-#1033 answer to "what does
        // help list": everything dispatchable plus the Lua-only
        // entry points. The grouped listing must still be it.
        #expect(Set(names) == Set(APIReference.allCommands))
    }

    @Test("an alias resolves to the command it spells")
    func aliasesResolve() {
        // `list_commands` is `help` under another Lua name, and
        // it is the only one today — but the entry is derived
        // from `commands`, so a second alias needs no edit here.
        for entry in APIReference.entries {
            for alias in entry.aliases {
                #expect(
                    APIReference.entry(named: alias)?
                        .qualifiedName == entry.qualifiedName
                )
            }
        }
        #expect(
            APIReference.entry(named: "list_commands")?.command
                == "help"
        )
    }
}
