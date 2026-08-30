import SwiftUI

/// Reusable chip primitives shared across settings views (#6, #7).

/// A pill rendering a space name.
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

/// Small status capsule used across settings sections.
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
    /// Filled chip surface with sunken fill and hairline border (#678).
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

/// Shared layout metrics for chip views.
enum ChipMetrics {
    static let spacing: CGFloat = 6

    /// Rounded rect matching `SettingsTheme.chipRadius`.
    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SettingsTheme.chipRadius)
    }

    /// Internal padding for chips and search field.
    static let padH: CGFloat = 12
    static let padV: CGFloat = 7
}

/// Flowing horizontal chip row wrapping across lines.
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
