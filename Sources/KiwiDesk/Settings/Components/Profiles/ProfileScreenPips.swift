import KiwiDeskCore
import SwiftUI

/// Outlined screen pips displaying layout glyphs for saved profiles (#789).
struct ProfileScreenPips: View {
    let count: Int
    var openingModes: [LayoutMode?] = []
    /// How many slots the row RESERVES — the widest profile in the
    /// list. Alignment is a property of the LIST, not a row, and
    /// reserving the cap stranded a one-screen profile's outline
    /// ~69 pt from its name (owner eye-confirm, 2026-08-16).
    var reservedSlots: Int = slots

    /// The "+N" chip takes a slot of its own, so `hidden` never
    /// equals 1 (`docs/ui-patterns.md` ▸ "+N").
    static let slots = 4
    /// The small mount of the outline `PresetScreenCard` draws
    /// large — the RATIO keeps them one picture, so a change to
    /// either is a change to both (#789); the ceiling on growing
    /// it is the row's ~32 pt text block, not taste.
    static let screen = CGSize(width: 34, height: 22)
    static let gap: CGFloat = 3
    static let corner: CGFloat = 3
    static let glyph: CGFloat = 12
    /// Scaled by `PresetScreenCard` for the large mount (#859) —
    /// the two must move together.
    static let moreSize: CGFloat = 9

    static func slotWidth(
        slots: Int,
        screen: CGSize,
        gap: CGFloat
    ) -> CGFloat {
        CGFloat(slots) * screen.width + CGFloat(slots - 1) * gap
    }

    var slotWidth: CGFloat {
        Self.slotWidth(
            slots: max(1, min(reservedSlots, Self.slots)),
            screen: Self.screen,
            gap: Self.gap
        )
    }

    /// Reserves slot count based on widest profile in collection.
    static func reservedSlots(
        forScreenCounts counts: some Collection<Int>
    ) -> Int {
        max(1, min(counts.max() ?? 1, slots))
    }

    /// Number of visible screen pips (`LayoutSchematicCountTests`).
    var shown: Int {
        OverflowSplit.shown(
            of: count,
            fitting: Self.slots,
            withMarker: Self.slots - 1
        )
    }

    var hidden: Int { max(count - shown, 0) }

    var body: some View {
        HStack(spacing: Self.gap) {
            ForEach(0..<shown, id: \.self) { index in
                screenOutline(mode(at: index))
            }
            if hidden > 0 { moreChip }
        }
        .frame(width: slotWidth, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func mode(at index: Int) -> LayoutMode? {
        guard index < openingModes.count else { return nil }
        return openingModes[index]
    }

    private func screenOutline(_ mode: LayoutMode?) -> some View {
        RoundedRectangle(cornerRadius: Self.corner)
            .fill(SettingsTheme.accent.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: Self.corner)
                    .strokeBorder(SettingsTheme.hairline)
            }
            .overlay {
                if let mode {
                    Image(systemName: mode.glyph)
                        .font(.system(size: Self.glyph))
                        .foregroundStyle(SettingsTheme.ink3)
                }
            }
            .frame(
                width: Self.screen.width,
                height: Self.screen.height
            )
    }

    private var moreChip: some View {
        Text(verbatim: "+\(hidden)")
            .font(.system(size: Self.moreSize, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(SettingsTheme.ink3)
            .frame(
                width: Self.screen.width,
                height: Self.screen.height
            )
    }
}
