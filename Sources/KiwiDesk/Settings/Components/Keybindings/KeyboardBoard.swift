import KiwiDeskCore
import SwiftUI

/// Keyboard visual matrix showing shortcut bindings for a scope.
struct KeyboardBoard: View {
    let type: KeyboardMatrix.PhysicalType
    let claims: [UInt32: [KeyboardCensus.ModifierLayer]]
    let scope: KeyboardCensus.Scope
    let conflicted: Set<UInt32>

    var body: some View {
        GeometryReader { geometry in
            let rows = KeyboardMatrix.rows(for: type)
            let units = rows.first?.reduce(0) { $0 + $1.units } ?? 1
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

    /// Key unit size derived from width constraint.
    static func unit(in width: CGFloat) -> CGFloat {
        let available = width - padding * 2
        return (available - gap * (unitsPerRow - 1))
            / unitsPerRow
    }

    /// Total units per row across keyboard models
    /// (`KeyboardMatrixTests.rowsKeepOneWidth`).
    private static let unitsPerRow: CGFloat = 15

    private var boardHeight: CGFloat {
        let rows = CGFloat(KeyboardMatrix.rows(for: type).count)
        let capUnit = Self.unit(
            in: SettingsTheme.panelWidth - Self.columnInset
        )
        return rows * capUnit + (rows - 1) * Self.gap
            + Self.padding * 2
    }

    private static let columnInset: CGFloat = 44

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
            isOverwritten: key.code
                .map(overwritten.contains) ?? false,
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

    private var overwritten: Set<UInt32> {
        KeyboardCensus.overwrittenReserved(
            claims: claims,
            scope: scope
        )
    }
}

/// Single keycap with status fill and ring (`KeyboardRingSeparationTests`).
struct KeyCap: View {
    let code: UInt32?
    let state: KeyboardCensus.KeyState
    let isConflicted: Bool
    let isOverwritten: Bool
    let legend: String?

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
        if isConflicted || isOverwritten {
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

    /// Layout-aware character glyph for keycode (`LayoutKeyGlyph`, #23).
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
