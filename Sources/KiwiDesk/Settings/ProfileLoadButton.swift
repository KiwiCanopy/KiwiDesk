import KiwiDeskCore
import SwiftUI

/// The one Load a Settings surface offers — the header's
/// not-loaded line and the Profiles row (#1393). A profile saved
/// for another screen count asks first, since it loads with
/// unsaved changes and claims no screen setup (#36, #1530); then
/// pending edits are confirmed away (#515). Both Loads take this
/// view, so they cannot answer differently.
struct ProfileLoadButton: View {
    @ObservedObject var model: SettingsModel
    let name: String
    var controlSize: ControlSize = .regular
    @State private var confirmingCount = false

    var body: some View {
        Button(L("profiles.load", "Load")) {
            if fitsScreens {
                loadDiscardingEdits()
            } else {
                confirmingCount = true
            }
        }
        .settingsActionButton()
        .controlSize(controlSize)
        .accessibilityLabel(L("profiles.load.ax", "Load %1$@", name))
        .alert(
            L("profiles.load_other_count.title", "Load %1$@?", name),
            isPresented: $confirmingCount
        ) {
            Button(
                L("profiles.load_other_count.cancel", "Cancel"),
                role: .cancel
            ) {}
            Button(L("profiles.load_other_count.confirm", "Load anyway")) {
                loadDiscardingEdits()
            }
        } message: {
            Text(
                L(
                    "profiles.load_other_count.message",
                    "%1$@ is saved for a different number of screens, "
                        + "so it loads with unsaved changes. To keep "
                        + "them, save them as a new profile.",
                    name
                )
            )
        }
    }

    /// Unknown screens (paused, before the boot scan) are no
    /// mismatch — Core's gate says the same.
    private var fitsScreens: Bool {
        guard !model.displays.isEmpty,
            let summary = model.profileSummaries.first(where: {
                $0.name == name
            })
        else { return true }
        return summary.matchesConnectedCount
    }

    private func loadDiscardingEdits() {
        model.discardingEdits(
            message: L(
                "discard.load_profile.message",
                "Loading a profile replaces the edits "
                    + "you haven't saved."
            ),
            confirmLabel: L(
                "discard.load_profile.confirm",
                "Discard & load"
            )
        ) { model.loadProfile(named: name) }
    }
}
