import SwiftUI

/// The Settings window's width bands (#678 turn 17a) and the one
/// place they are derived. Everything the shell drops as the
/// window narrows is a property on this type: the shell measures
/// once, publishes the CLASS, and every site asks it rather than
/// comparing a width of its own — the reserved-key lesson from
/// pass 7, where three sites each re-derived one predicate.
///
/// The bands come from the digest's ruled ORDER — "drop the
/// preview before you drop a control": the preview goes first
/// (1200), then the row layout reflows (900), then the chrome
/// collapses (820), **and controls never**. Below 720 the window
/// stops resizing (`SettingsView`'s `minWidth`), because a
/// settings window narrower than that is one where every row is
/// two lines and nothing is comparable.
///
/// The order is not decoration: it is why the properties below
/// are derived from each other rather than each keyed on its own
/// number. `docksSavePill` IS `stacksRows` — one threshold, so
/// the two cannot drift apart — and `SettingsResponsiveOrderTests`
/// walks every supported width to hold the implications.
enum SettingsWidthClass: String, CaseIterable, Sendable {
    /// ≥ 1200: the preview panel is docked beside the content,
    /// the shell's fullest form.
    case wide
    /// 900 ..< 1200: the panel detaches into a floating card
    /// over the content; rows keep their full width, because a
    /// segmented control that wraps is worse than a preview you
    /// have to move.
    case medium
    /// 820 ..< 900: rows go two-line and the save pill docks
    /// into a real footer bar — at this width a floating pill
    /// sits on top of the rows it is about.
    case compact
    /// < 820, down to the 720 hard minimum: the header chrome
    /// collapses too, the search field becoming an icon that
    /// opens it. No control leaves.
    case tight

    /// The three ruled breakpoints and the hard minimum. Public
    /// on the type because the shell's `minWidth` and the tests
    /// read the same numbers — a second copy of 720 anywhere is
    /// the drift this enum exists to prevent.
    static let panelBreakpoint: CGFloat = 1200
    static let rowBreakpoint: CGFloat = 900
    static let chromeBreakpoint: CGFloat = 820
    static let minimum: CGFloat = 720
    /// The shell's minimum content HEIGHT — the other half of the
    /// floor, named here beside its partner so a surface sized
    /// against the window derives from it rather than restating it
    /// (#859: a sheet's own bounds were literals whose comment
    /// claimed a relation to this number that did not hold).
    ///
    /// This type is about width BANDS and this is not one; it lives
    /// here because the MINIMUM is one fact with two axes — the
    /// smallest content rectangle the window may present — and
    /// splitting that across two files is how one half moves
    /// without the other.
    ///
    /// Scoped to the minimum deliberately. The window's opening
    /// WIDTH derives from a band
    /// (`SettingsWindowController.firstRunWidth`) while its opening
    /// HEIGHT is still a bare literal there — the very number
    /// #859's false claim was measured against. Naming that one too
    /// is a separate change; this docstring does not claim to have
    /// done it (re-review, 2026-08-17).
    static let minimumHeight: CGFloat = 540

    static func of(width: CGFloat) -> SettingsWidthClass {
        if width >= panelBreakpoint { return .wide }
        if width >= rowBreakpoint { return .medium }
        if width >= chromeBreakpoint { return .compact }
        return .tight
    }

    /// Whether the preview panel keeps its own column beside the
    /// content. Below this the area still HAS a preview — it
    /// floats (`floatsPreviewByDefault`) or waits behind the
    /// "Show preview" offer — so this is a layout verdict, never
    /// a capability one.
    var docksPanel: Bool { self == .wide }

    /// Whether a detached preview card shows itself without
    /// being asked. The 1100 pt frame draws the card open; the
    /// 820 pt frame draws "Show preview" instead, and this is
    /// the whole difference between them — one mechanism, two
    /// defaults, so the card the user closes at 1100 and the
    /// card they summon at 820 are the same card.
    var floatsPreviewByDefault: Bool { self == .medium }

    /// Whether a labelled row puts its control on a second line
    /// under the label instead of on the shared label axis
    /// (`SettingsMetrics.labelColumn`). Read by
    /// `SettingsRowShape`, which is the one arrangement site.
    var stacksRows: Bool { self == .compact || self == .tight }

    /// Whether the save pill stops floating and becomes a real
    /// footer bar — "same content, same three verbs, different
    /// physics", the one component that changes KIND rather than
    /// size. Derived from `stacksRows` rather than re-tested
    /// against 900: the digest gives both the same threshold, and
    /// two spellings of one number is how they come apart.
    var docksSavePill: Bool { stacksRows }

    /// Whether the header collapses its search field into an
    /// icon. The last thing to go, and it takes nothing with it:
    /// the icon opens the same field, in the same row, and the
    /// area title yields to it for as long as it is open.
    var collapsesChrome: Bool { self == .tight }

    /// Home's column ceiling. The count still derives from the
    /// measured width below this (`HomeScreen.columns`) — cards
    /// grow into a big screen up to their 360 pt maximum rather
    /// than a fifth column appearing (owner 2026-08-10) — so
    /// this caps the top end per band and the measurement owns
    /// the way down. At the 720 minimum the measurement lands on
    /// 2, which is why no band names 1: a single 688 pt-wide card
    /// is not a step this window can reach.
    var homeColumnCap: Int {
        switch self {
        case .wide: return 4
        case .medium: return 3
        case .compact, .tight: return 2
        }
    }

    /// The preset grid's cap — one column fewer than Home's at
    /// every band, DERIVED rather than re-tabulated (#789).
    ///
    /// Derived because the two share a threshold and this file's
    /// own rule is that properties which do are derived from each
    /// other, never re-tested against the number. One fewer
    /// because Home spans the whole shell while the preset grid
    /// sits in the CONTENT column, which gives up its width to
    /// the detail panel wherever one is offered; a cap copied
    /// from Home would put four preset cards in the room three
    /// Home cards were eye-confirmed at.
    ///
    /// At `.tight` this is 1, and that is the honest answer
    /// rather than a degenerate one: a grid whose cards cannot
    /// hold a picture, a title, two lines of prose and a button
    /// side by side is a list, and reflowing to one is the grid
    /// working. Reflow is not a control leaving, so the ruled
    /// narrowing order is untouched.
    var presetColumnCap: Int { max(1, homeColumnCap - 1) }
}

private struct SettingsWidthClassKey: EnvironmentKey {
    /// The full shell, so a view mounted outside the measured
    /// window — a preview, a test constructing a row directly —
    /// behaves as it did before this pass.
    static let defaultValue = SettingsWidthClass.wide
}

extension EnvironmentValues {
    /// The measured width band. Injected ONCE, by
    /// `SettingsView`, from the shell's own geometry; every
    /// responsive decision in the tree reads it from here.
    var settingsWidth: SettingsWidthClass {
        get { self[SettingsWidthClassKey.self] }
        set { self[SettingsWidthClassKey.self] = newValue }
    }
}
