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
                10, "deleteConfirmActions",
                "Returned to a confirmationDialog / contextMenu "
                    + "(Customize… among them, #2654), plus one "
                    + "icon affordance"
            ),
            // The one discard gate's verbs, returned to its
            // confirmationDialog per kind (#515, #2049).
            "DiscardConfirm.swift": (
                2, "gateActions",
                "Returned to the discard gate's confirmationDialog"
            ),
            "DiscardConfirm+Leave.swift": (
                3, "leaveActions",
                "Returned to the discard gate's confirmationDialog"
            ),
            "LayoutCycleList.swift": (
                2, "rowActions",
                "Returned to the row-menu builder the rowActions "
                    + "seam feeds (#845, #2673)"
            ),
            // Simple's Space card menu (#2777).
            "SimpleSpacesCard.swift": (
                3, "rowActions",
                "Returned to the row-menu builder the rowActions "
                    + "seam feeds (#845)"
            ),
            "SpaceAssignmentChip.swift": (
                3, "rowActions",
                "Returned to the row-menu builder the rowActions "
                    + "seam feeds (#845)"
            ),
            "LooksShelf.swift": (
                3, "menuItem",
                "Returned to the row-menu builder the rowActions "
                    + "seam feeds (#845, #1684)"
            ),
            "SimpleLookCard.swift": (
                1, "rowActions",
                "Returned to the row-menu builder the rowActions "
                    + "seam feeds (#2860)"
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
            // "No Color" joins Automatic there (#2569).
            "ColorField+AutomaticMenu.swift": (
                2, "rowActions",
                "Menu items from the builders the rowActions "
                    + "seam feeds (#845)"
            ),
            // A temporary Space's one row action (#1790).
            "LiveOnlySpaceRow.swift": (
                1, "rowActions",
                "Returned to the row-menu builder the rowActions "
                    + "seam feeds (#845)"
            ),
            // The Space menu's temporary section, built beside the
            // `Menu` it is placed in (#1790).
            "AppRuleSpaceRow.swift": (
                2, "temporarySpaces",
                "Items of the Space menu, built in a property the "
                    + "menu places"
            ),
            "HeaderSearch.swift": (
                1, "focusShortcut", "Invisible zero-size shortcut sink"
            ),
            // ⌘S on the Settings root, mounted whatever the draft
            // (#2584).
            "CommitsOnSave.swift": (
                1, "KeyboardSaveButton",
                "Invisible zero-size shortcut sink — ⌘S"
            ),
            // The same shape one surface over: a sheet's Escape
            // needs a carrier that does not depend on focus, and an
            // invisible one draws nothing to style (#859).
            "PresetPreviewSheet.swift": (
                1, "escapeRoute",
                "Invisible zero-size shortcut sink — Escape, "
                    + "focus-independently"
            ),
            // The same carrier on the About sheet (#1536).
            "AboutSheet.swift": (
                1, "escapeRoute",
                "Invisible zero-size shortcut sink — Escape, "
                    + "focus-independently"
            ),
            // And on Compare and Copy (#2324).
            "SyncCompareSheet.swift": (
                1, "escapeRoute",
                "Invisible zero-size shortcut sink — Escape, "
                    + "focus-independently"
            ),
            // The empty-folder alert's verbs, built in a property
            // the `.alert` places (#2324).
            "SyncAcrossMacsRow.swift": (
                3, "firstCopyActions",
                "Returned to the empty-folder alert's actions"
            ),
        ]
    }

    /// Styles applied to non-Button views (e.g. Link) that inflate
    /// the style count.
    typealias StyleNote = (count: Int, style: String, why: String)

    var stylesOnNonButtons: [String: StyleNote] {
        [
            // `Link`s taking plain style: a `Link` is not a
            // `Button` and cannot take the seal (#1407). Since
            // #1536 they live on Home's support strip and in the
            // About sheet, not on a General card.
            "SupportLinkRow.swift": (
                1, ".buttonStyle(.plain)",
                "One Link taking plain style — the row Home's "
                    + "support strip draws for Discord, GitHub "
                    + "and Ko-fi"
            ),
            "AboutSheet.swift": (
                1, ".buttonStyle(.plain)",
                "One Link helper taking plain style — drawn four "
                    + "times: Release Notes, License, "
                    + "Acknowledgements and Website"
            ),
            "ContextShortcut.swift": (
                1, ".buttonStyle(PopoverRowStyle())",
                "The chord popover's container style for the "
                    + "seam-fed menu buttons, which live in the "
                    + "call sites' builder files (#845)"
            ),
            // A Space card's layout menu draws its picture face
            // whole through the button menu style (#2777).
            "SpaceModeMenu.swift": (
                1, ".buttonStyle(.plain)",
                "The layout Menu taking plain style, so its face "
                    + "is the card's picture and layout name"
            ),
            // The profile chip's menu draws its label whole
            // through the button menu style (owner, 2026-10-17).
            "ProfileHeader.swift": (
                1, ".settingsPopUpTrigger()",
                "The profile chip's Menu taking the pop-up trigger "
                    + "seal, so the whole chip is the menu's hit area"
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
