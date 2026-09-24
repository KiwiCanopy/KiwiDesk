import KiwiDeskCore
import SwiftUI

/// "Install updates automatically" (#1542 ruling ▸ Automatic install
/// stays): Sparkle's own setting, read and written through the
/// updater. Applies at once; an update then installs when KiwiDesk
/// quits and never relaunches it unasked.
struct AutoInstallRow: View {
    @ObservedObject var model: SettingsModel
    /// Mirrors Sparkle's value, which nothing here can observe.
    @State private var isOn = false

    var body: some View {
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
        }
        .onAppear { isOn = model.updater.installsAutomatically }
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { on in
                model.updater.installsAutomatically = on
                isOn = model.updater.installsAutomatically
            }
        )
    }
}
