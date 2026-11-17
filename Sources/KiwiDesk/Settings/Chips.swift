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
    /// Cuts the tail past this width, for a badge whose whole text
    /// its help carries; nil draws it whole.
    var maxWidth: CGFloat? = nil

    var body: some View {
        Text(label)
            .font(.caption2)
            // One line whatever the row's width: a badge is a label,
            // and a wrapped one reads as two.
            .lineLimit(1)
            .truncationMode(.tail)
            .fixedSize(horizontal: maxWidth == nil, vertical: true)
            .frame(maxWidth: maxWidth, alignment: .leading)
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

/// A choice chip's surface — one of a set, its selection the rest
/// affordance (`ShortcutLayerChip`, `PresetChip`, #2047). A text
/// choice is a text button chip: the chip tokens plus the
/// constant edge, the chosen one drawn like a selected segment —
/// solid accent, `accentInk`, a semibold label over the width
/// every chip reserves. A glyph-only one (`edged: false`) takes
/// no edge and no weight, and a chip whose label shows a weight of
/// its own (`emboldens: false`) keeps it.
enum ChoiceChip {
    static func fill(selected: Bool, hovering: Bool) -> Color {
        if selected { return SettingsTheme.accent }
        return hovering ? SettingsTheme.chipHover : SettingsTheme.chipRest
    }

    static func ink(selected: Bool) -> Color {
        selected ? SettingsTheme.accentInk : SettingsTheme.ink
    }
}

extension View {
    /// Paints a choice chip's capsule behind the label and owns its
    /// hover, as `HoverChip` does: a disabled chip never lifts, and
    /// under Reduce Motion the lift is immediate.
    func choiceChip(
        selected: Bool = false,
        edged: Bool = true,
        emboldens: Bool = true
    ) -> some View {
        modifier(
            ChoiceChipSurface(
                selected: selected,
                edged: edged,
                emboldens: edged && emboldens
            )
        )
    }
}

/// The one home of a choice chip's surface and hover state.
private struct ChoiceChipSurface: ViewModifier {
    let selected: Bool
    let edged: Bool
    let emboldens: Bool
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.kiwiDeskReduceMotion)
    private var reduceMotion

    func body(content: Content) -> some View {
        label(content)
            .foregroundStyle(ChoiceChip.ink(selected: selected))
            .background(
                Capsule().fill(
                    ChoiceChip.fill(
                        selected: selected,
                        hovering: hovering && isEnabled
                    )
                )
            )
            .overlay {
                if edged {
                    Capsule().strokeBorder(
                        SettingsTheme.chipEdge,
                        lineWidth: 1
                    )
                }
            }
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: hovering
            )
            .onHover { hovering = isEnabled && $0 }
            .onChange(of: isEnabled) { _, now in
                if !now { hovering = false }
            }
    }

    /// The chosen label goes semibold over a hidden semibold copy
    /// that reserves its width, so a selection never reflows the
    /// strip.
    @ViewBuilder private func label(_ content: Content) -> some View {
        if emboldens {
            ZStack {
                content.fontWeight(.semibold).hidden()
                    .accessibilityHidden(true)
                content.fontWeight(selected ? .semibold : nil)
            }
        } else {
            content
        }
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
