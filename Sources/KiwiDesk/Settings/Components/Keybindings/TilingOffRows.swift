import KiwiDeskCore
import SwiftUI

/// Size & float ▸ Tiling off (#3089): a sub-header and the three
/// options of the tiling toggle, directly above its key row, each
/// in the shared setting row's shape (#2670) with its own "Applies
/// to". Drawn whatever the key's binding, as Wrap focus is: the
/// menu row and Lua pause tiling too. The hide rows grey with
/// their reason where they would hide nothing.
struct TilingOffRows: View {
    @ObservedObject var model: SettingsModel

    private typealias Table = RuleReachTable<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(TilingOffWords.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            startRow
            hideRow(
                .behaviour(.tilingOffHidesBorders),
                key: Table.offHidesBordersKey,
                title: TilingOffWords.hideBorders,
                path: \.offHidesBorders
            )
            hideRow(
                .behaviour(.tilingOffHidesBars),
                key: Table.offHidesBarsKey,
                title: TilingOffWords.hideBars,
                path: \.offHidesBars
            )
        }
    }

    private var startRow: some View {
        ShortcutSettingRow(
            title: TilingOffWords.start,
            help: TilingOffWords.startHelp,
            isOn: Binding(
                get: { model.tilingStartOn },
                set: { model.config.settings.tiling.start = $0 }
            ),
            reach: {
                reach(
                    .tilingStart,
                    key: Table.tilingStartKey,
                    subject: TilingOffWords.start,
                    reading: model.tilingStartReach(),
                    on: model.tilingStartOn
                )
            }
        )
    }

    /// A hide row, and outside its grey the live pointer to where
    /// its cause is set (gui.md ▸ a dim is not a sentence).
    @ViewBuilder private func hideRow(
        _ census: SettingKey,
        key: String,
        title: String,
        path: WritableKeyPath<TilingToggleSettings, Bool?>
    ) -> some View {
        let reason = ShortcutsGates(config: model.config)
            .inertReason(for: census)
        let link = reason.flatMap(TilingOffWords.link(for:))
        ShortcutSettingRow(
            title: title,
            help: nil,
            isOn: Binding(
                get: { model.tilingOffHidesOn(key) },
                set: { model.config.settings.tiling[keyPath: path] = $0 }
            ),
            grey: link.map(TilingOffWords.hover),
            reach: {
                reach(
                    .tilingOffHides,
                    key: key,
                    subject: title,
                    reading: model.tilingOffHidesReach(key),
                    on: model.tilingOffHidesOn(key)
                )
            }
        )
        if let link {
            CrossReferenceRow(
                prose: link.prose,
                linkTitle: link.destination.title,
                destination: link.destination
            )
            .font(.caption)
            .padding(.leading, SettingsMetrics.shortcutTextIndent)
        }
    }

    @ViewBuilder private func reach(
        _ family: RuleFamily,
        key: String,
        subject: String,
        reading: RuleReachReading?,
        on: Bool
    ) -> some View {
        if model.offersReachColumn, let reading {
            RuleReachControl(
                model: model,
                family: family,
                app: key,
                subject: subject,
                reading: reading,
                value: TilingOffWords.onOff(on)
            )
        }
    }
}

/// What the Tiling off rows are called and how their values read
/// — one home for the rows, the diff pill and the checklists.
@MainActor
enum TilingOffWords {
    static var title: String {
        L("shortcuts.tiling_off", "Tiling off")
    }

    static var start: String {
        L("shortcuts.tiling_off.start", "Spaces start with tiling on")
    }

    static var startHelp: String {
        L(
            "shortcuts.tiling_off.start.help",
            "When this is off, every Space starts with tiling off. A "
                + "change applies at once to every Space whose tiling you "
                + "have not turned on or off this session."
        )
    }

    static var hideBorders: String {
        L(
            "shortcuts.tiling_off.hide_borders",
            "Hide the focus border while tiling is off"
        )
    }

    static var hideBars: String {
        L(
            "shortcuts.tiling_off.hide_bars",
            "Hide the bars while tiling is off"
        )
    }

    static func onOff(_ on: Bool) -> String {
        on
            ? L("diff.value.on", "On")
            : L("diff.value.off", "Off")
    }
}

extension TilingOffWords {
    /// A grey's hover text: its sentence with the destination named
    /// where the link sits.
    static func hover(
        _ link: (prose: String, destination: SettingsDestination)
    ) -> String {
        link.prose.replacingOccurrences(
            of: CrossReferenceRow.linkSlot,
            with: link.destination.title
        )
    }

    /// What makes a greyed hide row work, its link at
    /// `CrossReferenceRow.linkSlot`; nil for a reason no hide row
    /// takes.
    static func link(
        for reason: ShortcutsGates.InertReason
    ) -> (prose: String, destination: SettingsDestination)? {
        switch reason {
        case .noBarShows:
            (
                L(
                    "shortcuts.tiling_off.bars_link",
                    "Works when the Space Bar or App Bar is set to %1$@ "
                        + "or %2$@ in %3$@.",
                    L("bar.visibility.always", "Always"),
                    L("bar.visibility.auto", "Auto"),
                    CrossReferenceRow.linkSlot
                ),
                .bars
            )
        case .focusBorderOff:
            (
                L(
                    "shortcuts.tiling_off.border_link",
                    "Works when the focus border is on in %1$@.",
                    CrossReferenceRow.linkSlot
                ),
                .gapsAndBorders
            )
        case .onlyDefaultLayer, .trackUnused, .appWideLuaOwned,
            .storedProfilePage, .otherLayerPicked, .matchesDefaults:
            nil
        }
    }
}
