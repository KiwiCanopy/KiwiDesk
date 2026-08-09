import Foundation

/// Where "Use one width for all borders" lives (#754).
///
/// Storage is app preferences (`UserDefaults`), NOT `gui.json`
/// and NOT `TilingSettings`, on `SettingsModePreference`'s
/// reasoning plus one of its own: the link is GUI convenience
/// over three values the config already has — the ring's width,
/// the ghost's and the drop zone's — so making it a config field
/// would invent a fourth axis whose only job is to describe the
/// other three, and Lua would then have a knob that changes
/// nothing it can read back. It also never enters the
/// dirty-tracked config: flipping it saves nothing on its own,
/// and the edit it triggers is an ordinary change to those three
/// stored widths.
///
/// Absent — and any unrecognised value — reads as LINKED, the
/// approachable default (a user who has set nothing wants one
/// look, not three sliders); unlinking stores `false`, and
/// re-linking removes the key so the default leaves no trace in
/// the domain.
enum BorderWidthLinkPreference {
    static let key = "borderWidthLinked"

    static func read(from defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return true
        }
        return defaults.bool(forKey: key)
    }

    static func write(_ linked: Bool, to defaults: UserDefaults) {
        if linked {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(false, forKey: key)
        }
    }
}
