import KiwiDeskCore
import SwiftUI

/// The shut Mouse & trackpad card's pictures (owner ruling
/// 2026-10-17): every entry's, in card order, the groups set apart,
/// scrolling sideways with the KiwiShelf's overflow fade at an end
/// that cuts a picture. A picture rests still, names its gesture
/// in a tooltip, and a click opens the card at its entry.
/// Pointer-only: VoiceOver and the keyboard reach every entry
/// through the disclosure above it.
struct GestureStrip: View {
    let settings: TilingSettings
    let gestures: ScrollGestureBase
    let onLand: (GestureItem) -> Void

    /// Between two pictures of a group, and between two groups.
    nonisolated static let gap: CGFloat = 10
    nonisolated static let groupGap: CGFloat = 24

    var body: some View {
        SidewaysStrip(run: Self.run) {
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
        }
        .accessibilityHidden(true)
    }

    /// The room ahead of `item`: none for the first, a group's gap
    /// where a group starts, the pictures' gap otherwise.
    nonisolated static func leading(of item: GestureItem) -> CGFloat {
        let all = GestureItem.allCases
        guard let index = all.firstIndex(of: item), index > 0 else {
            return 0
        }
        return all[index - 1].group == item.group ? gap : groupGap
    }

    /// Each picture's run, with a group's extra room on its last
    /// picture, since Core's arithmetic takes one gap.
    nonisolated static var run: StripRun {
        let all = GestureItem.allCases
        let lengths = all.indices.map { index -> CGFloat in
            let next = index + 1 < all.count ? all[index + 1] : nil
            let extra = next.map { leading(of: $0) - gap } ?? 0
            return GesturePlate<EmptyView>.size.width + extra
        }
        return StripRun(
            lengths: lengths,
            gap: gap,
            depth: GesturePlate<EmptyView>.size.height
        )
    }
}
