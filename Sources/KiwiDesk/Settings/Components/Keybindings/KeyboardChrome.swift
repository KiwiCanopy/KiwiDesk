import Carbon.HIToolbox
import KiwiDeskCore
import SwiftUI

/// One modifier-combination chip. Selected chips drive the board,
/// the stripe legend and the count sentence; an unselected one
/// shows its stripe colour greyed rather than hidden, so the row
/// reads as a set of switches and not as a shrinking list.
/// One scope chip: "All", or one modifier combination. Single
/// select — the board shows one thing at a time, which is what
/// let the stripe palette (and its colour-vision ceiling) go.
struct ScopeChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    isOn
                        ? SettingsTheme.plateInk
                        : SettingsTheme.ink2
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            isOn
                                ? SettingsTheme.previewPlate
                                : SettingsTheme.sunken
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

/// How a key's stripes divide it: one claim fills the width, and
/// each further claim splits it, up to three abreast, then wraps
/// to another line (owner, 2026-08-10). Wrapping rather than
/// thinning, because width is the channel saying how many claims
/// a key carries and a stripe too fine to see reads as an
/// unclaimed key.
///
/// Kept off `KeyCap` deliberately: a `View`'s statics are
/// main-actor isolated, so a suite reading one off the main actor
/// traps the runner instead of failing an expectation.
enum KeyboardStripeLayout {
    static let perRow = 3

    /// The row shape as counts — the wrap rule, assertable
    /// without building a view (`LayoutSchematicCountTests`'
    /// lesson: a scan for the input is satisfied by a renderer
    /// that draws a constant, so the arithmetic is asserted
    /// directly).
    static func rowShape(
        count: Int,
        perRow: Int = KeyboardStripeLayout.perRow
    ) -> [Int] {
        guard count > 0, perRow > 0 else { return [] }
        return stride(from: 0, to: count, by: perRow).map {
            min(perRow, count - $0)
        }
    }
}

/// The name macOS gives the active input source ("German"), read
/// and never stored — which is what the panel's "from macOS"
/// suffix claims to the user.
enum KeyboardInputSource {
    static func localizedName() -> String? {
        guard
            let source = TISCopyCurrentKeyboardLayoutInputSource()?
                .takeRetainedValue()
                ?? TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
                .takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(
                source,
                kTISPropertyLocalizedName
            )
        else { return nil }
        return Unmanaged<CFString>
            .fromOpaque(pointer)
            .takeUnretainedValue() as String
    }
}

/// The label for a key with no printable character. `ComboSymbols`
/// owns the glyphs a COMBO renders; a board also draws keys no
/// combo names, so the fallbacks live beside the board.
enum KeyboardKeyLabel {
    /// A keycap prints its letter capitalised. The rule is
    /// `ComboSymbols.capitalisedGlyph`'s — the board and every
    /// combo-rendering surface must agree about what a key is
    /// called, so there is one copy of it and this is a
    /// forwarder, not a second implementation.
    static func capped(_ char: String) -> String {
        ComboSymbols.capitalisedGlyph(char)
    }

    /// What a modifier chip shows. Every other chip is pure
    /// symbol; the bare-key one has no symbol to show, so it is
    /// the row's one word.
    ///
    /// "No modifier", not "plain key", and the reasons are the
    /// row's rather than the phrase's: every sibling chip names a
    /// modifier COMBINATION, so a label naming a *key* answers a
    /// different question than the chips beside it; and the panel
    /// already says "modifier" to the user twice
    /// (`keyboard.legend.conflict`, `keyboard.tally`), so a third
    /// noun for it on one surface is drift. Not "None" either —
    /// in a multi-select row that reads as *clear the selection*.
    /// The chip is not where a user learns the option exists: it
    /// only appears once the draft already has such a binding.
    @MainActor
    static func chipLabel(
        for layer: KeyboardCensus.ModifierLayer
    ) -> String {
        layer.modifiers.isEmpty
            ? L("keyboard.modifier.bare", "No modifier")
            : layer.label
    }

    /// Mac symbols, because this is a Mac keyboard and the user
    /// reads these shapes on the hardware in front of them.
    static let functional: [UInt32: String] = [
        36: "↩", 48: "⇥", 49: "space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func fallback(for code: UInt32) -> String {
        if let symbol = functional[code] { return symbol }
        return KeyCombo.keyName(for: code)?.uppercased() ?? ""
    }

    /// Whether a translated character is something a cap can
    /// actually print.
    ///
    /// `UCKeyTranslate` answers for an arrow or a delete with a
    /// **private-use** character (`NSUpArrowFunctionKey` and its
    /// family live at U+F700), which is neither empty nor
    /// whitespace — so a nil-or-empty test passes it straight
    /// through and the cap draws a blank. That is what shipped:
    /// every arrow, and `⌫`, silently unlabelled while the
    /// fallback table that names them sat unreached.
    static func isPrintable(_ char: String) -> Bool {
        guard let scalar = char.unicodeScalars.first,
            char.unicodeScalars.count == 1
        else { return !char.isEmpty }
        if scalar.properties.generalCategory == .privateUse {
            return false
        }
        return !scalar.properties.isDefaultIgnorableCodePoint
            && scalar.value >= 0x20
    }
}

/// A row that wraps. The chip row and the legends are lists of
/// unknown length in a fixed-width column, and an `HStack` would
/// push them off the panel's edge rather than wrapping.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layout(subviews, width: width)
        let height =
            rows.reduce(0) { $0 + $1.height }
            + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var y = bounds.minY
        for row in layout(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var height: CGFloat = 0
    }

    private func layout(
        _ subviews: Subviews,
        width: CGFloat
    ) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !row.indices.isEmpty, x + size.width > width {
                rows.append(row)
                row = Row()
                x = 0
            }
            row.indices.append(index)
            row.height = max(row.height, size.height)
            x += size.width + spacing
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

extension KeyboardMatrix.PhysicalType {
    /// Named, never translated: ANSI / ISO / JIS are the
    /// industry's own names for the physical shapes and macOS
    /// shows them untranslated too.
    var label: String {
        switch self {
        case .ansi: return "ANSI"
        case .iso: return "ISO"
        case .jis: return "JIS"
        }
    }
}
