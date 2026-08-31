import Foundation

/// Keybinding layer model representing shortcuts and optional bar icon.
public struct KeyLayer: Codable, Equatable, Sendable,
    Identifiable
{
    public var name: String
    /// SF Symbol name or emoji icon. Nil for default layer.
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

    /// The default keybinding layer (`default`).
    public static let defaultLayer = KeyLayer(
        name: KeyLayer.defaultName
    )
    public static let defaultName = "default"

    public var isDefault: Bool { name == Self.defaultName }
}

/// Shortcut row binding a key combo to a Lua action string.
public struct KeyBinding: Codable, Equatable, Sendable,
    Identifiable
{
    /// Authoring category for display in settings UI.
    public enum Kind: String, Codable, Sendable {
        case navigation
        case application
        case custom
    }

    public var id = UUID()
    /// Key combo string (`"alt+h"`); empty while unrecorded.
    public var combo: String
    /// Lua action executed on key trigger.
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

    /// Compares equality of binding content ignoring transient UUID.
    public static func == (
        lhs: KeyBinding,
        rhs: KeyBinding
    ) -> Bool {
        lhs.combo == rhs.combo && lhs.lua == rhs.lua
            && lhs.kind == rhs.kind && lhs.label == rhs.label
    }

    /// Semantic identity for the override cascade (#55): combo +
    /// lua only. The import classifier may upgrade `kind`/`label`,
    /// and that must never read as divergence from the base, or an
    /// unchanged edit session persists spurious overrides.
    public func sameAction(as other: KeyBinding) -> Bool {
        combo == other.combo && lua == other.lua
    }
}
