import KiwiDeskCore
import SwiftUI

/// Layout Standards ▸ Minimum window size (#2237): the "All
/// layouts" master over a "Per layout" drawer. The master stays
/// live over a "Mixed" axis and answers its `?` from
/// `SettingsModel.minSizesDiffer`; the drawer opens by itself and
/// stays open while any axis is mixed, as the bar-edge drawer does.
struct MinWindowSizeRows: View {
    @ObservedObject var model: SettingsModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            master
            drawer
        }
    }

    /// The drawer's title, which the section caption names.
    static var perLayout: String {
        L("layout_defaults.min_size.per_layout", "Per layout")
    }

    private var allLayouts: String {
        L("layout_defaults.min_size.all", "All layouts")
    }

    private var master: some View {
        SettingsRowShape(controlTrails: true) {
            SettingsRowLabel(
                label: allLayouts,
                help: model.minSizesDiffer
                    ? L(
                        "layout_defaults.min_size.mixed_help",
                        "Layouts use different sizes right now. A "
                            + "value here sets every layout."
                    )
                    : nil
            )
        } control: {
            MinSizeFields(
                name: {
                    $0 == .width
                        ? L(
                            "layout_defaults.min_size.all_width",
                            "Width, all layouts"
                        )
                        : L(
                            "layout_defaults.min_size.all_height",
                            "Height, all layouts"
                        )
                },
                width: model.minSizeShared(.width),
                height: model.minSizeShared(.height),
                base: { model.minSizeReference($0) },
                set: { model.setMinSize($1, axis: $0, for: nil) }
            )
        }
    }

    private var drawer: some View {
        let locked = model.minSizesDiffer
        return VStack(alignment: .leading, spacing: 8) {
            SettingsDisclosureButton(
                isExpanded: $expanded,
                locked: locked,
                isHeading: false
            ) {
                Text(Self.perLayout)
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.ink)
                if !(expanded || locked) {
                    Text(
                        L(
                            "layout_defaults.min_size.same",
                            "Same for every layout"
                        )
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if expanded || locked {
                ForEach(MinWindowSizes.Layout.allCases, id: \.self) {
                    layoutRow($0)
                }
            }
        }
    }

    private func layoutRow(_ layout: MinWindowSizes.Layout) -> some View {
        let mode = layout.mode
        let apart = model.minSizeStandsApart(layout)
        return VStack(alignment: .leading, spacing: 2) {
            SettingsRowShape(controlTrails: true) {
                HStack(spacing: 6) {
                    Image(systemName: mode.symbol)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(mode.displayName)
                        .lineLimit(1)
                        .accessibilityHidden(true)
                }
            } control: {
                MinSizeFields(
                    name: { MinSizeText.name(layout, $0) },
                    width: model.minSize(layout, .width),
                    height: model.minSize(layout, .height),
                    base: { model.minSize(layout, $0) },
                    set: { model.setMinSize($1, axis: $0, for: layout) }
                )
            }
            if layout == .scrolling {
                Text(scrollingHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(apart ? SettingsTheme.accent : .clear)
                .frame(width: 3)
                .accessibilityHidden(true)
        }
        .padding(.leading, 14)
    }

    /// Which axis Scrolling's direction makes apply.
    private var scrollingHint: String {
        model.config.settings.scrolling.axisIsHorizontal
            ? L(
                "layout_defaults.min_size.scrolling_h",
                "Scrolls horizontally, so only the width applies."
            )
            : L(
                "layout_defaults.min_size.scrolling_v",
                "Scrolls vertically, so only the height applies."
            )
    }
}
