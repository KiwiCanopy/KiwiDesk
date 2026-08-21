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
    /// tell a SPLIT from a whole file: move `screenItem` and
    /// `everyScreenItem` into their own file at §2.1's next
    /// squeeze — which this file is one row away from needing —
    /// and their rows go unguarded with the suite green. That is
    /// `gui.md`'s scan-root rule (`ChromeScanRoots` is the worked
    /// example): a new tree joins the list, and the guard carries a
    /// root-coverage check.
    ///
    /// **`StatusItemController+Menu.swift` is deliberately NOT
    /// here yet, and adding it reds.** That file constructs ten
    /// rows and states enablement on five, while its own header
    /// says "Every row below states its own `isEnabled` (#802)" —
    /// a false claim, though not a defect: the seven unstated rows
    /// (`paused`, `issues`, `shortcuts`, `settings`, `quit`, the
    /// switcher parent, a profile entry) all SHOULD be enabled,
    /// and unstated means enabled. So the rows are right and the
    /// sentence is wrong, which is #802's surface rather than this
    /// branch's — filed, not swept. Adding it here is the fix's
    /// second half.
    static let checked = [
        "Sources/KiwiDesk/StatusItemController+Layout.swift",
        // The Check-for-Updates row (#874). It joins the CHECKED
        // list rather than the exempt one because its enablement
        // is genuinely conditional — Sparkle refuses while a check
        // is running or an update is mid-install — so it is the
        // first quick-menu row that has to state `isEnabled` for a
        // reason rather than by convention.
        "Sources/KiwiDesk/StatusItemController+Updates.swift",
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
            "constructs ten rows and states five; the seven "
            + "unstated ones all SHOULD be enabled, so the rows "
            + "are right and only the file's own header claim is "
            + "wrong — #802's surface, filed rather than swept",
    ]

}
