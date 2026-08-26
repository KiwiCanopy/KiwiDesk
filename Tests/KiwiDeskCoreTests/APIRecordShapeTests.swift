import Foundation
import Testing

@testable import KiwiDeskCore

/// The shape 262 records written by different hands must share
/// (#1033).
///
/// Not a taste guard: `list_commands` prints these in one
/// aligned column, so a summary that runs to a paragraph, wraps
/// a newline or trails no full stop breaks the listing rather
/// than merely reading oddly. Each clause pins the SHAPE a
/// summary has, never the words it currently uses
/// (`tests.md`) — retuning a sentence must not red anything.
@Suite("API record shape")
struct APIRecordShapeTests {
    /// Long enough for a real sentence, short enough that a name
    /// column and a summary still fit a wide terminal line.
    static let summaryLimit = 96

    @Test("a written summary is one capitalized sentence")
    func summaries() {
        for entry in APIReference.entries
        where !entry.record.isPending {
            let summary = entry.record.summary
            let name = entry.qualifiedName
            #expect(
                !summary.contains("\n"),
                "\(name): a summary is one line"
            )
            #expect(
                summary.hasSuffix("."),
                "\(name): a summary ends in a full stop"
            )
            #expect(
                summary.first?.isUppercase == true,
                "\(name): a summary opens with a capital"
            )
            let overLong =
                "\(name): \(summary.count) characters, over the "
                + "\(Self.summaryLimit) the column allows"
            #expect(
                summary.count <= Self.summaryLimit,
                "\(overLong)"
            )
            #expect(
                summary.trimmingCharacters(in: .whitespaces)
                    == summary,
                "\(name): a summary carries no edge whitespace"
            )
        }
    }

    @Test("a pending summary is the shared placeholder")
    func pendingSummariesAreIdentical() {
        // Phase 2 replaces `.todo()` wholesale. A hand-written
        // near-miss ("TODO", "") would slip past the count in
        // `APIRecordFilledTests`, which asks `isPending`.
        for entry in APIReference.entries {
            let summary = entry.record.summary
            #expect(
                !summary.isEmpty,
                "\(entry.qualifiedName): empty summary"
            )
            #expect(
                !summary.lowercased().contains("todo"),
                "\(entry.qualifiedName): use .todo(), not prose"
            )
        }
    }

    @Test("argument names are lower_snake_case and unique")
    func argumentNames() {
        for entry in APIReference.entries {
            let names = entry.record.arguments.map(\.name)
            #expect(
                Set(names).count == names.count,
                "\(entry.qualifiedName): repeated argument name"
            )
            for name in names {
                let legal = name.allSatisfy {
                    ($0.isLetter && $0.isLowercase)
                        || $0.isNumber || $0 == "_"
                }
                let message =
                    "\(entry.qualifiedName): argument "
                    + "'\(name)' is not lower_snake_case"
                #expect(!name.isEmpty && legal, "\(message)")
            }
        }
    }

    @Test("optional arguments come last")
    func optionalArgumentsTrail() {
        // A positional list cannot skip an argument, so a
        // required one after an optional one is unreachable.
        for entry in APIReference.entries {
            let flags = entry.record.arguments.map(\.isOptional)
            let firstOptional = flags.firstIndex(of: true)
            let message =
                "\(entry.qualifiedName): a required argument "
                + "follows an optional one"
            guard let firstOptional else { continue }
            #expect(
                flags[firstOptional...].allSatisfy { $0 },
                "\(message)"
            )
        }
    }

    @Test("every enum-typed argument resolves to a Swift type")
    func choicesCarryTheirType() {
        for entry in APIReference.entries {
            for argument in entry.record.arguments {
                guard case .choice(let choice) = argument.kind
                else { continue }
                check(choice, of: argument, in: entry)
            }
        }
    }

    private func check(
        _ choice: APIChoice,
        of argument: APIArgument,
        in entry: APIEntry
    ) {
        let site = "\(entry.qualifiedName).\(argument.name)"
        #expect(
            choice.values.count >= 2,
            "\(site): an enum under two cases is no choice"
        )
        #expect(
            choice.values.allSatisfy { !$0.isEmpty },
            "\(site): empty case spelling"
        )
        #expect(
            Set(choice.values).count == choice.values.count,
            "\(site): repeated case spelling"
        )
        // `String(reflecting:)` on a real metatype gives a
        // dotted type path; a hand-written label would not have
        // to. This is the runtime half of
        // `APIChoiceDerivationTests`, which holds that no second
        // initializer exists to write one.
        let named =
            !choice.type.isEmpty && !choice.type.contains(" ")
            && choice.type.first?.isUppercase == true
        let message =
            "\(site): '\(choice.type)' is not a Swift type name"
        #expect(named, "\(message)")
    }

    @Test("a socket-reachable command takes no Lua-only value")
    func luaOnlyKindsStayLuaOnly() {
        // A callback and a table cannot cross the socket, so a
        // record claiming one on a dispatchable command is
        // describing something the CLI could never send.
        for entry in APIReference.entries
        where entry.channel != .lua {
            for argument in entry.record.arguments {
                let isLuaValue =
                    argument.kind == .callback
                    || argument.kind == .table
                let message =
                    "\(entry.qualifiedName): \(argument.name) is "
                    + "a Lua value on a socket command"
                #expect(!isLuaValue, "\(message)")
            }
        }
    }
}
