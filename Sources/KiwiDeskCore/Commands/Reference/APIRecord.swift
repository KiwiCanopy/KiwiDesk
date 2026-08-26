import Foundation

/// One command's machine-readable signature: what it takes, and
/// what it does in one line (#1033).
///
/// **A record carries neither its own name nor its group.** Both
/// are the keys it is filed under in `APIReference` — the
/// `commands`, `namespaces` and `luaOnly` tables stay the single
/// source of truth for names, exactly as that file already
/// claimed to be, and a record that cannot name itself cannot
/// disagree with them. What a record adds is the metadata those
/// tables never carried. `APIRecordCensusTests` holds the key
/// sets against the name tables in both directions.
public struct APIRecord: Sendable, Equatable {
    /// One line, sentence-shaped: a capital, a full stop, no
    /// newline. `APIRecordShapeTests` pins that shape, so 262
    /// summaries written by different hands read as one voice.
    public let summary: String

    /// Positional arguments, in the order the command reads
    /// them. Optional arguments come last — a positional list
    /// cannot skip one (`APIRecordShapeTests`).
    ///
    /// **Stated residue: this list is a hand-kept mirror of the
    /// decoder, and only its enum VALUES are derived.** A
    /// decoder reads `args[0]` / `args[1]` positionally with no
    /// declared signature to reflect over, so nothing can check
    /// that a record's argument names, count or optionality
    /// match what the command actually parses — `APIChoice`
    /// covers the values an argument may carry, and the census
    /// covers command names, but neither sees the argument that
    /// carries them. `APIRecordShapeTests` holds the shape a
    /// list must have, never that it is the right list.
    ///
    /// So an argument list is review's, and a wrong one is
    /// worse than a pending one — it describes a call that will
    /// be rejected. Closing this properly means the decoders
    /// declaring their signature and parsing FROM the record,
    /// which is a much larger change than #1033 and is where
    /// this data wants to go next.
    public let arguments: [APIArgument]

    public init(_ summary: String, _ arguments: APIArgument...) {
        self.init(summary, arguments)
    }

    public init(_ summary: String, _ arguments: [APIArgument]) {
        self.summary = summary
        self.arguments = arguments
    }

    /// The summary of a record whose prose is not written yet.
    ///
    /// Deliberately not sentence-shaped, so it can never be
    /// mistaken for a written one and `APIRecordShapeTests`
    /// exempts it by identity rather than by pattern.
    public static let pendingSummary = "(summary pending)"

    /// Whether this record still owes its prose.
    public var isPending: Bool { summary == Self.pendingSummary }
}

/// One positional argument of a command.
public struct APIArgument: Sendable, Equatable {
    /// `lower_snake_case`, the name the docs use for it.
    public let name: String
    public let kind: APIArgumentKind
    /// Whether the command reads a default when it is absent.
    public let isOptional: Bool

    public init(
        _ name: String,
        _ kind: APIArgumentKind,
        optional isOptional: Bool = false
    ) {
        self.name = name
        self.kind = kind
        self.isOptional = isOptional
    }

    public static func number(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .number, optional: optional)
    }

    public static func integer(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .integer, optional: optional)
    }

    public static func boolean(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .boolean, optional: optional)
    }

    public static func text(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .text, optional: optional)
    }

    public static func color(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .color, optional: optional)
    }

    /// A Space identifier — a string, and a numeric string is
    /// equivalent to the integer (AGENTS.md §5).
    public static func space(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .space, optional: optional)
    }

    /// A macOS Desktop's Mission Control number, counted
    /// globally across every screen (#884/#888).
    public static func desktop(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .desktop, optional: optional)
    }

    /// A Lua function. Only a Lua-only entry point takes one —
    /// nothing crossing the socket can carry a callback.
    public static func callback(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .callback, optional: optional)
    }

    /// A Lua table. Same reason as `callback`: it never crosses
    /// the socket.
    public static func table(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .table, optional: optional)
    }

    /// An argument whose legal values are a Swift enum's cases.
    ///
    /// **The only way to build one, and it takes the type, not
    /// the values** — so the listing can never disagree with the
    /// decoder that accepts or rejects what a caller sends.
    /// `APIChoiceDerivationTests` holds that there is no second
    /// initializer to type them into.
    public static func choice<T: APIChoiceType>(
        _ name: String,
        _ type: T.Type,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(
            name,
            .choice(APIChoice(type)),
            optional: optional
        )
    }
}

/// The closed vocabulary of argument shapes.
///
/// Closed on purpose: a value shape that is none of these — the
/// points-or-`"NN%"`-or-`0` of `scroll.set_slot_size`, say —
/// takes the closest kind and explains itself in the summary.
/// The alternative, a free-text type field, is where a second
/// hand-typed spelling of an enum would eventually land.
public enum APIArgumentKind: Sendable, Equatable {
    case number
    case integer
    case boolean
    case text
    case color
    case space
    case desktop
    case callback
    case table
    case choice(APIChoice)

    /// The word `list_commands` prints for this kind. English,
    /// like every other CLI/IPC string (core-boundaries.md).
    public var wireName: String {
        switch self {
        case .number: return "number"
        case .integer: return "integer"
        case .boolean: return "boolean"
        case .text: return "string"
        case .color: return "color"
        case .space: return "space"
        case .desktop: return "desktop"
        case .callback: return "function"
        case .table: return "table"
        case .choice: return "choice"
        }
    }
}
