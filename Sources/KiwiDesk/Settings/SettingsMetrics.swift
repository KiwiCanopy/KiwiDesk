import SwiftUI

/// Shared row metrics for the settings tabs: every labeled
/// control row hangs its control off the same leading axis,
/// and every slider readout shares one column width, so
/// controls start and end on one line across sections instead
/// of each row picking its own label width.
enum SettingsMetrics {
    /// The label column in front of sliders, segmented pickers
    /// and dropdowns. Holds the label-adjacent help `?` (#94
    /// placement, ~24 pt glyph + chip + gap) on rows that carry
    /// one.
    ///
    /// Widened from 150 to 210 when #95 landed the remaining
    /// eight languages. 150 was sized for English ("Mouse resize
    /// action", ~121 pt) and de; measured across all eleven
    /// locales, 53 of 451 row labels overflowed it — `es` 12,
    /// `ru` 11, `fr` 10, `pt-BR` 9, `it` 8, `de` 2, `ja` 1, with
    /// `en`/`ko`/`zh-*` clean. 210 cleared 43 of those 53; the
    /// remaining ten would have needed ~280 pt, which would cost
    /// every slider and picker in the app 130 pt of travel to
    /// serve five keys. Those five were shortened instead — one
    /// of them, `es` "Retardo de cambio al arrastrar (Spring
    /// delay)", was carrying a translator's English gloss in
    /// parentheses at 273 pt.
    ///
    /// **Nothing in any shipped locale truncates here today.**
    /// That is the state to keep, and the rule that keeps it:
    /// measure a new label, and past ~210 pt shorten the label
    /// rather than moving this number again — it is the shared
    /// alignment axis for every section, so it trades control
    /// width app-wide. A Settings label wants to be short in
    /// every language regardless.
    static let labelColumn: CGFloat = 210

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
    /// that fits `labelColumn` can still truncate here; the
    /// shared rows' `lineLimit(1)` makes that visible rather
    /// than a quiet wrap.
    ///
    /// It rides `labelColumn`, so #95's widening moved it 116 →
    /// 176, and every override label in every shipped locale now
    /// fits (the two that did not — `es`/`ru` "App symbol style" —
    /// were shortened instead, since an override label sits on the
    /// app's narrowest surface and wants the terser form anyway).
    /// Worth knowing what the widening costs there:
    /// the per-space popover is 392 pt, so an override row there
    /// now leaves ~150 pt for its control instead of ~210. That
    /// still holds its menus (the widest value, "Column width",
    /// measures well under it) — but it is the surface to check
    /// first if this number moves again, since it has the least
    /// room and no plain rows to align with.
    static let overrideLabelColumn: CGFloat =
        labelColumn - (2 * overrideRowInset + checkboxWidth)

    /// The label column for the Drag & drop editor's two
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
    /// wider than "2000 pt".
    ///
    /// 72, measured not guessed. The readouts render in the
    /// PROPORTIONAL system font with `monospacedDigit()` — System
    /// Settings' own idiom — so digit runs stay tabular ("8 pt"
    /// and "2000 pt" still stack) while letters render at their
    /// natural width. At 13 pt that is "Automatic" 61.3 and
    /// "2000 pt" 48.5, against 72.3 / 56.3 in the monospaced
    /// face this replaced: the same headroom ratio the retired
    /// 64 pt constant used, for 12 pt less column. A locale
    /// whose term runs longer (de "Automatisch", 75.6) shrinks
    /// via `minimumScaleFactor` rather than clipping.
    static let readoutColumn: CGFloat = 72

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
