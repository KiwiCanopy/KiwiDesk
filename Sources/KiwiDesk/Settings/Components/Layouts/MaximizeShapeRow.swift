import KiwiDeskCore
import SwiftUI

/// One screen shape's row on the Maximize card (#3062): its name,
/// the connected screens of that shape, and a pop-up per column in
/// the card's census order.
struct MaximizeShapeRow: View {
    @ObservedObject var model: SettingsModel
    let shape: ScreenShape
    let screens: [Display]
    /// Each column's width, from `MaximizeColumns`.
    let columns: MaximizeColumns

    /// Between the name and each column.
    static let spacing: CGFloat = 12

    private var maximize: Binding<MaximizeSettings> {
        $model.config.settings.maximize
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.spacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(MaximizeShapeText.name(shape))
                if !screens.isEmpty {
                    // The size Displays calls "Looks like", which a
                    // length is measured against (#3460).
                    Text(
                        LocalizedList.join(
                            screens.map(MaximizeShapeText.screenLine)
                        )
                    )
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.ink3)
                }
                ForEach(overflowLines, id: \.self) { line in
                    Text(line)
                        .font(.callout)
                        .foregroundStyle(SettingsTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(LayoutDefaultsRowOrder.maximizeColumns, id: \.id) { key in
                cell(key)
                    .measuredColumn(key)
                    .frame(width: columns.width(of: key), alignment: .leading)
            }
        }
    }

    @ViewBuilder
    func cell(_ key: SettingKey) -> some View {
        switch key {
        case .behaviour(.maximizeHeightShare):
            shareMenu(
                key,
                axis: .height,
                value: maximize[dynamicMember: \.heightShare[shape]]
            )
        case .behaviour(.maximizeWidthShare):
            shareMenu(
                key,
                axis: .width,
                value: maximize[dynamicMember: \.widthShare[shape]]
            )
        case .behaviour(.maximizeAnchor):
            anchorMenu(key)
        default:
            let _ = assertionFailure(
                "unrendered Maximize cell: \(key.id)"
            )
            EmptyView()
        }
    }

    /// A share's pop-up, `MaximizeSharePopUp`.
    private func shareMenu(
        _ key: SettingKey,
        axis: MaximizeAxis,
        value: Binding<MaximizeLength>
    ) -> some View {
        MaximizeSharePopUp(
            value: value,
            axis: axis,
            region: model.core.maximizeRegion(on: screens.first?.id),
            label: label(key),
            column: MaximizeCard.control(key)?.text ?? ""
        )
    }

    /// A line per connected screen a stored length overflows: the
    /// row shows the stored value, and this says what a press does
    /// there (#3460).
    private var overflowLines: [String] {
        let settings = model.config.settings.maximize
        return MaximizeAxis.allCases.flatMap { axis in
            screens.compactMap { display in
                model.core.maximizeRegion(on: display.id).flatMap {
                    MaximizeShapeText.overflow(
                        settings.share(for: axis, on: shape),
                        axis: axis,
                        on: display,
                        region: $0
                    )
                }
            }
        }
    }

    private func anchorMenu(_ key: SettingKey) -> some View {
        let anchor = maximize[dynamicMember: \.anchor[shape]]
        return Picker(label(key), selection: anchor) {
            ForEach(MaximizeAnchor.allCases, id: \.self) {
                Text(MaximizeCard.anchorName($0)).tag($0)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.large)
        .fixedSize()
        .accessibilityLabel(label(key))
        .accessibilityValue(MaximizeCard.anchorName(anchor.wrappedValue))
    }

    /// A cell's spoken name: its column's label on this shape.
    private func label(_ key: SettingKey) -> String {
        L(
            "layout_defaults.maximize.cell",
            "%1$@, %2$@",
            MaximizeCard.control(key)?.text ?? "",
            MaximizeShapeText.name(shape)
        )
    }
}

/// The words a screen shape is named and measured by (#3062).
@MainActor
enum MaximizeShapeText {
    /// The starter's noun for `shape` (#1662).
    static func name(_ shape: ScreenShape) -> String {
        StarterTitle.displayName(of: shape.screenClass)
    }

    /// A connected screen as the row lists it: its name and the size
    /// Displays shows as "Looks like" (#3460).
    static func screenLine(_ display: Display) -> String {
        L(
            "layout_defaults.maximize.screen_line",
            "%1$@ · %2$@ × %3$@ pt",
            display.name,
            SettingsValueReadout.trimmed(display.frame.width),
            SettingsValueReadout.trimmed(display.frame.height)
        )
    }

    /// The line saying a stored length is longer than `display`'s
    /// axis, so a press fills that axis there; nil for a fraction or
    /// a length that fits (#3460).
    static func overflow(
        _ share: MaximizeLength,
        axis: MaximizeAxis,
        on display: Display,
        region: MaximizeRegion
    ) -> String? {
        guard let points = share.points else { return nil }
        let drawn = region.points(of: share, axis: axis)
        guard drawn < points.rounded() else { return nil }
        let length = SettingsValueReadout.points(points)
        switch axis {
        case .height:
            return L(
                "layout_defaults.maximize.overflow.width",
                "%1$@ is wider than %2$@ (%3$@), so it fills the "
                    + "width there.",
                length,
                display.name,
                SettingsValueReadout.points(drawn)
            )
        case .width:
            return L(
                "layout_defaults.maximize.overflow.height",
                "%1$@ is taller than %2$@ (%3$@), so it fills the "
                    + "height there.",
                length,
                display.name,
                SettingsValueReadout.points(drawn)
            )
        }
    }

    /// The card's `?`: each shape's threshold, read from
    /// `ScreenClass`, then what From does.
    static var thresholds: String {
        L(
            "layout_defaults.maximize.caption.help",
            "%1$@: taller than wide. %2$@: %3$@ times as wide as "
                + "tall or more. %4$@: %5$@ points wide or more, or "
                + "%6$@ times as wide as tall or more. %7$@: under %8$@ "
                + "points wide. %9$@: every other screen. %10$@ "
                + "sets where the window sits on its other side: the "
                + "center of the screen, or over its own place in "
                + "the layout, moved in if it would cross an edge.",
            name(.portrait),
            name(.superUltrawide),
            number(ScreenClass.superUltrawideAspect),
            name(.ultrawide),
            number(ScreenClass.ultrawideWidth),
            number(ScreenClass.ultrawideAspect),
            name(.laptop),
            number(ScreenClass.laptopWidth),
            name(.widescreen),
            L("layout_defaults.maximize.from", "From")
        )
    }

    /// A threshold in the selected language's digits.
    private static func number(_ value: CGFloat) -> String {
        Double(value).formatted(
            .number.grouping(.never)
                .locale(
                    Locale(
                        identifier: LocalizationManager.shared
                            .effectiveLocale ?? "en"
                    )
                )
        )
    }
}
