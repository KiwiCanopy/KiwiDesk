import Foundation
import KiwiDeskCore

/// What KiwiHub's field holds while Save as New Profile… names a
/// profile (#2359 ruling 3): the typing, the name ↩ writes —
/// worked out once per change, since a free name reads the
/// profile directory — and whether the last save failed.
struct ProfileNaming: Equatable {
    var text: String
    /// The name a save writes, nil where the typing names none.
    var target: String?
    var failed = false
}

/// KiwiHub's Save as New Profile…: the field names the profile,
/// the live arrangement saves under it through `save_profile`,
/// and Esc returns to picking. No load and no forwarding: the
/// saved profile is the live one.
extension JumpModel {
    /// Save as New Profile… was picked: the field names the
    /// profile, pre-filled with a free name and selected.
    func beginNaming() {
        let start =
            newProfileName(ViewPickText.newProfileBase)
            ?? ViewPickText.newProfileBase
        let target = newProfileName(start)
        naming = ProfileNaming(text: start, target: target)
        requestFieldSelectAll()
        // The caption row joins the panel, which refits.
        onResultsChange()
        onAnnounce(ViewPickText.namingSpoken(target ?? start))
    }

    /// The typing changed: its target follows, a failure clears.
    func typeName(_ text: String) {
        naming = ProfileNaming(text: text, target: newProfileName(text))
    }

    /// Back to picking.
    func endNaming() {
        naming = nil
        requestFieldFocus()
        onResultsChange()
    }

    /// The name ↩ writes, nil where the typing names no profile.
    var namingTarget: String? { naming?.target }

    /// ↩ saves, Esc returns to picking; every other key is the
    /// field's (`JumpKey.of` classifies only these while naming).
    func handleNaming(_ key: JumpKey) {
        switch key {
        case .pick(moveHere: false):
            guard let name = naming?.target else {
                onAnnounce(ViewPickText.invalidName)
                return
            }
            if !onSaveProfile(name) {
                naming?.failed = true
                onAnnounce(ViewPickText.saveFailed)
            }
        case .escape:
            endNaming()
            onAnnounce(viewSpoken)
        default:
            break
        }
    }
}
