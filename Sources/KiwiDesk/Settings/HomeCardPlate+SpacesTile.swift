import SwiftUI

/// The Spaces & Layouts picture: a FAN of mini-desktops, one
/// per declared space in the draft's order, the active one
/// forward and fully exposed in the palette accent, the rest
/// ghosted behind it (ui-designer concept round, 2026-08-09 —
/// over the schematic band, which duplicated the Layout
/// Defaults card's picture). The fan reuses the Monocle
/// schematic's several-full-screens-one-current vocabulary;
/// interiors stay blank because the app has no per-layout
/// glyph — the schematic IS a layout's label, and a 20 pt one
/// is the 13b class. Position, exposure, fill density and
/// stroke weight all step, so hue never carries alone; past
/// the cap the family's "+N" grammar says so.
///
/// Split from `HomeCardPlate.swift` when the dark pass's plate
/// seam took that file past the §2.1 ceiling.
struct HomeCardSpacesTile: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.schematicPalette) private var palette

    // 16:10 landscape panes, not tall slabs — each pane is a
    // SCREEN (owner, 2026-08-09) — centred on both axes so the
    // first pane's leading margin equals the last one's
    // trailing margin.
    private static let card = CGSize(width: 70, height: 44)
    private static let exposed: CGFloat = 18
    private static let cap = 8

    var body: some View {
        let total = max(model.config.spaces.count, 1)
        let count = min(total, Self.cap)
        HStack(spacing: 6) {
            fan(count)
            if total > count {
                Text("+\(total - count)")
                    .font(
                        .system(size: 9, weight: .semibold)
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        palette?.ink ?? SettingsTheme.plateInk
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fan(_ count: Int) -> some View {
        ZStack(alignment: .leading) {
            ForEach(0..<count, id: \.self) { index in
                pane(active: index == 0)
                    .offset(
                        x: CGFloat(index) * Self.exposed
                    )
                    .zIndex(Double(-index))
            }
        }
        .frame(
            width: Self.card.width
                + CGFloat(count - 1) * Self.exposed,
            height: Self.card.height,
            // Leading, not the frame default: the ZStack's own
            // layout size is ONE pane (offsets are drawing
            // only), so a centre-aligned frame shifted the
            // whole run half a fan to the right — the first
            // screen started mid-plate (owner, 2026-08-09).
            alignment: .leading
        )
    }

    private func pane(active: Bool) -> some View {
        // Hoisted picks: the chained ternaries over optional
        // chains blew the type-checker's budget inline (the
        // shallow-body rule's CI-only failure class).
        let base: Color =
            palette?.base ?? SettingsTheme.previewPlate
        let fill: Color =
            active
            ? palette?.fill ?? LayoutSchematic.fill
            : palette?.ghostFill
                ?? SettingsTheme.ink2.opacity(0.15)
        // Full accent on the forward pane, not the family's
        // 0.6 tile stroke: beside the Gaps ring's unified
        // accent the softer alpha read as a third green
        // (owner, 2026-08-09).
        let stroke: Color =
            active
            ? palette?.accent ?? SettingsTheme.accent
            : palette?.ghostStroke
                ?? SettingsTheme.ink2.opacity(0.5)
        // Opaque base first: the ghosts overlap, and
        // translucent fills would sum where they do (the
        // #712 compounding trap).
        return RoundedRectangle(cornerRadius: 5)
            .fill(base)
            .overlay(
                RoundedRectangle(cornerRadius: 5).fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        stroke,
                        lineWidth: active ? 1.5 : 1
                    )
            )
            .frame(
                width: Self.card.width,
                height: Self.card.height
            )
    }
}
