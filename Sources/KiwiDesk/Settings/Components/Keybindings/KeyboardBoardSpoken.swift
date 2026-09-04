import KiwiDeskCore
import SwiftUI

/// VoiceOver accessibility summary for the keyboard board (#812):
/// ONE element, one description — the picture's meaning, not its
/// pixels. The sentences read the SAME predicates the caps draw
/// from, so the spoken board cannot disagree with the drawn one.
/// Separate sentences joined with a space: a frame may withhold
/// only its LAST argument (`localization.md`).
struct SpokenKeyboardBoard: View {
    let type: KeyboardMatrix.PhysicalType
    let claims: [UInt32: [KeyboardCensus.ModifierLayer]]
    let scope: KeyboardCensus.Scope
    let conflicted: Set<UInt32>
    /// The keybinding layer the caps were counted over, or nil
    /// while there is only one (#1127). The drawing moved to one
    /// layer, so the sentence moves with it.
    let layerLabel: String?

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            KeyboardBoardSpoken.sentence(
                buckets: KeyboardBoardSpoken.buckets(
                    rows: KeyboardMatrix.rows(for: type),
                    claims: claims,
                    scope: scope,
                    conflicted: conflicted
                ),
                scopeLabel: scopeLabel,
                layerLabel: layerLabel
            )
        )
    }
}

/// Pure accessibility sentence generation for keyboard matrix
/// (`KeyboardBoardSpokenTests`, `tests.md`).
enum KeyboardBoardSpoken {
    struct Buckets: Equatable {
        var bound: [String] = []
        var reserved: [String] = []
        var conflict: [String] = []
    }

    @MainActor
    static func buckets(
        rows: [[KeyboardMatrix.Key]],
        claims: [UInt32: [KeyboardCensus.ModifierLayer]],
        scope: KeyboardCensus.Scope,
        conflicted: Set<UInt32>,
        glyph: (UInt32) -> String? = LayoutKeyGlyph.char(for:)
    ) -> Buckets {
        let overwritten = KeyboardCensus.overwrittenReserved(
            claims: claims,
            scope: scope
        )
        var out = Buckets()
        for key in rows.joined() {
            guard let code = key.code else { continue }
            let name = spokenName(for: code, glyph: glyph)
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

    /// Assembles localized summary sentence from key categorization buckets.
    @MainActor
    static func sentence(
        buckets: Buckets,
        scopeLabel: String,
        layerLabel: String?
    ) -> String {
        var parts = [
            L(
                "keyboard.ax.board",
                "Keyboard preview, showing %1$@.",
                scopeLabel
            )
        ]
        if let layerLabel {
            parts.append(
                L(
                    "keyboard.ax.layer",
                    "In the \u{201C}%1$@\u{201D} layer.",
                    layerLabel
                )
            )
        }
        parts.append(
            buckets.bound.isEmpty
                ? L("keyboard.ax.bound_none", "No keys bound.")
                : L(
                    "keyboard.ax.bound",
                    "Bound: %1$@.",
                    join(buckets.bound)
                )
        )
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

    /// Resolves spoken name for key code, injecting glyph lookup seam (#812).
    @MainActor
    static func spokenName(
        for code: UInt32,
        glyph: (UInt32) -> String? = LayoutKeyGlyph.char(for:)
    ) -> String {
        if let word = functionalWord(code) { return word }
        if let char = glyph(code),
            KeyboardKeyLabel.isPrintable(char)
        {
            return KeyboardKeyLabel.capped(char)
        }
        return KeyCombo.keyName(for: code)
            ?? KeyboardKeyLabel.fallback(for: code)
    }

    /// Localized spoken names for functional keys.
    @MainActor
    private static func functionalWord(_ code: UInt32) -> String? {
        switch code {
        case 36: return L("keyboard.key.return", "return")
        case 48: return L("keyboard.key.tab", "tab")
        case 49: return L("keyboard.key.space", "space")
        case 51: return L("keyboard.key.delete", "delete")
        case 53: return L("keyboard.key.escape", "escape")
        case 123: return L("keyboard.key.left", "left")
        case 124: return L("keyboard.key.right", "right")
        case 125: return L("keyboard.key.down", "down")
        case 126: return L("keyboard.key.up", "up")
        default: return nil
        }
    }

    /// Joins names using the APP's locale, never the system's:
    /// `ListFormatter`'s class method joins in `Locale.current`,
    /// which put a German "und" inside an English sentence on a
    /// German Mac (owner, #812 session 3).
    @MainActor
    private static func join(_ names: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = Locale(
            identifier:
                LocalizationManager.shared.effectiveLocale ?? "en"
        )
        return formatter.string(from: names)
            ?? names.joined(separator: ", ")
    }
}
