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
                    Text(screens.map(\.name).joined(separator: ", "))
                        .font(.callout)
                        .foregroundStyle(SettingsTheme.ink3)
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
                value: maximize[dynamicMember: \.heightShare[shape]]
            )
        case .behaviour(.maximizeWidthShare):
            shareMenu(
                key,
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
        value: Binding<Double>
    ) -> some View {
        MaximizeSharePopUp(
            value: value,
            label: label(key),
            column: MaximizeCard.control(key)?.text ?? ""
        )
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
