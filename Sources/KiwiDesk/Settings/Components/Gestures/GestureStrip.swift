import KiwiDeskCore
import SwiftUI

/// The shut Mouse & trackpad card's pictures (owner ruling
/// 2026-10-17): every entry's, in card order, the groups set apart,
/// scrolling sideways with the KiwiShelf's overflow fade at an end
/// that cuts a picture. A picture plays while hovered, names its
/// gesture in a tooltip, and a click opens the card at its entry.
/// Pointer-only: VoiceOver and the keyboard reach every entry
/// through the disclosure above it.
struct GestureStrip: View {
    let settings: TilingSettings
    let gestures: ScrollGestureBase
    let onLand: (GestureItem) -> Void
    @State private var offset: CGFloat = 0
    @State private var viewport: CGFloat = 0

    /// Between two pictures of a group, and between two groups.
    nonisolated static let gap: CGFloat = 10
    nonisolated static let groupGap: CGFloat = 24

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(GestureItem.allCases) { item in
                    GestureStripPlate(
                        item: item,
                        settings: settings,
                        gestures: gestures,
                        onLand: onLand
                    )
                    .padding(.leading, Self.leading(of: item))
                }
            }
            .onGeometryChange(for: CGFloat.self) {
                -$0.frame(in: .named(Self.space)).minX
            } action: {
                offset = $0
            }
        }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            viewport = $0
        }
        .mask(GestureStripFade(fades: fades))
        .accessibilityHidden(true)
    }

    private static let space = "gestureStrip"

    /// The room ahead of `item`: none for the first, a group's gap
    /// where a group starts, the pictures' gap otherwise.
    nonisolated static func leading(of item: GestureItem) -> CGFloat {
        let all = GestureItem.allCases
        guard let index = all.firstIndex(of: item), index > 0 else {
            return 0
        }
        return all[index - 1].group == item.group ? gap : groupGap
    }

    var fades: ShelfOverflow.Fades {
        Self.fades(offset: offset, viewport: viewport)
    }

    /// Core's overflow fades (`ShelfOverflow.fades`), handed each
    /// picture's run with a group's extra room on its last picture,
    /// since that arithmetic takes one gap.
    nonisolated static func fades(offset: CGFloat, viewport: CGFloat)
        -> ShelfOverflow.Fades
    {
        let all = GestureItem.allCases
        let lengths = all.indices.map { index -> CGFloat in
            let next = index + 1 < all.count ? all[index + 1] : nil
            let extra = next.map { leading(of: $0) - gap } ?? 0
            return GesturePlate<EmptyView>.size.width + extra
        }
        let total =
            lengths.reduce(0, +)
            + gap * CGFloat(max(lengths.count - 1, 0))
        return ShelfOverflow.fades(
            lengths: lengths,
            gap: gap,
            total: total,
            offset: offset,
            viewport: viewport,
            depth: GesturePlate<EmptyView>.size.height
        )
    }
}

/// The strip's mask: opaque, fading out over each end's length.
/// Instant, never animated, like the bars' (`ShelfFadeMask`). A
/// mask reads only alpha, so any opaque token serves as its ink.
struct GestureStripFade: View {
    let fades: ShelfOverflow.Fades

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, SettingsTheme.ink],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fades.leading)
            Rectangle().fill(SettingsTheme.ink)
            LinearGradient(
                colors: [SettingsTheme.ink, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fades.trailing)
        }
    }
}
