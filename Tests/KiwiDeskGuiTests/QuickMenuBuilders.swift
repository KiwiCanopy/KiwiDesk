import Foundation

/// The ONE list of which files build KiwiDesk's menu-bar rows, and
/// which of them the #802 per-row enablement scan checks.
///
/// Shared rather than hand-listed per suite, exactly as
/// `ChromeScanRoots` is shared: two guards read it — the
/// enablement scan and the coverage check that no builder escapes
/// both lists — and a divergent copy would silently exempt a file
/// from a fail-open guard.
enum QuickMenuBuilders {
    /// Every file that builds quick-menu rows.
    ///
    /// **A list with a coverage check, not one hard-coded path.**
    /// The scan was pinned to a single file and `total > 0` cannot
    /// tell a SPLIT from a whole file: move a row builder into its
    /// own file and its rows go unguarded with the suite green. That is
    /// `gui.md`'s scan-root rule (`ChromeScanRoots` is the worked
    /// example): a new tree joins the list, and the guard carries a
    /// root-coverage check.
    ///
    /// **`StatusItemController+Menu.swift` is deliberately NOT
    /// here yet, and adding it reds** — see `unchecked`.
    static let checked = [
        // The Check-for-Updates row (#874). It joins the CHECKED
        // list rather than the exempt one because its enablement
        // is genuinely conditional — Sparkle refuses while a check
        // is running or an update is mid-install — so it is the
        // first quick-menu row that has to state `isEnabled` for a
        // reason rather than by convention.
        "Sources/KiwiDesk/StatusItemController+Updates.swift",
        // The Settings pull-down (#1393) turns auto-enabling off and
        // states every row's `isEnabled` from its item.
        "Sources/KiwiDesk/Settings/Components/Common/NativePullDown.swift",
    ]

    /// Files that construct rows and are NOT checked per row,
    /// each with the reason. The `allowed`-map idiom: an entry is a
    /// decision on record, not a gap.
    static let unchecked: [String: String] = [
        // Found by this suite's own tree scan on its first run,
        // which is the guard working: #802 binds a menu that turns
        // auto-enabling OFF, and this one never touches the flag,
        // so it keeps AppKit's default and validates rows the
        // standard way. Nothing here to state.
        "MainMenu.swift":
            "keeps AppKit's auto-enabling, so #802's per-row rule "
            + "does not bind it — the rule is about the cost of "
            + "switching the flag off",
        "StatusItemController+Menu.swift":
            "builds the quick menu's rows and states enablement only "
            + "where a row greys (the starting count) or must stay "
            + "live (Start Tiling, Open KiwiHub, #2309); the rest "
            + "SHOULD be enabled and unstated means enabled. Its "
            + "menu is created in StatusItemController.swift, so "
            + "the per-menu flag count cannot pair it here",
    ]

}
