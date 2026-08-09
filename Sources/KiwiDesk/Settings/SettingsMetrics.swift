import SwiftUI

/// Shared layout metrics for the Settings window. Chiefly the
/// row axes: every labeled control row hangs its control off the
/// same leading axis, and every slider readout shares one column
/// width, so controls start and end on one line across sections
/// instead of each row picking its own label width.
///
/// It also holds the surface-scoped columns that ride those
/// axes or stand beside them — the override chrome's, the
/// facet control's, the icon tile's. They live here rather
/// than on their views for discoverability and because each is
/// a *budget* something else must fit: a constant on a view is
/// one nobody measures against.
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

    /// The gutter around a destination pane's scrolling content.
    /// Horizontal and bottom are ordinary padding on the content;
    /// the TOP is spent as the scroll viewport's content margin
    /// instead (`SettingsView.detailPane`), which is what gives a
    /// revealed card the same gutter above it that a pane's first
    /// card has at rest.
    ///
    /// `scrollTo(anchor: .top)` aligns the target's top edge with
    /// the viewport's, so before the margin existed any card but
    /// a pane's first landed flush — and the reveal wash, which
    /// bleeds 4 pt past its content, had its rounded top corners
    /// clipped into a flat edge by the scroll view's own bounds.
    /// Spending the gutter as a margin rather than as padding is
    /// what fixes both.
    ///
    /// ONE number for both roles, and that is the design, not a
    /// shortcut: a content margin moves what "top of the
    /// viewport" means, so it cannot give a revealed card a
    /// different gutter from a resting one. Tried 30 on device to
    /// give reveals more room — it reads as too airy at rest,
    /// because it moves every pane too. The equality is the point:
    /// a revealed card should look like a pane you scrolled to the
    /// top yourself, not like a bespoke state.
    static let paneInset: CGFloat = 16

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

    /// `SidebarTile`, the destination icon square — since #678
    /// turn 9 it fronts the search result rows and the Home
    /// cards rather than a sidebar list (the fixed column and
    /// its label budget retired with the sidebar; card titles
    /// flex and wrap instead, the redesign's own rule for row
    /// labels).
    static let sidebarTile: CGFloat = 22

    /// The label column for a pair of half-width drag columns.
    /// Narrower than the shared 150, so a half-width column
    /// still leaves its control real travel, and the rows are
    /// relabeled to their in-group short forms ("Color",
    /// "Width") so this width holds; headroom over the longest
    /// of those covers a longer localization before
    /// `lineLimit(1)` would truncate.
    ///
    /// Born for the Gaps & Borders drag editor (#231), pushed
    /// in there through the `\.settingsLabelColumn` override.
    /// That editor's last narrow-axis row left in #754 and the
    /// override with it; what reads this now is Advanced
    /// Colours' twin drag columns, which pass it directly as
    /// `AdvancedColorRow`'s `labelWidth:`.
    static let dragColumnLabelColumn: CGFloat = 80

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

    /// The trailing "OVERRIDE" column in the per-space override
    /// editor (#678 8b): wide enough to seat the small-caps header
    /// over the checkbox below it, so the two align down the card.
    static let overrideStateColumn: CGFloat = 64
}

private struct SettingsLabelColumnKey: EnvironmentKey {
    static let defaultValue: CGFloat =
        SettingsMetrics.labelColumn
}

private struct OverrideLayoutNameKey: EnvironmentKey {
    static let defaultValue = ""
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

    /// The active layout's display name, set once by
    /// `SpaceOverrideRows` so each `OverrideChrome` can render
    /// "follows <Layout> defaults · <value>" without every row
    /// threading the mode through (#678 8b). The default is empty:
    /// an inheriting row is unusable without the wire (it would read
    /// "follows  defaults · …"), so the one injector is load-bearing
    /// — `SpaceOverrideRows` sets it on the card, and no other view
    /// mounts these rows.
    var overrideLayoutName: String {
        get { self[OverrideLayoutNameKey.self] }
        set { self[OverrideLayoutNameKey.self] = newValue }
    }
}
