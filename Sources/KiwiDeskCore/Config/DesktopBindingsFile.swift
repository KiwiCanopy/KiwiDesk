import Foundation

/// `bindings.json` in `MachineLocation`'s folder (#2324 ruling 12):
/// the Desktop→profile bindings, keyed by this Mac's Desktop stamps,
/// so it lives on this Mac while it travels in a backup as the
/// bundle's own `profile_bindings` field. A restore replaces it
/// whole and never touches `machine.json`.
public struct DesktopBindingsFile: Codable, Equatable, Sendable {
    /// 1 = `profile_bindings` (#2324).
    public static let currentFormat = 1

    public var format = DesktopBindingsFile.currentFormat
    /// `GuiConfig.profileBindings`.
    public var profileBindings: [DesktopKey: DesktopBinding] = [:]

    public init() {}

    public init(of config: GuiConfig) {
        profileBindings = config.profileBindings
    }

    public func applied(to config: GuiConfig) -> GuiConfig {
        var config = config
        config.profileBindings = profileBindings
        return config
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case format
        case profileBindings = "profile_bindings"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded =
            try container.decodeIfPresent(Int.self, forKey: .format) ?? 0
        guard decoded <= Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription:
                    "bindings format \(decoded) is newer "
                    + "than supported \(Self.currentFormat)"
            )
        }
        profileBindings =
            try container.decodeIfPresent(
                [DesktopKey: DesktopBinding].self,
                forKey: .profileBindings
            ) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        // Unlike the Space memory, a `.number` key persists: it is a
        // number the user declared (profiles.md ▸ the `.number`
        // fallback).
        try container.encode(profileBindings, forKey: .profileBindings)
    }
}

extension DesktopBindingsFile: MachineFile {
    static let fileName = "bindings.json"
    static let destination = MachineConfig.Destination.bindings
}
