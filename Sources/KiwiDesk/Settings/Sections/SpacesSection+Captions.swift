import KiwiDeskCore
import SwiftUI

/// The Spaces-list captions, split out of `SpacesSection` to keep
/// that file under the size ceiling — pure copy, no behavior.
extension SpacesSection {
    /// Why a temporary Space's add button is greyed (#1790): no
    /// profile file is live, and the cause is on another page.
    static var noProfileProse: String {
        L(
            "spaces.temporary.no_profile",
            "Save this setup as a profile in %1$@ first to add a "
                + "Space to it.",
            CrossReferenceRow.linkSlot
        )
    }

    /// The one pointer to every Space's shortcuts (#1827).
    static var shortcutsProse: String {
        L(
            "spaces.shortcuts_xref",
            "Shortcuts for every Space, named or numbered, are on "
                + "%1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    var emptyCaption: String {
        L(
            "spaces.empty",
            "No Spaces yet — add one below. Until you do, "
                + "every window tiles in a single default "
                + "Space."
        )
    }

    var spacesCaption: String {
        L(
            "spaces.caption",
            "Each Space has its own layout. Add Spaces "
                + "here; they appear in the shortcut and "
                + "app-rule lists too. Drag rows to "
                + "reorder."
        )
    }

    var fallbackCaption: String {
        L(
            "spaces.fallback_caption",
            "When you switch profiles, windows from a "
                + "Space the new profile doesn't have "
                + "land in its fallback Space (the first "
                + "Space when none is chosen)."
        )
    }
}
