import KiwiDeskCore
import SwiftUI

/// The shut card's summary (#3261): the values set, joined by `·`
/// — the Hyper key under the key's name, the base and the sides
/// under their rows' titles — or the card's description while
/// nothing is set. A Hyper key that is not working says so, since
/// the drawer opens only for the trouble it can fix. VoiceOver
/// hears the base in words, never ✦.
extension ModifierKeysCard {
    func summary(spoken: Bool) -> String {
        Self.summary(
            key: model.appWide.hyperKey,
            working: Self.hyperWorks(model.hyperStatus),
            base: model.config.shortcutBase,
            sides: model.appWide.modifierSides,
            spoken: spoken
        )
    }

    /// Whether a chosen Hyper key is in effect: neither in trouble
    /// nor paused, the caption's own two readings.
    static func hyperWorks(_ status: HyperKeyStatus) -> Bool {
        HyperKeyWords.trouble(status) == nil && status != .off
    }

    static func summary(
        key: HyperSourceKey?,
        working: Bool,
        base: ShortcutBase,
        sides: Bool,
        spoken: Bool
    ) -> String {
        let parts = summaryParts(
            key: key,
            working: working,
            base: base,
            sides: sides,
            spoken: spoken
        )
        guard !parts.isEmpty else { return description }
        return parts.joined(separator: " · ")
    }

    /// Each value set, in the rows' order.
    static func summaryParts(
        key: HyperSourceKey?,
        working: Bool,
        base: ShortcutBase,
        sides: Bool,
        spoken: Bool
    ) -> [String] {
        var parts: [String] = []
        if let key {
            parts.append(
                working
                    ? L(
                        "shortcuts.modifier_keys.summary.hyper",
                        "%1$@: %2$@",
                        HyperKeyWords.keyName,
                        HyperKeyWords.name(key)
                    )
                    : L(
                        "shortcuts.modifier_keys.summary.hyper_off",
                        "%1$@: %2$@, not working",
                        HyperKeyWords.keyName,
                        HyperKeyWords.name(key)
                    )
            )
        }
        if base == .hyper {
            parts.append(
                L(
                    "shortcuts.modifier_keys.summary.base",
                    "%1$@ %2$@",
                    ShortcutBaseWords.title,
                    spoken
                        ? ShortcutBaseWords.spoken(base, keySet: key != nil)
                        : ShortcutBaseWords.glyphs(base)
                )
            )
        }
        if sides { parts.append(ModifierSidesWords.title) }
        return parts
    }

    /// What the card holds, while nothing in it is set.
    static var description: String {
        L(
            "shortcuts.modifier_keys.summary",
            "Turn a key into Hyper, and choose the modifiers "
                + "your shortcuts use"
        )
    }
}
