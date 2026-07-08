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
    }
}

/// A simple left-to-right flowing row of chips that wraps to the
/// next line when it runs out of width.
struct WrapChips<Item, Chip: View>: View {
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
        FlowLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) {
                _,
                item in
                chip(item)
            }
        }
    }
}
