import KiwiDeskCore
import SwiftUI

/// The drawn keyboard. One board for the whole selection, never
/// one per layer — a key claimed twice carries two stripes, which
/// is what keeps a collision legible without a second picture.
struct KeyboardBoard: View {
    let type: KeyboardMatrix.PhysicalType
    let claims: [UInt32: [KeyboardCensus.ModifierLayer]]
    let scope: KeyboardCensus.Scope
    let conflicted: Set<UInt32>

    /// Widths are in key units, so the board scales to whatever
    /// the panel column gives it rather than to a pinned size —
    /// the responsive pass moves that column.
    var body: some View {
        GeometryReader { geometry in
            let rows = KeyboardMatrix.rows(for: type)
            let units = rows.first?.reduce(0) { $0 + $1.units } ?? 1
            // The plate's own padding comes off FIRST: it sits
            // outside the rows, so sizing the unit against the
            // full width overflows the column by exactly twice
            // it, which is how the board shipped clipped.
            let available =
                geometry.size.width - Self.padding * 2
            let unit =
                (available - Self.gap * (units - 1))
                / max(units, 1)
            VStack(spacing: Self.gap) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: Self.gap) {
                        ForEach(rows[row].indices, id: \.self) {
                            index in
                            cap(rows[row][index], unit: unit)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(Self.padding)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(SettingsTheme.previewPlate)
            )
        }
        .frame(height: boardHeight)
    }

    private static let gap: CGFloat = 3
    private static let padding: CGFloat = 8

    /// ONE unit governs both axes. The width was unit-derived
    /// and the height was a hardcoded 26, so the board's aspect
    /// ratio was a function of the panel width — the single
    /// thing a unit system exists to make invariant. At 392 that
    /// drew a 15u × 5-row keyboard at 2.2:1 instead of ~3:1, and
    /// what the eye reported was not "small" but "squashed".
    private var boardHeight: CGFloat {
        let rows = CGFloat(KeyboardMatrix.rows(for: type).count)
        return rows * Self.capUnit + (rows - 1) * Self.gap
            + Self.padding * 2
    }

    /// A letter key is `units: 1` wide in the matrix, so it is
    /// one unit tall too. Pinned rather than measured because the
    /// height has to be known before the width is proposed;
    /// `panelWidth` is back-solved from it.
    static let capUnit: CGFloat = 26

    @ViewBuilder
    private func cap(
        _ key: KeyboardMatrix.Key,
        unit: CGFloat
    ) -> some View {
        let width =
            unit * key.units
            + Self.gap * (key.units - 1)
        KeyCap(
            code: key.code,
            state: state(of: key),
            isConflicted: key.code.map(conflicted.contains)
                ?? false,
            legend: key.legend
        )
        .frame(width: max(width, 0), height: Self.capUnit)
    }

    private func state(
        of key: KeyboardMatrix.Key
    ) -> KeyboardCensus.KeyState {
        guard let code = key.code else { return .free }
        return KeyboardCensus.state(
            of: code,
            claims: claims,
            scope: scope
        )
    }

}

/// One key. Draws its state as a fill and its claims as stripes
/// along the bottom edge, with a conflict ringing the STRIPE —
/// which is what names the offending modifier (owner,
/// 2026-08-10).
///
/// The ring is drawn AROUND the stripe, not inside it. A stroke
/// inside a 3 pt capsule leaves no interior, so it reads as a
/// solid recolour and erases the very colour the stripe carries;
/// ringing the whole key instead says a conflict is here but not
/// which of two modifiers owns it. Outset by 2 pt, the stripe
/// keeps its colour and still gains a mark.
struct KeyCap: View {
    let code: UInt32?
    let state: KeyboardCensus.KeyState
    let isConflicted: Bool
    /// What a code-less cap prints (⇧, ⌘) — see
    /// `KeyboardMatrix.Key.legend`.
    let legend: String?

    /// The fill says what YOUR config has done with the key;
    /// the border warns about it. Two channels rather than one
    /// fill carrying three meanings — which is what let "can't
    /// bind" be a near-black hole that no longer needed to be
    /// (owner, 2026-08-10).
    ///
    /// The two warnings differ by DASH as well as by hue: a
    /// reserved key is dashed, a conflicted one solid. Amber and
    /// red are both warm, so hue alone would collapse them for
    /// the same viewers the palette work was about.
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fill)
            .overlay(border)
            .overlay(
                Text(glyph)
                    .font(.system(size: 9, weight: .medium))
                    .monospaced()
                    .foregroundStyle(ink)
                    .padding(.horizontal, 1)
            )
    }

    @ViewBuilder private var border: some View {
        if isConflicted {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(SettingsTheme.danger, lineWidth: 2)
        } else if state == .cantBind {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    SettingsTheme.keyReserved,
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                )
        }
    }

    /// A reserved key is drawn FREE and ringed, not blacked
    /// out: macOS owning it under this modifier is a warning
    /// about a key that is otherwise unclaimed, and the fill's
    /// job is to say whether the user has claimed it.
    private var fill: Color {
        state == .bound
            ? SettingsTheme.accent
            : SettingsTheme.keyFree
    }

    private var ink: Color {
        state == .bound
            ? SettingsTheme.previewPlate
            : SettingsTheme.plateInk.opacity(0.75)
    }

    /// The label the USER's keyboard prints, not the physical
    /// key's US name — `LayoutKeyGlyph` is the app's one
    /// layout-aware stage (#23) and the reason a German board
    /// shows `ß` where the model calls the key `minus`.
    private var glyph: String {
        guard let code else { return legend ?? "" }
        if let char = LayoutKeyGlyph.char(for: code),
            KeyboardKeyLabel.isPrintable(char)
        {
            return KeyboardKeyLabel.capped(char)
        }
        return KeyboardKeyLabel.fallback(for: code)
    }
}
