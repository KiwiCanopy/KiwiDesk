import KiwiDeskCore
import SwiftUI

/// The drawn keyboard: one board, showing one scope at a time.
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
            // 16b dark seam — see `SettingsTheme.planeRing`.
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        SettingsTheme.planeRing,
                        lineWidth: 1
                    )
            )
        }
        .frame(height: boardHeight)
    }

    private static let gap: CGFloat = 3
    private static let padding: CGFloat = 8

    /// ONE unit governs both axes, and it is DERIVED from the
    /// column the board is given rather than pinned. The width
    /// was unit-derived while the height was a hardcoded 26, so
    /// the board's aspect ratio was a function of the panel
    /// width — the single thing a unit system exists to make
    /// invariant, and what the eye read as "squashed".
    ///
    /// Deriving it from `panelWidth` rather than from a
    /// `GeometryReader` is deliberate: the height has to be known
    /// before the body is proposed, and the panel's width is a
    /// constant by design. A board asked to render in some other
    /// column would need the reader; nothing asks.
    static func unit(in width: CGFloat) -> CGFloat {
        let available = width - padding * 2
        return (available - gap * (unitsPerRow - 1))
            / unitsPerRow
    }

    /// Every row of both boards totals this — asserted by
    /// `KeyboardMatrixTests.rowsKeepOneWidth`.
    private static let unitsPerRow: CGFloat = 15

    private var boardHeight: CGFloat {
        let rows = CGFloat(KeyboardMatrix.rows(for: type).count)
        let capUnit = Self.unit(
            in: SettingsTheme.panelWidth - Self.columnInset
        )
        return rows * capUnit + (rows - 1) * Self.gap
            + Self.padding * 2
    }

    /// The panel's own horizontal padding, which the board never
    /// sees — `SettingsDetailPanel` applies it outside.
    private static let columnInset: CGFloat = 44

    @ViewBuilder
    private func cap(
        _ key: KeyboardMatrix.Key,
        unit: CGFloat
    ) -> some View {
        // A letter key is `units: 1` in the matrix, so it is one
        // unit tall as well as one wide.
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
        .frame(width: max(width, 0), height: unit)
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

/// One key. The FILL says what the user's config has done with
/// it — bound or free — and a RING warns about it: dashed where
/// macOS already owns the key under the shown modifier, solid
/// where two of the user's own bindings collide.
///
/// Two channels rather than one fill carrying three meanings,
/// which is what let "can't bind" stop being a near-black hole
/// on a key that is free under every other modifier.
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
                .strokeBorder(SettingsTheme.keyConflict, lineWidth: 2)
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
