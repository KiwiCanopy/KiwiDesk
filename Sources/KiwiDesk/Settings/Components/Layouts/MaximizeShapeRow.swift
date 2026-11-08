import KiwiDeskCore
import SwiftUI

/// One screen shape's row on the Maximize card (#3062): its name,
/// the connected screens of that shape, and a pop-up per column in
/// the card's census order.
struct MaximizeShapeRow: View {
    @ObservedObject var model: SettingsModel
    let shape: ScreenShape
    let screens: [Display]
    /// The open Custom popover, by column (#3062).
    @State private var custom: [SettingKey: MaximizeCustomRequest] = [:]

    /// A pop-up column's width, the headings' too.
    static let columnWidth: CGFloat = 120
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
            ForEach(LayoutDefaultsRowOrder.maximize, id: \.id) { key in
                cell(key)
                    .frame(width: Self.columnWidth, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func cell(_ key: SettingKey) -> some View {
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

    /// A share's pop-up: the five fractions, a stored value
    /// outside them as a checked item above a separator, then
    /// "Custom…", which opens an anchored percent popover.
    private func shareMenu(
        _ key: SettingKey,
        value: Binding<Double>
    ) -> some View {
        let offMenu = Self.offMenuShare(value.wrappedValue)
        let selection = Binding<Double>(
            get: { Self.selection(value.wrappedValue) },
            set: { picked in
                if picked == MaximizeCustomShare.tag {
                    custom[key] = MaximizeCustomRequest(
                        seed: MaximizeCustomShare.percent(
                            of: value.wrappedValue
                        )
                    )
                } else {
                    value.wrappedValue = picked
                }
            }
        )
        let spoken = SettingsValueReadout.percent(value.wrappedValue)
        return Picker(label(key), selection: selection) {
            if let offMenu {
                Text(spoken).tag(offMenu)
                Divider()
            }
            ForEach(FractionChips.shares, id: \.glyph) { share in
                Text(share.glyph).tag(share.value)
            }
            Divider()
            Text(L("layout_defaults.maximize.custom", "Custom…"))
                .tag(MaximizeCustomShare.tag)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.large)
        // A menu pop-up draws at its own width whatever frame it
        // gets; natural width on the cell's leading edge aligns it.
        .fixedSize()
        .accessibilityLabel(label(key))
        .accessibilityValue(spoken)
        .popover(item: customBinding(key)) { request in
            MaximizeCustomPopover(
                seed: request.seed,
                column: MaximizeCard.control(key)?.text ?? ""
            ) { percent in
                value.wrappedValue = MaximizeCustomShare.share(
                    forPercent: percent
                )
            }
            .settingsPopoverChrome()
        }
    }

    /// The Custom popover's request for `key`'s column alone.
    private func customBinding(
        _ key: SettingKey
    ) -> Binding<MaximizeCustomRequest?> {
        Binding(
            get: { custom[key] },
            set: { custom[key] = $0 }
        )
    }

    /// A stored share none of the five fractions reads as — one
    /// Lua or the CLI set — which the pop-up keeps as an extra
    /// checked item; nil for a preset. Custom… writes one too.
    static func offMenuShare(_ stored: Double) -> Double? {
        FractionChips.shares.contains {
            FractionChips.matches(stored, $0.value)
        } ? nil : stored
    }

    /// The tag a stored share checks: its preset's own value, so a
    /// share typed as 0.6667 checks ⅔, or itself when off the menu.
    static func selection(_ stored: Double) -> Double {
        FractionChips.shares.first {
            FractionChips.matches(stored, $0.value)
        }?.value ?? stored
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
