import Foundation

/// Machine-readable command signature and summary (#1033,
/// `APIRecordCensusTests`, `APIRecordShapeTests`).
public struct APIRecord: Sendable, Equatable {
    /// Single sentence summary (capitalized, ending in period).
    public let summary: String
    /// Positional arguments in decoding order; optionals come
    /// last. Stated residue: this list is a hand-kept mirror of
    /// the decoder — only the enum VALUES are derived — so a wrong
    /// list is worse than a pending one. Two shapes it cannot
    /// state take the closed-kind escape (`subscribe` is variadic,
    /// `set_mode` takes a LEADING optional); weigh a third such
    /// command as evidence the shape, not the summary, must
    /// change.
    public let arguments: [APIArgument]

    public init(_ summary: String, _ arguments: APIArgument...) {
        self.init(summary, arguments)
    }

    public init(_ summary: String, _ arguments: [APIArgument]) {
        self.summary = summary
        self.arguments = arguments
    }

    /// Placeholder summary for unwritten prose — deliberately not
    /// sentence-shaped, so `APIRecordShapeTests` exempts it by
    /// identity rather than by pattern.
    public static let pendingSummary = "(summary pending)"

    /// True if summary has not been authored yet.
    public var isPending: Bool { summary == Self.pendingSummary }
}

/// One positional argument of a command (#1033).
public struct APIArgument: Sendable, Equatable {
    /// Argument name in snake_case.
    public let name: String
    public let kind: APIArgumentKind
    /// True if argument has a default value when omitted.
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

    /// Space identifier argument (string or numeric string, AGENTS.md §5).
    public static func space(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .space, optional: optional)
    }

    /// macOS Desktop index across all screens (#884, #888).
    public static func desktop(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .desktop, optional: optional)
    }

    /// Lua function callback argument (Lua-only).
    public static func callback(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .callback, optional: optional)
    }

    /// Lua table argument (Lua-only).
    public static func table(
        _ name: String,
        optional: Bool = false
    ) -> APIArgument {
        APIArgument(name, .table, optional: optional)
    }

    /// Enum choice argument derived directly from type
    /// (`APIChoiceDerivationTests`).
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

/// Closed vocabulary of supported argument kinds.
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

    /// Name printed by `list_commands` (English, core-boundaries.md).
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
