import Foundation
import KiwiDeskCore

/// Renders the API listing for a terminal (#1033).
///
/// English, like every other CLI string (core-boundaries.md):
/// Core returns the structure, and this is the CLI narrating it.
/// Pure string work over `APIEntry`, so a test can read what a
/// user would see without owning a terminal.
enum CLIHelpText {
    /// The whole surface: one block per group, each command's
    /// call signature aligned against its summary.
    static func listing(
        of groups: [APIReference.APIGroup]
    ) -> String {
        let count = groups.reduce(0) { $0 + $1.entries.count }
        var lines = [
            "KiwiDesk — \(count) commands in "
                + "\(groups.count) groups",
            "",
            "run 'kiwidesk help <name>' for one command's "
                + "arguments",
        ]
        for group in groups {
            lines.append("")
            lines.append("\(group.name)")
            let widest =
                group.entries
                .map { signature(of: $0).count }
                .max() ?? 0
            let column = min(max(widest, 12), 44)
            for entry in group.entries {
                lines.append(row(entry, column: column))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// One command in full: what it takes, and how each channel
    /// spells it.
    static func detail(of entry: APIEntry) -> String {
        var lines = [
            "\(entry.qualifiedName) \(argumentList(of: entry))"
                .trimmingCharacters(in: .whitespaces),
            "",
            "  \(entry.record.summary)",
        ]
        if !entry.record.arguments.isEmpty {
            lines.append("")
            lines.append("arguments:")
            for argument in entry.record.arguments {
                lines += argumentLines(argument)
            }
        }
        lines.append("")
        lines += channelLines(entry)
        if !entry.aliases.isEmpty {
            lines.append("")
            lines.append(
                "  also spelled: "
                    + entry.aliases.joined(separator: ", ")
            )
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Pieces

    /// `set_anchor <anchor>` — the name plus its arguments.
    static func signature(of entry: APIEntry) -> String {
        let arguments = argumentList(of: entry)
        return arguments.isEmpty
            ? entry.name : "\(entry.name) \(arguments)"
    }

    /// `<space> [mode]` — required in angle brackets, optional
    /// in square ones, the shape a reader already knows from
    /// every other CLI.
    static func argumentList(of entry: APIEntry) -> String {
        entry.record.arguments
            .map {
                $0.isOptional ? "[\($0.name)]" : "<\($0.name)>"
            }
            .joined(separator: " ")
    }

    private static func row(
        _ entry: APIEntry,
        column: Int
    ) -> String {
        let signature = signature(of: entry)
        let padding = max(1, column - signature.count + 2)
        let mark: String
        switch entry.channel {
        case .both: mark = ""
        case .lua: mark = "(lua only) "
        case .cli: mark = "(cli only) "
        }
        return "  " + signature
            + String(repeating: " ", count: padding)
            + mark + entry.record.summary
    }

    private static func argumentLines(
        _ argument: APIArgument
    ) -> [String] {
        let width = max(argument.name.count, 12)
        let name = argument.name.padding(
            toLength: width,
            withPad: " ",
            startingAt: 0
        )
        var suffix = argument.kind.wireName
        if argument.isOptional { suffix += ", optional" }
        var lines = ["  \(name)  \(suffix)"]
        guard case .choice(let choice) = argument.kind else {
            return lines
        }
        // Continuation lines sit under the type column, so the
        // values read as one field rather than a new row.
        let indent = String(repeating: " ", count: width + 4)
        lines.append(
            indent + choice.values.joined(separator: " | ")
        )
        lines.append(indent + "(\(choice.type))")
        return lines
    }

    private static func channelLines(
        _ entry: APIEntry
    ) -> [String] {
        var lines: [String] = []
        if entry.channel != .cli {
            let arguments = entry.record.arguments
                .map(\.name)
                .joined(separator: ", ")
            lines.append(
                "  lua: \(luaCall(of: entry))(\(arguments))"
            )
        }
        if entry.channel == .lua {
            lines.append(
                "       Lua only — the CLI cannot reach it."
            )
            return lines
        }
        let arguments = argumentList(of: entry)
        let call =
            arguments.isEmpty
            ? entry.qualifiedName
            : "\(entry.qualifiedName) \(arguments)"
        lines.append("  cli: kiwidesk \(call)")
        return lines
    }

    /// A dispatcher verb and a Lua-only entry point are both
    /// reached through the global `KiwiDesk` table; a namespace
    /// function is its own table's.
    private static func luaCall(of entry: APIEntry) -> String {
        entry.group == APIReference.coreGroup
            ? "KiwiDesk.\(entry.name)" : entry.qualifiedName
    }
}
