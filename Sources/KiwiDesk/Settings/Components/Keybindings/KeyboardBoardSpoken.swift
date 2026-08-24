import KiwiDeskCore
import SwiftUI

/// The keyboard board as VoiceOver hears it (#812): ONE element,
/// one description — the picture's meaning, not its pixels.
///
/// Drawn, the board is a glance: which keys are green under this
/// chip. Read key by key it was one bare glyph per key ("A",
/// "S", "space") with no state at all, since every state lives
/// in a fill or a ring. And a stop per key is not the fix — a
/// picture's native spoken form is one description (an image's
/// description, a chart's summary), and the question a reader
/// brings here, "what is taken before I record?", is answered by
/// a list, not a walk (`ui-designer`, 2026-08-24).
///
/// The sentences read the SAME predicates the caps draw from —
/// `KeyboardCensus.state(of:claims:scope:)` for bound and
/// reserved, `collisions ∪ overwrittenReserved` for the red ring
/// — so the spoken board cannot disagree with the drawn one, the
/// way the legend may not point at a mark the frame does not
/// draw. Separate sentences joined with a space rather than one
/// frame with optional clauses: two of the three are
/// conditional, and a frame may withhold only its LAST argument
/// (localization.md).
struct SpokenKeyboardBoard: View {
    let type: KeyboardMatrix.PhysicalType
    let claims: [UInt32: [KeyboardCensus.ModifierLayer]]
    let scope: KeyboardCensus.Scope
    let conflicted: Set<UInt32>

    /// The chip row's own word for the scope ("All", "⌘", "No
    /// modifier"), so the sentence names what the chip row shows.
    private var scopeLabel: String {
        switch scope {
        case .all: return L("keyboard.scope.all", "All")
        case .one(let layer):
            return KeyboardKeyLabel.chipLabel(for: layer)
        }
    }

    var body: some View {
        KeyboardBoard(
            type: type,
            claims: claims,
            scope: scope,
            conflicted: conflicted
        )
        // Ignored, not hidden: the plate stays a stop in reading
        // order between the chips and the tally, where the eye
        // meets it.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            KeyboardBoardSpoken.sentence(
                buckets: KeyboardBoardSpoken.buckets(
                    rows: KeyboardMatrix.rows(for: type),
                    claims: claims,
                    scope: scope,
                    conflicted: conflicted
                ),
                scopeLabel: scopeLabel
            )
        )
    }
}

/// The pure half: which keys land in which sentence, in the
/// board's own order (left to right, top to bottom), and the
/// sentence itself. View-free so `KeyboardBoardSpokenTests` can
/// hold it without a window.
enum KeyboardBoardSpoken {
    struct Buckets: Equatable {
        var bound: [String] = []
        var reserved: [String] = []
        var conflict: [String] = []
    }

    static func buckets(
        rows: [[KeyboardMatrix.Key]],
        claims: [UInt32: [KeyboardCensus.ModifierLayer]],
        scope: KeyboardCensus.Scope,
        conflicted: Set<UInt32>
    ) -> Buckets {
        let overwritten = KeyboardCensus.overwrittenReserved(
            claims: claims,
            scope: scope
        )
        var out = Buckets()
        for key in rows.joined() {
            // A code-less cap (⇧, ⌘) has no state and is never
            // listed.
            guard let code = key.code else { continue }
            let name = spokenName(for: code)
            switch KeyboardCensus.state(
                of: code,
                claims: claims,
                scope: scope
            ) {
            case .bound: out.bound.append(name)
            case .cantBind: out.reserved.append(name)
            case .free: break
            }
            if conflicted.contains(code) || overwritten.contains(code) {
                out.conflict.append(name)
            }
        }
        return out
    }

    /// One sentence per non-empty bucket; bound always speaks,
    /// so a chip that claims nothing still says so.
    @MainActor
    static func sentence(
        buckets: Buckets,
        scopeLabel: String
    ) -> String {
        var parts = [
            L(
                "keyboard.ax.board",
                "Keyboard preview, showing %1$@.",
                scopeLabel
            ),
            buckets.bound.isEmpty
                ? L("keyboard.ax.bound_none", "No keys bound.")
                : L(
                    "keyboard.ax.bound",
                    "Bound: %1$@.",
                    join(buckets.bound)
                ),
        ]
        if !buckets.reserved.isEmpty {
            parts.append(
                L(
                    "keyboard.ax.reserved",
                    "macOS owns: %1$@.",
                    join(buckets.reserved)
                )
            )
        }
        if !buckets.conflict.isEmpty {
            parts.append(
                L(
                    "keyboard.ax.conflict",
                    "Conflict: %1$@.",
                    join(buckets.conflict)
                )
            )
        }
        return parts.joined(separator: " ")
    }

    /// The key as the board prints it where that is a letter or
    /// sign, and as a WORD where the board prints a symbol —
    /// VoiceOver reads "←" as "leftwards arrow" and "⎋" however
    /// it likes, so a functional key takes its `KeyCombo` name
    /// ("left", "return", "space"): drawn and spoken agree on
    /// WHICH key and differ only in rendering.
    static func spokenName(for code: UInt32) -> String {
        if let char = LayoutKeyGlyph.char(for: code),
            KeyboardKeyLabel.isPrintable(char)
        {
            return KeyboardKeyLabel.capped(char)
        }
        return KeyCombo.keyName(for: code)
            ?? KeyboardKeyLabel.fallback(for: code)
    }

    /// The list is not a grammatical clause, so no locale has
    /// to agree with it; the platform's own joiner.
    private static func join(_ names: [String]) -> String {
        ListFormatter.localizedString(byJoining: names)
    }
}
