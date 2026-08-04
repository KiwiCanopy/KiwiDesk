import SwiftUI

/// Reusable chip primitives shared across the settings tabs: the
/// space palette and assignment rows (#6) and the profile palette
/// (#7). Kept in a neutral home so no feature file owns them.

/// A pill rendering a space name, shared by the palette and the
/// assignment rows.
struct SpaceChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(.tint.opacity(0.15))
            )
            .overlay(
                Capsule().strokeBorder(.tint.opacity(0.4))
            )
    }
}

/// The small status capsule used across the settings sections
/// ("active", "default", "Fallback", …) — one chip language
/// everywhere a row carries a state marker.
struct BadgeChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.tint.opacity(0.2))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    .tint.opacity(0.3),
                    lineWidth: 0.5
                )
            )
    }
}

extension View {
    /// The filled chip surface (#678 turn 16b): `sunken` fill and
    /// a hairline on `ChipMetrics.shape`.
    ///
    /// Owned here beside the other chip primitives rather than in
    /// the header, because it is what a chip IS — the header is
    /// one consumer.
    ///
    /// The hairline is not decoration. `sunken` on `card` is
    /// **1.08:1 in both appearances**, so a fill-only chip is a
    /// rectangle very nearly the colour of the bar behind it — and
    /// the search field, which is the header's central affordance,
    /// is one of these. The section container carries a hairline
    /// one level up for exactly this reason: in a palette spaced
    /// this closely, the border is what does the separating and
    /// the fill only sets the mood.
    func chipSurface() -> some View {
        padding(.horizontal, ChipMetrics.padH)
            .padding(.vertical, ChipMetrics.padV)
            .background(
                ChipMetrics.shape
                    .fill(SettingsTheme.sunken)
                    .overlay(
                        ChipMetrics.shape.strokeBorder(
                            SettingsTheme.hairline
                        )
                    )
            )
    }
}

/// Geometry every chip list shares.
///
/// Owned HERE, at the shared widget, not in one area's component:
/// `WrapChips` is used by Monitors, App Rules and Layout
/// Defaults, so taking its gap from `MonitorCardChips` let a
/// Monitors retune silently move the other two. The card-capacity
/// arithmetic is this constant's consumer, not its owner
/// (architect review, 2026-08-04).
enum ChipMetrics {
    static let spacing: CGFloat = 6

    /// A rounded rect, never a `Capsule` like the two chips
    /// above. The prototype draws these as square-ish tokens, and
    /// a capsule beside the Simple|Power User segmented control
    /// reads as a second control rather than as a label.
    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SettingsTheme.chipRadius)
    }

    /// The padding inside a header chip — and inside the search
    /// field, which is a chip that happens to take text. ONE pair
    /// for both, because they sit in the same row and a chip a few
    /// points shorter than the field beside it reads as
    /// misaligned rather than as smaller. Sized up from 10/4 when
    /// the chips read as cramped against the taller bar (owner,
    /// 2026-08-04).
    static let padH: CGFloat = 12
    static let padV: CGFloat = 7
}

/// A simple left-to-right flowing row of chips that wraps to the
/// next line when it runs out of width.
///
/// `Item: Hashable` and identity by VALUE, not by index: a chip
/// list that re-identified its children by position handed the
/// wrong view state to the wrong chip whenever membership changed
/// mid-drag, which is exactly what these lists do.
struct WrapChips<Item: Hashable, Chip: View>: View {
    private let items: [Item]
    private let chip: (Item) -> Chip

    init(
        _ items: [Item],
        @ViewBuilder chip: @escaping (Item) -> Chip
    ) {
        self.items = items
        self.chip = chip
    }

    var body: some View {
        FlowLayout(spacing: ChipMetrics.spacing) {
            ForEach(items, id: \.self) { item in
                chip(item)
            }
        }
    }
}
