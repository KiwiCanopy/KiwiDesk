import KiwiDeskCore
import SwiftUI

/// Footer action slot views and profile naming sheet prefill (#68 §3.12).
extension SettingsFooter {
    /// Secondary action slot for saving a profile copy.
    @ViewBuilder var copySlot: some View {
        if model.editingLua {
            EmptyView()
        } else if model.editingStoredProfile {
            Button(saveCopyAsLabel) {
                namingProfileCopy = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                SettingsTheme.savePillInk.opacity(0.8)
            )
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

    var saveCopyAsLabel: String {
        L("footer.save_a_copy_as", "Save as new profile…")
    }

    /// Primary Save action button slot.
    ///
    /// Sealed rather than `.borderedProminent`: the pill is a
    /// fixed-dark ground and AppKit picks against the window
    /// (#1198, gui.md).
    @ViewBuilder var primarySlot: some View {
        let save = L("footer.save", "Save")
        switch model.primarySaveAction {
        case .saveLua:
            Button(save) { model.saveLuaSource() }
                .keyboardShortcut("s")
                .kiwiProminentButton()
                .disabled(!model.isDirty)
        case .updateStoredProfile:
            Button(save) { model.saveEditedProfile() }
                .keyboardShortcut("s")
                .kiwiProminentButton()
                .disabled(!model.isDirty)
        case .updateActiveProfile:
            // Update blocked while permission is paused (#335).
            Button(save) { model.updateActiveProfile() }
                .keyboardShortcut("s")
                .kiwiProminentButton()
                .disabled(
                    model.profileSaveBlockedReason != nil
                        || !model.updateEnabled
                        || !(model.isDirty
                            || model.profileDirty)
                )
                .help(
                    model.profileSaveBlockedReason
                        ?? model.updateHint ?? ""
                )
        case .saveGlobalsOnly:
            // Saves globals only when permission paused (#516).
            Button(save) { model.saveGlobalsWhilePaused() }
                .keyboardShortcut("s")
                .kiwiProminentButton()
                .disabled(!model.isDirty)
        case .saveAsNewProfile:
            // Blocked while permission paused (#335).
            Button(
                L(
                    "footer.save_as_new_profile",
                    "Save as New Profile…"
                )
            ) {
                prefillNewProfileName()
                namingNewProfile = true
            }
            .keyboardShortcut("s")
            .kiwiProminentButton()
            .disabled(model.profileSaveBlockedReason != nil)
            .help(model.profileSaveBlockedReason ?? "")
        }
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
