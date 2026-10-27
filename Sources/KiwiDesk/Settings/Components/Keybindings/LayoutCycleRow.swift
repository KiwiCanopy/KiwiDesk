import KiwiDeskCore
import SwiftUI

/// Layout ▸ Layouts to cycle (#2673): the label, and the list as a
/// bordered button in the recorder column that opens
/// `LayoutCycleList` in a popover. Its "Applies to" sits in the
/// shortcut rows' reach column, in the shared setting row (#2670).
struct LayoutCycleRow: View {
    @ObservedObject var model: SettingsModel
    @State private var request: LayoutCycleRequest?

    var body: some View {
        ShortcutSettingRow(
            title: LayoutCycleWords.title,
            help: LayoutCycleWords.help,
            reach: { reach },
            control: {
                // The recorder's own button width, inside its slots.
                summary.padding(
                    .horizontal,
                    KeyRecorderField.iconSlotWidth + 6
                )
            }
        )
        .searchAnchored(SettingsCatalog.shortcuts.modeCycle)
    }

    private var summary: some View {
        let readout = LayoutCycleWords.readout(model.config.modeCycle)
        return Button {
            request = LayoutCycleRequest()
        } label: {
            Text(readout)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
        .settingsActionButton()
        .help(readout)
        .accessibilityLabel(LayoutCycleWords.title)
        .accessibilityValue(LayoutCycleWords.spoken(model.config.modeCycle))
        .popover(item: $request, arrowEdge: .bottom) { _ in
            LayoutCycleList(model: model)
                .settingsPopoverChrome()
        }
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

/// The popover's request — one row's (#843).
struct LayoutCycleRequest: Identifiable {
    let id = "modeCycle"
}

/// The plate's switch (#2144) under the cycle list: app-wide
/// (#1741), written at once like the Desktop switch cue, and
/// greyed with its sentence only where `init.lua` owns the config,
/// as `ShortcutsGates` answers it. Indented to the cycle row's
/// label, both rows taking the shortcut rows' icon slot.
struct LayoutCueRow: View {
    @ObservedObject var model: SettingsModel

    private var reason: ShortcutsGates.InertReason? {
        ShortcutsGates(config: model.config, guiManaged: model.guiManaged)
            .inertReason(for: .shortcuts(.modeCue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            toggle
        }
        .padding(.leading, SettingsMetrics.shortcutTextIndent)
    }

    @ViewBuilder private var toggle: some View {
        let luaOwned = reason == .appWideLuaOwned
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
