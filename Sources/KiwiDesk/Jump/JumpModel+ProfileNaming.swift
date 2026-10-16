import Foundation
import KiwiDeskCore

/// KiwiHub's Save as New Profile… (#2359 ruling 3): the field
/// names the profile, the live arrangement saves under it through
/// `save_profile`, and Esc returns to picking. No load and no
/// forwarding: the saved profile is the live one.
extension JumpModel {
    /// Save as New Profile… was picked: the field names the
    /// profile, pre-filled with a free name and selected.
    func beginNaming() {
        profileNaming = freeProfileName(ViewPickText.newProfileBase)
        requestFieldSelectAll()
        onAnnounce(ViewPickText.namingPrompt)
    }

    /// The name ↩ writes — the typed name, made free so a save
    /// never overwrites — or nil where it cannot name a profile.
    var namingTarget: String? {
        guard let typed = profileNaming,
            ProfileManager.isValidName(typed)
        else { return nil }
        return freeProfileName(
            typed.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// ↩ saves, Esc returns to picking; the field keeps every
    /// other key.
    func handleNaming(_ key: JumpKey) {
        switch key {
        case .pick(moveHere: false):
            if let name = namingTarget {
                namingFailed = !onSaveProfile(name)
            }
        case .escape:
            profileNaming = nil
            namingFailed = false
            requestFieldFocus()
            onAnnounce(viewSpoken)
        default:
            break
        }
    }
}
