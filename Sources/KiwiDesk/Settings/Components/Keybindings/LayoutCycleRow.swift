import KiwiDeskCore
import SwiftUI

/// Layout ▸ Layouts to cycle (#453, owner ruling 2026-10-11): one
/// line at rest — the label and the list as a readout, which wraps
/// under the label where it does not fit — that unfolds the
/// editable list in place on a click of either. Its "Applies to"
/// sits in the shortcut rows' reach column, as the Space history
/// row's does.
struct LayoutCycleRow: View {
    @ObservedObject var model: SettingsModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                // The icon slot every shortcut row reserves (#264).
                Color.clear.frame(width: Self.iconSlot, height: 1)
                SettingsDisclosureButton(
                    isExpanded: $expanded,
                    isHeading: false
                ) {
                    heading
                }
                .layoutPriority(1)
                HelpButton(
                    explanation: LayoutCycleWords.help,
                    subject: LayoutCycleWords.title
                )
                Spacer(minLength: 0)
                reach
                KeyRecorderField.footprint
            }
            if expanded {
                LayoutCycleList(model: model)
                    .padding(.leading, Self.iconSlot + 8)
            }
        }
        .searchAnchored(SettingsCatalog.shortcuts.modeCycle)
    }

    static let iconSlot: CGFloat = 18

    /// The label, then the readout while shut: beside it where it
    /// fits, on a second line where it does not.
    @ViewBuilder private var heading: some View {
        if expanded {
            label
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    label
                    readout
                }
                VStack(alignment: .leading, spacing: 2) {
                    label
                    readout
                }
            }
        }
    }

    private var label: some View {
        Text(LayoutCycleWords.title)
            .foregroundStyle(SettingsTheme.ink)
            .fixedSize()
    }

    private var readout: some View {
        Text(LayoutCycleWords.readout(model.config.modeCycle))
            .foregroundStyle(SettingsTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var reach: some View {
        if model.offersReachColumn, let reading = model.cycleReach() {
            RuleReachControl(
                model: model,
                family: .cycle,
                app: RuleReachTable<[LayoutMode]>.modeCycleKey,
                subject: LayoutCycleWords.title,
                reading: reading,
                value: LayoutCycleWords.readout(model.config.modeCycle)
            )
        }
    }
}

/// The plate's switch (#2144) under the cycle list: app-wide
/// (#1741), written at once like the Desktop switch cue, and
/// greyed with its sentence only where `init.lua` owns the config.
struct LayoutCueRow: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        let luaOwned = !model.guiManaged
        ToggleRow(
            label: LayoutCycleWords.cueTitle,
            isOn: Binding(
                get: { model.appWide.modeCue },
                set: { on in model.setAppWide { $0.modeCue = on } }
            ),
            help: LayoutCycleWords.cueHelp,
            disabled: luaOwned
        )
        .searchAnchored(SettingsCatalog.shortcuts.modeCue)
        if luaOwned {
            Text(GeneralGateHelp.sentence(for: .luaOwned))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, ToggleRow.captionIndent)
        }
    }
}
