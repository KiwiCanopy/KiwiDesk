import KiwiDeskCore
import SwiftUI

/// The Spaces preview's chips on the one sideways strip (#2990):
/// the overflow fade, and a scroll that follows the focused chip,
/// else the shown one. The chips' measured sizes are this row's own
/// state, so a window resize never re-evaluates the panel's
/// schematic.
struct SpacePreviewChipRow: View {
    let spaces: [SpaceID]
    let shown: SpaceID?
    let pick: (SpaceID) -> Void
    /// Each chip's drawn size, which the strip's run reads, since a
    /// Space's name sets its chip's width.
    @State private var chipSizes: [String: CGSize] = [:]
    @FocusState private var focusedChip: String?

    private static let gap: CGFloat = 6
    /// Room past the end chips for a focus ring, inside the clip.
    private static let ringRoom: CGFloat = 4

    var body: some View {
        let names = spaces.map(\.raw)
        SidewaysStrip(
            run: StripRun(
                lengths: names.map { chipSizes[$0]?.width ?? 0 },
                gap: Self.gap,
                depth: chipSizes.values.map(\.height).max() ?? 0,
                endRoom: Self.ringRoom
            ),
            followed: followed(in: names)
        ) {
            HStack(spacing: Self.gap) {
                ForEach(spaces, id: \.raw) { candidate in
                    chip(candidate).id(candidate.raw)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func followed(in names: [String]) -> StripFollow<String>? {
        let item =
            focusedChip.flatMap { names.contains($0) ? $0 : nil }
            ?? shown?.raw
        guard let item else { return nil }
        return names.firstIndex(of: item).map {
            StripFollow(id: item, index: $0)
        }
    }

    private func chip(_ candidate: SpaceID) -> some View {
        SpacePreviewChip(
            title: candidate.raw,
            isOn: candidate == shown
        ) {
            pick(candidate)
        }
        .focused($focusedChip, equals: candidate.raw)
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: {
            chipSizes[candidate.raw] = $0
        }
    }
}

/// One Space's chip in the preview's row: a choice chip, lifting
/// under the pointer and drawn chosen while shown.
private struct SpacePreviewChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .choiceChip(selected: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            isOn ? [.isButton, .isSelected] : .isButton
        )
    }
}
