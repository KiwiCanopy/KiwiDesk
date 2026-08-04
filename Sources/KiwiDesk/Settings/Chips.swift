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

/// A simple left-to-right flowing row of chips that wraps to the
/// next line when it runs out of width.
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
}

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
