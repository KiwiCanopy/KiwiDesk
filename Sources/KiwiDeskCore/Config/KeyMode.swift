import Foundation

/// One keybinding mode: a named set of shortcut rows plus an
/// optional menu bar indicator (SF Symbol name or flat emoji).
public struct KeyMode: Codable, Equatable, Sendable,
    Identifiable
{
    public var name: String
    /// SF Symbol name (`arrow.left.and.right`) or emoji
    /// (`📐`). Nil for the default mode's standard icon.
    public var icon: String?
    public var bindings: [KeyBinding]

    public var id: String { name }

    public init(
        name: String,
        icon: String? = nil,
        bindings: [KeyBinding] = []
    ) {
        self.name = name
        self.icon = icon
        self.bindings = bindings
    }

    /// The always-present default mode (`KiwiDesk.bind`).
    public static let defaultMode = KeyMode(
        name: KeyMode.defaultName
    )
    public static let defaultName = "default"

    public var isDefault: Bool { name == Self.defaultName }
}

/// One shortcut row: a key combo bound to a Lua action.
public struct KeyBinding: Codable, Equatable, Sendable,
    Identifiable
{
    /// How the action was authored — display only; the writer
    /// only consumes `lua`.
    public enum Kind: String, Codable, Sendable {
        case navigation
        case application
        case custom
    }

    public var id = UUID()
    /// Key combo string (`"alt+h"`); empty while unrecorded.
    public var combo: String
    /// The Lua statement(s) run on trigger — the body placed
    /// inside `function() ... end`.
    public var lua: String
    public var kind: Kind
    /// Row label shown in the editor (nav name / app name).
    public var label: String

    public init(
        combo: String = "",
        lua: String = "",
        kind: Kind = .custom,
        label: String = ""
    ) {
        self.combo = combo
        self.lua = lua
        self.kind = kind
        self.label = label
    }

    private enum CodingKeys: String, CodingKey {
        case combo
        case lua
        case kind
        case label
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        combo = try container.decode(String.self, forKey: .combo)
        lua = try container.decode(String.self, forKey: .lua)
        kind =
            try container.decodeIfPresent(
                Kind.self,
                forKey: .kind
            ) ?? .custom
        label =
            try container.decodeIfPresent(
                String.self,
                forKey: .label
            ) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )
        try container.encode(combo, forKey: .combo)
        try container.encode(lua, forKey: .lua)
        try container.encode(kind, forKey: .kind)
        try container.encode(label, forKey: .label)
    }

    /// `id` is a transient row handle (not persisted), so it is
    /// excluded from equality — two rows with the same content
    /// are equal even across a save/load cycle.
    public static func == (
        lhs: KeyBinding,
        rhs: KeyBinding
    ) -> Bool {
        lhs.combo == rhs.combo && lhs.lua == rhs.lua
            && lhs.kind == rhs.kind && lhs.label == rhs.label
    }
}
