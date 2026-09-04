import KiwiDeskCore
import SwiftUI

/// What the board's status slot says about one key (#798).
///
/// The slot is bimodal — the tally at rest, this under the
/// pointer — so the reading is a value the panel computes rather
/// than a second view: the drawn and spoken halves take the same
/// one, and neither can name a fact the caps do not draw.
struct KeyboardHoverReading: Equatable {
    /// One bound action on the key, chord first.
    struct Claim: Equatable {
        /// Modifier GLYPHS, empty for a bare key — never the
        /// chip's prose, which reads "No modifier" and welded
        /// itself onto the key name (localization audit, #798).
        let chord: String
        let action: String
        /// The cost of this claim's conflict, where the board
        /// RINGS it — `ConflictText`'s sentence verbatim, never
        /// a second wording (#1126 forbids re-branching on the
        /// target).
        let conflict: String?
    }

    var claims: [Claim] = []
    /// Set where the key is free and the board draws it as
    /// macOS's: the owner, and the chord that owns it.
    var freeOwner: (chord: String, name: String)?
    /// The key as the board's spoken form names it — a localized
    /// word for the nine functional keys ("space", "left"), the
    /// cap's character otherwise. Deliberately the SPOKEN name,
    /// not the drawn glyph: this goes in a sentence.
    var keyName: String

    static func == (
        a: KeyboardHoverReading,
        b: KeyboardHoverReading
    ) -> Bool {
        a.claims == b.claims && a.keyName == b.keyName
            && a.freeOwner?.chord == b.freeOwner?.chord
            && a.freeOwner?.name == b.freeOwner?.name
    }

    /// Lines the slot draws, in order — each claim followed by
    /// its own cost, so a two-claim collision does not orphan
    /// its sentences at the bottom.
    @MainActor var lines: [String] {
        guard !claims.isEmpty else { return [freeSentence] }
        return claims.flatMap { claim -> [String] in
            [
                L(
                    "keyboard.hover.bound",
                    "%1$@ — %2$@",
                    claim.chord + keyName,
                    claim.action
                )
            ] + (claim.conflict.map { [$0] } ?? [])
        }
    }

    @MainActor private var freeSentence: String {
        guard let freeOwner else {
            return L(
                "keyboard.hover.free",
                "%1$@ — not bound",
                keyName
            )
        }
        // Names the CHORD macOS owns, not the bare key: the
        // reservation is a combination, and a line saying
        // "space — macOS owns this" would be false of the key.
        return L(
            "keyboard.hover.reserved",
            "%1$@ — macOS owns this: %2$@",
            freeOwner.chord + keyName,
            freeOwner.name
        )
    }
}

extension KeyboardHoverReading {
    /// Reads the key the pointer is on from the board's own
    /// predicates (#798): the same `shown` layer, the same
    /// `selected` set, and the same SCOPE the caps are drawn
    /// under — so the words cannot assert what the picture
    /// refuses to draw. Under `.all` the board rings nothing
    /// reserved (macOS reserves a combination, not a key), and
    /// this says nothing about macOS either.
    @MainActor
    static func of(
        _ code: UInt32,
        in layers: [KeyLayer],
        scope: KeyboardCensus.Scope,
        selected: Set<KeyboardCensus.ModifierLayer>,
        config: GuiConfig,
        disabled: Set<SystemShortcut>
    ) -> KeyboardHoverReading {
        let all = layers.flatMap(\.bindings)
        let ringed = KeyboardCensus.ringedKeys(
            in: layers,
            selected: selected,
            scope: scope
        )
        .contains(code)
        let claims = KeyboardCensus.bindings(
            on: code,
            in: layers,
            selected: selected
        )
        .map { entry in
            Claim(
                chord: entry.layer.label,
                action: KeybindingCatalog.localizedLabel(
                    for: entry.binding.label,
                    config: config
                ),
                conflict: ringed
                    ? ConflictText.reading(
                        for: entry.binding,
                        in: all,
                        config: config,
                        disabled: disabled
                    )?.sentence
                    : nil
            )
        }
        let owner = KeyboardCensus.reservedOwner(
            of: code,
            scope: scope
        )
        return KeyboardHoverReading(
            claims: claims,
            freeOwner: claims.isEmpty
                ? owner.map {
                    (
                        chord: KeyboardCensus.chordLabel(
                            of: scope
                        ),
                        name: $0.localizedName
                    )
                }
                : nil,
            keyName: KeyboardBoardSpoken.spokenName(for: code)
        )
    }
}
