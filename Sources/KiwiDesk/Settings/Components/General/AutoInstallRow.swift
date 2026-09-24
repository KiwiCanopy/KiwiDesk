import KiwiDeskCore
import SwiftUI

/// "Install updates automatically" (#1542 ruling ▸ Automatic install
/// stays): Sparkle's own setting, observed through the updater.
/// On, an update installs the next time KiwiDesk quits and never
/// relaunches it; greyed with its reason where Sparkle refuses it
/// (`GeneralGates`).
struct AutoInstallRow: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var setting: AutoInstallSetting

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DropdownRow(
                label: L(
                    "general.updates.install_automatically",
                    "Install updates automatically"
                ),
                spokenValue: nil,
                help: L(
                    "general.updates.install_automatically.help",
                    "KiwiDesk downloads updates on its own and installs "
                        + "them the next time it quits. It never restarts "
                        + "by itself."
                )
            ) {
                Toggle("", isOn: binding)
                    .labelsHidden()
                    .disabled(reason != nil)
            }
            if let reason {
                Text(GeneralGateHelp.sentence(for: reason))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
            }
        }
    }

    /// The grey and its sentence come from the one resolver, never
    /// a predicate re-derived here.
    private var reason: GeneralGates.InertReason? {
        model.generalGates.inertReason(
            for: .general(.installUpdatesAutomatically)
        )
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { setting.isOn },
            set: { setting.set($0) }
        )
    }
}
