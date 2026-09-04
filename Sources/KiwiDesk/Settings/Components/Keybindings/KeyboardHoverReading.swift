import KiwiDeskCore
import SwiftUI

/// What the board's status slot says about one key (#798).
///
/// The slot is bimodal — the tally at rest, this under the
/// pointer — so the reading is a value the panel computes rather
/// than a second view: the drawn and spoken halves take the same
/// one, and neither can name an action the caps do not draw.
struct KeyboardHoverReading: Equatable {
    /// One bound action on the key, chord first.
    struct Claim: Equatable {
        let chord: String
        let action: String
        /// The cost of this claim's conflict, where it has one —
        /// `ConflictText`'s sentence verbatim, never a second
        /// wording (#1126 forbids re-branching on the target).
        let conflict: String?
    }

    var claims: [Claim] = []
    /// Set where the key is free: macOS's owner, or nil when
    /// nothing owns it under the shown scope.
    var freeOwner: String?
    /// The key as the board draws it, so the sentence names what
    /// the pointer is on.
    var keyName: String

    /// Lines the slot draws, in order.
    @MainActor var lines: [String] {
        guard !claims.isEmpty else {
            return [freeSentence]
        }
        return claims.map { claim in
            [claim.chord + keyName, claim.action]
                .joined(separator: " — ")
        }
            + claims.compactMap(\.conflict)
    }

    @MainActor private var freeSentence: String {
        guard let freeOwner else {
            return L(
                "keyboard.hover.free",
                "%1$@ — not bound",
                keyName
            )
        }
        return L(
            "keyboard.hover.reserved",
            "%1$@ — macOS uses this for %2$@",
            keyName,
            freeOwner
        )
    }
}

extension KeyboardHoverReading {
    /// Reads the key the pointer is on from the board's own
    /// predicates (#798): the same `shown` layer, the same
    /// `selected` modifier set, and — for the cost sentence —
    /// `ConflictText`, which is the one place a conflict is
    /// worded (#1126).
    @MainActor
    static func of(
        _ code: UInt32,
        in layers: [KeyLayer],
        selected: Set<KeyboardCensus.ModifierLayer>,
        config: GuiConfig,
        disabled: Set<SystemShortcut>,
        labels: [String: String]
    ) -> KeyboardHoverReading {
        let all = layers.flatMap(\.bindings)
        let claims = KeyboardCensus.bindings(
            on: code,
            in: layers,
            selected: selected
        )
        .map { entry in
            Claim(
                chord: KeyboardKeyLabel.chipLabel(for: entry.layer),
                action: labels[entry.binding.lua]
                    ?? entry.binding.label,
                conflict: ConflictText.reading(
                    for: entry.binding,
                    in: all,
                    config: config,
                    disabled: disabled
                )?.sentence
            )
        }
        return KeyboardHoverReading(
            claims: claims,
            freeOwner: claims.isEmpty
                ? reservedOwner(code, selected: selected)
                : nil,
            keyName: KeyboardBoardSpoken.spokenName(for: code)
        )
    }

    /// What macOS uses a free key for under the shown scope,
    /// read from the same map the amber ring draws from.
    @MainActor
    private static func reservedOwner(
        _ code: UInt32,
        selected: Set<KeyboardCensus.ModifierLayer>
    ) -> String? {
        for layer in selected.sorted() {
            let combo = SystemShortcuts.map.keys.first {
                $0.keyCode == code
                    && KeyboardCensus.ModifierLayer(
                        modifiers: $0.modifiers
                    ) == layer
            }
            if let combo, let owned = SystemShortcuts.map[combo] {
                return owned.localizedName
            }
        }
        return nil
    }
}
