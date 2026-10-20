import Foundation
import KiwiDeskCore

/// What one role group's colour reads and writes (#1857): pure,
/// so the card only draws it. The group colour stores nothing —
/// it writes the ticked rows' own hexes, each keeping its alpha.
struct RolePaint {
    let role: ColorRole
    let settings: TilingSettings
    let ticked: Set<SettingKey>
    /// Rows that draw nothing right now (`ColorRowVerdict`); the
    /// group colour leaves them as they are.
    let dimmed: Set<SettingKey>

    /// The rows a fresh page ticks: those the palette already
    /// draws in the anchor's colour, ignoring alpha — a row the
    /// palette split off on purpose stays unticked.
    static func seed(
        _ role: ColorRole,
        _ settings: TilingSettings
    ) -> Set<SettingKey> {
        let anchor = rgb(of: role.anchor, in: settings)
        return Set(
            role.keys.filter {
                !role.followers.contains($0)
                    && rgb(of: $0, in: settings) == anchor
            }
        )
    }

    /// Whether a row takes a tick at all: a follower never does.
    func tickable(_ key: SettingKey) -> Bool {
        !role.followers.contains(key)
    }

    /// The rows a write reaches, in row order.
    var targets: [SettingKey] {
        role.keys.filter {
            ticked.contains($0) && tickable($0) && !dimmed.contains($0)
        }
    }

    /// What the group's well shows: the first target's colour, or
    /// the anchor's while nothing is ticked.
    var wellHex: String {
        targets.first.flatMap { Self.rgb(of: $0, in: settings) }
            ?? Self.rgb(of: role.anchor, in: settings) ?? ""
    }

    /// Why the well has nothing to write, or nil while it has.
    enum Idle: Equatable {
        case nothingTicked
        case allTickedDimmed
    }

    var idle: Idle? {
        guard targets.isEmpty else { return nil }
        return ticked.contains(where: tickable)
            ? .allTickedDimmed : .nothingTicked
    }

    /// The targets differ, so the well shows only the first.
    var mixed: Bool {
        Set(targets.compactMap { Self.rgb(of: $0, in: settings) })
            .count > 1
    }

    /// `settings` with every target set to `pick`'s colour at the
    /// target's own alpha; unchanged where `pick` does not parse.
    func painted(_ pick: String) -> TilingSettings {
        guard let rgb = Self.rgb(pick) else { return settings }
        var out = settings
        for key in targets {
            guard let path = ColorsAndGlassPaths.hex(key) else { continue }
            out[keyPath: path] = rgb + Self.alphaSuffix(out[keyPath: path])
        }
        return out
    }

    // MARK: - Hex

    static func rgb(
        of key: SettingKey,
        in settings: TilingSettings
    ) -> String? {
        ColorsAndGlassPaths.hex(key).flatMap { rgb(settings[keyPath: $0]) }
    }

    static func rgb(_ hex: String) -> String? {
        ColorPalette.rgbHex(hex)
    }

    static func alphaSuffix(_ hex: String) -> String {
        ColorPalette.alphaSuffix(hex)
    }
}
