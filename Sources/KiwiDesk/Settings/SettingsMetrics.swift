import SwiftUI

/// Shared row metrics for the settings tabs: every labeled
/// control row hangs its control off the same leading axis,
/// and every slider readout shares one column width, so
/// controls start and end on one line across sections instead
/// of each row picking its own label width.
enum SettingsMetrics {
    /// The label column in front of sliders, segmented pickers
    /// and dropdowns. The longest row label in use ("Mouse
    /// resize action") measures ~121 pt at body size; 150 also
    /// holds the label-adjacent help `?` (#94 placement, ~24 pt
    /// glyph + chip + gap) on rows that carry one — rows
    /// without help just gain truncation headroom for longer
    /// locales.
    static let labelColumn: CGFloat = 150

    /// `OverrideChrome`'s leading padding and checkbox
    /// spacing — consumed by the chrome itself, so retuning
    /// the chrome moves `overrideLabelColumn` in lockstep.
    static let overrideRowInset: CGFloat = 8

    /// The native checkbox's width — an AppKit metric no
    /// constant can truly pin; best estimate.
    static let checkboxWidth: CGFloat = 18

    /// The label column inside `OverrideChrome`, whose
    /// checkbox prefixes every row (inset + checkbox + inset):
    /// shrinking the label by that prefix lands the override
    /// row's control on the same axis as the plain rows. The
    /// chrome re-scopes the shared rows onto this via
    /// `\.settingsLabelColumn`. The discount means a label
    /// that fits `labelColumn` can still wrap here — override
    /// labels must measure under ~116 pt at body size (the
    /// old 94 pt column bit "Focused anchor" at 97 pt,
    /// shortened to "Focus anchor"; it would fit again now);
    /// the shared rows' `lineLimit(1)` makes an overflow
    /// truncate visibly instead of wrapping quietly.
    static let overrideLabelColumn: CGFloat =
        labelColumn - (2 * overrideRowInset + checkboxWidth)

    /// The label column for the Drag & Drop editor's two
    /// half-width columns (#231). Narrower than the shared 150,
    /// pushed onto every row in a column via the
    /// `\.settingsLabelColumn` override (the seam
    /// `OverrideChrome` uses), so a half-width column still
    /// leaves the slider real travel. The rows there are
    /// relabeled to their
    /// in-group short forms ("Color", "Width", "Alignment") so
    /// this width holds; headroom over "Alignment" (~58 pt at
    /// body) covers a longer localization before `lineLimit(1)`
    /// would truncate.
    static let dragColumnLabelColumn: CGFloat = 80

    /// The fixed slot for each App Rules facet menu (#260).
    /// Reserving one width stops the Float facet's x drifting row
    /// to row with the current Space value's length, so the list
    /// column-aligns like a native list-style pane. Sized for the
    /// widest Float option ("Windows titled…") plus the chevron;
    /// longer Space values truncate (`lineLimit(1)`) rather than
    /// push the column. Off the shared `settingsLabelColumn` axis
    /// (the facet grid is self-contained), so it lives here for
    /// discoverability beside the other feature-scoped column
    /// constants, not because it shares that axis.
    static let facetControlColumn: CGFloat = 140

    /// The trailing readout of a slider row. Sized for the
    /// widest STRING in use — which is no longer a number: an
    /// Auto-sentinel slider prints "Automatic" there (R6/#406),
    /// longer than "2000 pt". Widened 64 → 84 for it; a locale
    /// that runs longer still shrinks via `minimumScaleFactor`
    /// rather than clipping (`PtSlider`).
    static let readoutColumn: CGFloat = 84

    /// `HexColorField`'s label column. The color fields live
    /// in their own two-column grid, deliberately NOT on the
    /// shared row axis (120-ish would misalign the grid's
    /// second column) — don't "fix" them onto `labelColumn`.
    static let colorLabelColumn: CGFloat = 140

    /// The label column for a color swatch inside an
    /// `OverrideChrome` row (#2). An override color cell is a
    /// half-width grid cell that also spends ~34 pt on the
    /// leading checkbox (`overrideRowInset` + `checkboxWidth` +
    /// inset) before the swatch and hex field, so the label is
    /// deliberately narrower than Global's ungated
    /// `colorLabelColumn` (140) to keep the cell inside half the
    /// pane — not to align the swatch onto Global's axis (that
    /// would need ~106 pt). 80 pt fits the English labels;
    /// longer locales (e.g. German "Gruppen-Badge") truncate
    /// with `lineLimit(1)` rather than wrap, and the same field
    /// still shows full at 140 pt in Global's grid — an
    /// asymmetry the half-width cell forces, tracked on #135.
    static let overrideColorLabelColumn: CGFloat = 80

    /// The inline hex `TextField` beside each color swatch.
    /// Fixed (not auto-sizing) so the two-column color grid in
    /// `AppBarGroups` keeps stable cell widths as values
    /// change; sized for the widest stored form, "#RRGGBBAA".
    static let colorHexColumn: CGFloat = 84
}

private struct SettingsLabelColumnKey: EnvironmentKey {
    static let defaultValue: CGFloat =
        SettingsMetrics.labelColumn
}

extension EnvironmentValues {
    /// The label-column width the shared rows read.
    /// `OverrideChrome` narrows it once for everything it
    /// wraps, so a row is on the override axis by construction
    /// instead of every row type plumbing a width parameter.
    var settingsLabelColumn: CGFloat {
        get { self[SettingsLabelColumnKey.self] }
        set { self[SettingsLabelColumnKey.self] = newValue }
    }
}
