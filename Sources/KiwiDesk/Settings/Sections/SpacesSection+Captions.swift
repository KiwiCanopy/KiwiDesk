import KiwiDeskCore
import SwiftUI

/// The Spaces-list captions, split out of `SpacesSection` to keep
/// that file under the size ceiling — pure copy, no behavior.
extension SpacesSection {
    var emptyCaption: String {
        L(
            "spaces.empty",
            "No spaces yet — add one below. Until you do, "
                + "every window tiles in a single default "
                + "space."
        )
    }

    var spacesCaption: String {
        L(
            "spaces.caption",
            "Each space has its own layout. Add spaces "
                + "here; they appear in the shortcut and "
                + "app-rule lists too. Drag rows to "
                + "reorder."
        )
    }

    var fallbackCaption: String {
        L(
            "spaces.fallback_caption",
            "When you switch profiles, windows from a "
                + "space the new profile doesn't have "
                + "land in its fallback space (the first "
                + "space when none is chosen)."
        )
    }
}
