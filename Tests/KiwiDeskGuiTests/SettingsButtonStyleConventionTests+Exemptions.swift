import Foundation
import Testing

@testable import KiwiDesk

/// The button-style convention's two EXEMPTION registers, split out
/// when the suite reached the 350-line ceiling (tests.md ▸ split
/// suites early).
///
/// Both are "the one copy of who may", and both had the same defect
/// until #859's prover rounds: their third field — the needle or the
/// style that IS each exemption's reason — was read by no assertion,
/// so an entry could argue at length about a token its file no
/// longer held. One did, for years ("Picker taking plain style" in a
/// file with neither a picker nor a `.plain`). The suite now asserts
/// each stated token and, from the keys' side, that every exempted
/// file was actually scanned.
extension SettingsButtonStyleConventionTests {
    /// Allowed unstyled action buttons that cannot take a style
    /// for a documented reason.
    typealias Exemption = (count: Int, needle: String, why: String)

    var unstyledExempt: [String: Exemption] {
        [
            "SpacesSection+Customize.swift": (
                9, "deleteConfirmActions",
                "Returned to a confirmationDialog / contextMenu, "
                    + "plus one icon affordance"
            ),
            "SpaceAssignmentChip.swift": (
                3, "rowActions",
                "Returned to the row-menu builder the rowActions "
                    + "seam feeds (#845)"
            ),
            "PaletteShelf.swift": (
                3, "menuItem",
                "Returned to the row-menu builder the rowActions "
                    + "seam feeds (#845)"
            ),
            // Moved out of `ColorField.swift` with the §2.1
            // split (#678 Phase 4 pass 10). The needle changed
            // with it and is the reason: the item is not
            // written inside any one channel's builder — it is
            // built once by `automaticItem` and handed to the
            // `rowActions` seam, which feeds every route from
            // it (#845); one builder is what stops the routes
            // from drifting. A button in a shared menu-item
            // builder is as unstyleable as one written inline
            // in the menu.
            "ColorField+AutomaticMenu.swift": (
                1, "automaticItem",
                "Menu item from the one builder the rowActions "
                    + "seam feeds (#845)"
            ),
            "HeaderSearch.swift": (
                1, "focusShortcut", "Invisible zero-size shortcut sink"
            ),
            // The same shape one surface over: a sheet's Escape
            // needs a carrier that does not depend on focus, and an
            // invisible one draws nothing to style (#859).
            "PresetPreviewSheet.swift": (
                1, "escapeRoute",
                "Invisible zero-size shortcut sink — Escape, "
                    + "focus-independently"
            ),
        ]
    }

    /// Styles applied to non-Button views (e.g. Link) that inflate
    /// the style count.
    typealias StyleNote = (count: Int, style: String, why: String)

    var stylesOnNonButtons: [String: StyleNote] {
        [
            // Three since #1019 gave the guide a PERMANENT route
            // here — the tour's card and Home's banner both being
            // one-shot — beside the Release Notes link #570 added.
            // All three are `Link`s, which is why they are exempt
            // at all rather than owing `settingsActionButton()`: a
            // `Link` is not a `Button` and cannot take the seal.
            // They are deliberately NOT styled alike beyond this —
            // the support link keeps the heart and `.callout`, the
            // two informational pointers take the plainer caption
            // treatment, so the card's one ask stays
            // distinguishable from a pointer.
            "GeneralSection+About.swift": (
                3, ".buttonStyle(.plain)",
                "Three Links taking plain style — the Guide and "
                    + "Release Notes pointers, and the support ask"
            ),
            "ContextShortcut.swift": (
                1, ".buttonStyle(.plain)",
                "The chord popover's container style for the "
                    + "seam-fed menu buttons, which live in the "
                    + "call sites' builder files (#845)"
            ),
            // Moved from `PresetsSection.swift` with the card
            // itself in #859. The reason is also CORRECTED: the
            // entry said "Picker taking plain style" and this file
            // has never held a picker or a `.plain`. The real
            // extra is Apply's zero-profile spotlight — ONE button
            // naming two styles across the two arms
            // (`.borderedProminent` when it is the lone primary,
            // `.settingsActionButton()` otherwise) — so the count
            // was right for a reason nobody could check against
            // the prose beside it.
            "PresetCard.swift": (
                1,
                ".buttonStyle(.borderedProminent)",
                "Apply's spotlight arm — one button, two styles"
            ),
        ]
    }
}
