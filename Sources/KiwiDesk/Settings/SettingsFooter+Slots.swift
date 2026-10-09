import KiwiDeskCore
import SwiftUI

/// Footer action slot views and profile naming sheet prefill (#68 §3.12).
extension SettingsFooter {
    /// Secondary action slot for saving a profile copy.
    @ViewBuilder var copySlot: some View {
        if model.editingLua {
            EmptyView()
        } else if model.editingStoredProfile {
            // A copy takes this profile's draft; a checklist change
            // reaches OTHER profiles, which a copy cannot carry
            // (#1393), so it waits for a Save.
            Button(saveCopyAsLabel) {
                namingProfileCopy = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                SettingsTheme.savePillInk.opacity(0.8)
            )
            .disabled(copyBlockedReason != nil)
            .help(copyBlockedReason ?? "")
        } else if model.activeProfile != nil {
            // Blocked while permission is paused (#335).
            Button(saveCopyAsLabel) {
                namingNewProfile = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                SettingsTheme.savePillInk.opacity(0.8)
            )
            .disabled(model.profileSaveBlockedReason != nil)
            .help(model.profileSaveBlockedReason ?? "")
        }
    }

    var pausedScopeCaption: String {
        L(
            "footer.save.globals_only",
            "Layout and screens stay paused; %1$@ covers "
                + "everything else.",
            L("footer.save", "Save")
        )
    }

    /// Why a copy waits: a checklist choice reaches other
    /// profiles. A plain value edit is the copy's own.
    var copyBlockedReason: String? {
        guard model.copyWaitsOnReach else { return nil }
        return L(
            "footer.save_copy.reach_blocked",
            "This draft changes other profiles too. %1$@ first, "
                + "then save a copy.",
            L("footer.save", "Save")
        )
    }

    var saveCopyAsLabel: String {
        L("footer.save_a_copy_as", "Save as new profile…")
    }

    /// Primary Save action button slot: the model's one Save
    /// (`performPrimarySave`), which the close / quit question
    /// takes too (#2049).
    ///
    /// Sealed rather than `.borderedProminent`: the pill is a
    /// fixed-dark ground and AppKit picks against the window
    /// (#1198, gui.md).
    var primarySlot: some View {
        Button(model.primarySaveLabel) { model.performPrimarySave() }
            .keyboardShortcut("s")
            .kiwiProminentButton()
            .disabled(!model.primarySaveEnabled)
            .help(model.primarySaveBlockedReason ?? "")
    }

    /// Pre-fills unique name in new profile sheet using `isProfileNameFree`.
    func prefillNewProfileName() {
        guard newProfileName.trimmed.isEmpty else { return }
        let base = L(
            "footer.default_profile_name",
            "My Setup"
        )
        var name = base
        var suffix = 2
        while !model.core.isProfileNameFree(name) {
            name = "\(base) \(suffix)"
            suffix += 1
        }
        newProfileName = name
    }
}
