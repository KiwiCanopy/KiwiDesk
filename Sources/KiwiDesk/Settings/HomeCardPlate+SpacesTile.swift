import SwiftUI

/// Spaces & Layouts home card tile illustration with layered mini-desktops.
struct HomeCardSpacesTile: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.schematicPalette) private var palette

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
            alignment: .leading
        )
    }

    private func pane(active: Bool) -> some View {
        let base: Color =
            palette?.base ?? SettingsTheme.previewPlate
        let fill: Color =
            active
            ? palette?.fill ?? LayoutSchematic.fill
            : palette?.ghostFill
                ?? SettingsTheme.ink2.opacity(0.15)
        let stroke: Color =
            active
            ? palette?.accent ?? SettingsTheme.accent
            : palette?.ghostStroke
                ?? SettingsTheme.ink2.opacity(0.5)
        // Opaque base layer to prevent compounding transparency (#712).
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
