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
            reach: {
                reach(
                    .tilingStart,
                    key: Table.tilingStartKey,
                    subject: TilingOffWords.start,
                    reading: model.tilingStartReach(),
                    on: model.tilingStartOn
                )
            },
            control: {
                toggle(
                    TilingOffWords.start,
                    isOn: Binding(
                        get: { model.tilingStartOn },
                        set: { model.config.settings.tiling.start = $0 }
                    )
                )
            }
        )
    }

    @ViewBuilder private func hideRow(
        _ census: SettingKey,
        key: String,
        title: String,
        path: WritableKeyPath<TilingToggleSettings, Bool?>
    ) -> some View {
        let reason = ShortcutsGates(config: model.config)
            .inertReason(for: census)
        let sentence = reason.flatMap(ShortcutsGateHelp.sentence(for:))
        ShortcutSettingRow(
            title: title,
            help: nil,
            reach: {
                reach(
                    .tilingOffHides,
                    key: key,
                    subject: title,
                    reading: model.tilingOffHidesReach(key),
                    on: model.tilingOffHidesOn(key)
                )
            },
            control: {
                toggle(
                    title,
                    isOn: Binding(
                        get: { model.tilingOffHidesOn(key) },
                        set: {
                            model.config.settings.tiling[keyPath: path] = $0
                        }
                    )
                )
                .modifier(
                    GreyOut(active: reason != nil, help: sentence ?? "")
                )
            }
        )
        if let sentence {
            Text(sentence)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, SettingsMetrics.shortcutTextIndent)
        }
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
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
                + "change applies at once to every Space you have not "
                + "switched this session."
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

    /// A row's own value in the diff: nil follows All profiles.
    static func value(_ own: Bool?) -> String {
        own.map(onOff)
            ?? L("shortcuts.tiling_off.follows", "Same as all profiles")
    }
}

/// The Shortcuts greys' sentences (#3089); nil for a reason that
/// withholds rather than greys.
@MainActor
enum ShortcutsGateHelp {
    static func sentence(for reason: ShortcutsGates.InertReason) -> String? {
        switch reason {
        case .noBarShows:
            L(
                "shortcuts.tiling_off.no_bar_shows",
                "No bar shows in any layout, so there is nothing to hide."
            )
        case .focusBorderOff:
            L(
                "shortcuts.tiling_off.border_off",
                "The focus border is off, so there is nothing to hide."
            )
        case .onlyDefaultLayer, .trackUnused, .appWideLuaOwned,
            .storedProfilePage, .otherLayerPicked, .matchesDefaults:
            nil
        }
    }
}
